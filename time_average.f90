!!
!!  Copyright (C) 2009-2017  Johns Hopkins University
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

!*******************************************************************************
module time_average
!*******************************************************************************
use types, only : rprec
use param, only : nx, ny, nz, lbz

private
public :: tavg_t

!  Sums performed over time
type tavg_t
    real(rprec), dimension(:,:,:), allocatable :: u, v, w, u_w, v_w, w_uv
    real(rprec), dimension(:,:,:), allocatable :: u2, v2, w2, uv, uw, vw
    real(rprec), dimension(:,:,:), allocatable :: txx, tyy, tzz, txy, txz, tyz
    real(rprec), dimension(:,:,:), allocatable :: p, fx, fy, fz
    real(rprec), dimension(:,:,:), allocatable :: cs_opt2
    real(rprec) :: total_time
    ! Time between calls of tavg_compute, built by summing dt
    real(rprec) :: dt
    ! Switch for determining if time averaging has been initialized
    logical :: initialized = .false.
contains
    procedure, public :: init
    procedure, public :: compute
    procedure, public :: finalize
    procedure, public :: checkpoint
end type tavg_t

contains

!*******************************************************************************
subroutine init(this)
!*******************************************************************************
use param, only : nx, ny, lbz, nz
use messages
use string_util
use param, only : read_endian, coord, path, nx, ny, nz, lbz
implicit none

class(tavg_t), intent(inout) :: this

character (*), parameter :: ftavg_in = path // 'tavg.out'
#ifdef PPMPI
character (*), parameter :: MPI_suffix = '.c'
#endif
character (128) :: fname
integer :: i, j, k

logical :: exst

! Allocate
allocate( this%u(nx,ny,lbz:nz) )
allocate( this%v(nx,ny,lbz:nz) )
allocate( this%w(nx,ny,lbz:nz) )
allocate( this%u_w(nx,ny,lbz:nz) )
allocate( this%v_w(nx,ny,lbz:nz) )
allocate( this%w_uv(nx,ny,lbz:nz) )
allocate( this%u2(nx,ny,lbz:nz) )
allocate( this%v2(nx,ny,lbz:nz) )
allocate( this%w2(nx,ny,lbz:nz) )
allocate( this%uv(nx,ny,lbz:nz) )
allocate( this%uw(nx,ny,lbz:nz) )
allocate( this%vw(nx,ny,lbz:nz) )
allocate( this%txx(nx,ny,lbz:nz) )
allocate( this%tyy(nx,ny,lbz:nz) )
allocate( this%tzz(nx,ny,lbz:nz) )
allocate( this%txy(nx,ny,lbz:nz) )
allocate( this%txz(nx,ny,lbz:nz) )
allocate( this%tyz(nx,ny,lbz:nz) )
allocate( this%p(nx,ny,lbz:nz) )
allocate( this%fx(nx,ny,lbz:nz) )
allocate( this%fy(nx,ny,lbz:nz) )
allocate( this%fz(nx,ny,lbz:nz) )
allocate( this%cs_opt2(nx,ny,lbz:nz) )

! Initialize the derived types tavg
do k = 1, Nz
    do j = 1, Ny
    do i = 1, Nx
        this%u(i,j,k) = 0._rprec
        this%v(i,j,k) = 0._rprec
        this%w(i,j,k) = 0._rprec
        this%u_w(i,j,k)  = 0._rprec
        this%v_w(i,j,k)  = 0._rprec
        this%w_uv(i,j,k) = 0._rprec
        this%u2(i,j,k) = 0._rprec
        this%v2(i,j,k) = 0._rprec
        this%w2(i,j,k) = 0._rprec
        this%uv(i,j,k) = 0._rprec
        this%uw(i,j,k) = 0._rprec
        this%vw(i,j,k) = 0._rprec
        this%txx(i,j,k) = 0._rprec
        this%tyy(i,j,k) = 0._rprec
        this%tzz(i,j,k) = 0._rprec
        this%txy(i,j,k) = 0._rprec
        this%txz(i,j,k) = 0._rprec
        this%tyz(i,j,k) = 0._rprec
        this%fx(i,j,k) = 0._rprec
        this%fy(i,j,k) = 0._rprec
        this%fz(i,j,k) = 0._rprec
        this%cs_opt2(i,j,k) = 0._rprec
    end do
    end do
