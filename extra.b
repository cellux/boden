: die type cr 1 sys:exit ;

: source-start source drop ;
: source-pos source-start >in @ + ;

variable assert/next-address

: assert/save-next-address skip-while-whitespace source-pos assert/next-address ! ;

: assert/last-text
  assert/next-address @
  dup source-pos swap -
  ;

: assert
  0= if
    s" assertion failed:" type cr
    assert/last-text die
  then
  assert/save-next-address
  ;

0 constant cond immediate
: thens begin ?dup while postpone then repeat ; immediate
