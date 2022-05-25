.arch generic64
.code64

.intel_syntax noprefix

.global _start

.local $KiB,$MiB,$GiB

$KiB = 1024
$MiB = 1024 * $KiB
$GiB = 1024 * $MiB

.text

/* interface to linux syscalls */

.macro sys_exit status
  mov rdi, \status
  mov rax, 60
  syscall
.endm

.macro sys_write fd buf count
  mov rdi, \fd
  lea rsi, [\buf]
  lea rdx, [\count]
  mov rax, 1
  syscall
.endm

.macro sys_mprotect addr len prot
  lea rdi, [\addr]
  lea rsi, [\len]
  mov rdx, \prot
  mov rax, 10
  syscall
.endm

# structure of a dictionary entry:
#
# field   size  description
# -------------------------
# link    8     link to previous xt
# name    ?     name of definition
# len     1     name length (bits 0-4) + control bits (bits 5-7)
# body    ?     body of definition
#
# an xt (eXecution Token) is a pointer to body

.local $last_xt, $name_len, $control_bits

$last_xt = 0

.macro begin_dict_entry name immediate
  .dc.a $last_xt    # link
0:
  .ascii "\name"    # name
  $name_len = . - 0b
  $control_bits = 0
  .ifnb \immediate
    $control_bits = $control_bits | 0x20
  .endif
  .dc.b $name_len | $control_bits
  $last_xt = .
.endm

# rbp -> data stack
# rsp -> return stack
#
# data/returns stacks share the same memory region
#
# data stack grows upwards, return stack downwards

.macro dpush src
  mov qword ptr [rbp], \src
  add rbp, 8
.endm

.macro compile_dpush_rax
  #   mov [rbp], rax      48 89 45 00
  #   add rbp, 8          48 83 C5 08
  mov rax, 0x08c5834800458948
  stosq
.endm

.macro dpop dst
  sub rbp, 8
  mov \dst, qword ptr [rbp]
.endm

.macro compile_dpop_rax
  #   sub rbp, 8          48 83 ED 08
  #   mov rax, [rbp]      48 8B 45 00
  mov rax, 0x00458b4808ed8348
  stosq
.endm

.local $msg, $msg_len

.macro die msg
  jmp 0f
$msg = .
  .ascii "\msg"
$msg_len = . - $msg
0:
  sys_write 1, $msg, $msg_len
  call _cr
  sys_exit 1
.endm

.macro align_reg reg
  test \reg, 7
  jz 1f
  and \reg, -8
  add \reg, 8
1:
.endm

# whitespace := space (0x20) | control character (0x00-0x1f)

begin_dict_entry "word-size"
# ( -- n )
_word_size:
  dpush 8
  ret

begin_dict_entry "skip-while-whitespace"
# ( -- )
_skip_while_whitespace:
  lea rsi, [source_start]
  mov rbx, [source_index]
0:
  cmp byte ptr [rsi+rbx], 0x20
  jbe 1f
  mov [source_index], rbx
  ret
1:
  inc rbx
  jmp 0b

begin_dict_entry "skip-until-whitespace"
# ( -- )
_skip_until_whitespace:
  lea rsi, [source_start]
  mov rbx, [source_index]
0:
  cmp byte ptr [rsi+rbx], 0x20
  jbe 1f
  inc rbx
  jmp 0b
1:
  mov [source_index], rbx
  ret

begin_dict_entry "break"
# ( -- )
_break:
  int 3
  ret

begin_dict_entry "cells"
# ( n1 -- n2 )
_cells:
  shl qword ptr [rbp-8], 3
  ret

begin_dict_entry "cell+"
# ( a-addr1 -- a-addr2 )
_cell_plus:
  add qword ptr [rbp-8], 8
  ret

begin_dict_entry "depth"
# ( -- +n )
_depth:
  lea rbx, [data_stack]
  mov rax, rbp
  sub rax, rbx
  shr rax, 3
  dpush rax
  ret

