\ true false
true -1 = assert
false 0 = assert

\ numbers
8 5 + 13 = assert
8 5 - 3 = assert
2 3 * 6 = assert
100 4 / 25 = assert

\ # (base 10)
1234 #1234 = assert
\ $ (base 16)
1234 $4d2 = assert
$deadbeef 1+ $deadbef0 = assert
\ % (base 2)
1234 %10011010010 = assert

\ base
base @ #10 = assert \ initial value is 10
#16 base ! base @ #16 = assert
30 #48 = assert
#10 base ! \ restore initial value

\ hex
hex
10 #16 = assert
base @ #16 = assert

\ decimal
decimal
10 #10 = assert
base @ #10 = assert

\ negative numbers
-5 3 + -2 = assert
-1234 #-1234 = assert
-1234 $-4d2 = assert
-1234 %-10011010010 = assert
-5 8 + 7 - -4 = assert
2 -3 * -6 = assert
8 -4 / 5 + 3 = assert

\ character literals
'x' 120 = assert
'!' $21 = assert

\ abs
7 abs 7 = assert
-7 abs 7 = assert

\ mod
7 3 mod 1 = assert
15 6 mod 3 = assert

\ and
0 0 and 0 = assert
$17 $0f and 7 = assert
$face $ff00 and $fa00 = assert

\ or
0 0 or 0 = assert
$17 $0f or $1f = assert
$fa00 $ce or $face = assert

\ xor
0 -1 xor -1 = assert
1234 4321 xor 5171 = assert

\ lshift
1 1 lshift 2 = assert
1 2 lshift 4 = assert
1 3 lshift 8 = assert
-128 8 lshift $-8000 = assert

\ rshift
1 1 rshift 0 = assert
2 1 rshift 1 = assert
4 2 rshift 1 = assert
8 3 rshift 1 = assert
$ffff8000 8 rshift $00ffff80 = assert

\ invert
0 invert -1 = assert
-1 invert 0 = assert
2 invert -3 = assert
-3 invert 2 = assert

\ negate
0 negate 0 = assert
1 negate -1 = assert
-1 negate 1 = assert
2 negate -2 = assert
-2 negate 2 = assert

\ < <= <> = >= >
-3 0 < assert
0 -3 < invert assert
0 3 < assert
3 0 < invert assert
2 2 <= assert
-1 2 <= assert
1 2 <> assert
2 2 = assert
2 2 >= assert
2 -1 >= assert
-1 2 >= invert assert
2 -1 > assert
-1 2 > invert assert
3 0 > assert
0 3 > invert assert

\ 0< 0<> 0= 0>
-1 0< assert
1 0<> assert
0 0= assert
1 0> assert

\ dup
1 2 3 dup
3 = assert
3 = assert
2 = assert
1 = assert

\ nip
depth 0 = assert
5 3 depth 2 = assert
nip 3 = assert
depth 0 = assert

\ over
depth 0 = assert
1 2 over
depth 3 = assert
1 = assert
2 = assert
1 = assert
depth 0 = assert

\ pick
1 2 3
depth 3 = assert
0 pick 3 = assert
1 pick 2 = assert
2 pick 1 = assert
depth 3 = assert
2drop drop

\ roll
1 2 3
0 roll
3 = assert 2 = assert 1 = assert

1 2 3
1 roll
2 = assert 3 = assert 1 = assert

1 2 3
2 roll
1 = assert 3 = assert 2 = assert

\ rot
1 2 3 rot
1 = assert 3 = assert 2 = assert

\ tuck
1 2 tuck 2 = assert 1 = assert 2 = assert

\ 2dup
3 1 2 2dup
2 = assert 1 = assert
2 = assert 1 = assert
3 = assert

\ 2drop
3 1 2 2drop 3 = assert

\ 2over
9 3 1 2 4 2over
1 = assert 3 = assert
4 = assert 2 = assert
1 = assert 3 = assert
9 = assert

\ compare
:noname
s" abc" s" abc" compare 0 = assert
s" abb" s" abc" compare -1 = assert
s" abd" s" abc" compare 1 = assert
s" abcd" s" abc" compare 1 = assert
s" abdd" s" abc" compare 1 = assert
s" abbd" s" abc" compare -1 = assert
s" abc" s" abcd" compare -1 = assert
s" abb" s" abcd" compare -1 = assert
s" abd" s" abcd" compare 1 = assert
s" Jerome" s" Calvin" compare 1 = assert
s" Calvin" s" Jerome" compare -1 = assert
; execute

\ max min
5 3 max 5 = assert
5 3 min 3 = assert
-5 3 max 3 = assert
-5 3 min -5 = assert

\ s"
:noname
s" Hello, world!"
( C: "<chars><dquote>" -- ; R: addr len )
13 = assert
dup 0 + c@ $48 = assert  \ H
dup 1 + c@ $65 = assert  \ e
dup 2 + c@ $6c = assert  \ l
dup 3 + c@ $6c = assert  \ l
dup 12 + c@ $21 = assert \ !
drop
; execute

\ create
create my-var 1234 ,
my-var @ 1234 = assert

\ >body
' my-var >body @ 1234 = assert

\ does>
: does1 does> @ 1 + ;
: does2 does> @ 2 + ;
create my-var 1234 ,
my-var @ 1234 = assert
does1
my-var 1235 = assert
does2
my-var 1236 = assert

: weird: create does> 1 + does> 2 + ;
weird: w1
' w1 >body here = assert
w1 here 1 + = assert
w1 here 2 + = assert

