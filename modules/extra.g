: die println 1 sys:exit ;

\ TODO: print line number and source code from parse buffer
: assert 0= if s" assertion failed" die then ;
