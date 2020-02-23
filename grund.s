.intel_syntax noprefix
.global _start

.local $KiB,$MiB,$GiB

$KiB = 1024
$MiB = 1024 * $KiB
$GiB = 1024 * $MiB

.text

/* interface to linux syscalls */

.macro sys_exit status
  mov ebx, \status
  mov eax, 0x01
  int 0x80
.endm

.macro sys_write fd buf count
  mov ebx, \fd
  lea ecx, [\buf]
  lea edx, [\count]
  mov eax, 0x04
  int 0x80
.endm

# structure of a dictionary entry:
#
# field   size  description
# -------------------------
# link    4     link to previous xt
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

# ebp -> data stack
# esp -> return stack
#
# data/returns stacks share the same memory region
#
# data stack grows upwards, return stack downwards

.macro dpush src
  mov dword ptr [ebp], \src
  add ebp, 4
.endm

.macro compile_dpush_eax
  #   mov [ebp], eax      89 45 00
  #   add ebp, 4          83 C5 04
  mov eax, 0x83004589
  stosd
  mov ax, 0x04c5
  stosw
.endm

.macro dpop dst
  sub ebp, 4
  mov \dst, dword ptr [ebp]
.endm

.macro compile_dpop_eax
  #   sub ebp, 4          83 ED 04
  #   mov eax, [ebp]      8B 45 00
  mov eax, 0x8b04ed83
  stosd
  mov ax, 0x0045
  stosw
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
  test \reg, 3
  jz 1f
  and \reg, -4
  add \reg, 4
1:
.endm

# whitespace := space (0x20) | control character (0x00-0x1f)

begin_dict_entry "skip-while-whitespace"
# ( -- )
_skip_while_whitespace:
  lea esi, [source_start]
  mov ebx, [source_index]
0:
  cmp byte ptr [esi+ebx], 0x20
  jbe 1f
  mov [source_index], ebx
  ret
1:
  inc ebx
  jmp 0b

begin_dict_entry "skip-until-whitespace"
# ( -- )
_skip_until_whitespace:
  lea esi, [source_start]
  mov ebx, [source_index]
0:
  cmp byte ptr [esi+ebx], 0x20
  jbe 1f
  inc ebx
  jmp 0b
1:
  mov [source_index], ebx
  ret

begin_dict_entry "break"
# ( -- )
_break:
  int 3
  ret

begin_dict_entry "cells"
# ( n1 -- n2 )
_cells:
  shl dword ptr [ebp-4], 2
  ret

begin_dict_entry "cell+"
# ( a-addr1 -- a-addr2 )
_cell_plus:
  add dword ptr [ebp-4], 4
  ret

begin_dict_entry "depth"
# ( -- +n )
_depth:
  lea ebx, [data_stack]
  mov eax, ebp
  sub eax, ebx
  shr eax, 2
  dpush eax
  ret

begin_dict_entry "aligned"
# ( addr -- a-addr )
_aligned:
  mov eax, [ebp-4]
  align_reg eax
  mov [ebp-4], eax
  ret

# `here` contains the address of the next free location in the dictionary

begin_dict_entry "align"
# ( -- )
_align:
  mov eax, [here]
  align_reg eax
  mov [here], eax
  ret

begin_dict_entry "parse"
# ( char "ccc<char>" -- c-addr u )
_parse:
  lea edi, [source_start]
  add edi, [source_index]
  mov esi, edi
  dpop eax          # al = delimiter
  mov ecx, 0x10000  # max length (64k)
  repne scasb
  je 1f
  die "parse overflow"

1:
  # esi -> first byte
  # edi -> one byte after delimiter
  mov eax, edi
  sub eax, esi
  add [source_index], eax
  dec eax
  dpush esi         # addr
  dpush eax         # len
  ret

begin_dict_entry "parse-name"
# ( "<spaces>name<space>" -- c-addr u )
_parse_name:
  call _skip_while_whitespace
  lea esi, [source_start]
  add esi, [source_index]
  dpush esi         # addr
  push esi
  call _skip_until_whitespace
  lea ebx, [source_start]
  add ebx, [source_index]
  pop esi
  sub ebx, esi
  dpush ebx         # len
  # skip first whitespace character following token
  inc dword ptr [source_index]
  ret

