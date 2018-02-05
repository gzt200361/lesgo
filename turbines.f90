!!
!!  Copyright (C) 2010-2016  Johns Hopkins University
!!
!!  This file is part of lesgo.
!!
!!  lesgo is free software: you can redistribute it and/or modify
!!  it under the terms of the GNU General Public License as published by
!!  the Free Software Foundation, either version 3 of the License, or
!!  (at your option) any later version.
!!
!!  lesgo is distributed in the hope that it will be useful,
!!  but WITHOUT ANY WARRANTY; without even the implied warranty of
!!  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!!  GNU General Public License for more details.
!!
!!  You should have received a copy of the GNU General Public License
!!  along with lesgo.  If not, see <http://www.gnu.org/licenses/>.
!!

!*******************************************************************************
module turbines
!*******************************************************************************
! This module contains all of the subroutines associated with drag-disk turbines

use types, only : rprec
use param
use grid_m
use messages
use string_util
use stat_defs, only : wind_farm
use bi_pchip
use wake_model_estimator
use turbines_mpc
use lbfgsb
#ifdef PPMPI
use mpi_defs, only : MPI_SYNC_DOWNUP, mpi_sync_real_array
#endif

implicit none

save
private

public :: turbines_init, turbines_forcing, turbine_vel_init, turbines_finalize,&
          generate_splines, count_lines

character (*), parameter :: mod_name = 'turbines'

! The following values are read from the input file
! number of turbines in the x-direction
integer, public :: num_x
! number of turbines in the y-direction
integer, public :: num_y
! baseline diameter in meters
real(rprec), public :: dia_all
! baseline height in meters
real(rprec), public :: height_all
! baseline thickness in meters
real(rprec), public :: thk_all
! orientation of turbines
integer, public :: orientation
! stagger percentage from baseline
real(rprec), public :: stag_perc
! angle from upstream (CCW from above, -x dir is zero)
real(rprec), public :: theta1_all
! angle above horizontal
real(rprec), public :: theta2_all
! thrust coefficient (default 1.33)
real(rprec), public :: Ct_prime
! power coefficient (default 1.33)
real(rprec), public :: Cp_prime
! Read parameters from input_turbines/param.dat
logical, public :: read_param
! Dynamically change theta1 from input_turbines/theta1.dat
logical, public :: dyn_theta1
! Dynamically change theta2 from input_turbines/theta2.dat
logical, public :: dyn_theta2
! disk-avg time scale in seconds (default 600)
real(rprec), public :: T_avg_dim
! filter size as multiple of grid spacing
real(rprec), public :: alpha
! indicator function only includes values above this threshold
real(rprec), public :: filter_cutoff
! Number of timesteps between the output
integer, public :: tbase
! Air density
real(rprec), public :: rho
! Inertia (kg*m^2)
real(rprec), public :: inertia_all
! Torque gain (kg*m^2)
real(rprec), public :: torque_gain
! Use wake model or not
logical, public :: use_wake_model
! time constant for estimating freestream velocity [seconds]
real(rprec), public :: tau_U_infty = 300
! std. deviation of noise of velocity deficit
real(rprec), public :: sigma_du = 0.5
! std. deviation of noise of wake expansion coefficient
real(rprec), public :: sigma_k = 0.001
! std. deviation of noise of power measurements
real(rprec), public :: sigma_uhat = 1.0
! Number of members in ensemble
integer, public :: num_ensemble = 50
! Use_receding horizon or not
logical, public :: use_receding_horizon
! Minimization solver: 1->Conjugate gradient; 2->L-BGFGS-B
integer, public :: solver
! Number of time steps between controller evaluations
integer, public :: advancement_base
! Length of receding horizon [seconds]
real(rprec), public :: horizon_time
! Maximum number of iterations for each minimization
integer, public     :: max_iter
! Rotational speed limits (in rad/s)
real(rprec), public :: speed_penalty
real(rprec), public :: omega_min
real(rprec), public :: omega_max
! Optimal pitch angle and TSR
real(rprec), public :: beta_penalty
real(rprec), public :: beta_star
real(rprec), public :: tsr_penalty
real(rprec), public :: lambda_prime_star

! Scaling of receding horizon
real(rprec) :: Ca = BOGUS, Cb = BOGUS

! The following are derived from the values above
integer :: nloc             ! total number of turbines
real(rprec) :: sx           ! spacing in the x-direction, multiple of diameter
real(rprec) :: sy           ! spacing in the y-direction

! Arrays for interpolating dynamic controls
real(rprec), dimension(:,:), allocatable :: theta1_arr
real(rprec), dimension(:), allocatable :: theta1_time
real(rprec), dimension(:,:), allocatable :: theta2_arr
real(rprec), dimension(:), allocatable :: theta2_time
real(rprec), dimension(:), allocatable :: Pref_arr
real(rprec), dimension(:), allocatable :: Pref_time
real(rprec), dimension(:,:), allocatable :: torque_gain_arr
real(rprec), dimension(:,:), allocatable :: beta_arr
real(rprec), dimension(:), allocatable :: rh_time

! Arrays for interpolating power and thrust coefficients for LES
type(bi_pchip_t), public :: Cp_prime_spline, Ct_prime_spline

! Input files
character(*), parameter :: input_folder = 'input_turbines/'
character(*), parameter :: param_dat = path // input_folder // 'param.dat'
character(*), parameter :: theta1_dat = path // input_folder // 'theta1.dat'
character(*), parameter :: theta2_dat = path // input_folder // 'theta2.dat'
character(*), parameter :: Ct_dat = path // input_folder // 'Ct.dat'
character(*), parameter :: Cp_dat = path // input_folder // 'Cp.dat'
character(*), parameter :: lambda_dat = path // input_folder // 'lambda.dat'
character(*), parameter :: beta_dat = path // input_folder // 'beta.dat'
character(*), parameter :: phi_dat = path // input_folder // 'phi.dat'
character(*), parameter :: Pref_dat = path // input_folder // 'Pref.dat'

! Output files
character(*), parameter :: output_folder = 'turbine/'
character(*), parameter :: vel_top_dat = path // output_folder // 'vel_top.dat'
character(*), parameter :: u_d_T_dat = path // output_folder // 'u_d_T.dat'
character(*), parameter :: rh_dat = path // output_folder // 'rh.dat'
integer, dimension(:), allocatable :: forcing_fid

! epsilon used for disk velocity time-averaging
real(rprec) :: eps

! Commonly used indices
integer :: i, j, k, i2, j2, k2, l, s
integer :: k_start, k_end

! for MPI sending and receiving
real(rprec), dimension(:), allocatable :: buffer_array

! Wake model
type(wake_model_estimator_t) :: wm
character(*), parameter :: wm_path = path // 'wake_model'
integer, dimension(:), allocatable :: wm_fid
type(bi_pchip_t), public :: wm_Cp_prime_spline, wm_Ct_prime_spline

