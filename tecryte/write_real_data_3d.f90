!*************************************************************
subroutine write_real_data_3D_single_(fname, write_position, write_format, nvars, &
  imax, jmax, kmax, vars, ibuff, x,y,z)
!*************************************************************
!
!  This subroutine variables the variables given by vars to the
!  specified file, fname. The number of variables can be arbitrary
!  but must be specified by nvars. An example in which vars
!  is to be specified as:
!    (/ u, v, w /)
!
!  Inputs:
!  fname (char) - file to write to
!  write_position (char) - postition to write in file : 'append' or 'rewind'
!  write_format (char) - Fotran format flag : 'formatted' or 'unformatted'
!  nvars (int) - number of variables contained in vars
!  imax (int) - size of 1st dimension of variables in vars
!  jmax (int) - size of 2nd dimension of variables in vars
!  kmax (int)- size of 3rd dimension of variables in vars
!  vars (real, vector) - vector contaning variables to write
!  ibuff (int) - flag for adding buffer region due to periodicity
!     0 - no buffer region
!     1 - buffer on i direction
!     2 - buffer on j direction
!     3 - buffer on k direction
!     4 - buffer on i,j direction
!     5 - buffer on i,k direction
!     6 - buffer on j,k direction
!     7 - buffer on i,j,k directions
!  x,y,z (real, vector, optional) - vectors containing x,y,z coordinates
!
use tecryte
implicit none

character(*), intent(in) :: fname, write_position, write_format
integer, intent(in) :: nvars, imax, jmax, kmax
real(4), intent(in), dimension(nvars*imax*jmax*kmax) :: vars
integer, intent(in) :: ibuff
real(4), intent(in), dimension(:), optional :: x,y,z

real(4), allocatable, dimension(:,:,:) :: x_3d, y_3d, z_3d
real(4), allocatable, dimension(:,:,:,:) :: vars_3d


logical :: coord_pres

character(*), parameter :: sub_name = mod_name // '.write_real_data_3D'

integer :: i,j,k,n
integer :: i0, j0, k0, imax_buff, jmax_buff, kmax_buff

