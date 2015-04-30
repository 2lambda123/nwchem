c
c     qmd_fix_momentum: remove global translations and rotations
c
      subroutine qmd_fix_momentum(n,m,v,r,ekin,pres_ekin)
c
      implicit none
c
#include "errquit.fh"
#include "mafdecls.fh"
#include "stdio.fh"
#include "global.fh"
c
#include "qmd_common.fh"
c
      integer n                  ! number of atoms
      double precision m(n)      ! atomic masses
      double precision v(3,n)    ! atomic velocities
      double precision r(3,n)    ! atomic position
      double precision ekin      ! kinetic energy, entry
      double precision ekin2     ! kinetic energy, after removal
      double precision mit(3,3)  ! inertia tensor
      double precision imit(3,3) ! inverse of inertia tensor
      double precision comr(3)   ! center of mass position
      double precision comv(3)   ! center of mass velocity
      double precision sam(3)    ! angular momentum to be removed
      double precision omega(3)  ! angular velocity correction
      double precision deter, deteri ! interia tensor determinant
      double precision tm        ! total mass
      logical pres_ekin          ! preserve kinetic energy on exit
c
      integer i,j, d1, d2
c
      character*32 pname
      pname='qmd_fix_momentum: '
c
c     calculate current kinetic energy
      call qmd_kinetic(n,m,v,ekin)
c     find center of mass
      comr=0.d0
      comv=0.d0
      tm=0.d0
      do i = 1,n
       tm = tm + m(i)
       do j = 1,3
        comr(j) = comr(j) + m(i)*r(j,i)
        comv(j) = comv(j) + m(i)*v(j,i)
       end do
      end do
      comr=comr/tm
      comv=comv/tm
      do i = 1,n
       do j = 1,3
        v(j,i) = v(j,i) - comv(j)
       end do
      end do
c     construct inertia tensor
      mit=0.d0
      do i = 1,n
c      moments of inertia
       mit(1,1) = mit(1,1) + ((r(2,i)-comr(2))**2
     $            + (r(3,i)-comr(3))**2)*m(i)
       mit(2,2) = mit(2,2) + ((r(1,i)-comr(1))**2
     $            + (r(3,i)-comr(3))**2)*m(i)
       mit(3,3) = mit(3,3) + ((r(1,i)-comr(1))**2
     $            + (r(2,i)-comr(2))**2)*m(i)
c      products of inertia
       mit(1,2) = mit(1,2) - ((r(1,i)-comr(1))*(r(2,i)-comr(2)))*m(i)
       mit(1,3) = mit(1,3) - ((r(1,i)-comr(1))*(r(3,i)-comr(3)))*m(i)
       mit(2,3) = mit(2,3) - ((r(2,i)-comr(2))*(r(3,i)-comr(3)))*m(i)
      end do
      mit(2,1)=mit(1,2)
      mit(3,1)=mit(3,1)
      mit(3,2)=mit(2,3)
c     calculate inverse of inertia tensor
      deter=mit(1,1)*(mit(2,2)*mit(3,3)-mit(3,2)*mit(2,3))
     $     -mit(2,1)*(mit(1,2)*mit(3,3)-mit(3,2)*mit(1,3))
     $     +mit(3,1)*(mit(1,2)*mit(2,3)-mit(2,2)*mit(1,3))
      if(abs(deter).gt.1.d-6) then
       deteri=1.d0/deter
       imit(1,1)= deteri*(mit(2,2)*mit(3,3)-mit(3,2)*mit(2,3))
       imit(1,2)=(-deteri)*(mit(1,2)*mit(3,3)-mit(3,2)*mit(1,3))
       imit(1,3)= deteri*(mit(1,2)*mit(2,3)-mit(2,2)*mit(1,3))
       imit(2,1)=(-deteri)*(mit(2,1)*mit(3,3)-mit(3,1)*mit(2,3))
       imit(2,2)= deteri*(mit(1,1)*mit(3,3)-mit(3,1)*mit(1,3))
       imit(2,3)=(-deteri)*(mit(1,1)*mit(2,3)-mit(2,1)*mit(1,3))
       imit(3,1)= deteri*(mit(2,1)*mit(3,2)-mit(3,1)*mit(2,2))
       imit(3,2)=(-deteri)*(mit(1,1)*mit(3,2)-mit(3,1)*mit(1,2))
       imit(3,3)= deteri*(mit(1,1)*mit(2,2)-mit(2,1)*mit(1,2))
c      calculate angular momentum to be removed
       sam=0.d0
       do i = 1,n
        sam(1) = sam(1) + (r(2,i)-comr(2))*m(i)*v(3,i)
     $           - (r(3,i)-comr(3))*m(i)*v(2,i)
        sam(2) = sam(2) + (r(3,i)-comr(3))*m(i)*v(1,i)
     $           - (r(1,i)-comr(1))*m(i)*v(3,i)
        sam(3) = sam(3) + (r(1,i)-comr(1))*m(i)*v(2,i)
     $           - (r(2,i)-comr(2))*m(i)*v(1,i)
       end do
       omega=0.d0
       do i = 1,3
        do j = 1,3
         omega(i) = omega(i) + imit(i,j)*sam(j)
        end do
       end do
c      remove angular velocity from total velocity
       do i = 1,n
        v(1,i) = v(1,i) - (omega(2)*(r(3,i)-comr(3))
     $           - omega(3)*(r(2,i)-comr(2)))
        v(2,i) = v(2,i) - (omega(3)*(r(1,i)-comr(1))
     $           - omega(1)*(r(3,i)-comr(3)))
        v(3,i) = v(3,i) - (omega(1)*(r(2,i)-comr(2))
     $           - omega(2)*(r(1,i)-comr(1)))
       end do
      else if (do_linear) then
       d1=0
       d2=0
       if (maxval(abs(r(1,:))).gt.1.d-6 .and.
     $     maxval(abs(r(2,:))).lt.1.d-6 .and.
     $     maxval(abs(r(3,:))).lt.1.d-6) then
        d1 = 2
        d2 = 3
       else if (maxval(abs(r(2,:))).gt.1.d-6 .and.
     $          maxval(abs(r(1,:))).lt.1.d-6 .and.
     $          maxval(abs(r(3,:))).lt.1.d-6) then
        d1 = 1
        d2 = 3
       else if (maxval(abs(r(3,:))).gt.1.d-6 .and.
     $          maxval(abs(r(1,:))).lt.1.d-6 .and.
     $          maxval(abs(r(2,:))).lt.1.d-6) then
        d1 = 1
        d2 = 2
       else
        call errquit('could not remove rotations from linear molecule',
     $               911,GEOM_ERR)
       end if
       if (d1.eq.0 .or. d2.eq.0) 
     $   call errquit('error with linear molecule',911,GEOM_ERR)
       do i = 1,n
        v(d1,i) = 0.d0
        v(d2,i) = 0.d0
       end do
      else
       call errquit('inertia tensor could not be inverted',911,GEOM_ERR)
      end if
c     make sure center of mass velocity is still zero
      comv=0.d0
      do i = 1,n
       do j = 1,3
        comv(j) = comv(j) + m(i)*v(j,i)
       end do
      end do
      comv=comv/tm
      do i = 1,n
       do j = 1,3
        v(j,i) = v(j,i) - comv(j)
       end do
      end do
c     calculate current kinetic energy
      call qmd_kinetic(n,m,v,ekin2)
      if (pres_ekin) then
c       rescale velocities to match kinetic energy on entry
        call qmd_rescale(n,m,v,ekin,ekin2)
      else
c       pass new kinetic energy to driver
        ekin=ekin2
      end if
c
      return
      end