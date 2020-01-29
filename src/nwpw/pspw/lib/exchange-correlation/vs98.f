*     ************************************************
*     *                                              *
*     *                   nwpw_GVT4                  *
*     *                                              *
*     ************************************************
      subroutine nwpw_GVT4(ag,bg,cg,dg,eg,fg,alphag,alphagt,
     >                     xg,zg,gammag,G,dGdx,dGdz)
      implicit none
      real*8 ag,bg,cg,dg,eg,fg,alphag,alphagt,xg,zg,gammag
      real*8 G,dGdx,dGdz
      real*8 xg2,zg2,gammag2

      xg2     = xg*xg
      zg2     = zg*zg
      gammag2 = gammag*gammag

      G = (ag + bg*xg + cg*zg
     &     + dg*xg2 + eg*xg*zg + fg*zg2)/gammag

      dGdx = ( -ag*alphag
     &        + bg*(1.0d0 - 2.0d0*alphag*xg)
     &        - 2.0d0*cg*alphag*zg
     &        + dg*(2.0d0*xg - 3.0d0*alphag*xg2)
     &        + eg*(zg - 3.0d0*alphag*zg*xg)
     &        - 3.0d0*fg*alphag*zg2)/gammag2

      dGdz = ( -ag*alphagt
     &        - 2.0d0*bg*alphagt*xg
     &        + cg*(1.0d0 - 2.0d0*alphagt*zg)
     &        - 3.0d0*dg*alphagt*xg2
     &        + eg*(xg - 3.0d0*alphagt*xg*zg)
     &        + fg*(2.0d0*zg - 3.0d0*alphagt*zg2))/gammag2

      return
      end
*     ************************************************
*     *                                              *
*     *              gen_VS98_restricted             *
*     *                                              *
*     ************************************************

*    This function returns the VS98 exchange-correlation
*  energy density, xce, and its derivatives with respect
*  to n, |grad n|, tau.

*
*   Entry - n2ft3d   : number of grid points
*           rho_in(*) :  density (nup+ndn)
*           agr_in(*): |grad rho_in|
*           tau_in(*): tau
*           x_parameter: scale parameter for exchange
*           c_parameter: scale parameter for correlation
*
*     Exit  - xce(n2ft3d) : VS98 exchange correlation energy density
*             fn(n2ft3d)  : d(n*xce)/dn
*             fdn(n2ft3d) : d(n*xce)/d|grad n|
*             fdtau(n2ft3d) : d(n*xce)/dtau
*
      subroutine gen_VS98_restricted(n2ft3d,rho_in,agr_in,tau_in,
     >                               x_parameter,c_parameter,
     >                               xce,fn,fdn,fdtau)
      implicit none
*     ***** input *****
      integer n2ft3d
      real*8 rho_in(*),agr_in(*),tau_in(*)    
      real*8 x_parameter,c_parameter
*     ***** output *****
      real*8 xce(*),fn(*),fdn(*),fdtau(*)    
*     ***** local declarations *****
      integer i
      real*8 n,agr,tau
      real*8 xr,zr,gamma
      real*8 inv_n,n_13,n_43,n_53,n_83,agr2
      real*8 x,dx_dn,dx_dagr,z,dz_dn,dz_dtau
      real*8 GG,dGdx,dGdz,dG_dn,dG_dagr,dG_dtau
      real*8 ex,fnx,fdnx,fdtaux
      real*8 ess0c,dess0c_drs,dess0c_dn
      real*8 eud0c,deud0c_drs
      real*8 eudc,eud1c,fud1c,dfud1c_dn
      real*8 dfudc_dn,dfudc_dagr,dfudc_dtau
      real*8 rs,drs_dn
      real*8 D,dD_dx,dD_dz,dD_dn,dD_dagr,dD_dtau,dummy
      real*8 ec,fnc,fdnc,fdtauc
*     ***** constants *****
      real*8 pi,thrd,twthrd,frthrd,fvthrd,etthrd
      parameter (pi     = 3.14159265358979311599d0)
      parameter (thrd   = 1.0d0/3.0d0)
      parameter (twthrd = 2.0d0/3.0d0)
      parameter (frthrd = 4.0d0/3.0d0)
      parameter (fvthrd = 5.0d0/3.0d0)
      parameter (etthrd = 8.0d0/3.0d0)
*     ***** density cutoff parametersi *****
      real*8 tol,ETA
      parameter (tol = 1.0d-10)
      parameter (ETA            =      1.0d-20)
*     ***** VS98 constants *****
      real*8 aax,bbx,ccx,ddx,eex,ffx,alphax
      real*8 aass,bbss,ccss,ddss,eess,ffss,alphass
      real*8 aaopp,bbopp,ccopp,ddopp,eeopp,ffopp,alphaopp
      real*8 cf,clda
      parameter (cf     = 9.115599720d0)