\ colon
: square dup * ;
5 square 25 = assert
6 square 36 = assert
7 square 49 = assert

\ words being defined are hidden until ;
: square square 1+ ;
5 square 26 = assert

\ aligned
0 aligned 0 = assert
1 aligned 1 cells = assert
1 cells 1- aligned 1 cells = assert
1 cells aligned 1 cells = assert
1 cells 1+ aligned 2 cells = assert

\ align
5 here 4 mod - allot
here 4 mod 1 = assert
align
here 4 mod 0= assert

\ tick execute
5 ' dup execute * 25 = assert
9 ' dup execute * 81 = assert
: no-such-word-string s" no-such-word" ;
' no-such-word 0 = assert no-such-word-string compare 0 = assert

\ swap
5 7 swap 5 = assert 7 = assert

\ literal [ ]
: test-literal [ 752 ] literal 3 + 'A' - ;
test-literal 690 = assert
test-literal 690 = assert

\ [']
: test-['] 5 ['] 1+ execute ;
test-['] 6 = assert

\ parse bl
: skip-until parse 2drop ;
'#' skip-until these will be skipped #
bl parse moo ( -- addr len )
3 = assert
dup 0 + c@ 'm' = assert
dup 1 + c@ 'o' = assert
dup 2 + c@ 'o' = assert
drop

\ parse-name
parse-name
   this-is-it
10 = assert
dup 0 + c@ 't' = assert
dup 1 + c@ 'h' = assert
dup 2 + c@ 'i' = assert
dup 3 + c@ 's' = assert
dup 4 + c@ '-' = assert
dup 5 + c@ 'i' = assert
dup 6 + c@ 's' = assert
dup 7 + c@ '-' = assert
dup 8 + c@ 'i' = assert
dup 9 + c@ 't' = assert
drop

\ >in
source drop
>in @ +
c@ '+' = assert

\ exit
:noname 5 exit drop 3 ;
execute 5 = assert

\ char+
0 char+ 1 = assert

\ variable
variable test-var
$face test-var !
test-var @ $face = assert

\ c!
$face1234 test-var !
'A' test-var c!
test-var @ $face1241 = assert

\ +!
1234 test-var !
500 test-var +!
test-var @ 1734 = assert

\ cell+
5 cell+ 5 $word-size + = assert

\ cells
5 3 cells + 5 $word-size 3 * + = assert

\ char
char abc $61 = assert

\ chars
5 chars 5 = assert

\ constant
10 constant ten
ten 10 = assert
ten 10 = assert

\ >r r> r@
:noname
10 >r
3 5 >r
dup 3 = assert
r@ 5 = assert
dup 3 = assert
r@ 5 = assert
r> 5 = assert
3 = assert
r> 10 = assert
; execute

\ 2>r 2r> 2r@
:noname
10 >r
9 >r
7 1
8 3 2>r
2dup 1 = assert drop
2dup swap 7 = assert drop
2r@ 3 = assert 8 = assert
2dup 1 = assert drop
2r@ 3 = assert 8 = assert
2r> 3 = assert 8 = assert
1 = assert
7 = assert
r> 9 = assert
r> 10 = assert
; execute

\ if then
:noname
2 0= if 2 then
depth 0= assert
; execute

\ if else then
:noname
5 3 > if 1 else 2 then 1 = assert
5 3 < if 1 else 2 then 2 = assert
; execute

\ begin again
:noname
0 test-var !
begin
test-var @ dup . 1+ test-var !
again
; drop \ execute ( if you want to get into an infinite loop )

\ begin while repeat
:noname
0 begin dup 505 < while 10 + repeat 510 = assert
; execute

\ begin until
:noname
0 begin 10 + dup 505 > until 510 = assert
; execute

\ do loop
:noname
1 5 0 do 2 * loop 32 = assert
64 8 2 do 2 / loop 1 = assert
; execute

\ i
:noname
0 11 1 do i + loop 55 = assert
1 11 1 do i * loop 3628800 = assert
; execute

\ leave
:noname
0 10 0 do
i +
i 5 = if leave then
i +
loop
25 = assert
; execute

\ unloop
:noname
0 10 0 do
i +
i 5 = if unloop exit then
i +
loop
; execute
25 = assert

\ depth
depth 0 = assert
1 2 3 depth 3 = assert
drop depth 2 = assert
drop depth 1 = assert
drop depth 0 = assert

create test-buffer 64 allot

\ fill
test-buffer 64 $aa fill
test-buffer 3 + 4 $55 fill
test-buffer @ $ffffffff and $55aaaaaa = assert

\ erase
$12345678 test-buffer !
$9abcdef0 test-buffer 4 + !
$0fedcba9 test-buffer 8 + !
$87654321 test-buffer 12 + !
test-buffer 3 + 4 erase
test-buffer @ $ffffffff and $00345678 = assert
test-buffer 4 + @ $ffffffff and $9a000000 = assert
test-buffer 8 + @ $ffffffff and $0fedcba9 = assert
test-buffer 12 + @ $ffffffff and $87654321 = assert

\ postpone shall append the compilation semantics
\ of the following word to the current definition
: postpone-1+ postpone 1+ ; immediate

55
:noname postpone-1+ ; execute
56 = assert

\ ?dup
100 -1 ?dup -1 = assert -1 = assert 100 = assert
101 0 ?dup 0 = assert 101 = assert
102 1 ?dup 1 = assert 1 = assert 102 = assert
