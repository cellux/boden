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

.macro compile_push_word
  #   mov [ebp], eax      89 45 00
  #   add ebp, 4          83 C5 04
  mov eax, 0x83004589
  stosd
  mov ax, 0x04c5
  stosw
.endm

.macro pop_word dst
  sub ebp, 4
  mov \dst, [ebp]
.endm

.macro compile_pop_word
  #   sub ebp, 4          83 ED 04
  #   mov eax, [ebp]      8B 45 00
  mov eax, 0x8b04ed83
  stosd
  mov ax, 0x0045
  stosw
.endm

.macro die msg_addr
  sys_write 1, \msg_addr, \msg_addr\()_len
  call _cr
  sys_exit 1
.endm

.macro align reg
  test \reg, 3
  jz 1f
  and \reg, -4
  add \reg, 4
1:
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

begin_dict_entry "debug-trap"
_debug_trap:
  int 3
  ret

begin_dict_entry "depth"
  lea ebx, [data_stack]
  mov eax, ebp
  sub eax, ebx
  shr eax, 2
  push_word eax
  ret

begin_dict_entry "aligned"
_aligned:
  mov eax, [ebp-4]
  align eax
  mov [ebp-4], eax
  ret

begin_dict_entry "align"
_align:
  mov eax, [here]
  align eax
  mov [here], eax
  ret

begin_dict_entry "parse"
_parse:
  pop_word eax      # al = delimiter
  mov edi, esi
  mov ecx, 0x10000  # max length (64k)
  repne scasb
  jz 1f
  die msg_parse_overflow

# found delimiter
1:
  # esi: first byte of string
  # edi: one byte after delimiter
  mov eax, edi
  dec eax
  sub eax, esi      # eax = length of string
  push_word esi     # addr
  push_word eax     # len
  mov esi, edi      # esi = address of next byte in parse area
  ret

begin_dict_entry "parse-name"
_parse_name:
  call skip_while_whitespace
  push_word esi     # addr
  mov ebx, esi
  call skip_until_whitespace
  mov eax, esi
  sub eax, ebx
  push_word eax     # len
  ret

begin_dict_entry "sys:exit"
_sys_exit:
  pop_word eax
  sys_exit eax

begin_dict_entry "emit"
_emit:
  sys_write 1, ebp-4, 1
  sub ebp, 4
  ret

begin_dict_entry "cr"
_cr:
  mov eax, 0x0a
  push_word eax
  jmp _emit

begin_dict_entry "type"
_type:
  pop_word edi      # len
  pop_word edx      # addr
  sys_write 1, edx, edi
  ret

begin_dict_entry "abs"
  mov eax, [ebp-4]
  or eax, eax
  jns 1f
  neg eax
  mov [ebp-4], eax
1:
  ret

begin_dict_entry "mod"
  pop_word ebx
  pop_word eax
  xor edx, edx
  idiv ebx
  push_word edx
  ret

begin_dict_entry "and"
  pop_word ebx
  pop_word eax
  and eax, ebx
  push_word eax
  ret

begin_dict_entry "or"
  pop_word ebx
  pop_word eax
  or eax, ebx
  push_word eax
  ret

begin_dict_entry "xor"
  pop_word ebx
  pop_word eax
  xor eax, ebx
  push_word eax
  ret

begin_dict_entry "lshift"
  pop_word ecx
  pop_word eax
  shl eax, cl
  push_word eax
  ret

begin_dict_entry "rshift"
  pop_word ecx
  pop_word eax
  shr eax, cl
  push_word eax
  ret

begin_dict_entry "="
_eq:
  pop_word ebx
  pop_word eax
  mov edx, -1       # true (equal)
  cmp eax, ebx
  je 1f
  inc edx           # false (not equal)
1:
  push_word edx
  ret

begin_dict_entry "<>"
_ne:
  pop_word ebx
  pop_word eax
  mov edx, -1       # true (equal)
  cmp eax, ebx
  jne 1f
  inc edx           # false (not equal)
1:
  push_word edx
  ret

begin_dict_entry "<"
_lt:
  pop_word ebx
  pop_word eax
  mov edx, -1
  cmp eax, ebx
  jl 1f
  inc edx
1:
  push_word edx
  ret

begin_dict_entry "<="
_le:
  pop_word ebx
  pop_word eax
  mov edx, -1
  cmp eax, ebx
  jle 1f
  inc edx
1:
  push_word edx
  ret

begin_dict_entry ">"
_ge:
  pop_word ebx
  pop_word eax
  mov edx, -1
  cmp eax, ebx
  jg 1f
  inc edx
1:
  push_word edx
  ret

begin_dict_entry ">="
_gt:
  pop_word ebx
  pop_word eax
  mov edx, -1
  cmp eax, ebx
  jge 1f
  inc edx
1:
  push_word edx
  ret