c     cf = 3.0d0/5.0d0*(6.0d0*pi*pi)**(2.0d0/3.0d0))
      parameter (clda = 0.9305257363491d0)
      parameter (aax   = -9.800683d-1) 
      parameter (bbx   = -3.556788d-3)
      parameter (ccx   = 6.250326d-3)
      parameter (ddx   = -2.354518d-5)
      parameter (eex   = -1.282732d-4)
      parameter (ffx   = 3.574822d-4)
      parameter (alphax = 0.00186726d0)
      parameter (aass  = 3.270912d-1) 
      parameter (bbss  = -3.228915d-2)
      parameter (ccss  = -2.942406d-2)
      parameter (ddss  = 2.134222d-3)
      parameter (eess  = -5.451559d-3)
      parameter (ffss  = 1.577575d-2)
      parameter (alphass = 0.00515088d0)
      parameter (aaopp = 7.035010d-1) 
      parameter (bbopp = 7.694574d-3)
      parameter (ccopp = 5.152765d-2)
      parameter (ddopp = 3.394308d-5)
      parameter (eeopp = -1.269420d-3)
      parameter (ffopp = 1.296118d-3)
      parameter (alphaopp = 0.00304966d0)

      do i=1,n2ft3d
        n        = rho_in(i) + ETA
        agr      = agr_in(i) + ETA
        tau      = 2.0d0*tau_in(i) + ETA

        n   = 0.50d0*n
        agr = 0.50d0*agr
        tau = 0.50d0*tau

        agr2  = agr*agr
        inv_n = 1.0d0/n
        n_13  = n**thrd
        n_43  = n_13*n
        n_53  = n_43*n_13
        n_83  = n_53*n

        x       = agr2/n_83
        dx_dn   = -etthrd*x*inv_n
        dx_dagr = 2.0d0*agr/n_83
        z       = tau/n_53 - cf
        dz_dn   = -fvthrd*tau/n_83
        dz_dtau = 1.0d0/n_53

*       ***** VS98 Exchange *****
        gamma = 1.0d0 + alphax*(x + z)
        xr = x/gamma
        zr = z/gamma

        call nwpw_GVT4(aax,bbx,ccx,ddx,eex,ffx,alphax,alphax,
     >              xr,zr,gamma,GG,dGdx,dGdz)

        dG_dn   = dGdx*dx_dn + dGdz*dz_dn
        dG_dagr = dGdx*dx_dagr
        dG_dtau = dGdz*dz_dtau

        ex     = clda*n_13*GG
        fnx    = frthrd*ex + clda*n_43*dG_dn
        fdnx   = clda*n_43*dG_dagr
        fdtaux = clda*n_43*dG_dtau

*       ***** VS98 Correlation *****
*       ***** Same-Spin (alpha-alpha/beta-beta) *****
        rs = (0.75d0/(pi*n))**thrd
        drs_dn = -thrd*rs/n

        call gen_PW91_c_rz(tol,rs,1.0d0,ess0c,dess0c_drs,dummy)
        dess0c_dn = dess0c_drs*drs_dn

        D = 1.0d0 - 0.25d0*x/(z+cf)
        if (D .lt. 0.0d0) then
           D       = 0.0d0
           dD_dn   = 0.0d0
           dD_dagr = 0.0d0
           dD_dtau = 0.0d0
        else
           dD_dx   = -1.0d0/(4.0d0*(z + cf))
           dD_dz   =  x/(4.0d0*(z + cf)*(z + cf))
           dD_dn   =  dD_dx*dx_dn + dD_dz*dz_dn
           dD_dagr =  dD_dx*dx_dagr
           dD_dtau =  dD_dz*dz_dtau
        end if

        gamma = 1.0d0 + alphass*(x + z)
        xr = x/gamma
        zr = z/gamma

        call nwpw_GVT4(aass,bbss,ccss,ddss,eess,ffss,alphass,alphass,
     >                 xr,zr,gamma,GG,dGdx,dGdz)

        dG_dn   = dGdx*dx_dn + dGdz*dz_dn
        dG_dagr = dGdx*dx_dagr
        dG_dtau = dGdz*dz_dtau

        ec = ess0c*GG*D
        fnc = ec + n*dess0c_drs*drs_dn*GG*D
     &        + n*ess0c*dG_dn*D 
     &        + n*ess0c*GG*dD_dn
        fdnc = n*ess0c*(dG_dagr*D + GG*dD_dagr)
        fdtauc = n*ess0c*(dG_dtau*D + GG*dD_dtau)

*       ***** Opposite-Spin (alpha-beta) *****
        n = 2.0d0*n
        rs         =  (0.75d0/(pi*n))**thrd
        drs_dn     = -thrd*rs/n

        call gen_PW91_c_rz(tol,rs,0.0d0,eud0c,deud0c_drs,dummy)
        eud1c = eud0c - ess0c
        fud1c = n*eud1c

        x   = 2.0d0*x
        z   = 2.0d0*z

        gamma = 1.0d0 + alphaopp*(x + z)
        xr = x/gamma
        zr = z/gamma

        call nwpw_GVT4(aaopp,bbopp,ccopp,ddopp,eeopp,ffopp,
     >                 alphaopp,alphaopp,
     >                 xr,zr,gamma,GG,dGdx,dGdz)

        dG_dn   = dGdx*dx_dn + dGdz*dz_dn
        dG_dagr = dGdx*dx_dagr
        dG_dtau = dGdz*dz_dtau

        eudc = eud1c*GG

        dfud1c_dn  = eud0c + n*deud0c_drs*drs_dn
     &           - ess0c - 0.50d0*n*dess0c_dn
        dfudc_dn   = fud1c*dG_dn    + GG*dfud1c_dn
        dfudc_dagr = fud1c*dG_dagr
        dfudc_dtau = fud1c*dG_dtau

        ec     = ec     + eudc
        fnc    = fnc    + dfudc_dn
        fdnc   = fdnc   + dfudc_dagr
        fdtauc = fdtauc + dfudc_dtau

        xce(i)   = x_parameter*ex     + c_parameter*ec
        fn(i)    = x_parameter*fnx    + c_parameter*fnc
        fdn(i)   = x_parameter*fdnx   + c_parameter*fdnc
        fdtau(i) = x_parameter*fdtaux + c_parameter*fdtauc
      end do

      return
      end
