      PROGRAM IO_HANDLER
      INTEGER INPUT_FILE, OUTPUT_FILE
      REAL VALUE
      CHARACTER*80 BUFFER

      INPUT_FILE = 10
      OUTPUT_FILE = 20

      OPEN(INPUT_FILE, FILE='input.dat', STATUS='OLD', ERR=999)
      OPEN(OUTPUT_FILE, FILE='output.dat', STATUS='NEW', ERR=999)

      READ(INPUT_FILE, *, ERR=998, END=997) VALUE
      IF (VALUE .LT. 0.0) GOTO 100
      IF (VALUE .GT. 100.0) GOTO 200
      WRITE(OUTPUT_FILE, '(F10.2)') VALUE
      GOTO 300

  100 CONTINUE
      WRITE(BUFFER, '(A)') 'Value too low'
      WRITE(OUTPUT_FILE, '(A)') BUFFER
      GOTO 300

  200 CONTINUE
      WRITE(BUFFER, '(A)') 'Value too high'
      WRITE(OUTPUT_FILE, '(A)') BUFFER
      GOTO 300

  300 CONTINUE
      CLOSE(INPUT_FILE)
      CLOSE(OUTPUT_FILE)
      STOP

 997 CONTINUE
      WRITE(*,*) 'End of file reached'
      STOP

 998 CONTINUE
      WRITE(*,*) 'Read error'
      STOP

 999 CONTINUE
      WRITE(*,*) 'File open error'
      STOP
      END
