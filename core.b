: true -1 ;
: false 0 ;
: \ $0a parse 2drop ; immediate
: ( ')' parse 2drop ; immediate
: 1+ 1 + ;
: 1- 1 - ;
: erase 0 fill ;
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
: ['] ' postpone literal ; immediate
: :noname here postpone ] ; immediate

: if ,jmpz ; immediate
: else here 5 + swap patch-jmp ,jmp ; immediate
: then here swap patch-jmp ; immediate

: begin here ; immediate
: again ,jmp patch-jmp ; immediate
: while ,jmpz ; immediate
: repeat postpone else patch-jmp ; immediate
: until ,jmpz patch-jmp ; immediate

: do
  here lit-offset + \ address of the value pushed to DS by the code compiled by LITERAL
  0
  postpone literal  \ push LEAVE target to DS
  postpone >r       \ move LEAVE target to RS
  postpone >r       \ move index to RS
  postpone >r       \ move limit to RS
  here              \ target address of LOOP
  ; immediate

: unloop
  postpone r>       \ remove limit
  postpone drop
  postpone r>       \ remove index
  postpone drop
  postpone r>       \ remove LEAVE target
  postpone drop
  ; immediate

: loop
  postpone r>       \ move limit to DS
  postpone r>       \ move index to DS
  postpone 1+       \ increase index by one
  postpone >r       \ move index to RS
  postpone >r       \ move limit to RS
  postpone 2r@
  postpone =        \ compare index with limit
  ,jmpz patch-jmp   \ loop if result is false
  postpone unloop
  here swap !       \ patch LEAVE target
  ; immediate

: i
  postpone 2r@
  postpone drop
  ; immediate

: leave
  postpone r>       \ remove limit
  postpone drop
  postpone r>       \ remove index
  postpone drop
  postpone exit     \ return to LEAVE target left on RS
  ; immediate

: max 2dup > if drop else nip then ;
: min 2dup < if drop else nip then ;

: ?dup dup dup if exit then drop ;