end do

fname = ftavg_in
#ifdef PPMPI
call string_concat(fname, MPI_suffix, coord)
#endif

inquire (file=fname, exist=exst)
if (.not. exst) then
    !  Nothing to read in
    if (coord == 0) then
        write(*,*) ' '
        write(*,*)'No previous time averaged data - starting from scratch.'
    end if
    this%total_time = 0._rprec
else
    open(1, file=fname, action='read', position='rewind', form='unformatted',  &
        convert=read_endian)
    read(1) this%total_time
    read(1) this%u
    read(1) this%v
    read(1) this%w
    read(1) this%u_w
    read(1) this%v_w
    read(1) this%w_uv
    read(1) this%u2
    read(1) this%v2
    read(1) this%w2
    read(1) this%uv
    read(1) this%uw
    read(1) this%vw
    read(1) this%txx
    read(1) this%tyy
    read(1) this%tzz
    read(1) this%txy
    read(1) this%txz
    read(1) this%tyz
    read(1) this%fx
    read(1) this%fy
    read(1) this%fz
    read(1) this%cs_opt2
    close(1)
end if

! Initialize dt
this%dt = 0._rprec

! Set global switch that tavg as been initialized
this%initialized = .true.

end subroutine init

!*******************************************************************************
subroutine compute(this)
!*******************************************************************************
!
!  This subroutine collects the stats for each flow
!  variable quantity
!
use param, only : nx, ny, nz, lbz, jzmax, ubc_mom, lbc_mom, coord, nproc
use sgs_param, only : Cs_opt2
use sim_param, only : u, v, w, p
use sim_param, only : txx, txy, tyy, txz, tyz, tzz
#if defined(PPTURBINES) || defined(PPATM) || defined(PPLVLSET)
use sim_param, only : fxa, fya, fza
#endif
use functions, only : interp_to_uv_grid, interp_to_w_grid
implicit none

class(tavg_t), intent(inout) :: this

integer :: i, j, k
real(rprec) :: u_p, u_p2, v_p, v_p2, w_p, w_p2
real(rprec), allocatable, dimension(:,:,:) :: w_uv, u_w, v_w
real(rprec), allocatable, dimension(:,:,:) :: pres_real
#if defined(PPTURBINES) || defined(PPATM) || defined(PPLVLSET)
real(rprec), allocatable, dimension(:,:,:) :: fza_uv
#endif

allocate(w_uv(nx,ny,lbz:nz), u_w(nx,ny,lbz:nz), v_w(nx,ny,lbz:nz))
allocate(pres_real(nx,ny,lbz:nz))

w_uv(1:nx,1:ny,lbz:nz) = interp_to_uv_grid(w(1:nx,1:ny,lbz:nz), lbz )
u_w(1:nx,1:ny,lbz:nz) = interp_to_w_grid(u(1:nx,1:ny,lbz:nz), lbz )
v_w(1:nx,1:ny,lbz:nz) = interp_to_w_grid(v(1:nx,1:ny,lbz:nz), lbz )
pres_real(1:nx,1:ny,lbz:nz) = 0._rprec
pres_real(1:nx,1:ny,lbz:nz) = p(1:nx,1:ny,lbz:nz)                              &
    - 0.5 * ( u(1:nx,1:ny,lbz:nz)**2 + w_uv(1:nx,1:ny,lbz:nz)**2               &
    + v(1:nx,1:ny,lbz:nz)**2 )
#if defined(PPTURBINES) || defined(PPATM) || defined(PPLVLSET)
allocate(fza_uv(nx,ny,lbz:nz))
fza_uv(1:nx,1:ny,lbz:nz) = interp_to_uv_grid(fza(1:nx,1:ny,lbz:nz), lbz )
#endif

! note: u_w not necessarily zero on walls, but only mult by w=0 vu u'w', so OK
! can zero u_w at BC anyway:
if(coord==0       .and. lbc_mom>0) u_w(:,:,1)  = 0._rprec
if(coord==nproc-1 .and. ubc_mom>0) u_w(:,:,nz) = 0._rprec
if(coord==0       .and. lbc_mom>0) v_w(:,:,1)  = 0._rprec
if(coord==nproc-1 .and. ubc_mom>0) v_w(:,:,nz) = 0._rprec