begin_dict_entry "invert"
_invert:
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
  jmp _cr

begin_dict_entry "swap"
_swap:
  mov eax, [ebp-4]
  mov ebx, [ebp-8]
  mov [ebp-4], ebx
  mov [ebp-8], eax
  ret

begin_dict_entry "dup"
_dup:
  mov eax, [ebp-4]
  push_word eax
  ret

begin_dict_entry "drop"
_drop:
  sub ebp, 4
  ret

begin_dict_entry "nip"
_nip:
  sub ebp, 4
  mov eax, [ebp]
  mov [ebp-4], eax
  ret

begin_dict_entry "over"
_over:
  mov eax, [ebp-8]
  push_word eax
  ret

begin_dict_entry "pick"
_pick:
  pop_word ebx
  shl ebx, 2
  lea edi, [ebp-4]
  sub edi, ebx
  mov eax, [edi]
  push_word eax
  ret

begin_dict_entry "roll"
  push esi
  pop_word ebx
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
_2dup:
  mov eax, [ebp-8]
  push_word eax
  mov eax, [ebp-8]
  push_word eax
  ret

begin_dict_entry "2drop"
_2drop:
  sub ebp, 8
  ret

begin_dict_entry "c@"
_char_at:
  pop_word ebx
  movzx eax, byte ptr [ebx]
  push_word eax
  ret

begin_dict_entry "c!"
  pop_word edi
  pop_word eax
  stosb
  ret

begin_dict_entry "fill"
  pop_word eax    # char
  pop_word ecx    # len
  pop_word edi    # addr
  rep stosb
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

begin_dict_entry ","
_comma:
  mov edi, [here]
  pop_word eax
  stosd
  mov [here], edi
  ret

begin_dict_entry "c,"
_c_comma:
  mov edi, [here]
  pop_word eax
  stosb
  mov [here], edi
  ret

begin_dict_entry "base"
_base:
  lea eax, [base]
  push_word eax
  ret

begin_dict_entry "create"
_create:
  call _parse_name        # ( -- addr len )
  mov edx, esi            # save parse area pointer
  mov edi, [here]
  mov eax, [last_xt]
  stosd                   # link
  pop_word ecx            # ecx = len
  pop_word esi            # esi = addr
  push ecx
  rep movsb               # name
  pop eax
  stosb                   # namelen
  mov [last_xt], edi

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
  align eax               # align to cell boundary
  pop edi
  stosd                   # patch aligned address into data pointer
  mov [here], eax
  mov esi, edx            # restore parse area pointer
  ret

begin_dict_entry "'"
_tick:
  call skip_while_whitespace

  mov ebx, [last_xt]
  mov edx, esi      # first character of word to parse

compare_next:
  or ebx,ebx        # no more words in the dictionary?
  jz word_not_found

  mov edi, ebx      # xt
  dec edi
  mov cl, [edi]     # namelen
  and ecx, 0x1f     # zero out all other bits, max(namelen) = 31
  sub edi, ecx      # first character of name in dictionary entry
  mov ebx, [edi-4]  # previous xt from link field
  mov esi, edx      # first character of word to parse
  repe cmpsb
  jnz compare_next

  # if next char is blank, we found the word
  lodsb
  cmp al, 0x20
  ja compare_next

word_found:
  mov cl, [edi]
  test cl, 0x40     # smudge bit set?
  jnz compare_next  # yes: ignore this word

  inc edi           # skip namelen, edi = xt
  push_word edi     # always non-zero (true)
  ret

word_not_found:
  mov esi, edx      # restore parse area ptr to first char of word
  xor eax, eax
  push_word eax     # false
  ret

begin_dict_entry "execute"
_execute:
  pop_word edi
  jmp edi

begin_dict_entry ":"
_colon:
  call _create
  mov edi, [last_xt]
  mov [here], edi       # overwrite code compiled by create
  dec edi
  mov al, [edi]
  or al, 0x40           # set smudge bit
  stosb
  mov eax, -1           # set compilation state
  mov [state], eax
  ret

begin_dict_entry ";" immediate
_semicolon:
  mov edi, [here]
  mov al, 0xc3          # RET
  stosb
  align edi
  mov [here], edi
  mov edi, [last_xt]
  dec edi
  mov al, [edi]         # namelen
  and al, 0xbf          # clear smudge bit
  stosb
  mov eax, 0            # set interpretation state
  mov [state], eax
  ret

begin_dict_entry "immediate"
_immediate:
  mov edi, [last_xt]
  dec edi               # edi -> namelen
  mov al, [edi]
  or al, 0x20           # set immediate bit
  stosb
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
  pop_word eax          # value comes from the data stack
  stosd
  compile_push_word
  mov [here], edi
  ret

