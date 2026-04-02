! io_utils.f90 -- observation file I/O for gravity reduction pipeline
! K. Nakamura, 1999
! Assumes ASCII input: lat(deg) lon(deg) height(m) g_obs(mGal) per line
! Max 500 observations -- increase MAXPTS if needed

      SUBROUTINE READ_OBS(fname, npts, lats, lons, hgts, gobs, ierr)
      ! Read observation data from file. Sets ierr=1 on open failure,
      ! ierr=2 on read error, ierr=0 on success.
      IMPLICIT NONE
      CHARACTER(LEN=*), INTENT(IN)  :: fname
      INTEGER,          INTENT(OUT) :: npts, ierr
      REAL(8),          INTENT(OUT) :: lats(500), lons(500)
      REAL(8),          INTENT(OUT) :: hgts(500), gobs(500)
      INTEGER :: ios, i
      INTEGER, PARAMETER :: IUNIT = 11

      ierr = 0
      npts = 0
      i    = 0

      OPEN(UNIT=IUNIT, FILE=fname, STATUS='OLD', IOSTAT=ios)
      IF (ios .NE. 0) THEN
         WRITE(*,'(2A)') 'READ_OBS: cannot open file: ', TRIM(fname)
         ierr = 1
         RETURN
      END IF

   20 CONTINUE
         READ(IUNIT, *, IOSTAT=ios) lats(i+1), lons(i+1), &
                                     hgts(i+1), gobs(i+1)
         IF (ios .LT. 0) GOTO 60          ! normal EOF
         IF (ios .GT. 0) THEN
            WRITE(*,'(A,I5)') 'READ_OBS: parse error at record ', i+1
            ierr = 2
            GOTO 60
         END IF
         i = i + 1
         IF (i .GE. 500) THEN
            WRITE(*,'(A)') 'READ_OBS: MAXPTS reached, input truncated'
            GOTO 60
         END IF
      GOTO 20

   60 CONTINUE
      npts = i
      CLOSE(IUNIT)

      END SUBROUTINE READ_OBS

      SUBROUTINE WRITE_RESULTS(outfile, npts, lats, lons, ganoms, stats)
      ! Write reduced anomalies to output file.
      ! Also computes mean and RMS of the anomaly field (stats(1), stats(2)).
      ! TODO: the statistics part should really be a separate routine.
      IMPLICIT NONE
      CHARACTER(LEN=*), INTENT(IN)  :: outfile
      INTEGER,          INTENT(IN)  :: npts
      REAL(8),          INTENT(IN)  :: lats(npts), lons(npts), ganoms(npts)
      REAL(8),          INTENT(OUT) :: stats(2)
      INTEGER :: ios, i
      INTEGER, PARAMETER :: OUNIT = 12
      REAL(8) :: sumg, sumg2, gmean, grms
      CHARACTER(LEN=80) :: line

      sumg  = 0.0D0
      sumg2 = 0.0D0

      OPEN(UNIT=OUNIT, FILE=outfile, STATUS='REPLACE', IOSTAT=ios)
      IF (ios .NE. 0) THEN
         WRITE(*,'(A)') 'WRITE_RESULTS: failed to open output file'
         stats(1) = 0.0D0
         stats(2) = 0.0D0
         RETURN
      END IF

      WRITE(OUNIT,'(A)') '# lat(deg)      lon(deg)      g_anom(mGal)'

      DO i = 1, npts
         CALL FORMAT_LINE(lats(i), lons(i), ganoms(i), line)
         WRITE(OUNIT,'(A)') TRIM(line)
         sumg  = sumg  + ganoms(i)
         sumg2 = sumg2 + ganoms(i)**2
      END DO

      ! This branch is unreachable: npts arrives from READ_OBS which
      ! only calls us on success, so npts >= 1 here.
      IF (npts .LT. 0) THEN
         WRITE(OUNIT,'(A)') '# no data written'
         CLOSE(OUNIT)
         RETURN
      END IF

      gmean = sumg / DBLE(npts)
      grms  = DSQRT(DABS(sumg2/DBLE(npts) - gmean**2))

      WRITE(OUNIT,'(A,F12.4)') '# mean anomaly (mGal) : ', gmean
      WRITE(OUNIT,'(A,F12.4)') '# rms  anomaly (mGal) : ', grms

      CLOSE(OUNIT)

      stats(1) = gmean
      stats(2) = grms

      END SUBROUTINE WRITE_RESULTS

      SUBROUTINE FORMAT_LINE(lat, lon, ganom, line)
      ! Format a single data line for output.
      IMPLICIT NONE
      REAL(8),           INTENT(IN)  :: lat, lon, ganom
      CHARACTER(LEN=80), INTENT(OUT) :: line
      CHARACTER(LEN=14) :: clat, clon
      CHARACTER(LEN=12) :: cg

      WRITE(clat, '(F14.8)') lat
      WRITE(clon,  '(F14.8)') lon
      WRITE(cg,    '(F12.4)') ganom

      line = clat // '  ' // clon // '  ' // cg

      END SUBROUTINE FORMAT_LINE
