*
* $Id$
*
*  ************************************************************
*  *                                                          *
*  *                   BAND cpsd routine                      *
*  *                                                          *
*  ************************************************************
  
      subroutine band_inner_loop(ispin,ispinq,ne,neq,nbrill,nbrillq,
     >                      nfft3d,
     >                      psi1_tag,psi2_tag,dn,
     >                      it_in,E,deltae,deltac,deltar,
     >                      hml_tag,
     >                      psir_tag,Hpsi_tag)
      implicit none
      integer ispin,ispinq,ne(2),neq(2),nbrill,nbrillq,nfft3d
      integer psi1_tag,psi2_tag
      real*8  dn(nfft3d,*)
      integer it_in
      real*8  E(*)
      real*8  deltae,deltac,deltar
      integer hml_tag

*     **** very big workspace variables ****
      integer psir_tag,Hpsi_tag,next1_tag,next2_tag

#include "bafdecls.fh"
#include "errquit.fh"

*     **** local variables ****
      logical move,sic,hfx,done
      integer n2ft3d,np_i,np_j,np_k,np,nbq,nemaxq
      integer i,n,n1(2),n2(2),it,ms,ierr,shifto,indx
      integer shiftA,shiftB,nshiftA,nshiftB,psi1_shift,psi2_shift
      integer nx,ny,nz,nbi,nbj,ki,kj,occ_tag,nb,eig_shift
      integer gga,psi_shift,hpsi_shift,hml_shift,nshift1,nshift2
      real*8  sum,Eold,eorbit,eion,ehartr,eke,elocal,enlocal
      real*8  exc,exc2,pxc,pxc2,dte,scal1,scal2,dv,dt
      real*8  ehsic,phsic,exsic,pxsic,ehfx,phfx
      real*8  deltamm,weight
      real*8  e_lj, e_q, e_spring
      !real*8 e_ionmm,e_qmmm,e_mmmm,e_pol,e_vib,e_cav



*     **** MA local variables ****
      logical value,field_exist,fractional
      integer tmp_L(2),trho(2),txcp(2),txce(2)
      integer tmp1(2),tmp2(2)
      integer vl(2),vc(2),dng(2)
      integer rho(2)
      integer xcp(2),xce(2),dnall(2)
      integer natmx,fion(2),ftest(2)
      integer sumi(2)
      integer npack0
      integer npack1

*     ***** external functions ****
      logical  control_move,cpsp_semicore
      logical  pspw_SIC,pspw_SIC_relaxed
      logical  band_HFX,band_HFX_relaxed
      integer  ion_nion,control_gga,cpsi_data_nsize
      real*8   control_time_step,control_fake_mass,ion_dti
      real*8   lattice_omega,c_coulomb_e,ewald_e
      external control_move,cpsp_semicore
      external pspw_SIC,pspw_SIC_relaxed
      external band_HFX,band_HFX_relaxed
      external ion_nion,control_gga,cpsi_data_nsize
      external control_time_step,control_fake_mass,ion_dti
      external lattice_omega,c_coulomb_e,ewald_e
      integer  control_version,cpsi_data_get_next,cpsi_data_get_chnk
      external control_version,cpsi_data_get_next,cpsi_data_get_chnk
      real*8   brillioun_weight
      external brillioun_weight

      logical  C3dB_cr_pfft3_queue_filled
      external C3dB_cr_pfft3_queue_filled
      logical  Pneb_w_push_get_block,Pneb_w_pop_stack
      external Pneb_w_push_get_block,Pneb_w_pop_stack
      logical  nwpwxc_is_on,control_only_lda
      external nwpwxc_is_on,control_only_lda

*     ***** QM/MM external functions ****
      logical  pspw_charge_found,pspw_qmmm_found
      real*8   pspw_qmmm_LJ_E,pspw_qmmm_Q_E,pspw_qmmm_spring_E
      external pspw_charge_found,pspw_qmmm_found
      external pspw_qmmm_LJ_E,pspw_qmmm_Q_E,pspw_qmmm_spring_E
      logical  ion_disp_on
      external ion_disp_on
      real*8   ion_disp_energy
      external ion_disp_energy

      integer tid
      integer nthreads
      integer  Parallel_threadid, Parallel_nthreads
      external Parallel_threadid, Parallel_nthreads

      logical  control_fractional
      external control_fractional
      integer  control_fractional_smeartype
      external control_fractional_smeartype

      call Cram_npack(0,npack0)
      call Cram_max_npack(npack1)
      deltamm = 0.0d0
      gga     = control_gga()
      nshiftA = 2*npack1
      nshiftB = 2*nfft3d

      n1(1) = 1
      n2(1) = neq(1)
      n1(2) = neq(1)+1
      n2(2) = neq(1)+neq(2)
      nemaxq = neq(1)+neq(2)
      fractional = control_fractional()

      call nwpw_timing_start(12)