begin_dict_entry "sys:exit"
# ( n -- )
_sys_exit:
  dpop eax
  sys_exit eax

begin_dict_entry "emit"
# ( x -- )
_emit:
  sys_write 1, ebp-4, 1
  sub ebp, 4
  ret

begin_dict_entry "cr"
# ( -- )
_cr:
  dpush 0x0a        # actually LF
  jmp _emit

begin_dict_entry "type"
# ( c-addr u -- )
_type:
  dpop edi          # len
  dpop edx          # addr
  sys_write 1, edx, edi
  ret

begin_dict_entry "abs"
# ( n -- u )
_abs:
  mov eax, [ebp-4]
  or eax, eax
  jns 1f
  neg eax
  mov [ebp-4], eax
1:
  ret

begin_dict_entry "mod"
# ( n1 n2 -- n3 )
_mod:
  dpop ebx
  dpop eax
  xor edx, edx
  idiv ebx
  dpush edx
  ret

.macro define_bin_op name
begin_dict_entry "\name"
# ( x1 x2 -- x3 )
_\name\():
  dpop ebx
  dpop eax
  \name eax, ebx
  dpush eax
  ret
.endm

define_bin_op "and"
define_bin_op "or"
define_bin_op "xor"

.macro define_shift_op name shift_inst
begin_dict_entry "\name"
# ( x1 u -- x2 )
_\name\():
  dpop ecx
  dpop eax
  \shift_inst eax, cl
  dpush eax
  ret
.endm

define_shift_op "lshift" , "shl"
define_shift_op "rshift" , "shr"

.macro define_cmp_op name label branch_inst
begin_dict_entry "\name"
# ( n1 n2 -- flag )
_\label\():
  dpop ebx
  dpop eax
  mov edx, -1       # true (equal)
  cmp eax, ebx
  \branch_inst 1f
  inc edx           # false (not equal)
1:
  dpush edx
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
  mov eax, [ebp-4]
  xor eax, -1
  mov [ebp-4], eax
  ret

begin_dict_entry "+"
# ( n1|u1 n2|u2 -- n3|u3 )
_add:
  dpop eax
  add [ebp-4], eax
  ret

begin_dict_entry "-"
# ( n1|u1 n2|u2 -- n3|u3 )
_sub:
  dpop eax
  sub [ebp-4], eax
  ret

begin_dict_entry "*"
# ( n1|u1 n2|u2 -- n3|u3 )
_mul:
  dpop eax
  imul dword ptr [ebp-4]
  mov [ebp-4], eax
  ret

begin_dict_entry "/"
# ( n1 n2 -- n3 )
_div:
  dpop ebx
  dpop eax
  xor edx, edx
  idiv ebx
  dpush eax
  ret

begin_dict_entry "."
# ( n -- )
_dot:
  dpop eax
  xor ecx, ecx
0:
  xor edx, edx
  div dword ptr [base]
  push edx              # edx: remainder (next digit)
  inc ecx               # ecx: number of digits
  or eax, eax           # eax: quotient
  jnz 0b
1:
  pop edx
  push ecx
  sys_write 1, digit_chars+edx, 1
  pop ecx
  loop 1b
  jmp _cr

begin_dict_entry "swap"
# ( x1 x2 -- x2 x1 )
_swap:
  mov eax, [ebp-4]
  mov ebx, [ebp-8]
  mov [ebp-4], ebx
  mov [ebp-8], eax
  ret

begin_dict_entry "dup"
# ( x -- x x )
_dup:
  mov eax, [ebp-4]
  dpush eax
  ret

begin_dict_entry "drop"
# ( x -- )
_drop:
  sub ebp, 4
  ret

begin_dict_entry "nip"
# ( x1 x2 -- x2 )
_nip:
  sub ebp, 4
  mov eax, [ebp]
  mov [ebp-4], eax
  ret

