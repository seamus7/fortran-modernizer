C     gravity_model.f
C     Normal gravity, terrain corrections, station interpolation
C     Adapted from Moritz (1984) and internal survey notes
C     Last modified: March 1994

C     ---------------------------------------------------------------
      SUBROUTINE GRVNRM(PHI, GNRM)
C     Normal gravity by Somigliana formula (GRS80 reference ellipsoid)
C     PHI  = geodetic latitude (radians)
C     GNRM = normal gravity (m/s^2)
      IMPLICIT REAL*8 (A-H, O-Z)
      IMPLICIT INTEGER (I-N)

      DATA GE  / 9.7803267715D0 /
      DATA GP  / 9.8321863685D0 /
      DATA AE  / 6378137.0D0 /
      DATA BP  / 6356752.3141D0 /

      SP2 = DSIN(PHI)**2
      CP2 = DCOS(PHI)**2

      TOP  = AE*GE*CP2 + BP*GP*SP2
      BOT  = DSQRT(AE**2*CP2 + BP**2*SP2)
      GNRM = TOP / BOT

      RETURN
      END

C     ---------------------------------------------------------------
      SUBROUTINE GRVINT(X1,Y1,G1,X2,Y2,G2,X3,Y3,G3,XP,YP,GP)
C     Inverse-distance weighted gravity estimate at point P from 3 stations
C     X,Y in km (local grid); G in mGal
      REAL X1,Y1,G1,X2,Y2,G2,X3,Y3,G3,XP,YP,GP
      REAL D1,D2,D3,W1,W2,W3,WSUM

      D1 = SQRT((XP-X1)**2 + (YP-Y1)**2)
      D2 = SQRT((XP-X2)**2 + (YP-Y2)**2)
      D3 = SQRT((XP-X3)**2 + (YP-Y3)**2)

C     if point coincides with a station, return that value directly
      IF (D1 .LT. 0.001) THEN
         GP = G1
         RETURN
      ENDIF
      IF (D2 .LT. 0.001) THEN
         GP = G2
         RETURN
      ENDIF
      IF (D3 .LT. 0.001) THEN
         GP = G3
         RETURN
      ENDIF

      W1   = 1.0 / D1
      W2   = 1.0 / D2
      W3   = 1.0 / D3
      WSUM = W1 + W2 + W3
      GP   = (W1*G1 + W2*G2 + W3*G3) / WSUM

      RETURN
      END

C     ---------------------------------------------------------------
      SUBROUTINE BOUGUER(H, RHO, GCORR)
C     Complete Bouguer correction (free-air + plate)
C     H     = station orthometric height (m)
C     RHO   = assumed crustal density (g/cm^3)
C     GCORR = total correction in mGal (add to observed)
      REAL H, RHO, GCORR, FAC, BPC

C     free-air: +0.3086 mGal/m going up
      FAC = 0.3086 * H

C     Bouguer plate: remove slab of thickness H, density RHO
      BPC = 0.04193 * RHO * H

      GCORR = FAC - BPC

      RETURN
      END

C     ---------------------------------------------------------------
      SUBROUTINE GRVFAC(PHI, H, RHO, GOBS, GANOM)
C     Compute Bouguer anomaly from observed gravity
C     Calls GRVNRM for theoretical gravity and BOUGUER for terrain correction
C     PHI   = geodetic latitude (radians)
C     H     = station height (m)
C     RHO   = crustal density (g/cm^3)
C     GOBS  = observed gravity (mGal)
C     GANOM = Bouguer anomaly (mGal)
      IMPLICIT REAL*8 (A-H, O-Z)
      REAL GCORR, GANOM, GOBS, H, RHO

      CALL GRVNRM(PHI, GNRM)
C     convert m/s^2 to mGal
      GNRM = GNRM * 1.0D5

      CALL BOUGUER(H, RHO, GCORR)

      GANOM = GOBS - GNRM + GCORR

      RETURN
      END