begin_dict_entry "aligned"
# ( addr -- a-addr )
_aligned:
  mov rax, [rbp-8]
  align_reg rax
  mov [rbp-8], rax
  ret

# `here` contains the address of the next free location in the dictionary

begin_dict_entry "align"
# ( -- )
_align:
  mov rax, [here]
  align_reg rax
  mov [here], rax
  ret

begin_dict_entry "parse"
# ( char "ccc<char>" -- c-addr u )
_parse:
  lea rdi, [source_start]
  add rdi, [source_index]
  mov rsi, rdi
  dpop rax          # al = delimiter
  mov rcx, 0x10000  # max length (64k)
  repne scasb
  je 1f
  die "parse overflow"

1:
  # rsi -> first byte
  # rdi -> one byte after delimiter
  mov rax, rdi
  sub rax, rsi
  add [source_index], rax
  dec rax
  dpush rsi         # addr
  dpush rax         # len
  ret

begin_dict_entry "parse-name"
# ( "<spaces>name<space>" -- c-addr u )
_parse_name:
  call _skip_while_whitespace
  lea rsi, [source_start]
  add rsi, [source_index]
  dpush rsi         # addr
  push rsi
  call _skip_until_whitespace
  lea rbx, [source_start]
  add rbx, [source_index]
  pop rsi
  sub rbx, rsi
  dpush rbx         # len
  # skip first whitespace character following token
  inc qword ptr [source_index]
  ret

begin_dict_entry "sys:exit"
# ( n -- )
_sys_exit:
  dpop rax
  sys_exit rax

begin_dict_entry "emit"
# ( x -- )
_emit:
  sys_write 1, rbp-8, 1
  sub rbp, 8
  ret

begin_dict_entry "cr"
# ( -- )
_cr:
  dpush 0x0a        # actually LF
  jmp _emit

begin_dict_entry "type"
# ( c-addr u -- )
_type:
  dpop rcx          # len
  dpop rbx          # addr
  sys_write 1, rbx, rcx
  ret

begin_dict_entry "abs"
# ( n -- u )
_abs:
  mov rax, [rbp-8]
  or rax, rax
  jns 1f
  neg rax
  mov [rbp-8], rax
1:
  ret

begin_dict_entry "mod"
# ( n1 n2 -- n3 )
_mod:
  dpop rbx
  dpop rax
  xor rdx, rdx
  idiv rbx
  dpush rdx
  ret

.macro define_bin_op name
begin_dict_entry "\name"
# ( x1 x2 -- x3 )
_\name\():
  dpop rbx
  dpop rax
  \name rax, rbx
  dpush rax
  ret
.endm

define_bin_op "and"
define_bin_op "or"
define_bin_op "xor"

.macro define_shift_op name shift_inst
begin_dict_entry "\name"
# ( x1 u -- x2 )
_\name\():
  dpop rcx
  dpop rax
  \shift_inst rax, cl
  dpush rax
  ret
.endm

define_shift_op "lshift" , "shl"
define_shift_op "rshift" , "shr"

.macro define_cmp_op name label branch_inst
begin_dict_entry "\name"
# ( n1 n2 -- flag )
_\label\():
  dpop rbx
  dpop rax
  mov rdx, -1       # true (equal)
  cmp rax, rbx
  \branch_inst 1f
  inc rdx           # false (not equal)
1:
  dpush rdx
  ret
.endm

define_cmp_op "="  , "eq" , je
define_cmp_op "<>" , "ne" , jne
define_cmp_op "<"  , "lt" , jl
define_cmp_op "<=" , "le" , jle
define_cmp_op ">=" , "ge" , jge
define_cmp_op ">"  , "gt" , jg

begin_dict_entry "invert"
# ( x1 -- x2 )
_invert:
  mov rax, [rbp-8]
  xor rax, -1
  mov [rbp-8], rax
  ret

begin_dict_entry "+"
# ( n1|u1 n2|u2 -- n3|u3 )
_add:
  dpop rax
  add [rbp-8], rax
  ret