*     **** allocate MA local variables ****
      value = Pneb_w_push_get_block(0,1,8,tmp_L)
      value = value.and.
     >        BA_push_get(mt_dcpl,(npack0),'vc',  vc(2),  vc(1))
      value = value.and.
     >        BA_push_get(mt_dcpl,(npack0),'vloc', vl(2), vl(1))
      value = value.and.
     >        BA_push_get(mt_dcpl,(nfft3d),'rho',rho(2),rho(1))
      value = value.and.
     >        BA_push_get(mt_dcpl,(npack0),'dng',dng(2), dng(1))
      value = value.and.
     >        BA_push_get(mt_dbl,(2*nfft3d),'xcp',xcp(2), xcp(1))
      value = value.and.
     >        BA_push_get(mt_dbl,(2*nfft3d),'xce',xce(2), xce(1))
      value = value.and.
     >        BA_push_get(mt_dbl,(2*nfft3d),'dnall',dnall(2),dnall(1))
      natmx = ion_nion()
      value = value.and.
     >        BA_push_get(mt_dbl,(3*natmx),'fion',fion(2),fion(1))
      value = value.and.
     >        BA_push_get(mt_dbl,(3*natmx),'ftest',ftest(2),ftest(1))
      value = value.and.
     >        BA_push_get(mt_dbl,(nemaxq),'sumi',sumi(2),sumi(1))
      if (.not.control_only_lda()) then
         call D3dB_n2ft3d(1,n2ft3d)
         value = BA_push_get(mt_dbl,(2*n2ft3d),'trho',trho(2),trho(1))
         value = value.and.
     >           BA_push_get(mt_dbl,(2*n2ft3d),'txcp',txcp(2),txcp(1))
         value = value.and.
     >           BA_push_get(mt_dbl,(2*n2ft3d),'txce',txce(2),txce(1))
      end if
      if (.not. value) 
     > call errquit('band_inner_loop:out of stack memory',0, MA_ERR)
      call Parallel_shared_vector_zero(.false.,2*nfft3d,dbl_mb(xcp(1)))
      call Parallel_shared_vector_zero(.true., 2*nfft3d,dbl_mb(xce(1)))
      if (fractional) then
         next1_tag = cpsi_data_get_next(psi1_tag)
         next2_tag = cpsi_data_get_next(psi2_tag)
      end if

      call nwpw_timing_end(12)
     
      call C3dB_nx(1,nx)
      call C3dB_ny(1,ny)
      call C3dB_nz(1,nz)
      move = control_move()

      dt = control_time_step()
      dte = dt/dsqrt(control_fake_mass())
      scal1 = 1.0d0/dble(nx*ny*nz)
      scal2 = 1.0d0/lattice_omega()
      dv    = scal1*lattice_omega()

*     ******************************************
*     ****                                  ****
*     ****   Start of steepest descent loop ****
*     ****                                  ****
*     ******************************************
*!$OMP PARALLEL private(it,tid,nthreads)
*      tid      = Parallel_threadid()
*      nthreads = Parallel_nthreads()

      do it=1,it_in

c!$OMP PARALLEL private(tid,nthreads)
c      tid      = Parallel_threadid()
c      nthreads = Parallel_nthreads()
c      write(*,*) "tid,nthreads=",tid,nthreads

        call cpsi_data_copyall(psi2_tag,psi1_tag)
        if (fractional) call cpsi_data_copyall(next2_tag,next1_tag)
        if (move) call ion_shift()

*       ********************************
*       **** generate phaze factors ****
*       ********************************
        call cphafac()
        call cphafac_k()
        call ewald_phafac()
        call nwpw_timing_start(11)

*       *******************
*       **** get psi_r ****
*       *******************
        nbi = 1
        ki  = 1
        shiftA =  cpsi_data_get_chnk(psi1_tag,nbi)

        nbj = 1
        kj  = 1
        shiftB =  cpsi_data_get_chnk(psir_tag,nbj)