*     ************************************************
*     *                                              *
*     *              gen_VS98_unrestricted             *
*     *                                              *
*     ************************************************

*    This function returns the VS98 exchange-correlation
*  energy density, xce, and its derivatives with respect
*  to nup, ndn, |grad nup|, |grad ndn|, tauup, taudn.

*
*   Entry - n2ft3d   : number of grid points
*           rho_in(*,2) :  density (nup and ndn)
*           agr_in(*,3): |grad rho_in| (nup, ndn and n)
*           tau_in(*,2): tau (nup and ndn)
*           x_parameter: scale parameter for exchange
*           c_parameter: scale parameter for correlation
*
*     Exit  - xce(n2ft3d) : VS98 exchange correlation energy density
*             fn(n2ft3d,2)  : d(n*xce)/dnup, d(n*xce)/dndn
*             fdn(n2ft3d,3) : d(n*xce)/d|grad nup|, d(n*xce)/d|grad ndn|, d(n*xce)/d|grad n|
*             fdtau(n2ft3d,2) : d(n*xce)/dtauup, d(n*xce)/dtaudn
*
      subroutine gen_VS98_unrestricted(n2ft3d,rho_in,agr_in,tau_in,
     >                               x_parameter,c_parameter,
     >                               xce,fn,fdn,fdtau)
      implicit none
*     ***** input *****
      integer n2ft3d
      real*8 rho_in(n2ft3d,2),agr_in(n2ft3d,3),tau_in(n2ft3d,2)      
      real*8 x_parameter,c_parameter
*     ***** output *****
      real*8 xce(n2ft3d),fn(n2ft3d,2),fdn(n2ft3d,3),fdtau(n2ft3d,2)  
*     ***** local declarations *****
      integer i
      real*8 nup,agrup,tauup
      real*8 ndn,agrdn,taudn
      real*8 n,agr,tau
      real*8 x,dxdn,dxdagr,z,dzdn,dzdtau
      real*8 xr,zr,gamma
      real*8 inv_nup,nup_13,nup_43,nup_53,nup_83,agrup2
      real*8 inv_ndn,ndn_13,ndn_43,ndn_53,ndn_83,agrdn2
      real*8 xup,dxup_dnup,dxup_dagrup,zup,dzup_dnup,dzup_dtauup
      real*8 xdn,dxdn_dndn,dxdn_dagrdn,zdn,dzdn_dndn,dzdn_dtaudn
      real*8 GG,dGdx,dGdz
      real*8 eupx,fnupx,fdnupx,fdtauupx
      real*8 ednx,fndnx,fdndnx,fdtaudnx
      real*8 euu0c,deuu0c_dnup
      real*8 euuc,dfuuc_dnup,dfuuc_dagrup,dfuuc_dtauup
      real*8 edd0c,dedd0c_dndn
      real*8 eddc,dfddc_dndn,dfddc_dagrdn,dfddc_dtaudn
      real*8 eud0c,deud0c_drs,deud0c_dzeta
      real*8 eudc,eud1c,fud1c,dfud1c_dnup,dfud1c_dndn
      real*8 dfudc_dnup,dfudc_dagrup,dfudc_dtauup
      real*8 dfudc_dndn,dfudc_dagrdn,dfudc_dtaudn
      real*8 rs,drs_dn,zeta,dzeta_dnup,dzeta_dndn,deuu0c_drs,dedd0c_drs
      real*8 D,dD_dx,dD_dz,dD_dn,dD_dagr,dD_dtau,dummy
      real*8 eupc,fnupc,fdnupc,fdtauupc
      real*8 ednc,fndnc,fdndnc,fdtaudnc
      real*8 ex,ec
*     ***** constants *****
      real*8 pi,thrd,twthrd,frthrd,fvthrd,etthrd
      parameter (pi     = 3.14159265358979311599d0)
      parameter (thrd   = 1.0d0/3.0d0)
      parameter (twthrd = 2.0d0/3.0d0)
      parameter (frthrd = 4.0d0/3.0d0)
      parameter (fvthrd = 5.0d0/3.0d0)
      parameter (etthrd = 8.0d0/3.0d0)
*     ***** density cutoff parameters *****
      real*8 tol,ETA
      parameter (tol = 1.0d-10)
      parameter (ETA            =      1.0d-20)
*     ***** VS98 constants *****
      real*8 aax,bbx,ccx,ddx,eex,ffx,alphax
      real*8 aass,bbss,ccss,ddss,eess,ffss,alphass
      real*8 aaopp,bbopp,ccopp,ddopp,eeopp,ffopp,alphaopp
      real*8 cf,clda
      parameter (cf     = 9.115599720d0)