begin_dict_entry "-"
# ( n1|u1 n2|u2 -- n3|u3 )
_sub:
  dpop rax
  sub [rbp-8], rax
  ret

begin_dict_entry "*"
# ( n1|u1 n2|u2 -- n3|u3 )
_mul:
  dpop rax
  imul qword ptr [rbp-8]
  mov [rbp-8], rax
  ret

begin_dict_entry "/"
# ( n1 n2 -- n3 )
_div:
  dpop rbx
  dpop rax
  xor rdx, rdx
  idiv rbx
  dpush rax
  ret

begin_dict_entry "."
# ( n -- )
_dot:
  dpop rax
  xor rcx, rcx
0:
  xor rdx, rdx
  div qword ptr [base]
  push rdx              # rdx: remainder (next digit)
  inc rcx               # rcx: number of digits
  or rax, rax           # rax: quotient
  jnz 0b
1:
  pop rdx
  push rcx
  sys_write 1, digit_chars+rdx, 1
  pop rcx
  loop 1b
  jmp _cr

begin_dict_entry "swap"
# ( x1 x2 -- x2 x1 )
_swap:
  mov rax, [rbp-8]
  mov rbx, [rbp-16]
  mov [rbp-8], rbx
  mov [rbp-16], rax
  ret

begin_dict_entry "dup"
# ( x -- x x )
_dup:
  mov rax, [rbp-8]
  dpush rax
  ret

begin_dict_entry "drop"
# ( x -- )
_drop:
  sub rbp, 8
  ret

begin_dict_entry "nip"
# ( x1 x2 -- x2 )
_nip:
  sub rbp, 8
  mov rax, [rbp]
  mov [rbp-8], rax
  ret

begin_dict_entry "over"
# ( x1 x2 -- x1 x2 x1 )
_over:
  mov rax, [rbp-16]
  dpush rax
  ret

begin_dict_entry "pick"
# ( x[u] ... x[1] x[0] u -- x[u] ... x[1] x[0] x[u] )
_pick:
  dpop rbx
  shl rbx, 3
  lea rdi, [rbp-8]
  sub rdi, rbx
  mov rax, [rdi]
  dpush rax
  ret

begin_dict_entry "roll"
# ( x[u] x[u-1] ... x[0] u -- x[u-1] ... x[0] x[u] )
_roll:
  push rsi
  dpop rbx
  mov rcx, rbx
  shl rbx, 3
  mov rdi, rbp
  sub rdi, rbx
  mov rsi, rdi
  sub rdi, 8
  mov rax, [rdi]
  rep movsq
  stosq
  pop rsi
  ret

begin_dict_entry "2dup"
# ( x1 x2 -- x1 x2 x1 x2 )
_2dup:
  mov rax, [rbp-16]
  dpush rax
  mov rax, [rbp-16]
  dpush rax
  ret

begin_dict_entry "2drop"
# ( x1 x2 -- )
_2drop:
  sub rbp, 16
  ret

begin_dict_entry "2over"
# ( x1 x2 x3 x4 -- x1 x2 x3 x4 x1 x2 )
_2over:
  mov rax, [rbp-32]
  dpush rax
  mov rax, [rbp-32]
  dpush rax
  ret

begin_dict_entry "compare"
# ( c-addr1 u1 c-addr2 u2 -- n )
_compare:
  dpop rcx
  dpop rdi
  dpop rbx
  dpop rsi

  xor rax, rax
  cmp rbx, rcx
  je 2f
  ja 1f

  # len1 (rbx) < len2 (rcx)
  dec rax
  xchg rbx, rcx
  jmp 2f

1:
  # len1 (rbx) > len2 (rcx)
  inc rax

2:
  repe cmpsb
  je 3f
  mov rax, -1
  jb 3f
  neg rax
3:
  dpush rax
  ret

begin_dict_entry "c@"
# ( c-addr -- char )
_char_at:
  dpop rbx
  movzx rax, byte ptr [rbx]
  dpush rax
  ret

