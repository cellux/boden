\ cond thens
5
:noname
cond
dup 3 < if 111 else
dup 5 < if 222 else
dup 7 < if 333 else
dup 9 < if 444 else
dup 11 < if 555 thens
; execute
333 = assert
5 = assert