begin_dict_entry "over"
# ( x1 x2 -- x1 x2 x1 )
_over:
  mov eax, [ebp-8]
  dpush eax
  ret

begin_dict_entry "pick"
# ( x[u] ... x[1] x[0] u -- x[u] ... x[1] x[0] x[u] )
_pick:
  dpop ebx
  shl ebx, 2
  lea edi, [ebp-4]
  sub edi, ebx
  mov eax, [edi]
  dpush eax
  ret

begin_dict_entry "roll"
# ( x[u] x[u-1] ... x[0] u --- x[u-1] ... x[0] x[u] )
_roll:
  push esi
  dpop ebx
  mov ecx, ebx
  shl ebx, 2
  mov edi, ebp
  sub edi, ebx
  mov esi, edi
  sub edi, 4
  mov eax, [edi]
  rep movsd
  stosd
  pop esi
  ret

begin_dict_entry "2dup"
# ( x1 x2 -- x1 x2 x1 x2 )
_2dup:
  mov eax, [ebp-8]
  dpush eax
  mov eax, [ebp-8]
  dpush eax
  ret

begin_dict_entry "2drop"
# ( x1 x2 -- )
_2drop:
  sub ebp, 8
  ret

begin_dict_entry "2over"
# ( x1 x2 x3 x4 -- x1 x2 x3 x4 x1 x2 )
_2over:
  mov eax, [ebp-16]
  dpush eax
  mov eax, [ebp-16]
  dpush eax
  ret

begin_dict_entry "compare"
# ( c-addr1 u1 c-addr2 u2 -- n )
_compare:
  dpop ecx
  dpop edi
  dpop ebx
  dpop esi

  xor eax, eax
  cmp ebx, ecx
  je 2f
  ja 1f

  # len1 (ebx) < len2 (ecx)
  dec eax
  xchg ebx, ecx
  jmp 2f

1:
  # len1 (ebx) > len2 (ecx)
  inc eax

2:
  repe cmpsb
  je 3f
  mov eax, -1
  jb 3f
  neg eax
3:
  dpush eax
  ret

begin_dict_entry "c@"
# ( c-addr -- char )
_char_at:
  dpop ebx
  movzx eax, byte ptr [ebx]
  dpush eax
  ret

begin_dict_entry "c!"
# ( char c-addr -- )
_c_bang:
  dpop edi
  dpop eax
  stosb
  ret

begin_dict_entry "fill"
# ( c-addr u char -- )
_fill:
  dpop eax    # char
  dpop ecx    # len
  dpop edi    # addr
  rep stosb
  ret

begin_dict_entry "here"
# ( -- addr)
_here:
  mov eax, [here]
  dpush eax
  ret

begin_dict_entry "allot"
# ( n -- )
_allot:
  dpop eax
  add [here], eax
  ret

begin_dict_entry ","
# ( x -- )
_comma:
  mov edi, [here]
  dpop eax
  stosd
  mov [here], edi
  ret

begin_dict_entry "c,"
# ( char -- )
_c_comma:
  mov edi, [here]
  dpop eax
  stosb
  mov [here], edi
  ret

begin_dict_entry "base"
# ( -- a-addr )
_base:
  lea eax, [base]
  dpush eax
  ret

begin_dict_entry "create-dict-entry"
# ( "<spaces>name" -- )
_create_dict_entry:
  call _parse_name        # ( -- addr len )
  mov edi, [here]
  mov eax, [last_xt]
  stosd                   # link
  dpop ecx                # ecx = len
  dpop esi                # esi = addr
  push ecx
  rep movsb               # name
  pop eax
  or al, 0x40             # set smudge bit
  stosb                   # namelen
  mov [last_xt], edi
  mov [here], edi
  ret

