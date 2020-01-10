.intel_syntax noprefix
.global _start

.text

/* linux system calls */

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

$last_xt = 0

.macro begin_dict_entry name immediate
  .dc.a $last_xt    # link
0:
  .ascii "\name"    # name
  .ifb \immediate
  .dc.b .-0b        # namelen
  .else
  .dc.b .-0b+0x20   # namelen + immediate
  .endif
  $last_xt = .
.endm

.macro push_word src
  mov [ebp], \src
  add ebp, 4
.endm

.macro pop_word dst
  sub ebp, 4
  mov \dst, [ebp]
.endm

skip_while_whitespace:
  mov al, [esi]
  cmp al, 0x20
  jbe 0f
  ret
0:
  inc esi
  jmp skip_while_whitespace

skip_until_whitespace:
  mov al, [esi]
  cmp al, 0x20
  jbe 0f
  inc esi
  jmp skip_until_whitespace
0:
  ret

begin_dict_entry "aligned"
_aligned:
  mov eax, [ebp-4]
  test eax, 3
  jz 1f
  and eax, -4
  add eax, 4
1:
  mov [ebp-4], eax
  ret

begin_dict_entry "align"
  mov eax, [here]
  push_word eax
  call _aligned
  pop_word eax
  mov [here], eax
  ret

begin_dict_entry "parse"
_parse:
  pop_word eax      # al = end delimiter
  mov edi, esi
  mov ecx, 0x10000  # max length (64k)
  repne scasb
  jz 1f
  sys_write 1, msg_parse_overflow, msg_parse_overflow_len
  sys_exit 1

# found end delimiter
1:
  # esi: first byte of string
  # edi: one byte after the end delimiter
  mov eax, edi
  dec eax
  sub eax, esi      # eax = length of string
  push_word esi     # addr
  push_word eax     # len
  mov esi, edi      # esi = address of next byte in parse buffer
  ret

begin_dict_entry "\\"
_comment_backslash:
  mov eax, 0x0a     # line feed
  push_word eax
  call _parse
  sub ebp, 8        # drop return values
  ret

begin_dict_entry "("
_comment_paren:
  mov eax, 0x29     # ')'
  push_word eax
  call _parse
  sub ebp, 8        # drop return values
  ret

begin_dict_entry "s\x22"
_squote:
  mov eax, 0x22
  push_word eax
  jmp _parse

begin_dict_entry "parse-name"
_parse_name:
  call skip_while_whitespace
  push_word esi     # addr
  mov edx, esi
  call skip_until_whitespace
  mov eax, esi
  sub eax, edx
  push_word eax     # len
  ret

begin_dict_entry "exit"
_exit:
  pop_word eax
  sys_exit eax

begin_dict_entry "println"
_println:
  pop_word edi      # len
  pop_word edx      # addr
  sys_write 1, edx, edi
  sys_write 1, msg_lf, 1
  ret

begin_dict_entry "abs"
  mov eax, [ebp-4]
  or eax, eax
  jns 1f
  neg eax
1:
  mov [ebp-4], eax
  ret

begin_dict_entry "mod"
  pop_word ebx
  pop_word eax
  xor edx, edx
  idiv ebx
  push_word edx
  ret

begin_dict_entry "="
_eq:
  pop_word eax
  pop_word ebx
  mov edx, -1       # true (equal)
  cmp eax, ebx
  je 1f
  mov edx, 0        # false (not equal)
1:
  push_word edx
  ret

begin_dict_entry "0="
  xor eax, eax
  push_word eax
  jmp _eq

begin_dict_entry "<"
  pop_word ebx
  pop_word eax
  mov edx, -1
  cmp eax, ebx
  jb 1f
  mov edx, 0
1:
  push_word edx
  ret

begin_dict_entry "<="
  pop_word ebx
  pop_word eax
  mov edx, -1
  cmp eax, ebx
  jbe 1f
  mov edx, 0
1:
  push_word edx
  ret

begin_dict_entry ">"
  pop_word ebx
  pop_word eax
  mov edx, -1
  cmp eax, ebx
  ja 1f
  mov edx, 0
1:
  push_word edx
  ret