! controller
type(turbines_mpc_t) :: controller
type(lbfgsb_t) :: m

contains

!*******************************************************************************
subroutine turbines_init()
!*******************************************************************************
!
! This subroutine creates the 'turbine' folder and starts the turbine forcing
! output files. It also creates the indicator function (Gaussian-filtered from
! binary locations - in or out) and sets values for turbine type
! (node locations, etc)
!
use open_file_fid_mod
implicit none

real(rprec), pointer, dimension(:) :: x,y,z
character (*), parameter :: sub_name = mod_name // '.turbines_init'
integer :: fid
real(rprec) :: T_avg_dim_file, delta2
logical :: test_logical, exst
character (100) :: string1

! Turn on wake model if use_receding_horizon
if (use_receding_horizon) use_wake_model = .true.

! Set pointers
nullify(x,y,z)
x => grid % x
y => grid % y
z => grid % z

! Allocate and initialize
nloc = num_x*num_y
nullify(wind_farm%turbine)
allocate(wind_farm%turbine(nloc))
allocate(buffer_array(nloc))

! Create turbine directory
call system("mkdir -vp turbine")
if (use_wake_model) call system("mkdir -vp wake_model")

! Non-dimensionalize length values by z_i
height_all = height_all / z_i
dia_all = dia_all / z_i
thk_all = thk_all / z_i

! Spacing between turbines (as multiple of mean diameter)
sx = L_x / (num_x * dia_all )
sy = L_y / (num_y * dia_all )

! Place the turbines and specify some parameters
call place_turbines

! Resize thickness to capture at least on plane of gridpoints
! and set baseline values for size
do k = 1, nloc
    wind_farm%turbine(k)%thk = max(wind_farm%turbine(k)%thk, dx * 1.01)
    wind_farm%turbine(k)%vol_c = dx*dy*dz/(pi/4.*(wind_farm%turbine(k)%dia)**2 &
        * wind_farm%turbine(k)%thk)
end do

! Specify starting and ending indices for the processor
#ifdef PPMPI
k_start = 1+coord*(nz-1)
k_end = nz-1+coord*(nz-1)
#else
k_start = 1
k_end = nz
#endif

! Find the center of each turbine
do k = 1,nloc
    wind_farm%turbine(k)%icp = nint(wind_farm%turbine(k)%xloc/dx)
    wind_farm%turbine(k)%jcp = nint(wind_farm%turbine(k)%yloc/dy)
    wind_farm%turbine(k)%kcp = nint(wind_farm%turbine(k)%height/dz + 0.5)

    ! Check if turbine is the current processor
    test_logical = wind_farm%turbine(k)%kcp >= k_start .and.                   &
           wind_farm%turbine(k)%kcp<=k_end
    if (test_logical) then
        wind_farm%turbine(k)%center_in_proc = .true.
    else
        wind_farm%turbine(k)%center_in_proc = .false.
    end if

    ! Make kcp the local index
    wind_farm%turbine(k)%kcp = wind_farm%turbine(k)%kcp - k_start + 1

end do

! Read dynamic control input files
call read_control_files

! Read power and thrust coefficient curves
call generate_splines

!Compute a lookup table object for the indicator function
delta2 = alpha**2 * (dx**2 + dy**2 + dz**2)
do s = 1, nloc
    call  wind_farm%turbine(s)%turb_ind_func%init(delta2,                      &
            wind_farm%turbine(s)%thk, wind_farm%turbine(s)%dia,                &
            max( max(nx, ny), nz) )
end do

! Find turbine nodes - including filtered ind, n_hat, num_nodes, and nodes for
! each turbine. Each processor finds turbines in its domain
call turbines_nodes

! Read the time-averaged disk velocities from file if available
inquire (file=u_d_T_dat, exist=exst)
if (exst) then
    if (coord == 0) write(*,*) 'Reading from file ', trim(u_d_T_dat)
    fid = open_file_fid( u_d_T_dat, 'rewind', 'formatted' )
    do i=1,nloc
        wind_farm%turbine(i)%torque_gain = torque_gain
        wind_farm%turbine(i)%beta = 0._rprec
        read(fid,*) wind_farm%turbine(i)%u_d_T, wind_farm%turbine(i)%omega
    end do
    read(fid,*) T_avg_dim_file
    if (T_avg_dim_file /= T_avg_dim) then
        if (coord == 0) then
            write(*,*) 'Time-averaging window does not match value in ',   &
                   trim(u_d_T_dat)
        end if
    end if
    close (fid)
else
    if (coord == 0) write (*, *) 'File ', trim(u_d_T_dat), ' not found'
    if (coord == 0) write (*, *) 'Assuming u_d_T = -8, omega = 1 for all turbines'
    do k=1,nloc
        wind_farm%turbine(k)%u_d_T = -8._rprec
        wind_farm%turbine(k)%omega = 1._rprec
        wind_farm%turbine(k)%torque_gain = torque_gain
        wind_farm%turbine(k)%beta = 0._rprec
    end do
end if

! Calculate Ct_prime and Cp_prime
do i = 1, nloc
    call Ct_prime_spline%interp(0._rprec, -wind_farm%turbine(i)%omega * 0.5    &
        * wind_farm%turbine(i)%dia * z_i / wind_farm%turbine(i)%u_d_T / u_star,&
         wind_farm%turbine(i)%Ct_prime)
    call Cp_prime_spline%interp(0._rprec, -wind_farm%turbine(i)%omega * 0.5    &
        * wind_farm%turbine(i)%dia * z_i / wind_farm%turbine(i)%u_d_T / u_star,&
         wind_farm%turbine(i)%Cp_prime)
end do

! Generate top of domain file
if (coord .eq. nproc-1) then
    fid = open_file_fid( vel_top_dat, 'rewind', 'formatted' )
    close(fid)
end if