c!$OMP END PARALLEL

        done = .false.
        do while (.not.done)

           if (nbi.le.nbrillq) then
              call C3dB_cr_pfft3b_queuein(nbi,dbl_mb(shiftA))
              shiftA = shiftA + nshiftA
              ki = ki+1
              if (ki.gt.nemaxq) then
                 nbi = nbi + 1
                 ki  = 1
                 if (nbi.le.nbrillq) then
                    shiftA =  cpsi_data_get_chnk(psi1_tag,nbi)
                 endif
              end if
           end if

           if ((C3dB_cr_pfft3_queue_filled()).or.(nbi.gt.nbrillq)) then
              call C3dB_cr_pfft3b_queueout(nbj,dbl_mb(shiftB))
              shiftB = shiftB + nshiftB
              kj = kj+1
              if (kj.gt.nemaxq) then
                 nbj = nbj + 1
                 kj  = 1
                 if (nbj.le.nbrillq) then
                    shiftB =  cpsi_data_get_chnk(psir_tag,nbj)
                 endif
              end if
           endif
           done = ((nbi.gt.nbrillq).and.(nbj.gt.nbrillq))
        end do

*       **** set the occupations ****
        call cpsi_data_set_next(psir_tag,cpsi_data_get_next(psi1_tag))

*       *********************
*       **** generate dn ****
*       *********************
        call Parallel_shared_vector_zero(.true.,ispin*nfft3d,dn)


        occ_tag = cpsi_data_get_next(psir_tag)
        if (occ_tag.gt.0) then
         do nbq=1,nbrillq
          weight = brillioun_weight(nbq)
          shiftB = cpsi_data_get_chnk(psir_tag,nbq)
          shifto = cpsi_data_get_chnk(occ_tag,nbq)
          do ms=1,ispin
          do n=n1(ms),n2(ms)
             call C3dB_cr_aSqrpy(1,dbl_mb(shifto)*weight,
     >                             dbl_mb(shiftB),
     >                             dn(1,ms))
             shiftB = shiftB + nshiftB
             shifto = shifto + 1
          end do
          end do
         end do
        else
         do nbq=1,nbrillq
          weight = brillioun_weight(nbq)
          shiftB = cpsi_data_get_chnk(psir_tag,nbq)
          do ms=1,ispin
          do n=n1(ms),n2(ms)
             call C3dB_cr_aSqrpy(1,weight,dbl_mb(shiftB),dn(1,ms))
             shiftB = shiftB + nshiftB
          end do
          end do
         end do
        end if

*       *** reduce over brillioun zone ***
        call K1dB_Vector_SumAll(ispin*nfft3d,dn)
        call DSCAL_OMP(ispin*nfft3d,scal2,dn,1)

        call c_rho_symmetrizer_dn(ispin,nfft3d,dn)


*       **********************
*       **** generate dng ****
*       **********************
        call C3dB_rrc_Sum(1,dn,dn(1,ispin),dcpl_mb(rho(1)))
        call C3dB_rc_pfft3f(1,0,dcpl_mb(rho(1)))
        call C3dB_c_SMul1(1,scal1,dcpl_mb(rho(1)))
        call Cram_c_pack(0,dcpl_mb(rho(1)))
        call Cram_c_Copy(0,dcpl_mb(rho(1)),dcpl_mb(dng(1)))

*       ********************************************************
*       **** generate dnall - used for semicore corrections ****
*       ********************************************************
        if (cpsp_semicore(0)) then
           if (move .or. (it.eq.1)) call c_semicore_density_update()
           call c_semicore_density(dcpl_mb(rho(1)))
           call C3dB_r_SMul1(1,0.5d0,dcpl_mb(rho(1)))
           do ms=1,ispin
             call C3dB_rr_Sum(1,dn(1,ms),
     >                        dcpl_mb(rho(1)),
     >                        dbl_mb(dnall(1)+(ms-1)*nfft3d))
           end do
        else
           call Parallel_shared_vector_copy(.true.,ispin*nfft3d,
     >                                      dn,dbl_mb(dnall(1)))
        end if
        call nwpw_timing_end(11)


*       *****************************************
*       **** generate local pseudopotential  ****
*       **** and also get force if move true ****
*       *****************************************
        call cpsp_v_local(dcpl_mb(vl(1)),
     >               move,
     >               dcpl_mb(dng(1)),
     >               dbl_mb(fion(1)))


*       ************************************
*       **** generate coulomb potential ****
*       ************************************
        call c_coulomb_v(dcpl_mb(dng(1)),dcpl_mb(vc(1)))