do k = lbz, jzmax     ! lbz = 0 for mpi runs, otherwise lbz = 1
do j = 1, ny
do i = 1, nx
    u_p = u(i,j,k)       !! uv grid
    u_p2= u_w(i,j,k)     !! w grid
    v_p = v(i,j,k)       !! uv grid
    v_p2= v_w(i,j,k)     !! w grid
    w_p = w(i,j,k)       !! w grid
    w_p2= w_uv(i,j,k)    !! uv grid

    this%u(i,j,k) = this%u(i,j,k) + u_p * this%dt !! uv grid
    this%v(i,j,k) = this%v(i,j,k) + v_p * this%dt !! uv grid
    this%w(i,j,k) = this%w(i,j,k) + w_p * this%dt !! w grid
    this%w_uv(i,j,k) = this%w_uv(i,j,k) + w_p2 * this%dt !! uv grid

    ! Note: compute u'w' on w-grid because stresses on w-grid --pj
    this%u2(i,j,k) = this%u2(i,j,k) + u_p * u_p * this%dt !! uv grid
    this%v2(i,j,k) = this%v2(i,j,k) + v_p * v_p * this%dt !! uv grid
    this%w2(i,j,k) = this%w2(i,j,k) + w_p * w_p * this%dt !! w grid
    this%uv(i,j,k) = this%uv(i,j,k) + u_p * v_p * this%dt !! uv grid
    this%uw(i,j,k) = this%uw(i,j,k) + u_p2 * w_p * this%dt !! w grid
    this%vw(i,j,k) = this%vw(i,j,k) + v_p2 * w_p * this%dt !! w grid

    this%txx(i,j,k) = this%txx(i,j,k) + txx(i,j,k) * this%dt !! uv grid
    this%tyy(i,j,k) = this%tyy(i,j,k) + tyy(i,j,k) * this%dt !! uv grid
    this%tzz(i,j,k) = this%tzz(i,j,k) + tzz(i,j,k) * this%dt !! uv grid
    this%txy(i,j,k) = this%txy(i,j,k) + txy(i,j,k) * this%dt !! uv grid
    this%txz(i,j,k) = this%txz(i,j,k) + txz(i,j,k) * this%dt !! w grid
    this%tyz(i,j,k) = this%tyz(i,j,k) + tyz(i,j,k) * this%dt !! w grid

    this%p(i,j,k) = this%p(i,j,k) + pres_real(i,j,k) * this%dt
end do
end do
end do

do k = 1, jzmax     ! lbz = 0 for mpi runs, otherwise lbz = 1
do j = 1, ny
do i = 1, nx
#if defined(PPTURBINES) || defined(PPATM) || defined(PPLVLSET)
    this%fx(i,j,k) = this%fx(i,j,k) + fxa(i,j,k) * this%dt
    this%fy(i,j,k) = this%fy(i,j,k) + fya(i,j,k) * this%dt
    this%fz(i,j,k) = this%fz(i,j,k) + fza_uv(i,j,k) * this%dt
#endif
    this%cs_opt2(i,j,k) = this%cs_opt2(i,j,k) + Cs_opt2(i,j,k) * this%dt
end do
end do
end do

! Update this%total_time for variable time stepping
this%total_time = this%total_time + this%dt

! Set this%dt back to zero for next increment
this%dt = 0._rprec

end subroutine compute

!*******************************************************************************
subroutine finalize(this)
!*******************************************************************************
use grid_m
use param, only : write_endian, jzmin, jzmax, lbz, path
use param, only : ny, nz, coord
use string_util
#ifdef PPMPI
use mpi_defs, only : mpi_sync_real_array,MPI_SYNC_DOWNUP
use param, only : ierr,comm
#endif
implicit none

class(tavg_t), intent(inout) :: this

#ifndef PPCGNS
character(64) :: bin_ext
#endif

character(64) :: fname_vel, fname_velw, fname_vel2, fname_tau, fname_pres
character(64) :: fname_f, fname_rs, fname_cs

integer :: i,j,k

real(rprec), pointer, dimension(:) :: x, y, z, zw

real(rprec), allocatable, dimension(:,:,:) :: up2, vp2, wp2, upvp, upwp, vpwp

nullify(x,y,z,zw)

x => grid % x
y => grid % y
z => grid % z
zw => grid % zw