c     cf = 3.0d0/5.0d0*(6.0d0*pi*pi)**(2.0d0/3.0d0))
      parameter (clda = 0.9305257363491d0)
      parameter (aax   = -9.800683d-1) 
      parameter (bbx   = -3.556788d-3)
      parameter (ccx   = 6.250326d-3)
      parameter (ddx   = -2.354518d-5)
      parameter (eex   = -1.282732d-4)
      parameter (ffx   = 3.574822d-4)
      parameter (alphax = 0.00186726d0)
      parameter (aass  = 3.270912d-1) 
      parameter (bbss  = -3.228915d-2)
      parameter (ccss  = -2.942406d-2)
      parameter (ddss  = 2.134222d-3)
      parameter (eess  = -5.451559d-3)
      parameter (ffss  = 1.577575d-2)
      parameter (alphass = 0.00515088d0)
      parameter (aaopp = 7.035010d-1) 
      parameter (bbopp = 7.694574d-3)
      parameter (ccopp = 5.152765d-2)
      parameter (ddopp = 3.394308d-5)
      parameter (eeopp = -1.269420d-3)
      parameter (ffopp = 1.296118d-3)
      parameter (alphaopp = 0.00304966d0)

      do i=1,n2ft3d
        nup        = rho_in(i,1) + ETA
        agrup      = agr_in(i,1) + ETA
        tauup      = tau_in(i,1) + ETA
        ndn        = rho_in(i,2) + ETA
        agrdn      = agr_in(i,2) + ETA
        taudn      = tau_in(i,2) + ETA

        n = nup + ndn

*       ***** VS98 Exchange *****
*       ***** Up *****
        agrup2  = agrup*agrup
        inv_nup = 1.0d0/nup
        nup_13  = nup**thrd
        nup_43  = nup_13*nup
        nup_53  = nup_43*nup_13
        nup_83  = nup_53*nup

        xup         = agrup2/nup_83
        dxup_dnup   = -etthrd*xup*inv_nup
        dxup_dagrup = 2.0d0*agrup/nup_83
        zup         = tauup/nup_53 - cf
        dzup_dnup   = -fvthrd*tauup/nup_83
        dzup_dtauup = 1.0d0/nup_53

        gamma = 1.0d0 + alphax*(xup + zup)
        xr = xup/gamma
        zr = zup/gamma

        call nwpw_GVT4(aax,bbx,ccx,ddx,eex,ffx,alphax,alphax,
     >              xr,zr,gamma,GG,dGdx,dGdz)

        eupx     = clda*nup_13*GG
        fnupx    = frthrd*eupx + clda*nup_43*(dGdx*dxup_dnup 
     &             + dGdz*dzup_dnup)
        fdnupx   = clda*nup_43*(dGdx*dxup_dagrup)
        fdtauupx = clda*nup_43*(dGdz*dzup_dtauup)

*       ***** Down *****
        agrdn2  = agrdn*agrdn
        inv_ndn = 1.0d0/ndn
        ndn_13  = ndn**thrd
        ndn_43  = ndn_13*ndn
        ndn_53  = ndn_43*ndn_13
        ndn_83  = ndn_53*ndn

        xdn         = agrdn2/ndn_83
        dxdn_dndn   = -etthrd*xdn*inv_ndn
        dxdn_dagrdn = 2.0d0*agrdn/ndn_83
        zdn         = taudn/ndn_53 - cf
        dzdn_dndn   = -fvthrd*taudn/ndn_83
        dzdn_dtaudn = 1.0d0/ndn_53

        gamma = 1.0d0 + alphax*(xdn + zdn)
        xr = xdn/gamma
        zr = zdn/gamma

        call nwpw_GVT4(aax,bbx,ccx,ddx,eex,ffx,alphax,alphax,
     >              xr,zr,gamma,GG,dGdx,dGdz)

        ednx     = clda*ndn_13*GG
        fndnx    = frthrd*ednx + clda*ndn_43*(dGdx*dxdn_dndn 
     &             + dGdz*dzdn_dndn)
        fdndnx   = clda*ndn_43*(dGdx*dxdn_dagrdn)
        fdtaudnx = clda*ndn_43*(dGdz*dzdn_dtaudn)

        ex = (eupx*nup + ednx*ndn)/n

*       ***** VS98 Correlation *****
*       ***** Same-Spin *****
*       ***** alpha-alpha *****
        rs = (0.75d0/(pi*nup))**thrd
        drs_dn = -thrd*rs/nup

        call gen_PW91_c_rz(tol,rs,1.0d0,euu0c,deuu0c_drs,dummy)
        deuu0c_dnup = deuu0c_drs*drs_dn
        D = 1.0d0 - 0.25d0*xup/(zup+cf)
        if (D .lt. 0.0d0) then
           D       = 0.0d0
           dD_dn   = 0.0d0
           dD_dagr = 0.0d0
           dD_dtau = 0.0d0
        else
           dD_dx   = -1.0d0/(4.0d0*(zup + cf))
           dD_dz   =  xup/(4.0d0*(zup + cf)*(zup + cf))
           dD_dn   =  dD_dx*dxup_dnup + dD_dz*dzup_dnup
           dD_dagr =  dD_dx*dxup_dagrup
           dD_dtau =  dD_dz*dzup_dtauup
        end if

        gamma = 1.0d0 + alphass*(xup + zup)
        xr = xup/gamma
        zr = zup/gamma

        call nwpw_GVT4(aass,bbss,ccss,ddss,eess,ffss,alphass,alphass,
     >                 xr,zr,gamma,GG,dGdx,dGdz)

        eupc = euu0c*GG*D
        fnupc = eupc + nup*deuu0c_drs*drs_dn*GG*D
     &        + nup*euu0c*(dGdx*dxup_dnup+dGdz*dzup_dnup)*D 
     &        + nup*euu0c*GG*dD_dn
        fdnupc = nup*euu0c*(dGdx*dxup_dagrup*D + GG*dD_dagr)
        fdtauupc = nup*euu0c*(dGdz*dzup_dtauup*D + GG*dD_dtau)