*       *************************************************
*       **** generate exchange-correlation potential ****
*       *************************************************
        !if ((.not.nwpwxc_is_on()).and.(gga.eq.0)) then
        if (control_only_lda()) then
           call vxc(nfft3d,ispin,
     >              dbl_mb(dnall(1)),
     >              dbl_mb(xcp(1)),
     >              dbl_mb(xce(1)),
     >              dcpl_mb(rho(1)))

c        !*** this code needs to be optimized!!! ****
         !*** GGA calculation ****
         else
            do ms=1,ispin
              call C3dB_D3dB_r_Copy(1,dbl_mb(dnall(1)+(ms-1)*nfft3d),
     >                                dbl_mb(trho(1) +(ms-1)*n2ft3d))
            end do
            call v_bwexc_all(gga,n2ft3d,ispin,
     >                       dbl_mb(trho(1)),
     >                       dbl_mb(txcp(1)),
     >                       dbl_mb(txce(1)))
            do ms=1,ispin
              call D3dB_C3dB_r_Copy(1,dbl_mb(txcp(1)+(ms-1)*n2ft3d),
     >                                dbl_mb(xcp(1) +(ms-1)*nfft3d))
            end do
            call D3dB_C3dB_r_Copy(1,dbl_mb(txce(1)),
     >                              dbl_mb(xce(1)))
         end if

*       ******************
*       **** get Hpsi ****
*       ******************
        call nwpw_timing_start(13)
        call cpsi_H(ispin,neq,
     >              psi1_tag,
     >              psir_tag,
     >              dcpl_mb(vl(1)),
     >              dcpl_mb(vc(1)),
     >              dbl_mb(xcp(1)),
     >              Hpsi_tag,
     >              move,dbl_mb(fion(1)))

*       ************************************
*       **** do a steepest descent step ****
*       ************************************
        call cpsi_data_update(psi2_tag)
        do nb=1,nbrillq
           psi1_shift = cpsi_data_get_chnk(psi1_tag,nb)
           psi2_shift = cpsi_data_get_chnk(psi2_tag,nb)
           Hpsi_shift = cpsi_data_get_chnk(Hpsi_tag,nb)
           call band_sd_subupdate(nb,npack1,(neq(1)+neq(2)),
     >                             dbl_mb(psi1_shift),
     >                             dbl_mb(psi2_shift),
     >                             dbl_mb(Hpsi_shift),
     >                             dte)
        end do
        call cpsi_data_noupdate(psi2_tag)

        call nwpw_timing_end(13)
c
c*       *******************************************
c*       **** get ewald and semicore forces     ****
c*       ****   and do steepest descent on ions ****
c*       *******************************************
        if (move) then

*          **** get the ewald force ****
           call ewald_f(dbl_mb(fion(1)))

*          **** get the semicore force ****
           if (cpsp_semicore(0)) then
              call c_semicore_xc_F(ispin,dbl_mb(xcp(1)),dbl_mb(fion(1)))
           end if

c*          **** get the qmmm force ****
c           if (pspw_qmmm_found()) call pspw_qmmm_fion(dbl_mb(fion(1)))

*          **** get the dispersion force ****
           if (ion_disp_on()) call ion_disp_force(dbl_mb(fion(1)))

*          **** remove ion forces using ion_FixIon ****
           call ion_FixIon(dbl_mb(fion(1)))

           call ion_optimize_step(dbl_mb(fion(1)))
        end if

*       *****************************************        
*       **** lagrange multiplier corrections ****
*       *****************************************        
        call cpsi_data_update(psi2_tag)
        do nb=1,nbrillq
          psi1_shift = cpsi_data_get_chnk(psi1_tag,nb)
          psi2_shift = cpsi_data_get_chnk(psi2_tag,nb)
          do ms=1,ispinq
          if (neq(ms).gt.0) then
             if (fractional) then
                shifto = cpsi_data_get_chnk(next1_tag,nb)
                call cpsi_lmbda2(ms,nb,npack1,
     >                   dbl_mb(psi1_shift),
     >                   dbl_mb(psi2_shift),
     >                   dte,dbl_mb(shifto),
     >                   dcpl_mb(tmp_L(1)),ierr)
             else
                call cpsi_lmbda(ms,nb,npack1,
     >                   dbl_mb(psi1_shift),
     >                   dbl_mb(psi2_shift),
     >                   dte,
     >                   dcpl_mb(tmp_L(1)),ierr)
             end if
          end if
          end do
        end do
        call cpsi_data_noupdate(psi2_tag)


      end do