begin_dict_entry "compile,"
_compile_comma:
  mov edi, [here]   # next free location in dictionary
  mov al, 0xe8      # compile CALL instruction
  stosb
  push edi
  add edi, 4        # address of location after CALL instruction
  pop_word eax      # xt (word address)
  sub eax, edi      # convert to relative
  pop edi
  stosd
  mov [here], edi
  ret

begin_dict_entry "constant"
  call _create
  mov edi, [last_xt]
  mov [here], edi       # overwrite code compiled by create
  jmp _literal

begin_dict_entry "state"
  lea eax, [state]
  push_word eax
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

begin_dict_entry ">r" immediate
  mov edi, [here]
  compile_pop_word
  mov al, 0x50      # push eax
  stosb
  mov [here], edi
  ret

begin_dict_entry "r>" immediate
  mov edi, [here]
  mov al, 0x58      # pop eax
  stosb
  compile_push_word
  mov [here], edi
  ret

begin_dict_entry "r@" immediate
  mov edi, [here]
  mov ax, 0x5058                # pop eax, push eax
  stosw
  compile_push_word
  mov [here], edi
  ret

compile_jump:
  # ( R: opcode -- S: address of branch offset )
  mov edi, [here]
  pop eax             # opcode (JMP, JZ, JNZ)
  stosb
  push_word edi       # address of branch offset
  xor al, al          # placeholder for branch offset (i8)
  stosb
  mov [here], edi
  ret

compile_conditional_branch:
  # ( R: opcode -- S: address of branch offset )
  #
  # compile the following:
  #
  #   sub ebp, 4              83 ED 04
  #   mov eax, [ebp]          8B 45 00
  #   or eax, eax             09 C0
  #   <opcode> <offset>       .. ..
  mov edi, [here]
  compile_pop_word
  mov eax, 0xc009             # or eax, eax
  stosw
  mov [here], edi
  jmp compile_jump

begin_dict_entry ",jmpz"
  mov eax, 0x74
  push eax
  jmp compile_conditional_branch

begin_dict_entry ",jmpnz"
  mov eax, 0x75
  push eax
  jmp compile_conditional_branch

begin_dict_entry ",jmp"
  mov eax, 0xeb
  push eax
  jmp compile_jump

begin_dict_entry "patch-jmp"
  # ( dest branch-offset-addr -- )
  pop_word edi
  pop_word eax
  sub eax, edi
  sub eax, 1        # offset counts from start of next instruction
  stosb
  ret

_start:
  # return stack grows top -> down
  lea esp, [return_stack]

  # data stack grows bottom -> up
  lea ebp, [data_stack]

  # esi: parse area pointer
  lea esi, [parse_area]

  lea eax, [dictionary]
  mov [here], eax

  lea eax, [$last_xt]
  mov [last_xt], eax

parse_word:
  call _tick        # ( -- xt|0 )
  pop_word edi
  or edi, edi
  jz unknown_word

  mov cl, [edi-1]   # namelen
  mov eax, [state]
  or eax, eax       # are we in interpretation state?
  jz execute_word

  test cl, 0x20     # is word immediate?
  jnz execute_word  # yes: execute it

compile_word:
  push_word edi
  call _compile_comma
  jmp parse_word

execute_word:
  call edi
  jmp parse_word

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
  # parse area should match 'X'<blank>
  mov bl, [esi+2]
  cmp bl, 0x27                  # single quote?
  jne not_a_number
  mov bl, [esi+3]
  cmp bl, 0x20                  # blank?
  ja not_a_number
  movzx eax, byte ptr [esi+1]
  add esi, 4                    # skip over char literal
  jmp positive_number

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
  cmp esi, edx
  je not_a_number

  or ecx, ecx
  jz positive_number
  neg eax

positive_number:
  push_word eax
  mov ebx, [state]
  or ebx, ebx         # interpretation state?
  jz 1f               # leave number on stack
  call _literal       # compile code which pushes number to stack
1:
  jmp parse_word

not_a_number:
  call skip_until_whitespace
  sub esi, edx
  sys_write 1, edx, esi             # print unknown word
  mov eax, 0x3f
  push_word eax
  call _emit                        # print '?'
  call _cr
  sys_exit 1

.data

.macro msg name str
msg_\name\():
  .ascii "\str"
msg_\name\()_len = . - msg_\name
.endm

msg parse_overflow "parse overflow"
msg assertion_failed "assertion failed"

base:
  .dc.a 10

state:
  .dc.a 0

digit_chars:
  .ascii "0123456789abcdefghijklmnopqrstuvwxyz"

parse_area:
  .incbin "grund.g"
  .byte 0x0a        # sentinel

.bss

here:
  .dc.a 0

last_xt:
  .dc.a 0

# data and return stack use the same memory region
#
# data stack grows upwards
# return stack grows downwards

data_stack:
  .space 4096
return_stack:

# definitions in grund.g will be compiled from here
dictionary:
  .space 1048576