begin_dict_entry "c!"
# ( char c-addr -- )
_c_bang:
  dpop rdi
  dpop rax
  stosb
  ret

begin_dict_entry "fill"
# ( c-addr u char -- )
_fill:
  dpop rax    # char
  dpop rcx    # len
  dpop rdi    # addr
  rep stosb
  ret

begin_dict_entry "here"
# ( -- addr)
_here:
  mov rax, [here]
  dpush rax
  ret

begin_dict_entry "allot"
# ( n -- )
_allot:
  dpop rax
  add [here], rax
  ret

begin_dict_entry ","
# ( x -- )
_comma:
  mov rdi, [here]
  dpop rax
  stosq
  mov [here], rdi
  ret

begin_dict_entry "c,"
# ( char -- )
_c_comma:
  mov rdi, [here]
  dpop rax
  stosb
  mov [here], rdi
  ret

begin_dict_entry "base"
# ( -- a-addr )
_base:
  lea rax, [base]
  dpush rax
  ret

begin_dict_entry "create-dict-entry"
# ( "<spaces>name" -- )
_create_dict_entry:
  call _parse_name        # ( -- addr len )
  mov rdi, [here]
  mov rax, [last_xt]
  stosq                   # link
  dpop rcx                # rcx = len
  dpop rsi                # rsi = addr
  push rcx
  rep movsb               # name
  pop rax
  or al, 0x40             # set smudge bit
  stosb                   # namelen
  mov [last_xt], rdi
  mov [here], rdi
  ret

begin_dict_entry "create"
# ( "<spaces>name" -- )
_create:
  call _create_dict_entry
  mov rdi, [here]
  and byte ptr [rdi-1], 0xbf  # clear smudge bit

  # now compile the following:
  #
  #   mov rax, data       48 B8 .. .. .. .. .. .. .. ..
  #   mov [rbp], rax      48 89 45 00
  #   add rbp, 8          48 83 C5 08
  #   ret                 C3
  #
  # data:

  mov ax, 0xb848
  stosw
  push rdi
  add rdi, 8              # leave space for data pointer
  mov rax, 0x08c5834800458948
  stosq
  mov al, 0xc3
  stosb
  mov rax, rdi
  align_reg rax           # align to cell boundary
  mov [here], rax
  pop rdi
  stosq                   # patch aligned address into data pointer
  ret

begin_dict_entry "'"
# ( "<spaces>name" -- xt | c-addr u 0 )
_tick:
  call _parse_name
  dpop rax          # token length
  dpop rdx          # token address

  mov rbx, [last_xt]

compare_next:
  or rbx,rbx        # no more words in the dictionary?
  jz word_not_found

  mov rdi, rbx      # xt
  dec rdi
  mov cl, [rdi]     # namelen
  and rcx, 0x1f     # zero out all other bits, max(namelen) = 31
  sub rdi, rcx      # first character of name
  mov rbx, [rdi-8]  # previous xt from link field
  cmp cl, al        # length matches?
  jne compare_next

  mov rsi, rdx
  repe cmpsb        # characters match?
  jne compare_next

word_found:
  mov cl, [rdi]
  test cl, 0x40     # smudge bit set?
  jnz compare_next  # yes: ignore this word

  inc rdi           # skip over namelen, rdi = xt
  dpush rdi         # true
  ret

word_not_found:
  dpush rdx         # token address
  dpush rax         # token length
  xor rax, rax
  dpush rax         # false
  ret

begin_dict_entry "execute"
# ( i*x xt -- j*x )
_execute:
  dpop rdi
  jmp rdi

begin_dict_entry ":"
_colon:
  call _create_dict_entry
  mov qword ptr [state], -1   # set compilation state
  ret

begin_dict_entry ";" immediate
_semicolon:
  mov rdi, [here]
  mov al, 0xc3                # compile RET
  stosb
  align_reg rdi
  mov [here], rdi
  mov rdi, [last_xt]
  and byte ptr [rdi-1], 0xbf  # clear smudge bit
  mov qword ptr [state], 0    # set interpretation state
  ret