begin_dict_entry ">="
  pop_word ebx
  pop_word eax
  mov edx, -1
  cmp eax, ebx
  jae 1f
  mov edx, 0
1:
  push_word edx
  ret

begin_dict_entry "invert"
  mov eax, [ebp-4]
  xor eax, -1
  mov [ebp-4], eax
  ret

begin_dict_entry "+"
_add:
  pop_word eax
  add [ebp-4], eax
  ret

begin_dict_entry "-"
_sub:
  pop_word eax
  sub [ebp-4], eax
  ret

begin_dict_entry "*"
_mul:
  pop_word eax
  imul dword ptr [ebp-4]
  mov [ebp-4], eax
  ret

begin_dict_entry "/"
_div:
  pop_word ebx
  pop_word eax
  xor edx, edx
  idiv ebx
  push_word eax
  ret

begin_dict_entry "assert"
_assert:
  pop_word eax
  or eax, eax
  jnz 1f
  sys_write 1, msg_assertion_failed, msg_assertion_failed_len
  sys_write 1, msg_lf, 1
  # TODO: print line number and source from parse buffer
  sys_exit 1
1:
  ret

begin_dict_entry "."
_dot:
  pop_word eax
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
  sys_write 1, msg_lf, 1
  ret

begin_dict_entry "dec"
_dec:
  mov eax, 10
  mov [base], eax
  ret

begin_dict_entry "hex"
_hex:
  mov eax, 16
  mov [base], eax
  ret

begin_dict_entry "dup"
_dup:
  mov eax, [ebp-4]
  push_word eax
  ret

begin_dict_entry "2dup"
_twodup:
  mov eax, [ebp-8]
  push_word eax
  mov eax, [ebp-8]
  push_word eax
  ret

begin_dict_entry "drop"
_drop:
  sub ebp, 4
  ret

begin_dict_entry "c@"
_char_at:
  pop_word ebx
  movzx eax, byte ptr [ebx]
  push_word eax
  ret

begin_dict_entry "here"
_here:
  mov eax, [here]
  push_word eax
  ret

begin_dict_entry "allot"
_allot:
  pop_word eax
  add [here], eax
  ret

begin_dict_entry "base"
_base:
  lea eax, [base]
  push_word eax
  ret

begin_dict_entry "create"
_create:
  call _parse_name
  mov edi, [here]
  mov eax, [last_xt]
  stosd           # link field
  mov edx, esi
  pop_word ecx    # ecx = len
  pop_word esi    # esi = addr
  push ecx
  rep movsb       # name
  pop eax
  stosb           # namelen
  mov [last_xt], edi

  # compile the following:
  #
  #   mov eax, data       B8 .. .. .. ..
  #   mov [ebp], eax      89 45 00
  #   add ebp, 4          83 C5 04
  #   ret                 C3
  #
  # data:

  mov al, 0xb8
  stosb
  lea eax, [edi+4+3+3+1]
  stosd
  mov eax, 0x83004589
  stosd
  mov ax, 0x04c5
  stosw
  mov al, 0xc3
  stosb
  mov [here], edi
  mov esi, edx
  ret

begin_dict_entry "'"
_tick:
  call skip_while_whitespace

parse_word:
  mov ebx, [last_xt]
  mov edx, esi      # first character of word to parse

compare_next:
  or ebx,ebx        # sentinel?
  jz word_not_found

  mov edi, ebx      # current xt
  dec edi
  mov cl, [edi]     # namelen
  and ecx, 0x1f     # zero out all other bits, max(namelen) = 31
  sub edi, ecx      # first character of name in dictionary entry
  mov ebx, [edi-4]  # previous xt
  mov esi, edx      # first character of word to parse
  repe cmpsb
  jnz compare_next

  # if next char in source is blank, we found the word
  lodsb
  cmp al, 0x20
  ja compare_next

word_found:
  inc edi           # skip namelen, edi = xt
  push_word edi
  ret

word_not_found:
  mov esi, edx
  xor eax, eax
  push_word eax     # false
  ret

begin_dict_entry ":"
_colon:
  call _create
  # definition shall overwrite the default behavior compiled by create
  mov edi, [last_xt]
  mov [here], edi
  mov eax, -1           # compilation state
  mov [state], eax
  ret