begin_dict_entry "create"
# ( "<spaces>name" -- )
_create:
  call _create_dict_entry
  mov edi, [here]
  and byte ptr [edi-1], 0xbf  # clear smudge bit

  # now compile the following:
  #
  #   mov eax, data       B8 .. .. .. ..
  #   mov [ebp], eax      89 45 00
  #   add ebp, 4          83 C5 04
  #   ret                 C3
  #
  # data:

  mov al, 0xb8
  stosb
  push edi
  add edi, 4              # leave space for data pointer
  mov eax, 0x83004589
  stosd
  mov ax, 0x04c5
  stosw
  mov al, 0xc3
  stosb
  mov eax, edi
  align_reg eax           # align to cell boundary
  mov [here], eax
  pop edi
  stosd                   # patch aligned address into data pointer
  ret

begin_dict_entry "'"
# ( "<spaces>name" -- xt ) 
_tick:
  call _parse_name
  dpop eax          # token length
  dpop edx          # token address

  mov ebx, [last_xt]

compare_next:
  or ebx,ebx        # no more words in the dictionary?
  jz word_not_found

  mov edi, ebx      # xt
  dec edi
  mov cl, [edi]     # namelen
  and ecx, 0x1f     # zero out all other bits, max(namelen) = 31
  sub edi, ecx      # first character of name
  mov ebx, [edi-4]  # previous xt from link field
  cmp cl, al        # length matches?
  jne compare_next

  mov esi, edx
  repe cmpsb        # characters match?
  jne compare_next

word_found:
  mov cl, [edi]
  test cl, 0x40     # smudge bit set?
  jnz compare_next  # yes: ignore this word

  inc edi           # skip over namelen, edi = xt
  dpush edi         # true
  ret

word_not_found:
  # rewind source index to first character of unrecognized token
  lea esi, [source_start]
  sub edx, esi
  mov [source_index], edx

  xor eax, eax
  dpush eax         # false
  ret

begin_dict_entry "execute"
# ( i*x xt -- j*x )
_execute:
  dpop edi
  jmp edi

begin_dict_entry ":"
_colon:
  call _create_dict_entry
  mov dword ptr [state], -1   # set compilation state
  ret

begin_dict_entry ";" immediate
_semicolon:
  mov edi, [here]
  mov al, 0xc3                # compile RET
  stosb
  align_reg edi
  mov [here], edi
  mov edi, [last_xt]
  and byte ptr [edi-1], 0xbf  # clear smudge bit
  mov dword ptr [state], 0    # set interpretation state
  ret

begin_dict_entry "immediate"
# ( -- )
_immediate:
  mov edi, [last_xt]
  or byte ptr [edi-1], 0x20   # set immediate bit
  ret

begin_dict_entry "literal" immediate
_literal:
  mov edi, [here]

  # now compile the following:
  #
  #   mov eax, value      B8 .. .. .. ..
  #   mov [ebp], eax      89 45 00
  #   add ebp, 4          83 C5 04

  mov al, 0xb8
  stosb
  dpop eax          # value comes from data stack
  stosd
  compile_dpush_eax
  mov [here], edi
  ret

begin_dict_entry "compile,"
# ( xt -- )
_compile_comma:
  mov edi, [here]   # next free location in dictionary
  mov al, 0xe8      # compile CALL instruction
  stosb
  push edi
  add edi, 4        # address of location after CALL instruction
  dpop eax          # xt (word address)
  sub eax, edi      # convert to relative offset
  pop edi
  stosd             # patch CALL offset
  mov [here], edi
  ret

begin_dict_entry "postpone" immediate
# ( "<spaces>name" -- )
_postpone:
  call _tick
  mov ebx, [ebp-4]
  mov cl, [ebx-1]   # namelen
  test cl, 0x20     # immediate?
  jnz _compile_comma
  call _literal
  lea ebx, [_compile_comma]
  dpush ebx
  jmp _compile_comma

begin_dict_entry "constant"
# ( x "<spaces>name" -- )
_constant:
  call _create_dict_entry
  mov edi, [here]
  and byte ptr [edi-1], 0xbf  # clear smudge bit
  call _literal
  mov al, 0xc3                # compile RET
  stosb
  mov [here], edi
  ret

begin_dict_entry "state"
# ( -- a-addr )
_state:
  lea eax, [state]
  dpush eax
  ret

