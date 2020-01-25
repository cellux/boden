: true -1 ;
: false 0 ;
: \ $0a parse 2drop ; immediate
: ( ')' parse 2drop ; immediate
: 1+ 1 + ;
: 1- 1 - ;
: erase 0 fill ;
: postpone ' compile, ; immediate
: s" '"' parse swap postpone literal postpone literal ; immediate
: bl $20 ;
: space bl emit ;
: char+ 1+ ;
: chars ;
: char parse-name drop c@ ;
: variable create 1 cells allot ;
: exit $c3 c, ; immediate
: 0= 0 = ;
: 0< 0 < ;
: 0> 0 > ;
: 0<> 0 = invert ;
: negate invert 1+ ;
: rot 2 roll ;
: tuck swap over ;
: decimal #10 base ! ;
: hex #16 base ! ;
: +! swap over @ + swap ! ;
: [ 0 state ! ; immediate
: ] -1 state ! ; immediate
: :noname here postpone ] ; immediate

: if ,jmpz ; immediate
: else here 5 + swap patch-jmp ,jmp ; immediate
: then here swap patch-jmp ; immediate

: begin here ; immediate
: again ,jmp patch-jmp ; immediate
: while ,jmpz ; immediate
: repeat postpone else patch-jmp ; immediate
: until ,jmpz patch-jmp ; immediate

: max 2dup > if drop else nip then ;
: min 2dup < if drop else nip then ;
