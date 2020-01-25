\ add,

here
$c3 %al /imm8 /reg8 add,
dup c@ $04 = assert 1+
dup c@ $c3 = assert 1+
drop

here
$face %ax /imm16 /reg16 add,
dup c@ $66 = assert 1+
dup c@ $05 = assert 1+
dup c@ $ce = assert 1+
dup c@ $fa = assert 1+
drop

here
$deadbeef %eax /imm32 /reg32 add,
dup c@ $05 = assert 1+
dup c@ $ef = assert 1+
dup c@ $be = assert 1+
dup c@ $ad = assert 1+
dup c@ $de = assert 1+
drop