begin_dict_entry "immediate"
# ( -- )
_immediate:
  mov rdi, [last_xt]
  or byte ptr [rdi-1], 0x20   # set immediate bit
  ret

begin_dict_entry "literal" immediate
_literal:
  mov rdi, [here]

  # now compile the following:
  #
  #   mov rax, value      48 B8 .. .. .. .. .. .. .. ..
  #   mov [rbp], rax      48 89 45 00
  #   add rbp, 8          48 83 C5 08

  mov ax, 0xb848
  stosw
  dpop rax          # value comes from data stack
  stosq
  compile_dpush_rax
  mov [here], rdi
  ret

begin_dict_entry "lit-offset"
_lit_offset:
  dpush 2
  ret

begin_dict_entry "compile,"
# ( xt -- )
_compile_comma:
  mov rdi, [here]   # next free location in dictionary
  mov al, 0xe8      # compile CALL instruction
  stosb
  push rdi
  add rdi, 4        # address of location after CALL instruction
  dpop rax          # xt (word address)
  sub rax, rdi      # convert to relative offset
  pop rdi
  stosd             # patch CALL offset
  mov [here], rdi
  ret

begin_dict_entry "postpone" immediate
# ( "<spaces>name" -- )
_postpone:
  call _tick
  mov rbx, [rbp-8]
  or rbx, rbx
  jnz 1f
  dpop rbx
  mov rax, 0x3f     # '?'
  dpush rax
  call _emit
  call _type
  die " (postpone)"
1:
  mov cl, [rbx-1]   # namelen
  test cl, 0x20     # immediate?
  jnz _compile_comma
  call _literal
  lea rbx, [_compile_comma]
  dpush rbx
  jmp _compile_comma

begin_dict_entry "constant"
# ( x "<spaces>name" -- )
_constant:
  call _create_dict_entry
  mov rdi, [here]
  and byte ptr [rdi-1], 0xbf  # clear smudge bit
  call _literal
  mov al, 0xc3                # compile RET
  stosb
  mov [here], rdi
  ret

begin_dict_entry "state"
# ( -- a-addr )
_state:
  lea rax, [state]
  dpush rax
  ret

begin_dict_entry "@"
# ( a-addr -- x )
_at:
  mov rbx, [rbp-8]
  mov rax, [rbx]
  mov [rbp-8], rax
  ret

begin_dict_entry "!"
# ( x a-addr -- }
_bang:
  dpop rbx
  dpop rax
  mov [rbx], rax
  ret

begin_dict_entry ">r" immediate
# ( x -- ) ( R: -- x )
_to_r:
  mov rdi, [here]
  compile_dpop_rax
  mov al, 0x50      # push rax
  stosb
  mov [here], rdi
  ret

begin_dict_entry "r>" immediate
# ( -- x ) ( R: x -- )
_from_r:
  mov rdi, [here]
  mov al, 0x58      # pop rax
  stosb
  compile_dpush_rax
  mov [here], rdi
  ret

begin_dict_entry "r@" immediate
# ( -- x ) ( R: x -- x )
_at_r:
  mov rdi, [here]
  mov ax, 0x5058                # pop rax, push rax
  stosw
  compile_dpush_rax
  mov [here], rdi
  ret

begin_dict_entry "2>r" immediate
# ( x1 x2 -- ) ( R: -- x1 x2 )
_2_to_r:
  mov rdi, [here]
  # push qword ptr [rbp-16]    FF 75 F0
  # push qword ptr [rbp-8]     FF 75 F8
  # sub rbp, 16                48 83 ED 10
  mov rax, 0x8348f875fff075ff
  stosq
  mov ax, 0x10ed
  stosw
  mov [here], rdi
  ret