*       ***** beta-beta *****
        rs = (0.75d0/(pi*ndn))**thrd
        drs_dn = -thrd*rs/ndn

        call gen_PW91_c_rz(tol,rs,1.0d0,edd0c,dedd0c_drs,dummy)
        dedd0c_dndn = dedd0c_drs*drs_dn
        D = 1.0d0 - 0.25d0*xdn/(zdn+cf)
        if (D .lt. 0.0d0) then
           D       = 0.0d0
           dD_dn   = 0.0d0
           dD_dagr = 0.0d0
           dD_dtau = 0.0d0
        else
           dD_dx   = -1.0d0/(4.0d0*(zdn + cf))
           dD_dz   =  xdn/(4.0d0*(zdn + cf)*(zdn + cf))
           dD_dn   =  dD_dx*dxdn_dndn + dD_dz*dzdn_dndn
           dD_dagr =  dD_dx*dxdn_dagrdn
           dD_dtau =  dD_dz*dzdn_dtaudn
        end if

        gamma = 1.0d0 + alphass*(xdn + zdn)
        xr = xdn/gamma
        zr = zdn/gamma

        call nwpw_GVT4(aass,bbss,ccss,ddss,eess,ffss,alphass,alphass,
     >                 xr,zr,gamma,GG,dGdx,dGdz)

        ednc = edd0c*GG*D
        fndnc = ednc + ndn*dedd0c_drs*drs_dn*GG*D
     &        + ndn*edd0c*(dGdx*dxdn_dndn+dGdz*dzdn_dndn)*D 
     &        + ndn*edd0c*GG*dD_dn
        fdndnc = ndn*edd0c*(dGdx*dxdn_dagrdn*D + GG*dD_dagr)
        fdtaudnc = ndn*edd0c*(dGdz*dzdn_dtaudn*D + GG*dD_dtau)

        ec = (eupc*nup + ednc*ndn)/n

*       ***** Opposite-Spin (alpha-beta) *****
        rs         =  (0.75d0/(pi*n))**thrd
        drs_dn     = -thrd*rs/n
        zeta       =  (nup - ndn)/n
        dzeta_dnup =  ( 1.0d0 - zeta)/n
        dzeta_dndn =  (-1.0d0 - zeta)/n

        call gen_PW91_c_rz(tol,rs,zeta,eud0c,deud0c_drs,deud0c_dzeta)
        eud1c = eud0c - (euu0c*nup + edd0c*ndn)/n
        fud1c = n*eud1c

        x   = xup + xdn
        z   = zup + zdn

        gamma = 1.0d0 + alphaopp*(x + z)
        xr = x/gamma
        zr = z/gamma

        call nwpw_GVT4(aaopp,bbopp,ccopp,ddopp,eeopp,ffopp,
     >                 alphaopp,alphaopp,
     >                 xr,zr,gamma,GG,dGdx,dGdz)

        eudc = eud1c*GG

        dfud1c_dnup = eud0c + n*(deud0c_drs*drs_dn
     &              + deud0c_dzeta*dzeta_dnup) - euu0c
     &              - nup*deuu0c_dnup
        dfud1c_dndn = eud0c + n*(deud0c_drs*drs_dn
     &              + deud0c_dzeta*dzeta_dndn) - edd0c
     &              - ndn*dedd0c_dndn

        dfudc_dnup   = dfud1c_dnup*GG 
     &                 + fud1c*(dGdx*dxup_dnup + dGdz*dzup_dnup)
        dfudc_dndn   = dfud1c_dndn*GG + 
     &                 + fud1c*(dGdx*dxdn_dndn + dGdz*dzdn_dndn)
        dfudc_dagrup = fud1c*dGdx*dxup_dagrup
        dfudc_dagrdn = fud1c*dGdx*dxdn_dagrdn
        dfudc_dtauup = fud1c*dGdz*dzup_dtauup
        dfudc_dtaudn = fud1c*dGdz*dzdn_dtaudn

        ec       = ec       + eudc
        fnupc    = fnupc    + dfudc_dnup
        fndnc    = fndnc    + dfudc_dndn
        fdnupc   = fdnupc   + dfudc_dagrup
        fdndnc   = fdndnc   + dfudc_dagrdn
        fdtauupc = fdtauupc + dfudc_dtauup
        fdtaudnc = fdtaudnc + dfudc_dtaudn

        xce(i)     = x_parameter*ex       + c_parameter*ec
        fn(i,1)    = x_parameter*fnupx    + c_parameter*fnupc
        fn(i,2)    = x_parameter*fndnx    + c_parameter*fndnc
        fdn(i,1)   = x_parameter*fdnupx   + c_parameter*fdnupc
        fdn(i,2)   = x_parameter*fdndnx   + c_parameter*fdndnc
        fdn(i,3)   = 0.0d0
        fdtau(i,1) = x_parameter*fdtauupx + c_parameter*fdtauupc
        fdtau(i,2) = x_parameter*fdtaudnx + c_parameter*fdtaudnc
      end do

      return
      end



******************************* following needed for m06 for now **********************************