begin_dict_entry ";" immediate
_semicolon:
  mov edi, [here]
  mov al, 0xc3          # RET
  stosb
  mov [here], edi
  mov eax, 0            # interpretation state
  mov [state], eax
  ret

begin_dict_entry "immediate"
_immediate:
  mov edi, [last_xt]
  dec edi             # edi: namelen
  mov al, [edi]
  or al, 0x20         # set immediate bit
  stosb
  ret

begin_dict_entry "@"
_at:
  mov ebx, [ebp-4]
  mov eax, [ebx]
  mov [ebp-4], eax
  ret

begin_dict_entry "!"
_bang:
  pop_word ebx
  pop_word eax
  mov [ebx], eax
  ret

_start:
  # return stack grows top -> down
  lea esp, [return_stack_end]

  # data stack grows bottom -> up
  lea ebp, [data_stack]

  # esi = parse buffer pointer
  lea esi, [parse_buffer]

  lea eax, [dictionary]
  mov [here], eax

  lea eax, [$last_xt]
  mov [last_xt], eax

interpret:
  call _tick
  pop_word edi
  or edi, edi
  jz unknown_word

  mov cl, [edi-1]   # namelen
  mov eax, [state]
  or eax, eax
  jz execute_word

compile_word:
  test cl, 0x20     # immediate?
  jnz execute_word

  # compile a call to the address of the word

  mov ebx, edi      # xt
  mov edi, [here]   # next free location in dictionary
  mov al, 0xe8      # CALL
  stosb
  # convert address to IP-relative
  push edi
  add edi, 4        # address of location after CALL instruction
  mov eax, ebx      # absolute address of xt
  sub eax, edi      # relative address of xt
  pop edi
  stosd
  mov [here], edi
  jmp interpret

execute_word:
  call edi
  jmp interpret

is_digit:
  # ebx: ASCII value to parse
  # edi: radix (base)
  cmp ebx, 0x30
  jb not_digit
  cmp ebx, 0x3a
  jb 0f
  and ebx, 0xdf     # a..z -> A..Z
  sub ebx, (0x41-0x3a)
0:
  sub ebx, 0x30
  cmp ebx, edi
  jb yes_digit
not_digit:
  mov ebx, -1
yes_digit:
  ret

unknown_word:
  mov edx, esi      # first byte of unknown word

  mov bl, [esi]
  cmp bl, 0x27      # single quote
  je char_literal
  cmp bl, 0x23      # '#'
  je base_10
  cmp bl, 0x24      # '$'
  je base_16
  cmp bl, 0x25      # '%'
  je base_2

  mov edi, [base]
  jmp parse_number

char_literal:
  mov bl, [esi+2]
  cmp bl, 0x27      # single quote
  jne not_a_number
  mov bl, [esi+3]
  cmp bl, 0x20
  ja not_a_number
  movzx eax, byte ptr [esi+1]
  push_word eax
  add esi, 4
  jmp interpret

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
  inc ecx                 # negative
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
  cmp esi, edx
  je not_a_number

  or ecx, ecx
  jz positive_number
  neg eax
positive_number:
  push_word eax
  jmp interpret

not_a_number:
  call skip_until_whitespace
  sub esi, edx                      # esi = length of unknown word
  sys_write 1, edx, esi
  sys_write 1, msg_question_mark, 1
  sys_write 1, msg_lf, 1
  sys_exit 1

.data

.macro msg name str
msg_\name\():
  .ascii "\str"
msg_\name\()_len = . - msg_\name
.endm

msg parse_overflow "parse overflow"
msg assertion_failed "assertion failed"

msg_lf:
  .byte 0x0a

msg_question_mark:
  .byte 0x3f

base:
  .dc.a 10

state:
  .dc.a 0

digit_chars:
  .ascii "0123456789abcdefghijklmnopqrstuvwxyz"

parse_buffer:
  .incbin "forth.f"
  .byte 0x20        # sentinel

.bss

here:
  .dc.a 0
last_xt:
  .dc.a 0

data_stack:
  .space 4096

return_stack:
  .space 4096
return_stack_end:

# forth.f definitions will be compiled from here
dictionary:
  .space 1048576