*     *************************************
*     ***** total energy calculation ******
*     *************************************
      call nwpw_timing_start(10)
      call Parallel_np(np)
      call Parallel3d_np_i(np_i)
      call Parallel3d_np_j(np_j)
      call Parallel3d_np_k(np_k)

*     *** get orbital energies ****
      eorbit = 0.0d0
      call cpsi_data_update(hml_tag)
      do nb=1,nbrillq
         psi_shift  = cpsi_data_get_chnk(psi1_tag,nb)
         hpsi_shift = cpsi_data_get_chnk(Hpsi_tag,nb)
         hml_shift  = cpsi_data_get_chnk(hml_tag,nb)
         call Pneb_ffw_hermit_Multiply(0,nb,
     >                  dbl_mb(psi_shift),
     >                  dbl_mb(hpsi_shift),npack1,
     >                  dbl_mb(hml_shift))
         call Pneb_w_scal(0,nb,-1.0d0,dbl_mb(hml_shift))
         if ((occ_tag.gt.0).and.(.true.)) then
            shifto = cpsi_data_get_chnk(occ_tag,nb)
            sum  = 0.0d0
             do ms=1,ispin
             do n=1,ne(ms)
                sum = sum 
     >              + dbl_mb(hml_shift+2*(n-1+(n-1)*ne(ms)
     >                      + (ms-1)*ne(1)*ne(1)))
     >                *dbl_mb(shifto) 
                shifto = shifto + 1
             end do
             end do
         else
            call Pneb_w_trace(0,nb,dbl_mb(hml_shift),sum)
         end if
         eorbit = eorbit + sum*brillioun_weight(nb)
      end do
      call cpsi_data_noupdate(hml_tag)
      call K1dB_SumAll(eorbit)
      if (ispin.eq.1) eorbit = eorbit + eorbit


*     **** get ewald energy ****
      eion = ewald_e()


*     **** get coulomb energy ****
      ehartr = c_coulomb_e(dcpl_mb(dng(1)))

*     **** get exchange-correlation energy ****
      call C3dB_rr_dot(1,dbl_mb(dnall(1)),dbl_mb(xce(1)),exc)
      call C3dB_rr_dot(1,dn(1,1),dbl_mb(xcp(1)),pxc)
      if (ispin.eq.1) then
         exc= exc + exc 
         pxc= pxc + pxc 
      else
         call C3dB_rr_dot(1,dbl_mb(dnall(1)+nfft3d),
     >                      dbl_mb(xce(1)),exc2)
         call C3dB_rr_dot(1,dn(1,2),dbl_mb(xcp(1)+nfft3d),pxc2)
         exc= exc + exc2
         pxc= pxc + pxc2
      end if
      exc = exc*dv
      pxc = pxc*dv
  
*     ***** average Kohn-Sham kinetic energy ****
      call cke_ave(ispin,ne,psi1_tag,eke)

*     **** average Kohn-Sham v_local energy ****
      call Cram_cc_dot(0,dcpl_mb(dng(1)),dcpl_mb(vl(1)),elocal)

 
*     ***** average Kohn-Sham v_nonlocal energy ****
      call cpsi_data_zeroall(Hpsi_tag)
      call cpsp_v_nonlocal(ispin,neq,psi1_tag,Hpsi_tag,
     >                     .false.,dbl_mb(ftest(1)))
      call cpsp_v_spin_orbit(ispin,neq,psi1_tag,Hpsi_tag,
     >                       .false.,dbl_mb(ftest(1)))
      call Pneb_ff_traceall_tag(0,0,psi1_tag,Hpsi_tag,enlocal)
      enlocal = -enlocal
      if (ispin.eq.1) enlocal = enlocal + enlocal


*     **** total energy ****
      Eold=E(1)
      E(1) = eorbit + eion + exc - ehartr - pxc
      E(2) = eorbit
      E(3) = ehartr
      E(4) = exc
      E(5) = eion
      E(6) = eke
      E(7) = elocal
      E(8) = enlocal
      E(9) = 2.0d0*ehartr
      E(10) = pxc
c
c      if (pspw_qmmm_found()) then
c         e_lj     = pspw_qmmm_LJ_E()
c         e_q      = pspw_qmmm_Q_E()
c         e_spring = pspw_qmmm_spring_E()
c         E(1)  = E(1) + e_lj + e_q + e_spring
c
c         E(11) = e_lj
c         E(12) = e_q
c         E(13) = e_spring
c      end if