*     ************************************************
*     *                                              *
*     *              nwpw_vs98_x                     *
*     *                                              *
*     ************************************************
      subroutine nwpw_vs98_x(avs,bvs,cvs,dvs,evs,fvs,
     >                       frthrd,nx_13,nx_43,
     >                       xx,zz,dxx_dn,dzz_dn,dxx_dagr,dzz_dtau,
     >                       xe,dfdnx,dfdagrx,dfdtaux)
      implicit none
*     ***** input *****
      real*8 avs,bvs,cvs,dvs,evs,fvs 
      real*8 frthrd,nx_13,nx_43
      real*8 xx,zz,dxx_dn,dzz_dn,dxx_dagr,dzz_dtau
*     ***** output *****
      real*8 xe,dfdnx,dfdagrx,dfdtaux
*     ***** local declarations *****
      real*8 gmm,xxr,zzr,GGx,dGx_dx,dGx_dz
*     ***** VS98 constants *****
      real*8 alphavs 
      parameter(alphavs =  0.00186726d0)

      gmm    = 1.0d0 + alphavs*(xx + zz)
      xxr    = xx/gmm
      zzr    = zz/gmm

      call nwpw_GVT4(avs,bvs,cvs,dvs,evs,fvs,alphavs,alphavs,
     >            xxr,zzr,gmm,GGx,dGx_dx,dGx_dz)

      xe      = nx_13*GGx
      dfdnx   = nx_43*(dGx_dx*dxx_dn    + dGx_dz*dzz_dn) 
     &        + frthrd*xe
      dfdagrx = nx_43*(dGx_dx*dxx_dagr)
      dfdtaux = nx_43*(dGx_dz*dzz_dtau) 
      
      return
      end
*     ************************************************
*     *                                              *
*     *                nwpw_vs98_c_ss                *
*     *                                              *
*     ************************************************
      subroutine nwpw_vs98_c_ss(as,bs,cs,ds,es,fs,alphas,
     >                   n,xs,zs,gammas,xsr,zsr,
     >                   dxs_dn,dxs_dagr,dzs_dn,dzs_dtau,
     >                   e0c,de0c_dn,
     >                   ce,dfnc,dfdnc,dfdtauc)
      implicit none
*     ***** input *****
      real*8 as,bs,cs,ds,es,fs,alphas
      real*8 n,xs,zs,gammas,xsr,zsr
      real*8 dxs_dn,dxs_dagr,dzs_dn,dzs_dtau
*     ***** output *****
      real*8 e0c,de0c_dn
      real*8 ce,dfnc,dfdnc,dfdtauc            
*     ***** local declarations *****
      real*8 rs,drs_dn,ne0c,pwc,dpwc_drs,dummy
      real*8 D,dD_dx,dD_dz,dD_dn,dD_dagr,dD_dtau
      real*8 GS,dG_dx,dG_dz,dG_dn,dG_dagr,dG_dtau
*     ***** constants *****
      real*8 pi,thrd
      parameter (pi     =  3.14159265358979311599d0)
      parameter (thrd   = 1.0d0/3.0d0)
*     ***** density cutoff parameters *****
      real*8 tol
      parameter (tol = 1.0d-18)
*     ***** VS98 constants *****
      real*8 cf
      parameter (cf = 9.115599720d0)         
c     cf = 3.0d0/5.0d0*(6.0d0*pi*pi)**(2.0d0/3.0d0))

      rs     =  (0.75d0/(pi*n))**thrd
      drs_dn = -thrd*rs/n

      call gen_PW91_c_rz(tol,rs,1.0d0,pwc,dpwc_drs,dummy)
      e0c     = pwc
      de0c_dn = dpwc_drs*drs_dn
      ne0c    = n*e0c

      call nwpw_GVT4(as,bs,cs,ds,es,fs,alphas,alphas,
     >               xsr,zsr,gammas,GS,dG_dx,dG_dz)

      dG_dn   = dG_dx*dxs_dn    + dG_dz*dzs_dn
      dG_dagr = dG_dx*dxs_dagr
      dG_dtau = dG_dz*dzs_dtau

      D = 1.0d0 - xs/(4.0d0*(zs + cf))      
      if (D .lt. 0.0d0) then
        D       = 0.0d0
        dD_dn   = 0.0d0
        dD_dagr = 0.0d0
        dD_dtau = 0.0d0
      else 
        dD_dx   = -1.0d0/(4.0d0*(zs + cf))
        dD_dz   =  xs/(4.0d0*(zs + cf)*(zs + cf))
        dD_dn   =  dD_dx*dxs_dn + dD_dz*dzs_dn
        dD_dagr =  dD_dx*dxs_dagr
        dD_dtau =  dD_dz*dzs_dtau
      end if

      ce      = e0c*GS*D
      dfnc    = ne0c*(dG_dn*D   + GS*dD_dn)    
     &        + n*GS*D*de0c_dn  + ce
      dfdnc   = ne0c*(dG_dagr*D + GS*dD_dagr)
      dfdtauc = ne0c*(dG_dtau*D + GS*dD_dtau)
      
      return
      end


*     ************************************************
*     *                                              *
*     *            nwpw_vs98_c_restricted            *
*     *                                              *
*     ************************************************
      subroutine nwpw_vs98_c_restricted(ass,bss,css,dss,ess,fss,
     >                               aopp,bopp,copp,dopp,eopp,fopp,
     >                               n,nup,agrup,tauup,
     >                               xup,dxup_dnup,dxup_dagrup,
     >                               zup,dzup_dnup,dzup_dtauup,
     >                               rs,drs_dn,
     >                               ce,fnc,fdnc,fdtauc)
      implicit none
