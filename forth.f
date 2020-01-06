8 5 + 13 = assert
8 5 - 3 = assert
2 3 * 6 = assert
100 4 / 25 = assert

\ numbers do not have to be followed by whitespace
2 5- 8+ 5= assert

\ base may be temporarily overridden via the following number prefixes:
\
\ 0x (base 16)
\ 0o (base 8)
\ 0b (base 2)
1234 0x4d2 = assert
1234 0o2322 = assert
1234 0b10011010010 = assert

\ prefixes on their own parse as zero
0x 0 = assert
0o 0 = assert
0b 0 = assert

s" Hello, world!"
( "<chars><dquote>" -- addr len )
2dup
13 = assert
dup 0 + c@ 0x48 = assert  \ H
dup 1 + c@ 0x65 = assert  \ e
dup 2 + c@ 0x6c = assert  \ l
dup 3 + c@ 0x6c = assert  \ l
dup 12 + c@ 0x21 = assert \ !
drop
println

0 exit
