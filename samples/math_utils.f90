      MODULE MATH_UTILS
      CONTAINS

      FUNCTION FACTORIAL(N) RESULT(RES)
      INTEGER, INTENT(IN) :: N
      REAL :: RES
      INTEGER :: I

      IF (N < 0) THEN
         RES = -1.0
         RETURN
      END IF

      RES = 1.0
      DO I = 1, N
         RES = RES * REAL(I)
         IF (RES > 3.4E38) THEN
            RES = 3.4E38
            EXIT
         END IF
      END DO
      END FUNCTION FACTORIAL

      FUNCTION POWER(BASE, EXP) RESULT(RES)
      REAL, INTENT(IN) :: BASE
      INTEGER, INTENT(IN) :: EXP
      REAL :: RES
      INTEGER :: I

      IF (EXP == 0) THEN
         RES = 1.0
         RETURN
      END IF

      RES = 1.0
      DO I = 1, ABS(EXP)
         RES = RES * BASE
         IF (ABS(RES) > 3.4E38) THEN
            RES = SIGN(3.4E38, RES)
            EXIT
         END IF
      END DO

      IF (EXP < 0) RES = 1.0 / RES
      END FUNCTION POWER

      END MODULE MATH_UTILS
