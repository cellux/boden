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

\ negative numbers
-5 3 + -2 = assert
-1234 #-1234 = assert
-1234 $-4d2 = assert
-1234 %-10011010010 = assert

\ character literals
'x' 120 = assert
'!' $21 = assert

s" Hello, world!"
( "<chars><dquote>" -- addr len )
13 = assert
dup 0 + c@ $48 = assert  \ H
dup 1 + c@ $65 = assert  \ e
dup 2 + c@ $6c = assert  \ l
dup 3 + c@ $6c = assert  \ l
dup 12 + c@ $21 = assert \ !
drop

: square dup * ;
5 square 25 = assert
6 square 36 = assert
7 square 49 = assert

s" All tests successful!" println

0 exit