*     **** HFX corrections ****
      if (band_HFX()) then
         call band_energy_HFX(ispin,psir_tag,ehfx,phfx)
         E(1) = E(1) + ehfx
         E(20) = ehfx
         if (band_HFX_relaxed()) then
            E(1)  = E(1) - phfx
            E(21) = phfx
         end if
      end if

*     **** Dispersion energy ****
      if (ion_disp_on()) then
         E(33) = ion_disp_energy()
         E(1)  = E(1) + E(33)
      end if

*     **** set convergence variables ****
      deltae = (E(1)-Eold)/(dt*dble(it_in))

*     *** deltac ***
      deltac = 0.0d0
      do nb=1,nbrillq
         psi1_shift = cpsi_data_get_chnk(psi1_tag,nb)
         psi2_shift = cpsi_data_get_chnk(psi2_tag,nb)
         Hpsi_shift = cpsi_data_get_chnk(Hpsi_tag,nb)
         call dcopy(2*npack1*nemaxq,dbl_mb(psi2_shift),1,
     >                              dbl_mb(Hpsi_shift),1)
         call daxpy(2*npack1*nemaxq,(-1.0d0),dbl_mb(psi1_shift),1,
     >                                       dbl_mb(Hpsi_shift),1)
         do n=1,nemaxq
            call Cram_cc_idot(nb,dbl_mb(Hpsi_shift),dbl_mb(Hpsi_shift),
     >                           dbl_mb(sumi(1)+n-1))
            Hpsi_shift = Hpsi_shift + 2*npack1
         end do
         if (np_i.gt.1) call C3dB_Vector_SumAll(nemaxq,dbl_mb(sumi(1)))
         do n=1,nemaxq
            if(dbl_mb(sumi(1)+n-1).gt.deltac) deltac=dbl_mb(sumi(1)+n-1)
         end do
      end do
c      if (np_j.gt.1) call C1dB_MaxAll(deltac)
      if (np_k.gt.1) call K1dB_MaxAll(deltac)
      deltac = deltac/dte


*     *** deltar ***
      deltar = deltamm
      if (move) then
        do i=1,ion_nion()
           sum = dsqrt( dbl_mb(fion(1)+(i-1)*3  )**2 
     >                + dbl_mb(fion(1)+(i-1)*3+1)**2 
     >                + dbl_mb(fion(1)+(i-1)*3+2)**2)
           if (sum.gt.deltar) deltar = sum
        end do
      end if
       
      call nwpw_timing_end(10)

*     **** dealocate MA local variables ****
      call nwpw_timing_start(12)
      value = .true.
      if (.not.control_only_lda()) then
         value = value.and.BA_pop_stack(txce(2))
         value = value.and.BA_pop_stack(txcp(2))
         value = value.and.BA_pop_stack(trho(2))
      end if
      value = value.and.BA_pop_stack(sumi(2))
      value = value.and.BA_pop_stack(ftest(2))
      value = value.and.BA_pop_stack(fion(2))
      value = value.and.BA_pop_stack(dnall(2))
      value = value.and.BA_pop_stack(xce(2))
      value = value.and.BA_pop_stack(xcp(2))
      value = value.and.BA_pop_stack(dng(2))
      value = value.and.BA_pop_stack(rho(2))
      value = value.and.BA_pop_stack(vl(2))
      value = value.and.BA_pop_stack(vc(2))
      value = value.and.Pneb_w_pop_stack(tmp_L)
      if (.not. value) 
     > call errquit('band_inner_loop:popping stack',0,MA_ERR)

      call nwpw_timing_end(12)

      return
      end
 
      subroutine band_sd_subupdate(nb,nfft3d,nn,
     >                             psi1,psi2,Hpsi,dte)
      implicit none
      integer    nb,nfft3d,nn
      complex*16 psi1(nfft3d,nn)
      complex*16 psi2(nfft3d,nn)
      complex*16 Hpsi(nfft3d,nn)
      real*8     dte

      integer n
*     ************************************
*     **** do a steepest descent step ****
*     ************************************
      do n=1,nn
        call Cram_c_SMul(nb,dte,Hpsi(1,n),psi2(1,n))
        call Cram_cc_Sum2(nb,psi1(1,n),psi2(1,n))
      end do

      return
      end