begin_dict_entry "2r>" immediate
# ( -- x1 x2 ) ( R: x1 x2 -- )
_2_from_r:
  mov rdi, [here]
  # add rbp, 16               48 83 C5 10
  # pop qword ptr [rbp-8]     8F 45 F8
  # pop qword ptr [rbp-16]    8F 45 F0
  mov rax, 0x8ff8458f10c58348
  stosq
  mov ax, 0xf045
  stosw
  mov [here], rdi
  ret

begin_dict_entry "2r@" immediate
# ( -- x1 x2 ) ( R: x1 x2 -- x1 x2 )
_2_at_r:
  mov rdi, [here]
  # mov rax, [rsp+8]          48 8B 44 24 08
  mov eax, 0x24448b48
  stosd
  mov al, 0x08
  stosb
  compile_dpush_rax
  # mov rax, [rsp]            48 8B 04 24
  mov eax, 0x24048b48
  stosd
  compile_dpush_rax
  mov [here], rdi
  ret

compile_jump:
# ( -- branch-offset-addr ) ( R: opcode -- )
  mov rdi, [here]
  pop rax             # opcode (JMP, JZ, JNZ)
  stosb
  test rax, 0xff00    # 2 byte opcode?
  jz 1f
  mov al, ah
  stosb               # store second opcode byte
1:
  dpush rdi           # address of branch offset
  xor rax, rax        # placeholder for branch offset (8 bytes)
  stosd
  mov [here], rdi
  ret

compile_conditional_branch:
# ( -- branch-offset-addr ) ( R: opcode -- )
#
# compile the following:
#
#   sub rbp, 8              48 83 ED 08
#   mov rax, [rbp]          48 8B 45 00
#   or rax, rax             48 09 C0
#   <opcode> <offset>       .. .. .. .. .. .. .. .. ..     for JMP
#                           .. .. .. .. .. .. .. .. .. ..  for Jcc
  mov rdi, [here]
  compile_dpop_rax
  mov al, 0x48              # REX prefix
  stosb
  mov ax, 0xc009            # or rax, rax
  stosw
  mov [here], rdi
  jmp compile_jump

begin_dict_entry ",jmpz"
_comma_jmpz:
  push 0x840f
  jmp compile_conditional_branch

begin_dict_entry ",jmpnz"
_comma_jmpnz:
  push 0x850f
  jmp compile_conditional_branch

begin_dict_entry ",jmp"
_comma_jmp:
  push 0xe9
  jmp compile_jump

begin_dict_entry "patch-jmp"
_patch_jmp:
  # ( dest branch-offset-addr -- )
  dpop rdi
  dpop rax
  sub rax, rdi      # convert to relative offset
  sub rax, 4        # offset counts from end of branch instruction
  stosd
  ret

begin_dict_entry "source"
# ( -- c-addr u )
_source:
  lea rsi, [source_start]
  dpush rsi                   # address of 'input buffer'
  lea rax, [source_end]
  sub rax, rsi
  dpush rax                   # number of characters in 'input buffer'
  ret

begin_dict_entry ">in"
  # ( -- a-addr )
_to_in:
  lea rax, [source_index]
  dpush rax
  ret

begin_dict_entry "interpret-1"
_interpret_1:
  call _tick        # ( -- xt | c-addr u 0 )
  dpop rbx
  or rbx, rbx
  jz unknown_word

  mov rax, [state]
  or rax, rax       # interpreting?
  jz execute_word

  mov cl, [rbx-1]   # namelen
  test cl, 0x20     # is word immediate?
  jnz execute_word  # yes: execute it

compile_word:
  dpush rbx
  jmp _compile_comma

execute_word:
  jmp rbx

is_digit: # helper function
  # parameters:
  #   rbx: ASCII value to parse
  #   rdi: radix (base)
  #
  # returns:
  #   rbx: numeric value of digit, -1 if rbx is not a digit

  cmp rbx, 0x30
  jb not_digit
  cmp rbx, 0x3a
  jb 0f
  and rbx, 0xdf     # a..z -> A..Z
  sub rbx, 0x41-0x3a