! Common file name
fname_vel = path // 'output/veluv_avg'
fname_velw = path // 'output/velw_avg'
fname_vel2 = path // 'output/vel2_avg'
fname_tau = path // 'output/tau_avg'
fname_f = path // 'output/force_avg'
fname_pres = path // 'output/pres_avg'
fname_rs = path // 'output/rs'
fname_cs = path // 'output/cs_opt2'

! CGNS
#ifdef PPCGNS
call string_concat(fname_vel, '.cgns')
call string_concat(fname_velw, '.cgns')
call string_concat(fname_vel2, '.cgns')
call string_concat(fname_tau, '.cgns')
call string_concat(fname_pres, '.cgns')
call string_concat(fname_f, '.cgns')
call string_concat(fname_rs, '.cgns')
call string_concat(fname_cs, '.cgns')

! Binary
#else
#ifdef PPMPI
call string_splice(bin_ext, '.c', coord, '.bin')
#else
bin_ext = '.bin'
#endif
call string_concat(fname_vel, bin_ext)
call string_concat(fname_velw, bin_ext)
call string_concat(fname_vel2, bin_ext)
call string_concat(fname_tau, bin_ext)
call string_concat(fname_pres, bin_ext)
call string_concat(fname_f, bin_ext)
call string_concat(fname_rs, bin_ext)
call string_concat(fname_cs, bin_ext)
#endif

! Final checkpoint all restart data
call this%checkpoint()

#ifdef PPMPI
call mpi_barrier(comm, ierr)
#endif

!  Perform time averaging operation
do k = jzmin, jzmax
do j = 1, Ny
do i = 1, Nx
    this%u(i,j,k) = this%u(i,j,k) /  this%total_time
    this%v(i,j,k) = this%v(i,j,k) /  this%total_time
    this%w(i,j,k) = this%w(i,j,k) /  this%total_time
    this%u_w(i,j,k)  = this%u_w(i,j,k)  /  this%total_time
    this%v_w(i,j,k)  = this%v_w(i,j,k)  /  this%total_time
    this%w_uv(i,j,k) = this%w_uv(i,j,k) /  this%total_time
    this%u2(i,j,k) = this%u2(i,j,k) /  this%total_time
    this%v2(i,j,k) = this%v2(i,j,k) /  this%total_time
    this%w2(i,j,k) = this%w2(i,j,k) /  this%total_time
    this%uv(i,j,k) = this%uv(i,j,k) /  this%total_time
    this%uw(i,j,k) = this%uw(i,j,k) /  this%total_time
    this%vw(i,j,k) = this%vw(i,j,k) /  this%total_time
    this%txx(i,j,k) = this%txx(i,j,k) /  this%total_time
    this%tyy(i,j,k) = this%tyy(i,j,k) /  this%total_time
    this%tzz(i,j,k) = this%tzz(i,j,k) /  this%total_time
    this%txy(i,j,k) = this%txy(i,j,k) /  this%total_time
    this%txz(i,j,k) = this%txz(i,j,k) /  this%total_time
    this%tyz(i,j,k) = this%tyz(i,j,k) /  this%total_time
    this%p(i,j,k) = this%p(i,j,k) /  this%total_time
    this%fx(i,j,k) = this%fx(i,j,k) /  this%total_time
    this%fy(i,j,k) = this%fy(i,j,k) /  this%total_time
    this%fz(i,j,k) = this%fz(i,j,k) /  this%total_time
    this%cs_opt2(i,j,k) = this%cs_opt2(i,j,k) /  this%total_time

end do
end do
end do

#ifdef PPMPI
call mpi_barrier( comm, ierr )
#endif

