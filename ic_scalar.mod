	  �  ;   k820309              15.0        �BX                                                                                                           
       t.ic_scalar.f90 IC_SCALAR                                                     
       RPREC                      @                              
  
     LD NX NY NZ Z_I DZ LBZ NPROC COORD NZ_TOT                                                     
       U V W                      @                              
       MPI_SYNC_REAL_ARRAY MPI_SYNC_DOWNUP                                                     
       ML_BASE_ON_GRID                                                                                                                                                                                                                                                                 	                                                      
                                                           
                                                       
                                                                                                           0                                                                                                                                                                                                                                 
                &                   &                   &                                                                                                       
                &                   &                   &                                                                                                       
                &                   &                   &                                           #         @                                                     #MPI_SYNC_REAL_ARRAY%SIZE    #MPI_SYNC_REAL_ARRAY%UBOUND    #VAR    #LBZ    #ISYNC                  @                                SIZE               @                                UBOUND        " 
    �                                              
               &                   &                   & 5 O p                                                    
                        @                              
                                                                                                                                                3#         @                                               	      #MPI!ML_BASE_ON_GRID%MPI_FORTRAN_BOTTOM    #MPI!ML_BASE_ON_GRID%MPI_FORTRAN_IN_PLACE    #MPI!ML_BASE_ON_GRID%MPI_FORTRAN_ARGV_NULL     #MPI!ML_BASE_ON_GRID%MPI_FORTRAN_ARGVS_NULL "   #MPI!ML_BASE_ON_GRID%MPI_FORTRAN_ERRCODES_IGNORE $   #MPI!ML_BASE_ON_GRID%MPI_FORTRAN_STATUS_IGNORE &   #MPI!ML_BASE_ON_GRID%MPI_FORTRAN_STATUSES_IGNORE (   #MPI!ML_BASE_ON_GRID%MPI_FORTRAN_UNWEIGHTED *   #MPI!ML_BASE_ON_GRID%MPI_FORTRAN_WEIGHTS_EMPTY ,   #Z_ML .                                                                     #ML_BASE_ON_GRID%MPI_FORTRAN_BOTTOM%MPI_BOTTOM              �            �                                                                                                       #ML_BASE_ON_GRID%MPI_FORTRAN_IN_PLACE%MPI_IN_PLACE              �            �                                                                                                        #ML_BASE_ON_GRID%MPI_FORTRAN_ARGV_NULL%MPI_ARGV_NULL !   -          �            �                 !                                 p          p            p                                                                          "                          #ML_BASE_ON_GRID%MPI_FORTRAN_ARGVS_NULL%MPI_ARGVS_NULL #   -          �            �                 #                                 p          p            p                                                                          $                          #ML_BASE_ON_GRID%MPI_FORTRAN_ERRCODES_IGNORE%MPI_ERRCODES_IGNORE %             �            �                 %                                 p          p            p                                                                          &                          #ML_BASE_ON_GRID%MPI_FORTRAN_STATUS_IGNORE%MPI_STATUS_IGNORE '             �            �                 '                                 p          p            p                                                                          (                          #ML_BASE_ON_GRID%MPI_FORTRAN_STATUSES_IGNORE%MPI_STATUSES_IGNORE )             �            �                 )                                 p          p          p            p          p                                                                          *                          #ML_BASE_ON_GRID%MPI_FORTRAN_UNWEIGHTED%MPI_UNWEIGHTED +             �            �                 +                                                            ,                          #ML_BASE_ON_GRID%MPI_FORTRAN_WEIGHTS_EMPTY%MPI_WEIGHTS_EMPTY -             �            �                 -                                                              .     
       #         @                                  /                    #FNAME_SCALAR 0   #SCALAR 1   #PRESSURE 2   #Z1 3   #SCALAR1 4             
                                 0     @                               D     �                           1                    
     p           & p         5 r 
         5 r 
   p         p                                   D     �                           2                    
     p           & p         5 r 
         5 r 
   p         p                                    D                                3     
                 D                                4     
       #         @                                   5                    #INITIALIZE_TEMPERATURE%REAL 6                                                                                                                                                                                                6     REAL #         @                                  7                                                                                                                                                     #         @                                   8                    #INITIALIZE_SALINITY%REAL 9                                                                                                                                                   9     REAL #         @                                  :                                                                                                                                            �   "      fn#fn    �   F   J  TYPES      j   j  PARAM    r  F   J  SIM_PARAM    �  d   J  MPI_DEFS      P   J  OCEAN_BASE    l  p       RPREC+TYPES    �  @       LD+PARAM      @       NX+PARAM    \  @       NY+PARAM    �  @       NZ+PARAM    �  @       Z_I+PARAM      @       DZ+PARAM    \  q       LBZ+PARAM    �  @       NPROC+PARAM      @       COORD+PARAM    M  @       NZ_TOT+PARAM    �  �       U+SIM_PARAM    I  �       V+SIM_PARAM      �       W+SIM_PARAM -   �  �       MPI_SYNC_REAL_ARRAY+MPI_DEFS 7   d  =      MPI_SYNC_REAL_ARRAY%SIZE+MPI_DEFS=SIZE ;   �  ?      MPI_SYNC_REAL_ARRAY%UBOUND+MPI_DEFS=UBOUND 1   �  �   a   MPI_SYNC_REAL_ARRAY%VAR+MPI_DEFS 1   �	  @   a   MPI_SYNC_REAL_ARRAY%LBZ+MPI_DEFS 3   �	  @   a   MPI_SYNC_REAL_ARRAY%ISYNC+MPI_DEFS )   (
  q       MPI_SYNC_DOWNUP+MPI_DEFS +   �
        ML_BASE_ON_GRID+OCEAN_BASE N   �  �   �  MPI!ML_BASE_ON_GRID%MPI_FORTRAN_BOTTOM+MPI=MPI_FORTRAN_BOTTOM M   '  H     ML_BASE_ON_GRID%MPI_FORTRAN_BOTTOM%MPI_BOTTOM+MPI=MPI_BOTTOM R   o  �   �  MPI!ML_BASE_ON_GRID%MPI_FORTRAN_IN_PLACE+MPI=MPI_FORTRAN_IN_PLACE S   �  H     ML_BASE_ON_GRID%MPI_FORTRAN_IN_PLACE%MPI_IN_PLACE+MPI=MPI_IN_PLACE T   >  �   �  MPI!ML_BASE_ON_GRID%MPI_FORTRAN_ARGV_NULL+MPI=MPI_FORTRAN_ARGV_NULL V   �  �     ML_BASE_ON_GRID%MPI_FORTRAN_ARGV_NULL%MPI_ARGV_NULL+MPI=MPI_ARGV_NULL V   k  �   �  MPI!ML_BASE_ON_GRID%MPI_FORTRAN_ARGVS_NULL+MPI=MPI_FORTRAN_ARGVS_NULL Y   �  �     ML_BASE_ON_GRID%MPI_FORTRAN_ARGVS_NULL%MPI_ARGVS_NULL+MPI=MPI_ARGVS_NULL `   �  �   �  MPI!ML_BASE_ON_GRID%MPI_FORTRAN_ERRCODES_IGNORE+MPI=MPI_FORTRAN_ERRCODES_IGNORE h   /  �     ML_BASE_ON_GRID%MPI_FORTRAN_ERRCODES_IGNORE%MPI_ERRCODES_IGNORE+MPI=MPI_ERRCODES_IGNORE \   �  �   �  MPI!ML_BASE_ON_GRID%MPI_FORTRAN_STATUS_IGNORE+MPI=MPI_FORTRAN_STATUS_IGNORE b   d  �     ML_BASE_ON_GRID%MPI_FORTRAN_STATUS_IGNORE%MPI_STATUS_IGNORE+MPI=MPI_STATUS_IGNORE `     �   �  MPI!ML_BASE_ON_GRID%MPI_FORTRAN_STATUSES_IGNORE+MPI=MPI_FORTRAN_STATUSES_IGNORE h   �  �     ML_BASE_ON_GRID%MPI_FORTRAN_STATUSES_IGNORE%MPI_STATUSES_IGNORE+MPI=MPI_STATUSES_IGNORE V   a  �   �  MPI!ML_BASE_ON_GRID%MPI_FORTRAN_UNWEIGHTED+MPI=MPI_FORTRAN_UNWEIGHTED Y   �  H     ML_BASE_ON_GRID%MPI_FORTRAN_UNWEIGHTED%MPI_UNWEIGHTED+MPI=MPI_UNWEIGHTED \   4  �   �  MPI!ML_BASE_ON_GRID%MPI_FORTRAN_WEIGHTS_EMPTY+MPI=MPI_FORTRAN_WEIGHTS_EMPTY b   �  H     ML_BASE_ON_GRID%MPI_FORTRAN_WEIGHTS_EMPTY%MPI_WEIGHTS_EMPTY+MPI=MPI_WEIGHTS_EMPTY 0     @   a   ML_BASE_ON_GRID%Z_ML+OCEAN_BASE !   M  �       READ_INIT_SCALAR .   �  P   a   READ_INIT_SCALAR%FNAME_SCALAR (   &  �   a   READ_INIT_SCALAR%SCALAR *   �  �   a   READ_INIT_SCALAR%PRESSURE $   �  @   a   READ_INIT_SCALAR%Z1 )   �  @   a   READ_INIT_SCALAR%SCALAR1 '   .  �       INITIALIZE_TEMPERATURE ,   *  =      INITIALIZE_TEMPERATURE%REAL !   g  �       INIT_TEMPERATURE $   /  �       INITIALIZE_SALINITY )   �  =      INITIALIZE_SALINITY%REAL    8  �       INIT_SALINITY 