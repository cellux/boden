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

\ invert
0 invert -1 = assert
-1 invert 0 = assert
2 invert -3 = assert
-3 invert 2 = assert

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

\ colon
: square dup * ;
5 square 25 = assert
6 square 36 = assert
7 square 49 = assert

\ aligned
0 aligned 0 = assert
1 aligned 4 = assert
2 aligned 4 = assert
3 aligned 4 = assert
4 aligned 4 = assert
5 aligned 8 = assert

\ align
5 here 4 mod - allot
here 4 mod 1 = assert
align
here 4 mod 0= assert

\ tick execute
5 ' dup execute * 25 = assert
9 ' dup execute * 81 = assert

\ swap
5 7 swap 5 = assert 7 = assert

\ literal [ ]
: test-literal [ 752 ] literal 3 + 'A' - ;
test-literal 690 = assert
test-literal 690 = assert

\ parse bl
: skip-until parse 2drop ;
'#' skip-until these will be skipped #
bl parse moo ( -- addr len )
3 = assert
@ $206f6f6d = assert

\ parse-name
parse-name
   this-is-it
10 = assert
@ $73696874 = assert

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

\ cell+
5 cell+ 9 = assert

\ cells
5 3 cells + 17 = assert

\ char
char abc $61 = assert

\ chars
5 chars 5 = assert

\ constant
10 constant ten
ten 10 = assert

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
; \ execute ( if you want to get into an infinite loop )

:noname
s" All tests successful. Ready to rock." println
; execute
