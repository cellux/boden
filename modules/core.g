: true -1 ;
: false 0 ;
: \ $0a parse 2drop ; immediate
: ( ')' parse 2drop ; immediate
: erase 0 fill ;
: postpone ' compile, ; immediate
: s" '"' parse swap postpone literal postpone literal ; immediate
: bl $20 ;
: cell+ 4 + ;
: cells 4 * ;
: char+ 1+ ;
: chars ;
: char parse-name drop c@ ;
: variable create 1 cells allot ;
: exit $c3 c, ; immediate
: 0= 0 = ;
: 0< 0 < ;
: 0> 0 > ;
: 0<> 0 = invert ;
: max 2dup > if drop else nip then ;
: min 2dup < if drop else nip then ;
: decimal #10 base ! ;
: hex #16 base ! ;
: 1+ 1 + ;
: 1- 1 - ;
: [ 0 state ! ; immediate
: ] -1 state ! ; immediate
: :noname here postpone ] ; immediate

: begin here ; immediate
: again
here 2 + \ -- begin-addr here+2
-        \ calculate jump offset
$eb c,   \ compile JMP opcode
c,       \ compile jump offset
; immediate