begin_dict_entry "@"
# ( a-addr -- x )
_at:
  mov ebx, [ebp-4]
  mov eax, [ebx]
  mov [ebp-4], eax
  ret

begin_dict_entry "!"
# ( x a-addr -- }
_bang:
  dpop ebx
  dpop eax
  mov [ebx], eax
  ret

begin_dict_entry ">r" immediate
# ( x -- ) ( R: -- x )
_to_r:
  mov edi, [here]
  compile_dpop_eax
  mov al, 0x50      # push eax
  stosb
  mov [here], edi
  ret

begin_dict_entry "r>" immediate
# ( -- x ) ( R: x -- )
_from_r:
  mov edi, [here]
  mov al, 0x58      # pop eax
  stosb
  compile_dpush_eax
  mov [here], edi
  ret

begin_dict_entry "r@" immediate
# ( -- x ) ( R: x -- x )
_at_r:
  mov edi, [here]
  mov ax, 0x5058                # pop eax, push eax
  stosw
  compile_dpush_eax
  mov [here], edi
  ret

begin_dict_entry "2>r" immediate
# ( x1 x2 -- ) ( R: -- x1 x2 )
_2_to_r:
  mov edi, [here]
  # push dword ptr [ebp-8]    FF 75 F8
  # push dword ptr [ebp-4]    FF 75 FC
  # sub ebp, 8                83 ED 08
  mov eax, 0xfff875ff
  stosd
  mov eax, 0xed83fc75
  stosd
  mov al, 0x08
  stosb
  mov [here], edi
  ret

begin_dict_entry "2r>" immediate
# ( -- x1 x2 ) ( R: x1 x2 -- )
_2_from_r:
  mov edi, [here]
  # add ebp, 8                # 83 C5 08
  # pop dword ptr [ebp-4]     # 8F 45 FC
  # pop dword ptr [ebp-8]     # 8F 45 F8
  mov eax, 0x8f08c583
  stosd
  mov eax, 0x458ffc45
  stosd
  mov al, 0xf8
  stosb
  mov [here], edi
  ret

begin_dict_entry "2r@" immediate
# ( -- x1 x2 ) ( R: x1 x2 -- x1 x2 )
_2_at_r:
  mov edi, [here]
  # mov eax, [esp+4]          8B 44 24 04
  mov eax, 0x0424448b
  stosd
  compile_dpush_eax
  # mov eax, [esp]            8B 04 24
  mov ax, 0x048b
  stosw
  mov al, 0x24
  stosb
  compile_dpush_eax
  mov [here], edi
  ret

compile_jump:
# ( -- branch-offset-addr ) ( R: opcode -- )
  mov edi, [here]
  pop eax             # opcode (JMP, JZ, JNZ)
  stosb
  test eax, 0xff00    # 2 byte opcode?
  jz 1f
  mov al, ah
  stosb               # store second opcode byte
1:
  dpush edi           # address of branch offset
  xor eax, eax        # placeholder for branch offset (4 bytes)
  stosd
  mov [here], edi
  ret

compile_conditional_branch:
# ( -- branch-offset-addr ) ( R: opcode -- )
#
# compile the following:
#
#   sub ebp, 4              83 ED 04
#   mov eax, [ebp]          8B 45 00
#   or eax, eax             09 C0
#   <opcode> <offset>       .. .. .. .. ..      for JMP
#                           .. .. .. .. .. ..   for Jcc
  mov edi, [here]
  compile_dpop_eax
  mov eax, 0xc009             # or eax, eax
  stosw
  mov [here], edi
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
  dpop edi
  dpop eax
  sub eax, edi      # convert to relative offset
  sub eax, 4        # offset counts from end of branch instruction
  stosd
  ret

begin_dict_entry "source"
# ( -- c-addr u )
_source:
  lea esi, [source_start]
  dpush esi                   # address of 'input buffer'
  lea eax, [source_end]
  sub eax, esi
  dpush eax                   # number of characters in 'input buffer'
  ret

begin_dict_entry ">in"
  # ( -- a-addr )
_to_in:
  lea eax, [source_index]
  dpush eax
  ret

