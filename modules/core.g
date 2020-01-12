: s" '"' parse ;
: \ $0a parse 2drop ; immediate
: ( ')' parse 2drop ; immediate
: bl $20 ;
: variable create 4 allot ;
: exit $c3 c, ; immediate
: 0= 0 = ;
: 0< 0 < ;
: 0> 0 > ;
: 0<> 0 = invert ;
: dec #10 base ! ;
: hex #16 base ! ;
: 1+ 1 + ;
: 1- 1 - ;
: cell+ 4 + ;
: cells 4 * ;
: char+ 1+ ;
: char parse-name drop c@ ;
: chars ;
: [ 0 state ! ; immediate
: ] -1 state ! ; immediate