*     ***** input *****
      real*8 ass,bss,css,dss,ess,fss
      real*8 aopp,bopp,copp,dopp,eopp,fopp
      real*8 n,nup,agrup,tauup
      real*8 xup,dxup_dnup,dxup_dagrup,zup,dzup_dnup,dzup_dtauup
      real*8 rs,drs_dn
*     ***** output *****
      real*8 ce,fnc,fdnc,fdtauc      
*     ***** local declarations *****
      real*8 xrup,zrup,gammaup
      real*8 GG,dG_dx,dG_dz
      real*8 ex,fnx,fdnx,fdtaux
      real*8 euu0c,deuu0c_dn
      real*8 euuc,dfuuc_dn,dfuuc_dagr,dfuuc_dtau
      real*8 x,z,gamma,xr,zr
      real*8 dG_dn,dG_dagr,dG_dtau
      real*8 eud0c,deud0c_drs,dummy
      real*8 eudc,eud1c,fud1c,dfud1c_dn
      real*8 dfudc_dn,dfudc_dagr,dfudc_dtau
*     ***** density cutoff parameters *****
      real*8 tol
      parameter (tol = 1.0d-18)
*     ***** VS98 constants *****
      real*8 cf,alpha
      parameter (cf = 9.115599720d0)         
c     cf = 3.0d0/5.0d0*(6.0d0*pi*pi)**(2.0d0/3.0d0))

*     ***** same spin (alpha-alpha or beta-beta)*****
      alpha   =  0.00515088d0
      gammaup = 1.0d0 + alpha*(xup + zup)
      xrup    = xup/gammaup
      zrup    = zup/gammaup

      call nwpw_vs98_c_ss(ass,bss,css,dss,ess,fss,alpha,
     >             nup,xup,zup,gammaup,xrup,zrup,
     >             dxup_dnup,dxup_dagrup,dzup_dnup,dzup_dtauup,
     >             euu0c,deuu0c_dn,
     >             euuc,dfuuc_dn,dfuuc_dagr,dfuuc_dtau)

*     ***** opposite spin (alpha-beta)*****
      x   = 2.0d0*xup
      z   = 2.0d0*zup

      alpha =  0.00304966d0
      gamma = 1.0d0 + alpha*(x + z)
      xr    = x/gamma
      zr    = z/gamma

      call gen_PW91_c_rz(tol,rs,0.0d0,eud0c,deud0c_drs,dummy)
      eud1c = eud0c - euu0c
      fud1c = n*eud1c

      call nwpw_GVT4(aopp,bopp,copp,dopp,eopp,fopp,alpha,alpha,
     >               xr,zr,gamma,GG,dG_dx,dG_dz)

      dG_dn   = dG_dx*dxup_dnup   + dG_dz*dzup_dnup
      dG_dagr = dG_dx*dxup_dagrup
      dG_dtau = dG_dz*dzup_dtauup

      eudc   = GG*eud1c

      dfud1c_dn  = eud0c + n*deud0c_drs*drs_dn  
     &           - euu0c - nup*deuu0c_dn
      dfudc_dn   = fud1c*dG_dn    + GG*dfud1c_dn
      dfudc_dagr = fud1c*dG_dagr
      dfudc_dtau = fud1c*dG_dtau

      ce     = eudc        + euuc 
      fnc    = dfudc_dn    + dfuuc_dn
      fdnc   = dfudc_dagr  + dfuuc_dagr
      fdtauc = dfudc_dtau  + dfuuc_dtau

      return
      end

*     ************************************************
*     *                                              *
*     *            nwpw_vs98_c_unrestricted          *
*     *                                              *
*     ************************************************
      subroutine nwpw_vs98_c_unrestricted(ass,bss,css,dss,ess,fss,
     >                               aopp,bopp,copp,dopp,eopp,fopp,
     >                               n,nup,agrup,tauup,ndn,agrdn,taudn,
     >              xup,dxup_dnup,dxup_dagrup,zup,dzup_dnup,dzup_dtauup,
     >              xdn,dxdn_dndn,dxdn_dagrdn,zdn,dzdn_dndn,dzdn_dtaudn,
     >                   rs,drs_dn,zeta,dzeta_dnup,dzeta_dndn,
     >                   ce,fnupc,fndnc,fdnupc,fdndnc,fdtauupc,fdtaudnc)
      implicit none
*     ***** input *****
      real*8 ass,bss,css,dss,ess,fss
      real*8 aopp,bopp,copp,dopp,eopp,fopp
      real*8 n,nup,agrup,tauup,ndn,agrdn,taudn 
      real*8 xup,dxup_dnup,dxup_dagrup,zup,dzup_dnup,dzup_dtauup
      real*8 xdn,dxdn_dndn,dxdn_dagrdn,zdn,dzdn_dndn,dzdn_dtaudn
      real*8 rs,drs_dn,zeta,dzeta_dnup,dzeta_dndn
*     ***** output *****
      real*8 ce,fnupc,fndnc,fdnupc,fdndnc,fdtauupc,fdtaudnc 