0:
  sub rbx, 0x30
  cmp rbx, rdi
  jb yes_digit
not_digit:
  mov rbx, -1
yes_digit:
  ret

unknown_word:
# ( c-addr u )
  mov rsi, [rbp-16] # first byte of unknown word

  mov bl, [rsi]
  cmp bl, 0x27      # single quote?
  je char_literal
  cmp bl, 0x23      # '#'?
  je base_10
  cmp bl, 0x24      # '$'?
  je base_16
  cmp bl, 0x25      # '%'?
  je base_2

  mov rdi, [base]
  jmp parse_number

char_literal:
  # token should match 'X'<blank>
  mov bl, [rsi+2]
  cmp bl, 0x27                  # single quote?
  jne not_a_number
  mov bl, [rsi+3]
  cmp bl, 0x20                  # blank?
  ja not_a_number
  movzx rax, byte ptr [rsi+1]
  add rsi, 4                    # skip over char literal
  jmp found_number

base_10:
  mov rdi, 10
  jmp skip_base_prefix

base_16:
  mov rdi, 16
  jmp skip_base_prefix

base_2:
  mov rdi, 2
  jmp skip_base_prefix

skip_base_prefix:
  inc rsi

parse_number:
  xor rcx, rcx            # sign: 0 = positive, 1 = negative
  mov bl, [rsi]
  cmp bl, 0x2d            # '-'
  jne check_first_digit
  inc rcx                 # shall be negated at the end
  inc rsi

check_first_digit:
  mov bl, [rsi]
  call is_digit
  or rbx, rbx
  js not_a_number

parse_digits:
  xor rax, rax
  xor rbx, rbx

parse_digit:
  mov bl, [rsi]
  call is_digit
  or rbx, rbx
  js end_of_number
  inc rsi
  mul rdi
  add rax, rbx
  jmp parse_digit

end_of_number:
  mov bl, [rsi]
  cmp bl, 0x20        # character after last digit is not whitespace?
  ja not_a_number
  or rcx, rcx         # multiply by -1 if there was a minus sign
  jz found_number
  neg rax

found_number:
  sub rbp, 16         # drop token address and length
  dpush rax
  mov rbx, [state]
  or rbx, rbx         # interpreting?
  jz 1f               # leave number on stack
  call _literal       # compile code which pushes number to stack
1:
  ret

not_a_number:
  mov rax, 0x3f
  dpush rax
  call _emit                  # print '?'
  dpop rsi                    # len
  dpop rdx                    # addr
  sys_write 1, rdx, rsi       # print unknown word
  call _cr
  sys_exit 1

_start:
  lea rsp, [return_stack]
  lea rbp, [data_stack]

  lea rax, [dictionary]
  mov [here], rax

  lea rax, [$last_xt]
  mov [last_xt], rax

  # set memory protection of the dictionary area to
	# PROT_READ|PROT_WRITE|PROT_EXEC
  #
  # without this, executing generated code results in a segfault

  sys_mprotect dictionary, dictionary_size, 7
  or rax, rax
  jz interpreter_loop
  dpush rax
  call _dot
  die "mprotect failed"

interpreter_loop:
  call _interpret_1
  lea rbx, [data_stack]
  cmp rbp, rbx
  jae interpreter_loop
  die "stack underflow"

.data

base:               .dc.a 10
state:              .dc.a 0

source_index:       .dc.a 0
source_start:
  .incbin "boden.b"
  .byte 0x0a        # sentinel
source_end:

digit_chars:        .ascii "0123456789abcdefghijklmnopqrstuvwxyz"

.bss

here:               .dc.a 0
last_xt:            .dc.a 0

# data and return stack use the same memory region
#
# data stack grows upwards, return stack grows downwards

data_stack:
  .space 4 * $KiB
return_stack:

.align 4096

# definitions in boden.b will be compiled starting from here
dictionary:
  .space 1 * $MiB
dictionary_end:
dictionary_size = dictionary_end - dictionary
