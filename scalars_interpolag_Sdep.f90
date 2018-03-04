!!
!!  Copyright (C) 2009-2013  Johns Hopkins University
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

subroutine scalars_interpolag_Sdep(I_LM,I_MM,I_QN,I_NN)
! This subroutine takes the arrays I_{LM,MM,QN,NN} from the previous  
!   timestep and essentially moves the values around to follow the 
!   corresponding particles. The (x, y, z) value at the current 
!   timestep will be the (x-u*dt, y-v*dt, z-w*dt) value at the 
!   previous timestep.  Since particle motion does not conform to
!   the grid, an interpolation will be required.  Variables should 
!   be on the w-grid.

! This subroutine assumes that dt and cs_count are chosen such that
!   the Lagrangian CFL in the z-direction will never exceed 1.  If the
!   Lag. CFL in the x-direction is less than one this should generally
!   be satisfied.

use types,only:rprec
use param
!use sgs_param, only: I_LM, I_MM, I_QN, I_NN, s_lagran_dt
use sgs_param, only: s_lagran_dt
use sim_param,only:u,v,w
use grid_defs,only:grid 
use functions, only:trilinear_interp
$if ($MPI)
use mpi_defs, only:mpi_sync_real_array,MPI_SYNC_DOWNUP
$endif
use cfl_util, only : get_max_cfl
implicit none

real(rprec), dimension(3) :: xyz_past

real(rprec), dimension(ld,ny,lbz:nz), intent(inout) :: I_LM, I_MM, I_QN, I_NN
real(rprec), dimension(ld,ny,lbz:nz) :: tempI_LM, tempI_MM, tempI_QN, tempI_NN
integer :: i,j,k,kmin

real (rprec) :: lcfl

real(rprec), pointer, dimension(:) :: x,y,z


!---------------------------------------------------------------------
$if ($VERBOSE)
write (*, *) 'started scalars_interpolag_Sdep'
$endif

nullify(x,y,z)
x => grid % x
y => grid % y
z => grid % z

! Perform (backwards) Lagrangian interpolation
    ! I_* arrays should be synced at this point (for MPI)

    ! Create dummy arrays so information will not be overwritten during interpolation
        tempI_LM = I_LM
        tempI_MM = I_MM
        tempI_QN = I_QN
        tempI_NN = I_NN      
        
        ! Loop over domain (within proc): for each, calc xyz_past then trilinear_interp
        ! Variables x,y,z, F_LM, F_MM, F_QN, F_NN, etc are on w-grid
        ! Interpolation out of top/bottom of domain is not permitted.
        ! Note: x,y,z values are only good for k=1:nz-1 within each proc
            if ( coord.eq.0 ) then
                kmin = 2                    
                ! At the bottom-most level (at the wall) the velocities are zero.
                ! Since there is no movement the values of F_LM, F_MM, etc should
                !   not change and no interpolation is necessary.           
            else
                kmin = 1
            endif
        ! Intermediate levels
            do k=kmin,nz-1
            do j=1,ny
            do i=1,nx
                ! Determine position at previous timestep (u,v interp to w-grid)
                xyz_past(1) = x(i) - 0.5_rprec*(u(i,j,k-1)+u(i,j,k))*s_lagran_dt
                xyz_past(2) = y(j) - 0.5_rprec*(v(i,j,k-1)+v(i,j,k))*s_lagran_dt
                xyz_past(3) = z(k) - w(i,j,k)*s_lagran_dt               
                 
                ! Interpolate   
                I_LM(i,j,k) = trilinear_interp(tempI_LM(1:nx,1:ny,lbz:nz),lbz,xyz_past)
                I_MM(i,j,k) = trilinear_interp(tempI_MM(1:nx,1:ny,lbz:nz),lbz,xyz_past)
                I_QN(i,j,k) = trilinear_interp(tempI_QN(1:nx,1:ny,lbz:nz),lbz,xyz_past)
                I_NN(i,j,k) = trilinear_interp(tempI_NN(1:nx,1:ny,lbz:nz),lbz,xyz_past)                          
            enddo
            enddo
            enddo               
        ! Top-most level should not allow negative w
            $if ($MPI)
            if (coord.eq.nproc-1) then
            $endif
                k = nz
                do j=1,ny
                do i=1,nx
                    ! Determine position at previous timestep (u,v interp to w-grid)
                    xyz_past(1) = x(i) - 0.5_rprec*(u(i,j,k-1)+u(i,j,k))*s_lagran_dt
                    xyz_past(2) = y(j) - 0.5_rprec*(v(i,j,k-1)+v(i,j,k))*s_lagran_dt   
                    xyz_past(3) = z(k) - max(0.0_rprec,w(i,j,k))*s_lagran_dt                                             
                    
                    ! Interpolate
                    I_LM(i,j,k) = trilinear_interp(tempI_LM(1:nx,1:ny,lbz:nz),lbz,xyz_past)
                    I_MM(i,j,k) = trilinear_interp(tempI_MM(1:nx,1:ny,lbz:nz),lbz,xyz_past)
                    I_QN(i,j,k) = trilinear_interp(tempI_QN(1:nx,1:ny,lbz:nz),lbz,xyz_past)
                    I_NN(i,j,k) = trilinear_interp(tempI_NN(1:nx,1:ny,lbz:nz),lbz,xyz_past)                      
                enddo
                enddo    
            $if ($MPI)
            endif     
            $endif     
        
         ! Share new data between overlapping nodes
         $if ($MPI)
            call mpi_sync_real_array( I_LM, 0, MPI_SYNC_DOWNUP )  
            call mpi_sync_real_array( I_MM, 0, MPI_SYNC_DOWNUP )   
            call mpi_sync_real_array( I_QN, 0, MPI_SYNC_DOWNUP )  
            call mpi_sync_real_array( I_NN, 0, MPI_SYNC_DOWNUP )              
        $endif   

! Compute the Lagrangian CFL number and print to screen
!   Note: this is only in the x-direction... not good for complex geometry cases
    if (mod (jt_total, lag_cfl_count) .eq. 0) then
        lcfl = get_max_cfl()
        lcfl = lcfl*s_lagran_dt/dt  
        $if($MPI)
            if(coord.eq.0) print*, 'Lagrangian CFL condition= ', lcfl
        $else
            print*, 'Lagrangian CFL condition= ', lcfl
        $endif
    endif
        
$if ($VERBOSE)
write (*, *) 'finished interpolag_Sdep'
$endif

nullify(x,y,z)

end subroutine scalars_interpolag_Sdep
