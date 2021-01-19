c     
      subroutine util_blas_set_num_threads(nt)
      implicit none
      integer  nt ! [in]
#if defined(OPENBLAS)
      call openblas_set_num_threads(nt)
#elif defined(MKL)
      call mkl_set_num_threads(nt)
#elif defined(BLIS)
      call bli_thread_set_num_threads(nt)
#elif defined(INTERNALBLAS)
c do nothing      
#else
      call errquit(' util_blas not ready ',0,0)
#endif
      return
      end
      subroutine util_blas_get_num_threads(nt)
      implicit none
      integer  nt ! [in]
#if defined(OPENBLAS)
      external openblas_get_num_threads
      integer openblas_get_num_threads
      nt=openblas_get_num_threads()
#elif defined(MKL) 
      external mkl_get_num_threads
      integer mkl_get_max_threads
      nt=mkl_get_max_threads()
#elif defined(BLIS)
      interface
         function bli_thread_get_num_threads() 
     c        result(res) bind(C, name="bli_thread_get_num_threads")
         use iso_c_binding
         implicit none
         integer(C_INT) :: res
         end function bli_thread_get_num_threads
      end interface
      nt=bli_thread_get_num_threads()
c     return value=-1 -> threading not enabled
#elif defined(INTERNALBLAS)
      nt=1
#else
      call errquit(' util_blas not ready ',0,0)
#endif
      return
      end
      
      