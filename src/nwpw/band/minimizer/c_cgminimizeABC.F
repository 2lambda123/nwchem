*
*     $Id$                       
*

*  ************************************************************
*  *                MPI cgminimize ABC routine                *
*  *               (Fletcher-Reeves' steps)                   *
*  *                                                          *
*  *  This is a developing band cg mimimization parallel code *
*  *  wrtten for NWChem that uses a Stich linearized line     *
*  *  search algorithm.                                       *
*  *                                                          *
*  ************************************************************
  
      subroutine c_cgminimizeABC(E,deltae,deltac,
     >                           current_iteration,it_in)
      implicit none
      real*8     E(*)
      real*8     deltae,deltac
      integer    current_iteration
      integer    it_in

#include "bafdecls.fh"
#include "errquit.fh"

*     **** local variables ****

      real*8  deltat_min
      parameter (deltat_min=1.0d-3)
       
      integer H0_tag,G0_tag,G1_tag,G2_tag
      real*8  E0,dE0,Ermdr

      real*8     sum0,sum1,scale,tole,tolc
      real*8     ehartree,eorbit,exc,pxc,eion
      real*8     Enew,Eold,Estart
      common / c_cgsd_block / Enew,Eold,Estart

      integer it
      real*8 tmin,deltat
      real*8 max_sigma,ehfx,phfx

      integer ispin,ne(2)
      integer neall,nfft3d,npack1,nbrill

*     **** define pointers ****
      integer Y,U,HY,HU

*     **** external functions ****
      logical  band_hfx
      integer  cpsi_neq,control_version,cpsi_ispinq,cpsi_nbrillq
      integer  cpsi_data_push_stack
      real*8   control_tole,control_tolc
      real*8   cpsi_geodesic_energy
      real*8   cpsi_geodesic_denergy
      real*8   c_rho_error
      real*8   c_dng_1ehartree
      real*8   cpsi_1ke
      real*8   cpsi_1vl
      real*8   cpsi_1vnl
      real*8   cpsi_1vnlso
      real*8   c_rho_1exc
      real*8   c_rho_1pxc
      real*8   ewald_e
      real*8   cpsi_1eorbit
      real*8   linesearch
      external band_hfx
      external cpsi_neq,control_version,cpsi_ispinq,cpsi_nbrillq
      external cpsi_data_push_stack
      external control_tole,control_tolc
      external cpsi_geodesic_energy
      external cpsi_geodesic_denergy
      external c_rho_error
      external c_dng_1ehartree
      external cpsi_1ke
      external cpsi_1vl
      external cpsi_1vnl
      external c_rho_1exc
      external c_rho_1pxc
      external ewald_e
      external cpsi_1eorbit
      external linesearch
      real*8   ion_disp_energy
      external ion_disp_energy
      logical  ion_disp_on
      external ion_disp_on

      real*8   c_geodesic_ABC_energy,c_geodesic_ABC_denergy
      external c_geodesic_ABC_energy,c_geodesic_ABC_denergy

      integer  cpsi_iptr_psi,c_geodesic_get_U_tag
      external cpsi_iptr_psi,c_geodesic_get_U_tag
       
  
      call C3dB_nfft3d(1,nfft3d)
      call Cram_max_npack(npack1)
      ispin  = cpsi_ispinq()
      ne(1)  = cpsi_neq(1)
      ne(2)  = cpsi_neq(2)
      neall  = ne(1)+ne(2)
      nbrill = cpsi_nbrillq()

      call c_geodesic_ABC_init()

*     **** allocate H0, G0, G1, and G2 ****
      H0_tag = cpsi_data_push_stack(nbrill,neall,2*npack1)
      G0_tag = cpsi_data_push_stack(nbrill,neall,2*npack1)
      G1_tag = cpsi_data_push_stack(nbrill,neall,2*npack1)
      G2_tag = cpsi_data_push_stack(nbrill,neall,2*npack1)

*     **** set ptrs ****
      Y  = cpsi_iptr_psi(1)
      U  = c_geodesic_get_U_tag()
      HY = G0_tag
      HU = G2_tag

      Estart = Enew
      Eold   = Enew

*     ***** get the initial gradient and direction ****
      call cpsi_1get_Tgradient(G1_tag,E0)
      call cpsi_1get_remainder0(Ermdr)

      call Pneb_ff_traceall_tag(0,0,G1_tag,G1_tag,sum1)

      call BGrsm_ff_Copy_tag(G1_tag,H0_tag)


*     ******************************************
*     ****                                  ****
*     **** Start of conjugate gradient loop ****
*     ****                                  ****
*     ******************************************

      tole  = control_tole()
      tolc  = control_tolc()
      tmin  = deltat_min

      do it=2,it_in

*        **** initialize the geoedesic line data structure ****
         call c_geodesic_start(H0_tag,max_sigma,dE0)

*        **** Copy Hpsi_k to HY then ****
*        **** generate Hpsi using psi_k=U and copy Hpsi_k to HU ****
*        **** compute A,B,C, <S0|H|S0>, <U|H|S0> and <U|H|U> matrices ****
         call c_geodesic_ABC_start(Ermdr,Y,U,HY,HU)

*        ******* line search *********
         if (tmin.gt.0.0d0) then
            deltat = tmin
         else
            deltat = deltat_min
         end if
c         Enew = linesearch(0.0d0,E0,dE0,deltat,
c     >                        cpsi_geodesic_energy,
c     >                        cpsi_geodesic_denergy,
c     >                        tole,tmin,deltae,1)
         Enew = linesearch(0.0d0,E0,dE0,deltat,
     >                        c_geodesic_ABC_energy,
     >                        c_geodesic_ABC_denergy,
     >                        tole,tmin,deltae,1)
         call cpsi_geodesic_final(tmin)
         call cpsi_2toelectron()
         deltac = c_rho_error()

*        **** exit loop early ****
         if ((dabs(deltae).lt.tole).and.(deltac.lt.tolc)) 
     >      go to 30
     
*        **** transport the previous search directions ****
         call cpsi_1geodesic_transport( tmin,H0_tag)

*        **** make psi1 <--- psi2(tmin) ****
         call cpsi_2to1()

*        **** get the new gradient - also updates densities****
         call cpsi_1get_Tgradient(G1_tag,E0)
         call cpsi_1get_remainder0(Ermdr)

         sum0  = sum1

         call Pneb_ff_traceall_tag(0,0,G1_tag,G1_tag,sum1)

*        **** the new direction using Fletcher-Reeves ****
         if ( (dabs(deltae).le.(1.0d-2)).and.
     >        (tmin.gt.deltat_min)) then

           if (sum0.gt.1.0d-15) then
              scale = sum1/sum0
           else
              scale = 0.0d0
           end if

           call BGrsm_f_dscale_tag(scale,H0_tag)

           call BGrsm_fff_sum_tag(G1_tag,H0_tag,H0_tag)

*        **** the new direction using steepest-descent ****
         else
              call BGrsm_ff_Copy_tag(G1_tag,H0_tag)

         end if

      end do

*     **** initialize the geoedesic line data structure ****
      call c_geodesic_start(H0_tag,max_sigma,dE0)

*     **** Copy Hpsi_k to HY then ****
*     **** generate Hpsi using psi_k=U and copy Hpsi_k to HU ****
*     **** compute A,B,C, <S0|H|S0>, <U|H|S0> and <U|H|U> matrices ****
      call c_geodesic_ABC_start(Ermdr,Y,U,HY,HU)


*     ******* line search *********
      if (tmin.gt.0.0d0) then
         deltat = tmin
      else
         deltat = deltat_min
      end if

c      Enew = linesearch(0.0d0,E0,dE0,deltat,
c     >                        cpsi_geodesic_energy,
c     >                        cpsi_geodesic_denergy,
c     >                        tole,tmin,deltae,1)
      Enew = linesearch(0.0d0,E0,dE0,deltat,
     >                        c_geodesic_ABC_energy,
     >                        c_geodesic_ABC_denergy,
     >                        tole,tmin,deltae,1)

      call cpsi_geodesic_final(tmin)
      call cpsi_2toelectron()
      deltac = c_rho_error()

*     **** free memory ****
  30  call cpsi_data_pop_stack(G2_tag)
      call cpsi_data_pop_stack(G1_tag)
      call cpsi_data_pop_stack(G0_tag)
      call cpsi_data_pop_stack(H0_tag)

      call c_geodesic_ABC_finalize()

      call cpsi_2to1()
      !call cpsi_1toelectron() 
      call c_rho_2to1()
      call c_dng_2to1()
      call cpsi_check()

      eion     = ewald_e()
      eorbit   = cpsi_1eorbit()
      ehartree = c_dng_1ehartree()
      exc      = c_rho_1exc()
      pxc      = c_rho_1pxc()

      E(1)  = Enew + eion
      E(2)  = eorbit
      E(3)  = ehartree
      E(4)  = exc
      E(5)  = eion
      E(6)  = cpsi_1ke()
      E(7)  = cpsi_1vl()
      E(8)  = cpsi_1vnl()
      E(9)  = 2.0d0*ehartree
      E(10) = pxc
      E(11) = cpsi_1vnlso()  

*     **** HFX terms ****
      if (band_HFX()) then
         call c_electron_HFX_energies(ehfx,phfx)
         E(26) = ehfx
         E(27) = phfx
      end if

*     **** Dispersion energy ****
      if (ion_disp_on()) then
         E(33) = ion_disp_energy()
         E(1)  = E(1) + E(33)
      end if

      return
      end
 