begin_dict_entry "interpret-1"
_interpret_1:
  call _tick        # ( -- xt|0 )
  dpop ebx
  or ebx, ebx
  jz unknown_word

  mov eax, [state]
  or eax, eax       # interpreting?
  jz execute_word

  mov cl, [ebx-1]   # namelen
  test cl, 0x20     # is word immediate?
  jnz execute_word  # yes: execute it

compile_word:
  dpush ebx
  jmp _compile_comma

execute_word:
  jmp ebx

is_digit: # helper function
  # parameters:
  #   ebx: ASCII value to parse
  #   edi: radix (base)
  #
  # returns:
  #   ebx: numeric value of digit, -1 if ebx is not a digit

  cmp ebx, 0x30
  jb not_digit
  cmp ebx, 0x3a
  jb 0f
  and ebx, 0xdf     # a..z -> A..Z
  sub ebx, 0x41-0x3a
0:
  sub ebx, 0x30
  cmp ebx, edi
  jb yes_digit
not_digit:
  mov ebx, -1
yes_digit:
  ret

unknown_word:
  lea esi, [source_start]
  add esi, [source_index]
  mov edx, esi      # first byte of unknown word

  mov bl, [esi]
  cmp bl, 0x27      # single quote?
  je char_literal
  cmp bl, 0x23      # '#'?
  je base_10
  cmp bl, 0x24      # '$'?
  je base_16
  cmp bl, 0x25      # '%'?
  je base_2

  mov edi, [base]
  jmp parse_number

char_literal:
  # parse area should match 'X'<blank>
  mov bl, [esi+2]
  cmp bl, 0x27                  # single quote?
  jne not_a_number
  mov bl, [esi+3]
  cmp bl, 0x20                  # blank?
  ja not_a_number
  movzx eax, byte ptr [esi+1]
  add esi, 4                    # skip over char literal
  jmp found_number

base_10:
  mov edi, 10
  jmp skip_base_prefix

base_16:
  mov edi, 16
  jmp skip_base_prefix

base_2:
  mov edi, 2
  jmp skip_base_prefix

skip_base_prefix:
  inc esi

parse_number:
  xor ecx, ecx            # sign: 0 = positive, 1 = negative
  mov bl, [esi]
  cmp bl, 0x2d            # '-'
  jne check_first_digit
  inc ecx                 # shall be negated at the end
  inc esi

check_first_digit:
  mov bl, [esi]
  call is_digit
  or ebx, ebx
  js not_a_number

parse_digits:
  xor eax, eax
  xor ebx, ebx
  push edx

parse_digit:
  mov bl, [esi]
  call is_digit
  or ebx, ebx
  js end_of_number
  inc esi
  mul edi
  add eax, ebx
  jmp parse_digit

end_of_number:
  pop edx
  mov bl, [esi]
  cmp bl, 0x20        # character after last digit is not whitespace?
  ja not_a_number
  or ecx, ecx         # multiply by -1 if there was a minus sign
  jz found_number
  neg eax

found_number:
  dpush eax
  mov ebx, [state]
  or ebx, ebx         # interpreting?
  jz 1f               # leave number on stack
  call _literal       # compile code which pushes number to stack
1:
  sub esi, edx
  add [source_index], esi
  ret

not_a_number:
  call _parse_name
  dpop esi                    # len
  dpop edx                    # addr
  sys_write 1, edx, esi       # print unknown word
  mov eax, 0x3f
  dpush eax
  call _emit                  # print '?'
  call _cr
  sys_exit 1

_start:
  lea esp, [return_stack]
  lea ebp, [data_stack]

  lea eax, [dictionary]
  mov [here], eax

  lea eax, [$last_xt]
  mov [last_xt], eax

0:
  call _interpret_1
  lea ebx, [data_stack]
  cmp ebp, ebx
  jae 0b
  die "stack underflow"

.data

base:               .dc.a 10
state:              .dc.a 0

source_index:       .dc.a 0
source_start:
  .incbin "grund.g"
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

# definitions in grund.g will be compiled starting from here
dictionary:
  .space 1 * $MiB
