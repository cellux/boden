: /reg8 $00 ;
: /reg16 $01 ;
: /reg32 $02 ;
: /reg64 $03 ;

: /imm8 $10 ;
: /imm16 $11 ;
: /imm32 $12 ;
: /imm64 $13 ;

: %al 0 ; : %ax 0 ; : %eax 0 ; : %rax 0 ;
: %cl 1 ; : %cx 1 ; : %ecx 1 ; : %rcx 0 ;
: %dl 2 ; : %dx 2 ; : %edx 2 ; : %rdx 2 ;
: %bl 3 ; : %bx 3 ; : %ebx 3 ; : %rbx 3 ;
: %ah 4 ; : %sp 4 ; : %esp 4 ; : %rsp 4 ;
: %ch 5 ; : %bp 5 ; : %ebp 5 ; : %rbp 5 ;
: %dh 6 ; : %si 6 ; : %esi 6 ; : %rsi 6 ;
: %bh 7 ; : %di 7 ; : %edi 7 ; : %rdi 7 ;

: add,
dup /reg8 = if
  drop
  dup /imm8 = if
    drop
    dup %al = if
      drop
      $04 c,
      c,
      exit
    then
  then
then

dup /reg16 = if
  drop
  dup /imm16 = if
    drop
    dup %ax = if
      drop
      $66 c, $05 c,
      dup c, 8 rshift
      c,
      exit
    then
  then
then

dup /reg32 = if
  drop
  dup /imm32 = if
    drop
    dup %eax = if
      drop
      $05 c,
      dup c, 8 rshift
      dup c, 8 rshift
      dup c, 8 rshift
      c,
      exit
    then
  then
then

s" invalid ADD instruction" die ;