! Generate the files for the turbine forcing output
allocate(forcing_fid(nloc))
if(coord==0) then
    do s=1,nloc
        call string_splice( string1, path // 'turbine/turbine_', s, '.dat' )
        forcing_fid(s) = open_file_fid( string1, 'append', 'formatted' )
    end do
end if

if (use_wake_model) call wake_model_init
if (use_receding_horizon) call receding_horizon_init

nullify(x,y,z)

end subroutine turbines_init

!*******************************************************************************
subroutine turbines_nodes
!*******************************************************************************
!
! This subroutine locates nodes for each turbine and builds the arrays: ind,
! n_hat, num_nodes, and nodes
!
implicit none

character (*), parameter :: sub_name = mod_name // '.turbines_nodes'

real(rprec) :: rx,ry,rz,r,r_norm,r_disk

real(rprec), pointer :: p_xloc => null(), p_yloc => null(), p_height => null()
real(rprec), pointer :: p_dia => null(), p_thk => null()
real(rprec), pointer :: p_theta1 => null(), p_theta2 => null()
real(rprec), pointer :: p_nhat1 => null(), p_nhat2=> null(), p_nhat3 => null()
integer :: icp, jcp, kcp
integer :: imax, jmax, kmax
integer :: min_i, max_i, min_j, max_j, min_k, max_k
integer :: count_i, count_n
real(rprec), dimension(:), allocatable :: z_tot

real(rprec), pointer, dimension(:) :: x, y, z

real(rprec) :: filt
real(rprec), dimension(:), allocatable :: sumA, turbine_vol

nullify(x,y,z)

x => grid % x
y => grid % y
z => grid % z

allocate(sumA(nloc))
allocate(turbine_vol(nloc))
sumA = 0

! z_tot for total domain (since z is local to the processor)
allocate(z_tot(nz_tot))
do k = 1,nz_tot
    z_tot(k) = (k - 0.5_rprec) * dz
end do

do s=1,nloc

    count_n = 0    !used for counting nodes for each turbine
    count_i = 1    !index count - used for writing to array "nodes"

    !set pointers
    p_xloc => wind_farm%turbine(s)%xloc
    p_yloc => wind_farm%turbine(s)%yloc
    p_height => wind_farm%turbine(s)%height
    p_dia => wind_farm%turbine(s)%dia
    p_thk => wind_farm%turbine(s)%thk
    p_theta1 => wind_farm%turbine(s)%theta1
    p_theta2 => wind_farm%turbine(s)%theta2
    p_nhat1 => wind_farm%turbine(s)%nhat(1)
    p_nhat2 => wind_farm%turbine(s)%nhat(2)
    p_nhat3 => wind_farm%turbine(s)%nhat(3)

    !identify "search area"
    imax = int(p_dia/dx + 2)
    jmax = int(p_dia/dy + 2)
    kmax = int(p_dia/dz + 2)

    !determine unit normal vector for each turbine
    p_nhat1 = -cos(pi*p_theta1/180.)*cos(pi*p_theta2/180.)
    p_nhat2 = -sin(pi*p_theta1/180.)*cos(pi*p_theta2/180.)
    p_nhat3 = sin(pi*p_theta2/180.)

    !determine nearest (i,j,k) to turbine center
    icp = nint(p_xloc/dx)
    jcp = nint(p_yloc/dy)
    kcp = nint(p_height/dz + 0.5)

    !determine limits for checking i,j,k
    !due to spectral BCs, i and j may be < 1 or > nx,ny
    !the mod function accounts for this when these values are used
    min_i = icp-imax
    max_i = icp+imax
    min_j = jcp-jmax
    max_j = jcp+jmax
    min_k = max((kcp-kmax),1)
    max_k = min((kcp+kmax),nz_tot)
    wind_farm%turbine(s)%nodes_max(1) = min_i
    wind_farm%turbine(s)%nodes_max(2) = max_i
    wind_farm%turbine(s)%nodes_max(3) = min_j
    wind_farm%turbine(s)%nodes_max(4) = max_j
    wind_farm%turbine(s)%nodes_max(5) = min_k
    wind_farm%turbine(s)%nodes_max(6) = max_k

    ! check neighboring grid points
    ! update num_nodes, nodes, and ind for this turbine
    ! split domain between processors
    ! z(nz) and z(1) of neighboring coords match so each coord gets
    ! (local) 1 to nz-1
    wind_farm%turbine(s)%ind = 0._rprec
    wind_farm%turbine(s)%nodes = 0
    wind_farm%turbine(s)%num_nodes = 0
    count_n = 0
    count_i = 1

    do k=k_start,k_end  !global k
        do j=min_j,max_j
            do i=min_i,max_i
                ! vector from center point to this node is (rx,ry,rz)
                ! with length r
                if (i<1) then
                    i2 = mod(i+nx-1,nx)+1
                    rx = (x(i2)-L_x) - p_xloc
                elseif (i>nx) then
                    i2 = mod(i+nx-1,nx)+1
                    rx = (L_x+x(i2)) - p_xloc
                else
                    i2 = i
                    rx = x(i) - p_xloc
                end if
                if (j<1) then
                    j2 = mod(j+ny-1,ny)+1
                    ry = (y(j2)-L_y) - p_yloc
                elseif (j>ny) then
                    j2 = mod(j+ny-1,ny)+1
                    ry = (L_y+y(j2)) - p_yloc
                else
                    j2 = j
                    ry = y(j) - p_yloc
                end if
                rz = z_tot(k) - p_height
                r = sqrt(rx*rx + ry*ry + rz*rz)
                !length projected onto unit normal for this turbine
                r_norm = abs(rx*p_nhat1 + ry*p_nhat2 + rz*p_nhat3)
                !(remaining) length projected onto turbine disk
                r_disk = sqrt(r*r - r_norm*r_norm)
                ! get the filter value
                filt = wind_farm%turbine(s)%turb_ind_func%val(r_disk, r_norm)
                if ( filt > filter_cutoff ) then
                    wind_farm%turbine(s)%ind(count_i) = filt
                    wind_farm%turbine(s)%nodes(count_i,1) = i2
                    wind_farm%turbine(s)%nodes(count_i,2) = j2
                    wind_farm%turbine(s)%nodes(count_i,3) = k-coord*(nz-1)!local
                    count_n = count_n + 1
                    count_i = count_i + 1
                    sumA(s) = sumA(s) + filt * dx * dy * dz
                end if
           end do
       end do
    end do
    wind_farm%turbine(s)%num_nodes = count_n

    ! Calculate turbine volume
    turbine_vol(s) = pi/4. * p_dia**2 * p_thk

end do

! Sum the indicator function across all processors if using MPI
#ifdef PPMPI
buffer_array = sumA
call MPI_Allreduce(buffer_array, sumA, nloc, MPI_rprec, MPI_SUM, comm, ierr)
#endif

! Normalize the indicator function
do s = 1, nloc
    wind_farm%turbine(s)%ind=wind_farm%turbine(s)%ind(:)*turbine_vol(s)/sumA(s)
end do

! Cleanup
deallocate(sumA)
deallocate(turbine_vol)
nullify(x,y,z)
deallocate(z_tot)

end subroutine turbines_nodes

!*******************************************************************************
subroutine turbines_forcing()
!*******************************************************************************
!
! This subroutine applies the drag-disk forcing
!
use sim_param, only : u, v, w, fxa, fya, fza
use functions, only : linear_interp, interp_to_uv_grid, bilinear_interp
implicit none

character (*), parameter :: sub_name = mod_name // '.turbines_forcing'

real(rprec), pointer :: p_u_d => null(), p_u_d_T => null(), p_f_n => null()
real(rprec), pointer :: p_Ct_prime => null(), p_Cp_prime => null()
real(rprec), pointer :: p_omega => null()
integer, pointer :: p_icp => null(), p_jcp => null(), p_kcp => null()

real(rprec) :: ind2
real(rprec), dimension(nloc) :: disk_avg_vel, disk_force
real(rprec), dimension(nloc) :: u_vel_center, v_vel_center, w_vel_center
real(rprec), allocatable, dimension(:,:,:) :: w_uv
real(rprec), pointer, dimension(:) :: y,z
real(rprec) :: const
character (64) :: fname

nullify(y,z)
y => grid % y
z => grid % z

allocate(w_uv(ld,ny,lbz:nz))

#ifdef PPMPI
!syncing intermediate w-velocities
call mpi_sync_real_array(w, 0, MPI_SYNC_DOWNUP)
#endif

w_uv = interp_to_uv_grid(w, lbz)

! Do interpolation for dynamically changing parameters
do s = 1, nloc
    if (dyn_theta1) wind_farm%turbine(s)%theta1 =                              &
        linear_interp(theta1_time, theta1_arr(s,:), total_time_dim)
    if (dyn_theta2) wind_farm%turbine(s)%theta2 =                              &
        linear_interp(theta2_time, theta2_arr(s,:), total_time_dim)
end do

! Recompute the turbine position if theta1 or theta2 can change
if (dyn_theta1 .or. dyn_theta2) call turbines_nodes

! Each processor calculates the weighted disk-averaged velocity
disk_avg_vel = 0._rprec
u_vel_center = 0._rprec
v_vel_center = 0._rprec
w_vel_center = 0._rprec
do s=1,nloc
    ! Calculate total disk-averaged velocity for each turbine
    ! (current, instantaneous) in the normal direction. The weighted average
    ! is calculated using "ind"
    do l=1,wind_farm%turbine(s)%num_nodes
        i2 = wind_farm%turbine(s)%nodes(l,1)
        j2 = wind_farm%turbine(s)%nodes(l,2)
        k2 = wind_farm%turbine(s)%nodes(l,3)
        disk_avg_vel(s) = disk_avg_vel(s) + wind_farm%turbine(s)%ind(l)    &
                        * ( wind_farm%turbine(s)%nhat(1)*u(i2,j2,k2)       &
                          + wind_farm%turbine(s)%nhat(2)*v(i2,j2,k2)       &
                          + wind_farm%turbine(s)%nhat(3)*w_uv(i2,j2,k2) )
    end do

    ! Set pointers
    p_icp => wind_farm%turbine(s)%icp
    p_jcp => wind_farm%turbine(s)%jcp
    p_kcp => wind_farm%turbine(s)%kcp

    ! Calculate disk center velocity
    if (wind_farm%turbine(s)%center_in_proc) then
        u_vel_center(s) = u(p_icp, p_jcp, p_kcp)
        v_vel_center(s) = v(p_icp, p_jcp, p_kcp)
        w_vel_center(s) = w_uv(p_icp, p_jcp, p_kcp)
    end if
end do

! Add the velocities
#ifdef PPMPI
call MPI_Allreduce(disk_avg_vel, buffer_array, nloc, MPI_rprec, MPI_SUM, comm, ierr)
disk_avg_vel = buffer_array
call MPI_Allreduce(u_vel_center, buffer_array, nloc, MPI_rprec, MPI_SUM, comm, ierr)
u_vel_center = buffer_array
call MPI_Allreduce(v_vel_center, buffer_array, nloc, MPI_rprec, MPI_SUM, comm, ierr)
v_vel_center = buffer_array
call MPI_Allreduce(w_vel_center, buffer_array, nloc, MPI_rprec, MPI_SUM, comm, ierr)
w_vel_center = buffer_array
#endif

! Calculate total disk force, then sends it back
!update epsilon for the new timestep (for cfl_dt)
if (T_avg_dim > 0.) then
    eps = (dt_dim / T_avg_dim) / (1. + dt_dim / T_avg_dim)
else
    eps = 1.
end if

do s = 1,nloc
    ! set pointers
    p_u_d => wind_farm%turbine(s)%u_d
    p_u_d_T => wind_farm%turbine(s)%u_d_T
    p_f_n => wind_farm%turbine(s)%f_n
    p_Ct_prime => wind_farm%turbine(s)%Ct_prime
    p_Cp_prime => wind_farm%turbine(s)%Cp_prime
    p_omega => wind_farm%turbine(s)%omega

    ! Read control variables
    if (use_receding_horizon) then
        wind_farm%turbine(s)%torque_gain =                                     &
            linear_interp(rh_time, torque_gain_arr(s,:), total_time_dim)
        wind_farm%turbine(s)%beta =                                            &
            linear_interp(rh_time, beta_arr(s,:), total_time_dim)
    end if

    ! Calculate rotational speed. Power needs to be dimensional.
    ! Use the previous step's values.
    const = -p_Cp_prime*0.5*rho*pi*0.25*(wind_farm%turbine(s)%dia*z_i)**2
    p_omega = p_omega + dt_dim / inertia_all * ( const*(p_u_d_T*u_star)**3 /   &
        p_omega - wind_farm%turbine(s)%torque_gain * p_omega**2 )

    !volume correction:
    !since sum of ind is turbine volume/(dx*dy*dz) (not exactly 1.)
    p_u_d = disk_avg_vel(s) * wind_farm%turbine(s)%vol_c

    !add this current value to the "running average" (first order filter)
    p_u_d_T = (1.-eps)*p_u_d_T + eps*p_u_d

    ! Calculate Ct_prime and Cp_prime
    call Ct_prime_spline%interp(wind_farm%turbine(s)%beta, -p_omega * 0.5      &
        * wind_farm%turbine(s)%dia * z_i / p_u_d_T / u_star, p_Ct_prime)
    call Cp_prime_spline%interp(wind_farm%turbine(s)%beta, -p_omega * 0.5      &
        * wind_farm%turbine(s)%dia * z_i / p_u_d_T / u_star, p_Cp_prime)

    ! calculate total thrust force for each turbine  (per unit mass)
    ! force is normal to the surface (calc from u_d_T, normal to surface)
    ! write force to array that will be transferred via MPI
    p_f_n = -0.5*p_Ct_prime*abs(p_u_d_T)*p_u_d_T/wind_farm%turbine(s)%thk
    disk_force(s) = p_f_n

    ! write current step's values to file
    if (modulo (jt_total, tbase) == 0 .and. coord == 0) then
        write( forcing_fid(s), *) total_time_dim, u_vel_center(s)*u_star,      &
            v_vel_center(s)*u_star, w_vel_center(s)*u_star, -p_u_d*u_star,     &
            -p_u_d_T*u_star, wind_farm%turbine(s)%theta1,                      &
            wind_farm%turbine(s)%theta2, wind_farm%turbine(s)%beta, p_Ct_prime,   &
            p_Cp_prime, p_omega, wind_farm%turbine(s)%torque_gain,             &
            wind_farm%turbine(s)%torque_gain*p_omega**2,                       &
            wind_farm%turbine(s)%torque_gain*p_omega**3
    end if
end do

if (coord == 0) write(*,*) "Farm power = ",                                    &
    sum(wind_farm%turbine(:)%torque_gain*wind_farm%turbine(:)%omega**3)

!apply forcing to each node
do s=1,nloc
    do l=1,wind_farm%turbine(s)%num_nodes
        i2 = wind_farm%turbine(s)%nodes(l,1)
        j2 = wind_farm%turbine(s)%nodes(l,2)
        k2 = wind_farm%turbine(s)%nodes(l,3)
        ind2 = wind_farm%turbine(s)%ind(l)
        fxa(i2,j2,k2) = disk_force(s) * wind_farm%turbine(s)%nhat(1) * ind2
        fya(i2,j2,k2) = disk_force(s) * wind_farm%turbine(s)%nhat(2) * ind2
        fza(i2,j2,k2) = disk_force(s) * wind_farm%turbine(s)%nhat(3) * ind2
    end do
end do

!spatially average velocity at the top of the domain and write to file
if (coord .eq. nproc-1) then
    open(unit=1,file=vel_top_dat,status='unknown',form='formatted',            &
        action='write',position='append')
    write(1,*) total_time, sum(u(:,:,nz-1))/(nx*ny)
    close(1)
end if

! Update wake model
if (use_wake_model) then
    call wm%advance(dt_dim, -wind_farm%turbine(:)%u_d_T*u_star,                &
        wind_farm%turbine(:)%omega, wind_farm%turbine(:)%beta,                 &
        wind_farm%turbine(:)%torque_gain)

    ! write values to file
    if (modulo (jt_total, tbase) == 0 .and. coord == 0) then
        do s = 1, nloc
            write(wm_fid(s), *) total_time_dim, wm%wm%Ctp(s), wm%wm%Cpp(s),    &
                wm%wm%uhat(s), wm%wm%omega(s), wm%wm%Phat(s), wm%wm%k(s),      &
                wm%wm%U_infty
        end do
    end if
end if

!  Determine if instantaneous velocities are to be recorded
if (zplane_calc .and. jt_total >= zplane_nstart .and. jt_total <= zplane_nend  &
    .and. mod(jt_total-zplane_nstart,zplane_nskip)==0 .and. coord == 0) then
    call string_splice(fname, path // 'output/wm_vel.', jt_total, '.bin')
    open(unit=13, file=fname, form='unformatted', convert=write_endian,        &
        access='direct', recl=wm%wm%nx*wm%wm%ny*rprec)
    write(13,rec=1) wm%wm%u
    close(13)
end if

! Calculate the receding horizon trajectories
if (use_receding_horizon) call eval_receding_horizon

! Cleanup
deallocate(w_uv)
nullify(y,z)
nullify(p_icp, p_jcp, p_kcp)

end subroutine turbines_forcing

!*******************************************************************************
subroutine turbines_finalize ()
!*******************************************************************************
implicit none

character (*), parameter :: sub_name = mod_name // '.turbines_finalize'

! write disk-averaged velocity to file along with T_avg_dim
! useful if simulation has multiple runs   >> may not make a large difference
call turbines_checkpoint

! deallocate
deallocate(wind_farm%turbine)

end subroutine turbines_finalize

!*******************************************************************************
subroutine turbines_checkpoint ()
!*******************************************************************************
!
!
!
use open_file_fid_mod
implicit none

character (*), parameter :: sub_name = mod_name // '.turbines_checkpoint'
integer :: fid

! write disk-averaged velocity to file along with T_avg_dim
! useful if simulation has multiple runs   >> may not make a large difference
if (coord == 0) then
    fid = open_file_fid( u_d_T_dat, 'rewind', 'formatted' )
    do i=1,nloc
        write(fid,*) wind_farm%turbine(i)%u_d_T, wind_farm%turbine(i)%omega
    end do
    write(fid,*) T_avg_dim
    close (fid)
end if

if (use_wake_model) call wm%write_to_file(wm_path)
if (use_receding_horizon) call receding_horizon_checkpoint

end subroutine turbines_checkpoint

!*******************************************************************************
subroutine turbine_vel_init(zo_high)
!*******************************************************************************
!
! called from ic.f90 if initu, lbc_mom==1, S_FLAG are all false.
! this accounts for the turbines when creating the initial velocity profile.
!
use param, only: zo
implicit none
character (*), parameter :: sub_name = mod_name // '.turbine_vel_init'

real(rprec), intent(inout) :: zo_high
real(rprec) :: cft, nu_w, exp_KE, induction_factor, Ct_noprime

! Convert Ct' to Ct
! a = Ct'/(4+Ct'), Ct = 4a(1-a)
induction_factor = Ct_prime / (4._rprec + Ct_prime)
Ct_noprime = 4*(induction_factor) * (1 - induction_factor)

! friction coefficient, cft
cft = pi*Ct_noprime/(4.*sx*sy)

!wake viscosity
nu_w = 28.*sqrt(0.5*cft)

!turbine friction height, Calaf, Phys. Fluids 22, 2010
zo_high = height_all*(1.+0.5*dia_all/height_all)**(nu_w/(1.+nu_w))* &
  exp(-1.*(0.5*cft/(vonk**2) + (log(height_all/zo* &
  (1.-0.5*dia_all/height_all)**(nu_w/(1.+nu_w))) )**(-2) )**(-0.5) )

exp_KE =  0.5*(log(0.45/zo_high)/0.4)**2

if(.false.) then
    write(*,*) 'sx,sy,cft: ',sx,sy,cft
    write(*,*) 'nu_w: ',nu_w
    write(*,*) 'zo_high: ',zo_high
    write(*,*) 'approx expected KE: ', exp_KE
end if
end subroutine turbine_vel_init

!*******************************************************************************
subroutine place_turbines
!*******************************************************************************
!
! This subroutine places the turbines on the domain. It also sets the values for
! each individual turbine. After the subroutine is called, the following values
! are set for each turbine in wind_farm: xloc, yloc, height, dia, thk, theta1,
! theta2, and Ct_prime.
!
use param, only: pi, z_i
use open_file_fid_mod
use messages
implicit none

character(*), parameter :: sub_name = mod_name // '.place_turbines'

real(rprec) :: sxx, syy, shift_base, const
real(rprec) :: dummy, dummy2
logical :: exst
integer :: fid

! Read parameters from file if needed
if (read_param) then
    ! Check if file exists and open
    inquire (file = param_dat, exist = exst)
    if (.not. exst) then
        call error (sub_name, 'file ' // param_dat // 'does not exist')
    end if

    ! Check that there are enough lines from which to read data
    nloc = count_lines(param_dat)
    if (nloc < num_x*num_y) then
        nloc = num_x*num_y
        call error(sub_name, param_dat // 'must have num_x*num_y lines')
    else if (nloc > num_x*num_y) then
        call warn(sub_name, param_dat // ' has more than num_x*num_y lines. '  &
                  // 'Only reading first num_x*num_y lines')
    end if

    ! Read from parameters file, which should be in this format:
    ! xloc [meters], yloc [meters], height [meters], dia [meters], thk [meters],
    ! theta1 [degrees], theta2 [degrees], Ct_prime [-]
    write(*,*) "Reading from", param_dat
    fid = open_file_fid(param_dat, 'rewind', 'formatted')
    do k = 1, nloc
        read(fid,*) wind_farm%turbine(k)%xloc, wind_farm%turbine(k)%yloc,      &
            wind_farm%turbine(k)%height, wind_farm%turbine(k)%dia,             &
            wind_farm%turbine(k)%thk, wind_farm%turbine(k)%theta1,             &
            wind_farm%turbine(k)%theta2, wind_farm%turbine(k)%Ct_prime,        &
            wind_farm%turbine(k)%Cp_prime
    end do
    close(fid)

    ! Make lengths dimensionless
    do k = 1, nloc
        wind_farm%turbine(k)%xloc = wind_farm%turbine(k)%xloc / z_i
        wind_farm%turbine(k)%yloc = wind_farm%turbine(k)%yloc / z_i
        wind_farm%turbine(k)%height = wind_farm%turbine(k)%height / z_i
        wind_farm%turbine(k)%dia = wind_farm%turbine(k)%dia / z_i
        wind_farm%turbine(k)%thk = wind_farm%turbine(k)%thk / z_i
    end do
else
    ! Set values for each turbine based on values in input file
    wind_farm%turbine(:)%height = height_all
    wind_farm%turbine(:)%dia = dia_all
    wind_farm%turbine(:)%thk = thk_all
    wind_farm%turbine(:)%theta1 = theta1_all
    wind_farm%turbine(:)%theta2 = theta2_all
    wind_farm%turbine(:)%Ct_prime = Ct_prime
    wind_farm%turbine(:)%Cp_prime = Cp_prime

    ! Set baseline locations (evenly spaced, not staggered aka aligned)
    k = 1
    sxx = sx * dia_all  ! x-spacing with units to match those of L_x
    syy = sy * dia_all  ! y-spacing
    do i = 1,num_x
        do j = 1,num_y
            wind_farm%turbine(k)%xloc = sxx*real(2*i-1)/2
            wind_farm%turbine(k)%yloc = syy*real(2*j-1)/2
            k = k + 1
        end do
    end do

    ! Place turbines based on orientation flag
    ! This will shift the placement relative to the baseline locations abive
    select case (orientation)
        ! Evenly-spaced, not staggered
        case (1)

        ! Evenly-spaced, horizontally staggered only
        ! Shift each row according to stag_perc
        case (2)
            do i = 2, num_x
                do k = 1+num_y*(i-1), num_y*i
                    shift_base = syy * stag_perc/100.
                    wind_farm%turbine(k)%yloc = mod( wind_farm%turbine(k)%yloc &
                                                    + (i-1)*shift_base , L_y )
                end do
            end do

        ! Evenly-spaced, only vertically staggered (by rows)
        case (3)
            ! Make even rows taller
            do i = 2, num_x, 2
                do k = 1+num_y*(i-1), num_y*i
                    wind_farm%turbine(k)%height = height_all*(1.+stag_perc/100.)
                end do
            end do
            ! Make odd rows shorter
            do i = 1, num_x, 2
                do k = 1+num_y*(i-1), num_y*i
                    wind_farm%turbine(k)%height = height_all*(1.-stag_perc/100.)
                end do
            end do

        ! Evenly-spaced, only vertically staggered, checkerboard pattern
        case (4)
            k = 1
            do i = 1, num_x
                do j = 1, num_y
                    ! this should alternate between 1, -1
                    const = 2.*mod(real(i+j),2.)-1.
                    wind_farm%turbine(k)%height = height_all                   &
                                                  *(1.+const*stag_perc/100.)
                    k = k + 1
                end do
            end do

        ! Aligned, but shifted forward for efficient use of simulation space
        ! during CPS runs
        case (5)
        ! Shift in spanwise direction: Note that stag_perc is now used
            k=1
            dummy=stag_perc                                                    &
                  *(wind_farm%turbine(2)%yloc - wind_farm%turbine(1)%yloc)
            do i = 1, num_x
                do j = 1, num_y
                    dummy2=dummy*(i-1)
                    wind_farm%turbine(k)%yloc=mod( wind_farm%turbine(k)%yloc   &
                                                  + dummy2,L_y)
                    k=k+1
                end do
            end do

        case default
            call error (sub_name, 'invalid orientation')

    end select
end if

end subroutine place_turbines

!*******************************************************************************
subroutine read_control_files
!*******************************************************************************
!
! This subroutine reads the input files for dynamic controls with theta1,
! theta2, and Ct_prime. This is calles from turbines_init.
!
use open_file_fid_mod
use messages
implicit none

character(*), parameter :: sub_name = mod_name // '.place_turbines'

integer :: fid, i, num_t

! Read the theta1 input data
if (dyn_theta1) then
    ! Count number of entries and allocate
    num_t = count_lines(theta1_dat)
    allocate( theta1_time(num_t) )
    allocate( theta1_arr(nloc, num_t) )

    ! Read values from file
    fid = open_file_fid(theta1_dat, 'rewind', 'formatted')
    do i = 1, num_t
        read(fid,*) theta1_time(i), theta1_arr(:,i)
    end do

    close(fid)
end if

! Read the theta2 input data
if (dyn_theta2) then
    ! Count number of entries and allocate
    num_t = count_lines(theta2_dat)
    allocate( theta2_time(num_t) )
    allocate( theta2_arr(nloc, num_t) )

    ! Read values from file
    fid = open_file_fid(theta2_dat, 'rewind', 'formatted')
    do i = 1, num_t
        read(fid,*) theta2_time(i), theta2_arr(:,i)
    end do

    close(fid)
end if

! Read the Pref input data
if (use_receding_horizon) then
    ! Count number of entries and allocate
    num_t = count_lines(Pref_dat)
    allocate( Pref_time(num_t) )
    allocate( Pref_arr(num_t) )

    ! Read values from file
    fid = open_file_fid(Pref_dat, 'rewind', 'formatted')
    do i = 1, num_t
        read(fid,*) Pref_time(i), Pref_arr(i)
    end do

    close(fid)
end if


end subroutine read_control_files

!*******************************************************************************
subroutine generate_splines
!*******************************************************************************
use open_file_fid_mod
use functions, only : linear_interp
use pchip
implicit none
integer :: N, fid, Nlp
real(rprec), dimension(:), allocatable :: lambda
real(rprec), dimension(:,:), allocatable :: Ct, Cp, a
real(rprec), dimension(:,:), allocatable :: iCtp, iCpp, ilp
real(rprec) :: dlp, phim
real(rprec), dimension(:,:), allocatable :: Cp_prime_arr
real(rprec), dimension(:,:), allocatable :: Ct_prime_arr
real(rprec), dimension(:), allocatable :: lambda_prime
real(rprec), dimension(:), allocatable :: beta
real(rprec), dimension(:), allocatable :: phi
real(rprec), dimension(:), allocatable :: Ctp_phi
type(pchip_t) :: cspl

! Read lambda
N = count_lines(lambda_dat)
allocate( lambda(N) )
fid = open_file_fid(lambda_dat, 'rewind', 'formatted')
do i = 1, N
    read(fid,*) lambda(i)
end do

! Read beta
N = count_lines(beta_dat)
allocate( beta(N) )
fid = open_file_fid(beta_dat, 'rewind', 'formatted')
do i = 1, N
    read(fid,*) beta(i)
end do

! Read Ct
allocate( Ct(size(beta), size(lambda)) )
fid = open_file_fid(Ct_dat, 'rewind', 'formatted')
do i = 1, size(beta)
    read(fid,*) Ct(i,:)
end do

! Read Cp
allocate( Cp(size(beta), size(lambda)) )
fid = open_file_fid(Cp_dat, 'rewind', 'formatted')
do i = 1, size(beta)
    read(fid,*) Cp(i,:)
end do

! Read phi
N = count_lines(phi_dat)
allocate( phi(N), Ctp_phi(N) )
fid = open_file_fid(phi_dat, 'rewind', 'formatted')
do i = 1, N
    read(fid,*) Ctp_phi(i), phi(i)
end do
close(fid)

! Ct_prime and Cp_prime are only really defined if 0<=Ct<=1
! Prevent negative power coefficients
do i = 1, size(beta)
    do j = 1, size(lambda)
        if (Ct(i,j) < 0._rprec) Ct(i,j) = 0._rprec
        if (Ct(i,j) > 1._rprec) Ct(i,j) = 1._rprec
        if (Cp(i,j) < 0._rprec) Cp(i,j) = 0._rprec
    end do
end do

! Calculate induction factor
allocate( a(size(beta), size(lambda)) )
a = 0.5*(1._rprec-sqrt(1._rprec-Ct))

! Calculate local Ct, Cp, and lambda
allocate( iCtp(size(beta), size(lambda)) )
allocate( iCpp(size(beta), size(lambda)) )
allocate( ilp(size(beta), size(lambda)) )
iCtp = Ct/((1._rprec-a)**2)
iCpp = Cp/((1._rprec-a)**3)
do i = 1, size(beta)
    do j = 1, size(lambda)
        ilp(i,j) = lambda(j)/(1._rprec - a(i,j))
    end do
end do

! Allocate arrays
Nlp = size(lambda)*3
allocate( lambda_prime(Nlp) )
allocate( Ct_prime_arr(size(beta), size(lambda_prime)) )
allocate( Cp_prime_arr(size(beta), size(lambda_prime)) )

! First save the uncorrected splines for use with the wake model
! Set the lambda_prime's onto which these curves will be interpolated
lambda_prime(1) = minval(lambda)
lambda_prime(Nlp) = maxval(2._rprec*lambda)
dlp = (lambda_prime(Nlp) - lambda_prime(1))
dlp = dlp / (Nlp - 1)
do i = 2, Nlp - 1
    lambda_prime(i) = lambda_prime(i-1) + dlp
end do

! Interpolate onto Ct_prime and Cp_prime arrays
do i = 1, size(beta)
    cspl = pchip_t(ilp(i,:), iCtp(i,:))
    call cspl%interp(lambda_prime, Ct_prime_arr(i,:))
    cspl = pchip_t(ilp(i,:), iCpp(i,:))
    call cspl%interp(lambda_prime, Cp_prime_arr(i,:))
end do

! Zero lambda_prime == 0
Ct_prime_arr(:,1) = 0._rprec
Cp_prime_arr(:,1) = 0._rprec

! Now generate splines
wm_Ct_prime_spline = bi_pchip_t(beta, lambda_prime, Ct_prime_arr)
wm_Cp_prime_spline = bi_pchip_t(beta, lambda_prime, Cp_prime_arr)

! Now save the adjusted splines for LES
! Adjust the lambda_prime and Cp_prime to use the LES velocity
cspl = pchip_t(Ctp_phi, phi)
do i = 1, size(beta)
    do j = 1, size(lambda)
        call cspl%interp(Ct_prime_arr(i,j), phim)
        Ct_prime_arr(i,j) = max(min(Ct_prime_arr(i,j)*phim, 4._rprec), 0._rprec)
    end do
end do

! For Ct_prime, low beta and lambda are zero. All edges have zero gradient
Ct_prime_arr(1,:) = 0._rprec
Ct_prime_arr(2,:) = 0._rprec
Ct_prime_arr(:,1) = 0._rprec
Ct_prime_arr(:,2) = 0._rprec
Ct_prime_arr(size(beta),:) = Ct_prime_arr(size(beta)-1,:)
Ct_prime_arr(:,Nlp) = Ct_prime_arr(:,Nlp-1)

! Now generate splines
Ct_prime_spline = bi_pchip_t(beta, lambda_prime, Ct_prime_arr)
Cp_prime_spline = bi_pchip_t(beta, lambda_prime, Cp_prime_arr)

! Cleanup
deallocate (lambda)
deallocate (Ct)
deallocate (Cp)
deallocate (a)
deallocate (iCtp)
deallocate (iCpp)
deallocate (ilp)
deallocate (Cp_prime_arr)
deallocate (Ct_prime_arr)
deallocate (lambda_prime)
deallocate (beta)
deallocate (phi)
deallocate (Ctp_phi)

end subroutine generate_splines

!*******************************************************************************
function count_lines(fname) result(N)
!*******************************************************************************
!
! This function counts the number of lines in a file
!
use open_file_fid_mod
use messages
use param, only : CHAR_BUFF_LENGTH
implicit none
character(*), intent(in) :: fname
logical :: exst
integer :: fid, ios
integer :: N

character(*), parameter :: sub_name = mod_name // '.count_lines'

! Check if file exists and open
inquire (file = trim(fname), exist = exst)
if (.not. exst) then
    call error (sub_name, 'file ' // trim(fname) // 'does not exist')
end if
fid = open_file_fid(trim(fname), 'rewind', 'formatted')

! count number of lines and close
ios = 0
N = 0
do
    read(fid, *, IOstat = ios)
    if (ios /= 0) exit
    N = N + 1
end do

! Close file
close(fid)

end function count_lines

!*******************************************************************************
subroutine wake_model_init
!*******************************************************************************
use param, only : CHAR_BUFF_LENGTH
use open_file_fid_mod
implicit none
real(rprec) :: U_infty
real(rprec), dimension(:), allocatable :: wm_k, wm_sx, wm_sy
logical :: exst
character (CHAR_BUFF_LENGTH) :: fstring

fstring = path // 'wake_model/wm_est.dat'
inquire (file=fstring, exist=exst)

if (exst) then
    write(*,*) 'Reading wake model estimator data from wake_model/'
    wm = wake_model_estimator_t(wm_path, wm_Ct_prime_spline,                   &
        wm_Cp_prime_spline, sigma_du, sigma_k, sigma_uhat,        &
        tau_U_infty)
else
    ! Set initial velocity
    U_infty = 8._rprec

    ! Specify spacing and wake expansion coefficients
    allocate( wm_k(nloc) )
    allocate( wm_sx(nloc) )
    allocate( wm_sy(nloc) )
    wm_k = 0.05_rprec
    do i = 1, nloc
        wm_sx(i) = wind_farm%turbine(i)%xloc * z_i
        wm_sy(i) = wind_farm%turbine(i)%yloc * z_i
    end do

    ! Create wake model
    wm = wake_model_estimator_t(num_ensemble, wm_sx, wm_sy, U_infty,           &
        0.5*wind_farm%turbine(1)%dia*z_i, wm_k, wind_farm%turbine(1)%dia*z_i,  &
        rho, inertia_all, nx/2, ny/2, wm_Ct_prime_spline, wm_Cp_prime_spline,  &
        torque_gain, sigma_du, sigma_k, sigma_uhat, tau_U_infty)

    ! Calculate U_infty
    wm%wm%Ctp = wind_farm%turbine(:)%Ct_prime
    call wm%calc_U_infty(-wind_farm%turbine(:)%u_d_T*u_star, 1._rprec)

    ! Generate the ensemble
    call wm%generate_initial_ensemble()

    ! Cleanup
    deallocate(wm_k)
    deallocate(wm_sx)
    deallocate(wm_sy)
end if

! Create output files
allocate( wm_fid(nloc) )
do i = 1, nloc
    call string_splice( fstring, path // 'turbine/wm_turbine_', i, '.dat')
    wm_fid(i) = open_file_fid( fstring, 'append', 'formatted' )
end do

end subroutine wake_model_init

!*******************************************************************************
subroutine receding_horizon_init
!*******************************************************************************
use turbines_mpc
use conjugate_gradient
use lbfgsb
use open_file_fid_mod
implicit none

logical :: exst
integer :: fid, N
integer :: i

inquire (file=rh_dat, exist=exst)

if (exst) then
    fid = open_file_fid(rh_dat, 'rewind', 'unformatted')
    write(*,*) "Reading receding horizon restart data..."
    read(fid) N
    allocate( rh_time(N) )
    allocate( beta_arr(nloc, N) )
    allocate( torque_gain_arr(nloc, N) )
    read(fid) rh_time
    read(fid) torque_gain_arr
    read(fid) beta_arr
    close(fid)
else
    allocate( rh_time(1) )
    rh_time = 0._rprec
    allocate( torque_gain_arr(nloc, 1) )
    allocate( beta_arr(nloc, 1) )
    do i = 1, nloc
        torque_gain_arr(i,:) = wind_farm%turbine(i)%torque_gain
        beta_arr(i,:) = wind_farm%turbine(i)%beta
    end do
 end if

if (coord == 0) then
    write(*,*) "Computing initial optimization..."
    controller = turbines_mpc_t(wm%wm, total_time_dim, horizon_time,           &
        0.1_rprec, Pref_time, Pref_arr, beta_penalty, beta_star,               &
        tsr_penalty, lambda_prime_star, speed_penalty, omega_min, omega_max)

    do i = 1, nloc
        controller%beta(i,:) = linear_interp(rh_time, torque_gain_arr(i,:),    &
            controller%t)
        controller%torque_gain(i,:) = linear_interp(rh_time, beta_arr(i,:),    &
            controller%t)
    end do
    call controller%makeDimensionless
    call controller%rescale_gradient(0.1_rprec, 1._rprec)

    ! Do the initial optimization
    m = lbfgsb_t(controller, max_iter, controller%get_lower_bound(),           &
        controller%get_upper_bound())
    call m%minimize( controller%get_control_vector() )
    call controller%makeDimensional
    if (.not. exst) N = controller%Nt
 end if

if (.not. exst) then
! Allocate arrays
#ifdef PPMPI
    call MPI_Bcast(N, 1, MPI_INT, 0, comm, ierr)
#endif
    deallocate(torque_gain_arr)
    deallocate(rh_time)
    deallocate(beta_arr)
    allocate(torque_gain_arr(nloc, N))
    allocate(beta_arr(nloc, N))
    allocate(rh_time(N))
end if

! Copy control arrays
if (coord == 0) then
    beta_arr = controller%beta
    torque_gain_arr = controller%torque_gain
    rh_time = controller%t
end if

#ifdef PPMPI
! Transfer via MPI
call MPI_Bcast(torque_gain_arr, nloc*N, MPI_RPREC, 0, comm, ierr)
call MPI_Bcast(beta_arr, nloc*N, MPI_RPREC, 0, comm, ierr)
call MPI_Bcast(rh_time, N, MPI_RPREC, 0, comm, ierr)
#endif

end subroutine receding_horizon_init

!*******************************************************************************
subroutine eval_receding_horizon ()
!*******************************************************************************
use turbines_mpc
use conjugate_gradient
use lbfgsb
use functions, only : linear_interp
implicit none

integer :: N = 0

! Only perform receding horizon control every advancement step
if (modulo (jt_total, advancement_base) == 0) then

    if (coord == 0) then
        write(*,*) "Optimizing..."
        call controller%reset_state(Pref_time, Pref_arr, total_time_dim, wm%wm)
        call controller%makeDimensionless
        call m%minimize( controller%get_control_vector() )
        call controller%MakeDimensional
    end if

    ! Allocate arrays
#ifdef PPMPI
    call MPI_Bcast(N, 1, MPI_INT, 0, comm, ierr)
#endif

    ! Copy control arrays
    if (coord == 0) then
        beta_arr = controller%beta
        torque_gain_arr = controller%torque_gain
        rh_time = controller%t
    end if

#ifdef PPMPI
    ! Transfer via MPI
    call MPI_Bcast(torque_gain_arr, nloc*N, MPI_RPREC, 0, comm, ierr)
    call MPI_Bcast(beta_arr, nloc*N, MPI_RPREC, 0, comm, ierr)
    call MPI_Bcast(rh_time, N, MPI_RPREC, 0, comm, ierr)
#endif

end if

end subroutine eval_receding_horizon

!*******************************************************************************
subroutine receding_horizon_checkpoint
!*******************************************************************************
use turbines_mpc
use open_file_fid_mod
implicit none

integer :: fid

if (coord == 0) then
    fid = open_file_fid(rh_dat, 'rewind', 'unformatted')
    write(*,*) "Writing receding horizon restart data..."
    write(fid) size(rh_time)
    write(fid) rh_time
    write(fid) beta_arr
    write(fid) torque_gain_arr
    close(fid)
end if

end subroutine receding_horizon_checkpoint

end module turbines