!  Check if file exists
!inquire ( file=fname, exist=exst)
!if (.not. exst) call mesg(sub_name, 'Creating : ' // fname)
call check_write_position(write_position, sub_name)
call check_write_format(write_format, sub_name)

!  Check if spatial coordinates are specified
coord_pres=.false.
if(present(x) .and. present(y) .and. present(z)) coord_pres = .true.

if( ibuff == 0 ) then

  imax_buff = imax
  jmax_buff = jmax
  kmax_buff = kmax

elseif( ibuff == 1 ) then

  imax_buff = imax + 1
  jmax_buff = jmax
  kmax_buff = kmax

elseif( ibuff == 2 ) then

  imax_buff = imax
  jmax_buff = jmax + 1
  kmax_buff = kmax

elseif( ibuff == 3 ) then

  imax_buff = imax
  jmax_buff = jmax
  kmax_buff = kmax + 1

elseif( ibuff == 4 ) then

  imax_buff = imax + 1
  jmax_buff = jmax + 1
  kmax_buff = kmax

elseif( ibuff == 5 ) then

  imax_buff = imax + 1
  jmax_buff = jmax
  kmax_buff = kmax + 1

elseif( ibuff == 6 ) then

  imax_buff = imax
  jmax_buff = jmax + 1
  kmax_buff = kmax + 1

elseif( ibuff == 7 ) then

  imax_buff = imax + 1
  jmax_buff = jmax + 1
  kmax_buff = kmax + 1

else

  write(*,*) 'ibuff not specified correctly'
  stop

endif

!allocate(ikey_vars(imax_buff,jmax_buff,kmax_buff,nvars))
allocate(vars_3d(imax_buff,jmax_buff,kmax_buff,nvars))

do n=1,nvars

  do k=1,kmax_buff

    k0 = buff_indx(k,kmax)

    do j = 1, jmax_buff

      j0 = buff_indx(j,jmax)

      do i = 1, imax_buff

        i0 = buff_indx(i,imax)

        vars_3d(i,j,k,n) = vars( (n-1)*imax*jmax*kmax + (k0-1)*imax*jmax + (j0-1)*imax + i0 )

      enddo

    enddo

  enddo

enddo

if( coord_pres ) then

  ! Allocate memory for 3D spatial coordinates
  allocate(x_3d(imax_buff,jmax_buff,kmax_buff))
  allocate(y_3d(imax_buff,jmax_buff,kmax_buff))
  allocate(z_3d(imax_buff,jmax_buff,kmax_buff))

  do k=1, kmax_buff
    do j=1, jmax_buff
      do i=1, imax_buff
        x_3d(i,j,k) = x(i)
        y_3d(i,j,k) = y(j)
        z_3d(i,j,k) = z(k)
      enddo
    enddo
  enddo

endif

open (unit = 2,file = fname, status='unknown',form=write_format, &
  action='write',position=write_position)

!  Write the data
select case(write_format)

  case('formatted')

    !  Specify output format; may want to use a global setting

    if (coord_pres) then
    
      write(2,data_format_single) x_3d, y_3d, z_3d, vars_3d
    
    else

      write(2,data_format_single) vars_3d

    endif

  case('unformatted')

    if (coord_pres) then

       write(2) x_3d, y_3d, z_3d, vars_3d

    else

       write(2) vars_3d

    endif

end select

close(2)


deallocate ( vars_3d )

if ( coord_pres ) then
    deallocate ( x_3d )
    deallocate ( y_3d )
    deallocate ( z_3d )
endif


return
end subroutine write_real_data_3D_single_
!*************************************************************
subroutine write_real_data_3D_double_(fname, write_position, write_format, nvars, &
  imax, jmax, kmax, vars, ibuff, x,y,z)
!*************************************************************
!
!  This subroutine variables the variables given by vars to the
!  specified file, fname. The number of variables can be arbitrary
!  but must be specified by nvars. An example in which vars
!  is to be specified as:
!    (/ u, v, w /)
!
!  Inputs:
!  fname (char) - file to write to
!  write_position (char) - postition to write in file : 'append' or 'rewind'
!  write_format (char) - Fotran format flag : 'formatted' or 'unformatted'
!  nvars (int) - number of variables contained in vars
!  imax (int) - size of 1st dimension of variables in vars
!  jmax (int) - size of 2nd dimension of variables in vars
!  kmax (int)- size of 3rd dimension of variables in vars
!  vars (real, vector) - vector contaning variables to write
!  ibuff (int) - flag for adding buffer region due to periodicity
!     0 - no buffer region
!     1 - buffer on i direction
!     2 - buffer on j direction
!     3 - buffer on k direction
!     4 - buffer on i,j direction
!     5 - buffer on i,k direction
!     6 - buffer on j,k direction
!     7 - buffer on i,j,k directions
!  x,y,z (real, vector, optional) - vectors containing x,y,z coordinates
!
use tecryte
implicit none

character(*), intent(in) :: fname, write_position, write_format
integer, intent(in) :: nvars, imax, jmax, kmax
real(8), intent(in), dimension(nvars*imax*jmax*kmax) :: vars
integer, intent(in) :: ibuff
real(8), intent(in), dimension(:), optional :: x,y,z

real(8), allocatable, dimension(:,:,:) :: x_3d, y_3d, z_3d
real(8), allocatable, dimension(:,:,:,:) :: vars_3d


logical :: coord_pres

character(*), parameter :: sub_name = mod_name // '.write_real_data_3D'

integer :: i,j,k,n
integer :: i0, j0, k0, imax_buff, jmax_buff, kmax_buff

!  Check if file exists
!inquire ( file=fname, exist=exst)
!if (.not. exst) call mesg(sub_name, 'Creating : ' // fname)
call check_write_position(write_position, sub_name)
call check_write_format(write_format, sub_name)

!  Check if spatial coordinates are specified
coord_pres=.false.
if(present(x) .and. present(y) .and. present(z)) coord_pres = .true.

if( ibuff == 0 ) then

  imax_buff = imax
  jmax_buff = jmax
  kmax_buff = kmax

elseif( ibuff == 1 ) then

  imax_buff = imax + 1
  jmax_buff = jmax
  kmax_buff = kmax

elseif( ibuff == 2 ) then

  imax_buff = imax
  jmax_buff = jmax + 1
  kmax_buff = kmax

elseif( ibuff == 3 ) then

  imax_buff = imax
  jmax_buff = jmax
  kmax_buff = kmax + 1

elseif( ibuff == 4 ) then

  imax_buff = imax + 1
  jmax_buff = jmax + 1
  kmax_buff = kmax

elseif( ibuff == 5 ) then

  imax_buff = imax + 1
  jmax_buff = jmax
  kmax_buff = kmax + 1

elseif( ibuff == 6 ) then

  imax_buff = imax
  jmax_buff = jmax + 1
  kmax_buff = kmax + 1

elseif( ibuff == 7 ) then

  imax_buff = imax + 1
  jmax_buff = jmax + 1
  kmax_buff = kmax + 1

else

  write(*,*) 'ibuff not specified correctly'
  stop

endif

!allocate(ikey_vars(imax_buff,jmax_buff,kmax_buff,nvars))
allocate(vars_3d(imax_buff,jmax_buff,kmax_buff,nvars))

do n=1,nvars

  do k=1,kmax_buff

    k0 = buff_indx(k,kmax)

    do j = 1, jmax_buff

      j0 = buff_indx(j,jmax)

      do i = 1, imax_buff

        i0 = buff_indx(i,imax)

        vars_3d(i,j,k,n) = vars( (n-1)*imax*jmax*kmax + (k0-1)*imax*jmax + (j0-1)*imax + i0 )

      enddo

    enddo

  enddo

enddo

if( coord_pres ) then

  ! Allocate memory for 3D spatial coordinates
  allocate(x_3d(imax_buff,jmax_buff,kmax_buff))
  allocate(y_3d(imax_buff,jmax_buff,kmax_buff))
  allocate(z_3d(imax_buff,jmax_buff,kmax_buff))

  do k=1, kmax_buff
    do j=1, jmax_buff
      do i=1, imax_buff
        x_3d(i,j,k) = x(i)
        y_3d(i,j,k) = y(j)
        z_3d(i,j,k) = z(k)
      enddo
    enddo
  enddo

endif

open (unit = 2,file = fname, status='unknown',form=write_format, &
  action='write',position=write_position)

!  Write the data
select case(write_format)

  case('formatted')

    !  Specify output format; may want to use a global setting

    if (coord_pres) then
    
      write(2,data_format_double) x_3d, y_3d, z_3d, vars_3d
    
    else

      write(2,data_format_double) vars_3d

    endif

  case('unformatted')

    if (coord_pres) then

       write(2) x_3d, y_3d, z_3d, vars_3d

    else

       write(2) vars_3d

    endif

end select

close(2)


deallocate ( vars_3d )

if ( coord_pres ) then
    deallocate ( x_3d )
    deallocate ( y_3d )
    deallocate ( z_3d )
endif


return
end subroutine write_real_data_3D_double_
