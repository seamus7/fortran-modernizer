! coord_transform.f90 -- geodetic coordinate transformations
! D. Harrison, Oct 1997
! WGS84 only. Don't use with other ellipsoids without changing INIT_WGS84.
! Note: all angles in radians unless otherwise stated

      SUBROUTINE INIT_WGS84()
      ! Load WGS84 ellipsoid constants into shared common block.
      ! Must be called before GEO2ECEF or ECEF2GEO.
      IMPLICIT NONE
      REAL(8) :: a, f
      COMMON /WGS84/ a, f
      a = 6378137.0D0
      f = 1.0D0 / 298.257223563D0
      END SUBROUTINE INIT_WGS84

      SUBROUTINE GEO2ECEF(phi, lam, h, X, Y, Z)
      ! Geodetic (lat, lon, ellipsoidal height) -> ECEF Cartesian
      IMPLICIT NONE
      REAL(8), INTENT(IN)  :: phi, lam, h
      REAL(8), INTENT(OUT) :: X, Y, Z
      REAL(8) :: a, f
      COMMON /WGS84/ a, f
      REAL(8) :: e2, Nphi, sp, cp

      e2   = 2.0D0*f - f*f
      sp   = DSIN(phi)
      cp   = DCOS(phi)
      Nphi = a / DSQRT(1.0D0 - e2*sp*sp)

      X = (Nphi + h) * cp * DCOS(lam)
      Y = (Nphi + h) * cp * DSIN(lam)
      Z = (Nphi*(1.0D0 - e2) + h) * sp

      END SUBROUTINE GEO2ECEF

      SUBROUTINE ECEF2GEO(Xin, Yin, Zin, phi, lam, h)
      ! ECEF -> geodetic, iterative Bowring method
      ! Exits with h=-9999 and a warning if iteration fails (shouldn't happen)
      IMPLICIT NONE
      REAL(8), INTENT(IN)  :: Xin, Yin, Zin
      REAL(8), INTENT(OUT) :: phi, lam, h
      REAL(8) :: a, f
      COMMON /WGS84/ a, f
      REAL(8) :: e2, p, phi0, phi1, sp, cp, Nphi, dphi
      INTEGER :: niter

      e2   = 2.0D0*f - f*f
      p    = DSQRT(Xin*Xin + Yin*Yin)
      lam  = DATAN2(Yin, Xin)

      phi0  = DATAN2(Zin, p*(1.0D0 - e2))
      niter = 0

   10 CONTINUE
      niter = niter + 1
      IF (niter .GT. 30) GOTO 99
      sp   = DSIN(phi0)
      cp   = DCOS(phi0)
      Nphi = a / DSQRT(1.0D0 - e2*sp*sp)
      phi1 = DATAN2(Zin + e2*Nphi*sp, p)
      dphi = phi1 - phi0
      phi0 = phi1
      IF (DABS(dphi) .GT. 1.0D-12) GOTO 10

      phi = phi1
      h   = p / DCOS(phi1) - Nphi
      RETURN

   99 CONTINUE
      WRITE(*,'(A)') 'ECEF2GEO: iteration did not converge'
      phi = 0.0D0
      lam = 0.0D0
      h   = -9999.0D0
      END SUBROUTINE ECEF2GEO

      SUBROUTINE ROT_ENU(phi0, lam0, R)
      ! Build 3x3 rotation matrix for ECEF-delta -> ENU at (phi0, lam0)
      IMPLICIT NONE
      REAL(8), INTENT(IN)  :: phi0, lam0
      REAL(8), INTENT(OUT) :: R(3,3)
      REAL(8) :: sp, cp, sl, cl

      sp = DSIN(phi0)
      cp = DCOS(phi0)
      sl = DSIN(lam0)
      cl = DCOS(lam0)

      ! East row
      R(1,1) = -sl;   R(1,2) =  cl;   R(1,3) = 0.0D0
      ! North row
      R(2,1) = -sp*cl; R(2,2) = -sp*sl; R(2,3) = cp
      ! Up row
      R(3,1) =  cp*cl; R(3,2) =  cp*sl; R(3,3) = sp

      END SUBROUTINE ROT_ENU

      SUBROUTINE ECEF2ENU(Xp, Yp, Zp, x0, y0, z0, phi0, lam0, e, n, u)
      ! ECEF point (Xp,Yp,Zp) -> ENU relative to reference (x0,y0,z0)
      ! phi0, lam0 are geodetic coords of reference point
      IMPLICIT NONE
      REAL(8), INTENT(IN)  :: Xp, Yp, Zp
      REAL(8), INTENT(IN)  :: x0, y0, z0
      REAL(8), INTENT(IN)  :: phi0, lam0
      REAL(8), INTENT(OUT) :: e, n, u
      REAL(8) :: R(3,3), dx, dy, dz

      dx = Xp - x0
      dy = Yp - y0
      dz = Zp - z0

      CALL ROT_ENU(phi0, lam0, R)

      e = R(1,1)*dx + R(1,2)*dy + R(1,3)*dz
      n = R(2,1)*dx + R(2,2)*dy + R(2,3)*dz
      u = R(3,1)*dx + R(3,2)*dy + R(3,3)*dz

      END SUBROUTINE ECEF2ENU

      SUBROUTINE BASELINE(phi1, lam1, h1, phi2, lam2, h2, de, dn, du)
      ! ENU baseline vector from point 1 to point 2
      ! Inputs in radians (lat/lon) and metres (height)
      IMPLICIT NONE
      REAL(8), INTENT(IN)  :: phi1, lam1, h1
      REAL(8), INTENT(IN)  :: phi2, lam2, h2
      REAL(8), INTENT(OUT) :: de, dn, du
      REAL(8) :: x1, y1, z1, x2, y2, z2

      CALL GEO2ECEF(phi1, lam1, h1, x1, y1, z1)
      CALL GEO2ECEF(phi2, lam2, h2, x2, y2, z2)
      CALL ECEF2ENU(x2, y2, z2, x1, y1, z1, phi1, lam1, de, dn, du)

      END SUBROUTINE BASELINE