*     ***** local declarations *****
      real*8 xud,zud
      real*8 gammaup,xrup,zrup
      real*8 gammadn,xrdn,zrdn
      real*8 gammaud,xrud,zrud,GGud,dGud_dxud,dGud_dzud
      real*8 GG,dG_dx,dG_dz
      real*8 dGud_dnup,dGud_dagrup,dGud_dtauup
      real*8 dGud_dndn,dGud_dagrdn,dGud_dtaudn
      real*8 eupx,fnupx,fdnupx,fdtauupx
      real*8 ednx,fndnx,fdndnx,fdtaudnx
      real*8 euu0c,deuu0c_dnup
      real*8 euuc,dfuuc_dnup,dfuuc_dagrup,dfuuc_dtauup
      real*8 edd0c,dedd0c_dndn
      real*8 eddc,dfddc_dndn,dfddc_dagrdn,dfddc_dtaudn
      real*8 eud0c,deud0c_drs,deud0c_dzeta
      real*8 eudc,eud1c,fud1c,dfud1c_dnup,dfud1c_dndn
      real*8 dfudc_dnup,dfudc_dagrup,dfudc_dtauup
      real*8 dfudc_dndn,dfudc_dagrdn,dfudc_dtaudn
*     ***** density cutoff parameters *****
      real*8 tol
      parameter (tol = 1.0d-18)
*     ***** VS98 constants ******
      real*8 cf,alpha
      parameter (cf = 9.115599720d0)        
c     cf = 3.0d0/5.0d0*(6.0d0*pi*pi)**(2.0d0/3.0d0))

*     ***** same spin *****
      alpha =  0.00515088d0
*     ***** alpha-alpha *****
      gammaup = 1.0d0 + alpha*(xup + zup)
      xrup    = xup/gammaup
      zrup    = zup/gammaup

      call nwpw_vs98_c_ss(ass,bss,css,dss,ess,fss,alpha,
     >             nup,xup,zup,gammaup,xrup,zrup,
     >             dxup_dnup,dxup_dagrup,dzup_dnup,dzup_dtauup,
     >             euu0c,deuu0c_dnup,
     >             euuc,dfuuc_dnup,dfuuc_dagrup,dfuuc_dtauup)

*     ***** beta-beta *****
      gammadn = 1.0d0 + alpha*(xdn + zdn)
      xrdn    = xdn/gammadn
      zrdn    = zdn/gammadn

      call nwpw_vs98_c_ss(ass,bss,css,dss,ess,fss,alpha,
     >             ndn,xdn,zdn,gammadn,xrdn,zrdn,
     >             dxdn_dndn,dxdn_dagrdn,dzdn_dndn,dzdn_dtaudn,
     >             edd0c,dedd0c_dndn,
     >             eddc,dfddc_dndn,dfddc_dagrdn,dfddc_dtaudn)

*     ***** opposite spin (alpha-beta) *****
      xud     = xup + xdn
      zud     = zup + zdn

      alpha   = 0.00304966d0
      gammaud = 1.0d0 + alpha*(xud + zud)
      xrud    = xud/gammaud
      zrud    = zud/gammaud

      call gen_PW91_c_rz(tol,rs,zeta,eud0c,deud0c_drs,deud0c_dzeta)
      eud1c = eud0c - (euu0c*nup + edd0c*ndn)/n
      fud1c = n*eud1c

      call nwpw_GVT4(aopp,bopp,copp,dopp,eopp,fopp,alpha,alpha,
     >               xrud,zrud,gammaud,GGud,dGud_dxud,dGud_dzud)

      dGud_dnup   = dGud_dxud*dxup_dnup   + dGud_dzud*dzup_dnup
      dGud_dndn   = dGud_dxud*dxdn_dndn   + dGud_dzud*dzdn_dndn
      dGud_dagrup = dGud_dxud*dxup_dagrup
      dGud_dagrdn = dGud_dxud*dxdn_dagrdn
      dGud_dtauup = dGud_dzud*dzup_dtauup
      dGud_dtaudn = dGud_dzud*dzdn_dtaudn

      eudc   = GGud*eud1c

      dfud1c_dnup = eud0c + n*(deud0c_drs*drs_dn 
     &            + deud0c_dzeta*dzeta_dnup) - euu0c - nup*deuu0c_dnup
      dfud1c_dndn = eud0c + n*(deud0c_drs*drs_dn 
     &            + deud0c_dzeta*dzeta_dndn) - edd0c - ndn*dedd0c_dndn

      dfudc_dnup   = fud1c*dGud_dnup    + GGud*dfud1c_dnup
      dfudc_dndn   = fud1c*dGud_dndn    + GGud*dfud1c_dndn
      dfudc_dagrup = fud1c*dGud_dagrup
      dfudc_dagrdn = fud1c*dGud_dagrdn
      dfudc_dtauup = fud1c*dGud_dtauup
      dfudc_dtaudn = fud1c*dGud_dtaudn

      ce       = eudc          + (euuc*nup  + eddc*ndn)/n 
      fnupc    = dfudc_dnup    + dfuuc_dnup
      fndnc    = dfudc_dndn    + dfddc_dndn
      fdnupc   = dfudc_dagrup  + dfuuc_dagrup
      fdndnc   = dfudc_dagrdn  + dfddc_dagrdn
      fdtauupc = dfudc_dtauup  + dfuuc_dtauup
      fdtaudnc = dfudc_dtaudn  + dfddc_dtaudn


      return
      end
