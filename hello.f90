program hello
  implicit none
  integer :: i, n
  real :: sum
  n = 11
  sum = 0.0
  do i = 1, n
    sum = sum + i
  end do
  print *, "Sum =", sum
end program hello