!  Sync entire tavg structure
#ifdef PPMPI
call mpi_sync_real_array( this%u(1:nx,1:ny,lbz:nz), 0, MPI_SYNC_DOWNUP )
call mpi_sync_real_array( this%v(1:nx,1:ny,lbz:nz), 0, MPI_SYNC_DOWNUP )
call mpi_sync_real_array( this%w(1:nx,1:ny,lbz:nz), 0, MPI_SYNC_DOWNUP )
call mpi_sync_real_array( this%u2(1:nx,1:ny,lbz:nz), 0, MPI_SYNC_DOWNUP )
call mpi_sync_real_array( this%v2(1:nx,1:ny,lbz:nz), 0, MPI_SYNC_DOWNUP )
call mpi_sync_real_array( this%w2(1:nx,1:ny,lbz:nz), 0, MPI_SYNC_DOWNUP )
call mpi_sync_real_array( this%uw(1:nx,1:ny,lbz:nz), 0, MPI_SYNC_DOWNUP )
call mpi_sync_real_array( this%vw(1:nx,1:ny,lbz:nz), 0, MPI_SYNC_DOWNUP )
call mpi_sync_real_array( this%uv(1:nx,1:ny,lbz:nz), 0, MPI_SYNC_DOWNUP )
call mpi_sync_real_array( this%p(1:nx,1:ny,lbz:nz), 0, MPI_SYNC_DOWNUP )
call mpi_sync_real_array( this%fx(1:nx,1:ny,lbz:nz), 0, MPI_SYNC_DOWNUP )
call mpi_sync_real_array( this%cs_opt2(1:nx,1:ny,lbz:nz), 0, MPI_SYNC_DOWNUP )
#endif

! Write all the 3D data
#ifdef PPCGNS
! Write CGNS Data
call write_parallel_cgns (fname_vel ,nx, ny, nz - nz_end, nz_tot,              &
    (/ 1, 1,   (nz-1)*coord + 1 /),                                            &
    (/ nx, ny, (nz-1)*(coord+1) + 1 - nz_end /),                               &
    x(1:nx) , y(1:ny) , z(1:(nz-nz_end) ), 3,                                  &
    (/ 'VelocityX', 'VelocityY', 'VelocityZ' /),                               &
    (/ this%u(1:nx,1:ny,1:nz-nz_end),                                          &
       this%v(1:nx,1:ny,1:nz-nz_end),                                          &
       this%w_uv(1:nx,1:ny,1:nz-nz_end) /) )

call write_parallel_cgns (fname_velw ,nx, ny, nz - nz_end, nz_tot,             &
    (/ 1, 1,   (nz-1)*coord + 1 /),                                            &
    (/ nx, ny, (nz-1)*(coord+1) + 1 - nz_end /),                               &
    x(1:nx) , y(1:ny) , zw(1:(nz-nz_end) ),                                    &
    1, (/ 'VelocityZ' /), (/ this%w(1:nx,1:ny,1:nz-nz_end) /) )

call write_parallel_cgns(fname_vel2,nx,ny,nz- nz_end,nz_tot,                   &
    (/ 1, 1,   (nz-1)*coord + 1 /),                                            &
    (/ nx, ny, (nz-1)*(coord+1) + 1 - nz_end /),                               &
    x(1:nx) , y(1:ny) , zw(1:(nz-nz_end) ), 6,                                 &
    (/ 'Mean--uu', 'Mean--vv', 'Mean--ww','Mean--uw','Mean--vw','Mean--uv'/),  &
    (/ this%u2(1:nx,1:ny,1:nz-nz_end),                                         &
       this%v2(1:nx,1:ny,1:nz-nz_end),                                         &
       this%w2(1:nx,1:ny,1:nz-nz_end),                                         &
       this%uw(1:nx,1:ny,1:nz-nz_end),                                         &
       this%vw(1:nx,1:ny,1:nz-nz_end),                                         &
       this%uv(1:nx,1:ny,1:nz-nz_end) /) )

call write_parallel_cgns(fname_tau,nx,ny,nz- nz_end,nz_tot,                    &
    (/ 1, 1,   (nz-1)*coord + 1 /),                                            &
    (/ nx, ny, (nz-1)*(coord+1) + 1 - nz_end /),                               &
    x(1:nx) , y(1:ny) , zw(1:(nz-nz_end) ), 6,                                 &
    (/ 'Tau--txx', 'Tau--txy', 'Tau--tyy','Tau--txz','Tau--tyz','Tau--tzz'/),  &
    (/ this%txx(1:nx,1:ny,1:nz-nz_end),                                        &
       this%txy(1:nx,1:ny,1:nz-nz_end),                                        &
       this%tyy(1:nx,1:ny,1:nz-nz_end),                                        &
       this%txz(1:nx,1:ny,1:nz-nz_end),                                        &
       this%tyz(1:nx,1:ny,1:nz-nz_end),                                        &
       this%tzz(1:nx,1:ny,1:nz-nz_end) /) )

