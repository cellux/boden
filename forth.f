8 5 + 13 = assert
8 5 - 3 = assert
2 3 * 6 = assert
100 4 / 25 = assert

\ numbers do not have to be followed by whitespace
2 5- 8+ 5= assert

\ base may be temporarily overridden via the following number prefixes:
\
\ # (base 10)
\ $ (base 16)
\ % (base 2)
1234 #1234 = assert
1234 $4d2 = assert
1234 %10011010010 = assert

\ BASE
base @ #10 = assert \ initial value is 10
#16 base ! base @ #16 = assert
30 #48 = assert
#10 base !

\ hex
hex 10 #16 = assert dec

\ negative numbers
-5 3 + -2 = assert
-1234 #-1234 = assert
-1234 $-4d2 = assert
-1234 %-10011010010 = assert

\ character literals
'x' 120 = assert
'!' $21 = assert

\ arithmetic on negative numbers
-5 8 + 7 - -4 = assert
2 -3 * -6 = assert
8 -4 / 5 + 3 = assert

7 abs 7 = assert
-7 abs 7 = assert

7 3 mod 1 = assert
15 6 mod 3 = assert

0 invert -1 = assert
-1 invert 0 = assert
2 invert -3 = assert
-3 invert 2 = assert

0 3 < assert
3 0 > assert
2 2 <= assert
2 2 < 0= assert
2 2 >= assert
2 2 > 0= assert

s" Hello, world!"
( "<chars><dquote>" -- addr len )
13 = assert
dup 0 + c@ $48 = assert  \ H
dup 1 + c@ $65 = assert  \ e
dup 2 + c@ $6c = assert  \ l
dup 3 + c@ $6c = assert  \ l
dup 12 + c@ $21 = assert \ !
drop

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

5 here 4 mod - allot
here 4 mod 1 = assert
align
here 4 mod 0= assert

s" All tests successful!" println

0 exit
