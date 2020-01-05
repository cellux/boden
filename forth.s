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
  mov eax, 0x04
  mov ebx, \fd
  lea ecx, [\buf]
  lea edx, [\count]
  int 0x80
.endm

$last_xt = 0

.macro begin_dict_entry namelen name
  .dc.a $last_xt
  .ascii "\name"
  .dc.b \namelen
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

begin_dict_entry 2 "s\x22"
_squote:
  # s"<blank>...
  #          ^ ESI points to one blank after s"
  push_word esi
  mov al, 0x22      # double quote
  mov edi, esi
  mov ecx, 1024     # max length of a string
  repne scasb
  jz 1f
  sys_write 1, msg_string_too_long, msg_string_too_long_len
  sys_exit 1

# found closing quote
1:
  # esi: first byte of string
  # edi: one byte after the closing quote
  mov eax, edi
  dec eax
  sub eax, esi      # eax = length of string
  push_word eax
  mov esi, edi      # address of next byte in parse buffer
  ret

begin_dict_entry 4 "exit"
_exit:
  pop_word eax
  sys_exit eax

begin_dict_entry 7 "println"
_println:
  pop_word edi # length
  pop_word edx # addr
  sys_write 1, edx, edi
  sys_write 1, msg_lf, 1
  ret

begin_dict_entry 1 "+"
_add:
  pop_word eax
  add [ebp-4], eax
  ret

begin_dict_entry 1 "-"
_sub:
  pop_word eax
  sub [ebp-4], eax
  ret

begin_dict_entry 1 "*"
_mul:
  pop_word eax
  mul dword ptr [ebp-4]
  mov [ebp-4], eax
  ret

begin_dict_entry 1 "/"
_div:
  pop_word ebx
  pop_word eax
  xor edx, edx
  div ebx
  push_word eax
  ret

begin_dict_entry 1 "."
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

_start:
  # return stack grows top -> down
  lea esp, [return_stack_end]

  # data stack grows bottom -> up
  lea ebp, [data_stack]

  # esi = forth source pointer
  lea esi, [forth_source]

  lea eax, [dictionary]
  mov [here], eax

  lea eax, [$last_xt]
  mov [last_xt], eax

interpret:
  # skip whitespace
  mov al, [esi]
  cmp al, 0x20
  jz 0f
  test al, 0xe0
  jnz parse_word
0:
  inc esi
  jmp interpret

parse_word:
  mov ebx, [last_xt]
  mov edx, esi      # first character of word to parse

compare_with_next_entry:
  or ebx,ebx
  jz word_not_found

  mov edi, ebx      # current xt
  dec edi
  mov cl, [edi]     # namelen
  and ecx, 0x1f     # zero out all other bits, max(namelen) = 32
  sub edi, ecx      # first character of name in dictionary entry
  mov ebx, [edi-4]  # previous xt
  mov esi, edx      # first character of word to parse
  repe cmpsb
  jnz compare_with_next_entry

  # if next char in source is blank, we found the word
  lodsb
  cmp al, 0x20
  jz word_found
  test al, 0xe0      # control characters are also blank
  jnz compare_with_next_entry

word_found:
  inc edi           # skip namelen, edi = xt
  call edi
  jmp interpret

is_digit:
  cmp bl, 0x30
  jb not_digit
  cmp bl, 0x3a
  jb 0f
  and bl, 0x20      # a..z -> A..Z
  sub bl, (0x41-0x3a)
0:
  sub bl, 0x30
  cmp bl, [base]
  jb yes_digit
not_digit:
  mov ebx, -1
yes_digit:
  ret

word_not_found:
  mov esi, edx      # first byte of unknown word
  push edx

  xor eax, eax
  xor ebx, ebx
0:
  mov bl, [esi]
  call is_digit
  or ebx, ebx
  js end_of_number
  inc esi
  mul dword ptr [base]
  add eax, ebx
  jmp 0b

end_of_number:
  pop edx
  cmp esi, edx
  je not_a_number
  push_word eax
  jmp interpret

not_a_number:
  # look for closing whitespace
0:
  mov al, [esi]
  cmp al, 0x20
  jz 2f
  test al, 0xe0
  jz 2f
1:
  inc esi
  jmp 0b
2:
  sub esi, edx      # length of unknown word
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

msg string_too_long "string too long: "
msg word_not_found "word not found: "

msg_lf:
  .byte 0x0a

msg_question_mark:
  .byte 0x3f

base:
  .dc.a 10

digit_chars:
  .ascii "0123456789abcdefghijklmnopqrstuvwxyz"

forth_source:
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