call write_parallel_cgns(fname_pres,nx,ny,nz- nz_end,nz_tot,                   &
   (/ 1, 1,   (nz-1)*coord + 1 /),                                             &
   (/ nx, ny, (nz-1)*(coord+1) + 1 - nz_end /),                                &
   x(1:nx) , y(1:ny) , zw(1:(nz-nz_end) ), 1,                                  &
   (/ 'pressure' /),                                                           &
   (/ this%p(1:nx,1:ny,1:nz-nz_end) /) )

#if defined(PPTURBINES) || defined(PPATM) || defined(PPLVLSET)
call write_parallel_cgns(fname_f,nx,ny,nz- nz_end,nz_tot,                      &
    (/ 1, 1,   (nz-1)*coord + 1 /),                                            &
    (/ nx, ny, (nz-1)*(coord+1) + 1 - nz_end /),                               &
    x(1:nx) , y(1:ny) , zw(1:(nz-nz_end) ), 3,                                 &
    (/ 'bodyForX', 'bodyForY', 'bodyForZ' /),                                  &
    (/ this%fx(1:nx,1:ny,1:nz-nz_end),                                         &
       this%fy(1:nx,1:ny,1:nz-nz_end),                                         &
       this%fz(1:nx,1:ny,1:nz-nz_end) /) )
#endif

call write_parallel_cgns(fname_cs,nx,ny,nz- nz_end,nz_tot,                     &
    (/ 1, 1,   (nz-1)*coord + 1 /),                                            &
    (/ nx, ny, (nz-1)*(coord+1) + 1 - nz_end /),                               &
    x(1:nx) , y(1:ny) , zw(1:(nz-nz_end) ), 1,                                 &
    (/ 'Cs_Coeff'/),  (/ this%cs_opt2(1:nx,1:ny,1:nz- nz_end) /) )

#else
! Write binary data
open(unit=13, file=fname_vel, form='unformatted', convert=write_endian,        &
    access='direct', recl=nx*ny*nz*rprec)
write(13,rec=1) this%u(:nx,:ny,1:nz)
write(13,rec=2) this%v(:nx,:ny,1:nz)
write(13,rec=3) this%w_uv(:nx,:ny,1:nz)
close(13)

! Write binary data
open(unit=13, file=fname_velw, form='unformatted', convert=write_endian,       &
    access='direct', recl=nx*ny*nz*rprec)
write(13,rec=1) this%w(:nx,:ny,1:nz)
close(13)

open(unit=13, file=fname_vel2, form='unformatted', convert=write_endian,       &
    access='direct', recl=nx*ny*nz*rprec)
write(13,rec=1) this%u2(:nx,:ny,1:nz)
write(13,rec=2) this%v2(:nx,:ny,1:nz)
write(13,rec=3) this%w2(:nx,:ny,1:nz)
write(13,rec=4) this%uw(:nx,:ny,1:nz)
write(13,rec=5) this%vw(:nx,:ny,1:nz)
write(13,rec=6) this%uv(:nx,:ny,1:nz)
close(13)

open(unit=13, file=fname_tau, form='unformatted', convert=write_endian,        &
    access='direct', recl=nx*ny*nz*rprec)
write(13,rec=1) this%txx(:nx,:ny,1:nz)
write(13,rec=2) this%txy(:nx,:ny,1:nz)
write(13,rec=3) this%tyy(:nx,:ny,1:nz)
write(13,rec=4) this%txz(:nx,:ny,1:nz)
write(13,rec=5) this%tyz(:nx,:ny,1:nz)
write(13,rec=6) this%tzz(:nx,:ny,1:nz)
close(13)

open(unit=13, file=fname_pres, form='unformatted', convert=write_endian,       &
    access='direct', recl=nx*ny*nz*rprec)
write(13,rec=1) this%p(:nx,:ny,1:nz)
close(13)

#if defined(PPTURBINES) || defined(PPATM) || defined(PPLVLSET)
open(unit=13, file=fname_f, form='unformatted', convert=write_endian,          &
    access='direct', recl=nx*ny*nz*rprec)
write(13,rec=1) this%fx(:nx,:ny,1:nz)
write(13,rec=2) this%fy(:nx,:ny,1:nz)
write(13,rec=3) this%fz(:nx,:ny,1:nz)
close(13)
#endif

