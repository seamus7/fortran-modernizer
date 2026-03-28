      PROGRAM ARRAY_OPS
      IMPLICIT INTEGER (A-Z)
      COMMON /DATA/ A(100), B(100), C(100)
      COMMON /SCALARS/ N, SCALE

      N = 100
      SCALE = 2.0

      DO 10 I = 1, N
         A(I) = I * 0.5
         B(I) = SQRT(FLOAT(I))
   10 CONTINUE

      DO 20 I = 1, N
         C(I) = A(I) + B(I) * SCALE
   20 CONTINUE

      WRITE(*,*) 'Array operation complete'
      STOP
      END