open(unit=13, file=fname_cs, form='unformatted', convert=write_endian,         &
    access='direct', recl=nx*ny*nz*rprec)
write(13,rec=1) this%cs_opt2(:nx,:ny,1:nz)
close(13)

#endif

#ifdef PPMPI
! Ensure all writes complete before preceeding
call mpi_barrier( comm, ierr )
#endif

! Do the Reynolds stress calculations afterwards. Now we can interpolate w and
! ww to the uv grid and do the calculations. We have already written the data to
! the files so we can overwrite now
allocate( up2(nx,ny,lbz:nz) )
allocate( vp2(nx,ny,lbz:nz) )
allocate( wp2(nx,ny,lbz:nz) )
allocate( upvp(nx,ny,lbz:nz) )
allocate( upwp(nx,ny,lbz:nz) )
allocate( vpwp(nx,ny,lbz:nz) )
up2 = this%u2 - this%u * this%u
vp2 = this%v2 - this%v * this%v
wp2 = this%w2 - this%w * this%w
upvp = this%uv - this%u * this%v
!! using u_w and v_w below instead of u and v ensures that the Reynolds
!! stresses are on the same grid as the squared velocities (i.e., w-grid)
upwp = this%uw - this%u_w * this%w
vpwp = this%vw - this%v_w * this%w

#ifdef PPCGNS
! Write CGNS data
call write_parallel_cgns(fname_rs,nx,ny,nz- nz_end,nz_tot,                     &
    (/ 1, 1,   (nz-1)*coord + 1 /),                                            &
    (/ nx, ny, (nz-1)*(coord+1) + 1 - nz_end /),                               &
    x(1:nx) , y(1:ny) , z(1:(nz-nz_end) ), 6,                                  &
    (/ 'Meanupup', 'Meanvpvp', 'Meanwpwp','Meanupwp','Meanvpwp','Meanupvp'/),  &
    (/ % up2(1:nx,1:ny,1:nz- nz_end) ,                                         &
    vp2(1:nx,1:ny,1:nz- nz_end) ,                                              &
    wp2(1:nx,1:ny,1:nz- nz_end) ,                                              &
    upwp(1:nx,1:ny,1:nz- nz_end) ,                                             &
    vpwp(1:nx,1:ny,1:nz- nz_end) ,                                             &
    upvp(1:nx,1:ny,1:nz- nz_end)  /) )
#else
! Write binary data
open(unit=13, file=fname_rs, form='unformatted', convert=write_endian,         &
    access='direct',recl=nx*ny*nz*rprec)
write(13,rec=1) up2(:nx,:ny,1:nz)
write(13,rec=2) vp2(:nx,:ny,1:nz)
write(13,rec=3) wp2(:nx,:ny,1:nz)
write(13,rec=4) upwp(:nx,:ny,1:nz)
write(13,rec=5) vpwp(:nx,:ny,1:nz)
write(13,rec=6) upvp(:nx,:ny,1:nz)
close(13)
#endif

#ifdef PPMPI
! Ensure all writes complete before preceeding
call mpi_barrier( comm, ierr )
#endif

end subroutine finalize

!*******************************************************************************
subroutine checkpoint(this)
!*******************************************************************************
!
! This subroutine writes the restart data and is to be called by 'checkpoint'
! for intermediate checkpoints and by 'tavg_finalize' at the end of the
! simulation.
!
use param, only : checkpoint_tavg_file, write_endian, coord
use string_util
implicit none

class(tavg_t), intent(inout) :: this

character(64) :: fname

fname = checkpoint_tavg_file
#ifdef PPMPI
call string_concat( fname, '.c', coord)
#endif

!  Write data to tavg.out
open(1, file=fname, action='write', position='rewind',form='unformatted',      &
    convert=write_endian)
write(1) this%total_time
write(1) this%u
write(1) this%v
write(1) this%w
write(1) this%u_w
write(1) this%v_w
write(1) this%w_uv
write(1) this%u2
write(1) this%v2
write(1) this%w2
write(1) this%uv
write(1) this%uw
write(1) this%vw
write(1) this%txx
write(1) this%tyy
write(1) this%tzz
write(1) this%txy
write(1) this%txz
write(1) this%tyz
write(1) this%fx
write(1) this%fy
write(1) this%fz
write(1) this%cs_opt2
close(1)

end subroutine checkpoint

end module time_average