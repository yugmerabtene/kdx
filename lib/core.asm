; KodPix Standard Library - core::io Module
; x86-64 NASM Assembly
; I/O utilities using Linux syscalls

section .data
    SYS_WRITE         equ 1
    STDOUT_FD        equ 1
    NEWLINE_CHAR     db 10
    MINUS_CHAR       db '-'
    DIGIT_ZERO       equ 48
    DIGIT_NINE       equ 57

section .bss
    print_buffer:    resb 32
    fmt_buffer:     resb 4096

section .text
    global println, print, printi, printc, print_newline
    global printi_with_prefix, printu, print_hex
    global print_format, print_format_buffer
    global printfmt

; Print a newline character
print_newline:
    push rbp
    mov rbp, rsp

    mov rax, SYS_WRITE
    mov rdi, STDOUT_FD
    lea rsi, [rel NEWLINE_CHAR]
    mov rdx, 1
    syscall

    pop rbp
    ret

; Print character in al
printc:
    push rbp
    mov rbp, rsp

    mov byte [rel print_buffer], al
    mov rax, SYS_WRITE
    mov rdi, STDOUT_FD
    lea rsi, [rel print_buffer]
    mov rdx, 1
    syscall

    pop rbp
    ret

; Print string (rdi = pointer to string, rsi = length)
print:
    push rbp
    mov rbp, rsp

    mov rax, SYS_WRITE
    mov rdi, STDOUT_FD
    mov rsi, rdi
    mov rdx, rsi
    mov rsi, rdi
    mov rdx, [rsi]
    syscall

    pop rbp
    ret

print_c_string:
    push rbp
    mov rbp, rsp
    push r12

    mov r12, rdi
    xor rcx, rcx
.len_loop:
    cmp byte [r12 + rcx], 0
    je .len_done
    inc rcx
    jmp .len_loop
.len_done:
    mov rax, SYS_WRITE
    mov rdi, STDOUT_FD
    mov rsi, r12
    mov rdx, rcx
    syscall

    pop r12
    pop rbp
    ret

print_c_string_with_len:
    push rbp
    mov rbp, rsp

    mov rax, SYS_WRITE
    mov rdi, STDOUT_FD
    mov rdx, rsi
    syscall

    pop rbp
    ret

print_c_string_nolen:
    push rbp
    mov rbp, rsp
    push r12
    push r13

    mov r12, rdi
    mov r13, rsi
    mov rax, SYS_WRITE
    mov rdi, STDOUT_FD
    mov rsi, r12
    mov rdx, r13
    syscall

    pop r13
    pop r12
    pop rbp
    ret

print_string_simple:
    push rbp
    mov rbp, rsp
    push r12
    push r13

    mov r12, rdi
    mov r13, rsi
    mov rax, SYS_WRITE
    mov rdi, STDOUT_FD
    mov rsi, r12
    mov rdx, r13
    syscall

    pop r13
    pop r12
    pop rbp
    ret

print_string_from_kodpix:
    push rbp
    mov rbp, rsp
    push r12
    push r13

    mov r12, rdi
    mov r13, rsi
    mov rax, SYS_WRITE
    mov rdi, STDOUT_FD
    mov rsi, r12
    mov rdx, r13
    syscall

    pop r13
    pop r12
    pop rbp
    ret

println_string:
    push rbp
    mov rbp, rsp
    push r12
    push r13

    mov r12, rdi
    mov r13, rsi
    mov rax, SYS_WRITE
    mov rdi, STDOUT_FD
    mov rsi, r12
    mov rdx, r13
    syscall

    mov rax, SYS_WRITE
    lea rsi, [rel NEWLINE_CHAR]
    mov rdx, 1
    syscall

    pop r13
    pop r12
    pop rbp
    ret

print_from_rax:
    push rbp
    mov rbp, rsp

    mov byte [rel print_buffer], al
    mov rax, SYS_WRITE
    mov rdi, STDOUT_FD
    lea rsi, [rel print_buffer]
    mov rdx, 1
    syscall

    pop rbp
    ret

print_digit:
    push rbp
    mov rbp, rsp

    mov byte [rel print_buffer], al
    mov rax, SYS_WRITE
    mov rdi, STDOUT_FD
    lea rsi, [rel print_buffer]
    mov rdx, 1
    syscall

    pop rbp
    ret

printi_with_prefix:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14

    mov r12, rdi
    mov r13, rsi
    mov r14, rcx

    mov rax, SYS_WRITE
    mov rdi, STDOUT_FD
    mov rsi, r12
    mov rdx, r13
    syscall

    mov rax, SYS_WRITE
    mov rdi, STDOUT_FD
    lea rsi, [rel NEWLINE_CHAR]
    mov rdx, 1
    syscall

    pop r14
    pop r13
    pop r12
    pop rbp
    ret

printi:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi
    xor r13, r13
    mov r15, 0

    cmp r12, 0
    je .zero_case

    mov r14, 10
    mov r13, 0

    cmp r12, 0
    jge .convert_loop

    mov r15, 1
    neg r12

.convert_loop:
    xor rdx, rdx
    mov rax, r12
    div r14
    mov r12, rax
    add dl, DIGIT_ZERO
    push rdx
    inc r13
    cmp r12, 0
    jne .convert_loop

    cmp r15, 1
    je .print_minus

.print_digits:
    pop rax
    mov byte [rel print_buffer], al
    mov rax, SYS_WRITE
    mov rdi, STDOUT_FD
    lea rsi, [rel print_buffer]
    mov rdx, 1
    syscall
    dec r13
    jnz .print_digits
    jmp .done

.zero_case:
    mov byte [rel print_buffer], '0'
    mov rax, SYS_WRITE
    mov rdi, STDOUT_FD
    lea rsi, [rel print_buffer]
    mov rdx, 1
    syscall
    jmp .done

.print_minus:
    mov byte [rel print_buffer], '-'
    mov rax, SYS_WRITE
    mov rdi, STDOUT_FD
    lea rsi, [rel print_buffer]
    mov rdx, 1
    syscall
    jmp .print_digits

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

printu:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14

    mov r12, rdi
    mov r14, 10
    mov r13, 0

    cmp r12, 0
    je .zero_case

.convert_loop:
    xor rdx, rdx
    mov rax, r12
    div r14
    mov r12, rax
    add dl, DIGIT_ZERO
    push rdx
    inc r13
    cmp r12, 0
    jne .convert_loop

.print_digits:
    pop rax
    mov byte [rel print_buffer], al
    mov rax, SYS_WRITE
    mov rdi, STDOUT_FD
    lea rsi, [rel print_buffer]
    mov rdx, 1
    syscall
    dec r13
    jnz .print_digits
    jmp .done

.zero_case:
    mov byte [rel print_buffer], '0'
    mov rax, SYS_WRITE
    mov rdi, STDOUT_FD
    lea rsi, [rel print_buffer]
    mov rdx, 1
    syscall

.done:
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

print_hex:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r15, 0
    mov r14, 16
    mov r13, 0

    cmp r12, 0
    je .zero_case

    mov byte [rel print_buffer], '0'
    mov rax, SYS_WRITE
    mov rdi, STDOUT_FD
    lea rsi, [rel print_buffer]
    mov rdx, 1
    syscall

    mov byte [rel print_buffer], 'x'
    mov rax, SYS_WRITE
    mov rdi, STDOUT_FD
    lea rsi, [rel print_buffer]
    mov rdx, 1
    syscall

.convert_loop:
    xor rdx, rdx
    mov rax, r12
    div r14
    mov r12, rax
    cmp dl, 9
    jbe .digit_char
    add dl, 55
    jmp .store_digit
.digit_char:
    add dl, 48
.store_digit:
    push rdx
    inc r13
    cmp r12, 0
    jne .convert_loop

.print_digits:
    pop rax
    mov byte [rel print_buffer], al
    mov rax, SYS_WRITE
    mov rdi, STDOUT_FD
    lea rsi, [rel print_buffer]
    mov rdx, 1
    syscall
    dec r13
    jnz .print_digits
    jmp .done

.zero_case:
    mov byte [rel print_buffer], '0'
    mov rax, SYS_WRITE
    mov rdi, STDOUT_FD
    lea rsi, [rel print_buffer]
    mov rdx, 1
    syscall

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

print_format:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    mov r15, rcx

    mov rax, SYS_WRITE
    mov rdi, STDOUT_FD
    mov rsi, r12
    mov rdx, r13
    syscall

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

print_format_buffer:
    push rbp
    mov rbp, rsp
    push r12
    push r13

    mov r12, rdi
    mov r13, rsi

    mov rax, SYS_WRITE
    mov rdi, STDOUT_FD
    mov rsi, r12
    mov rdx, r13
    syscall

    pop r13
    pop r12
    pop rbp
    ret

println:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14

    mov r12, rdi
    mov r13, rsi

    mov rax, SYS_WRITE
    mov rdi, STDOUT_FD
    mov rsi, r12
    mov rdx, r13
    syscall

    mov rax, SYS_WRITE
    lea rsi, [rel NEWLINE_CHAR]
    mov rdx, 1
    syscall

    pop r14
    pop r13
    pop r12
    pop rbp
    ret

printfmt:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    push r12
    push r13
    push r14
    push r15
    push rbx

    mov r12, rdi
    mov r13, rsi

    mov qword [rbp - 16], r12
    mov qword [rbp - 8], r13

    mov r12, 0
    mov rbx, 0

.fmt_loop:
    cmp byte [rdi + rbx], 0
    je .fmt_done

    cmp byte [rdi + rbx], '%'
    je .check_spec

    movzx r14, byte [rdi + rbx]
    mov byte [rel fmt_buffer + r12], r14b
    inc r12
    inc rbx
    jmp .fmt_loop

.check_spec:
    inc rbx
    cmp byte [rdi + rbx], 's'
    je .spec_string
    cmp byte [rdi + rbx], 'd'
    je .spec_int
    cmp byte [rdi + rbx], 'i'
    je .spec_int
    cmp byte [rdi + rbx], 'u'
    je .spec_uint
    cmp byte [rdi + rbx], 'x'
    je .spec_hex
    cmp byte [rdi + rbx], 'c'
    je .spec_char
    cmp byte [rdi + rbx], '%'
    je .spec_percent
    cmp byte [rdi + rbx], 'l'
    je .check_long
    jmp .spec_literal

.check_long:
    inc rbx
    cmp byte [rdi + rbx], 'd'
    je .spec_long
    cmp byte [rdi + rbx], 'i'
    je .spec_long
    cmp byte [rdi + rbx], 'u'
    je .spec_ulong
    cmp byte [rdi + rbx], 'x'
    je .spec_hex
    jmp .spec_literal

.spec_percent:
    mov byte [rel fmt_buffer + r12], '%'
    inc r12
    inc rbx
    jmp .fmt_loop

.spec_literal:
    mov byte [rel fmt_buffer + r12], '%'
    inc r12
    jmp .fmt_loop

.spec_string:
    push rdi
    push rsi
    push rdx
    mov rdi, [rsi]
    mov r13, 0
    cmp rdi, 0
    je .str_done
.str_len:
    cmp byte [rdi + r13], 0
    je .str_done
    inc r13
    jmp .str_len
.str_done:
    mov r14, 0
.str_copy:
    cmp r14, r13
    je .str_copy_done
    movzx r15, byte [rdi + r14]
    mov byte [rel fmt_buffer + r12], r15b
    inc r12
    inc r14
    jmp .str_copy
.str_copy_done:
    pop rdx
    pop rsi
    pop rdi
    add rsi, 8
    inc rbx
    jmp .fmt_loop

.spec_int:
    push rdi
    push rsi
    push rdx
    mov rdi, [rsi]
    mov r14, 0
    cmp rdi, 0
    je .int_zero
    mov r13, rdi
    mov r15, 0
    cmp r13, 0
    jge .int_convert
    mov r15, 1
    neg r13
.int_convert:
    mov r14, 0
.int_div_loop:
    mov rax, r13
    xor rdx, rdx
    mov r13, 10
    div r13
    mov r13, rax
    add rdx, 48
    push rdx
    inc r14
    cmp r13, 0
    jne .int_div_loop
    cmp r15, 1
    je .int_print_minus
.int_print_digits:
    pop rdx
    mov byte [rel fmt_buffer + r12], dl
    inc r12
    dec r14
    jnz .int_print_digits
    jmp .int_done
.int_minus_flag:
    mov r15, 1
    jmp .int_print_digits
.int_print_minus:
    mov byte [rel fmt_buffer + r12], '-'
    inc r12
    jmp .int_print_digits
.int_zero:
    mov byte [rel fmt_buffer + r12], '0'
    inc r12
.int_done:
    pop rdx
    pop rsi
    pop rdi
    add rsi, 8
    inc rbx
    jmp .fmt_loop

.spec_uint:
    push rdi
    push rsi
    push rdx
    mov rdi, [rsi]
    mov r14, 0
    cmp rdi, 0
    je .uint_zero
    mov r13, rdi
.uint_convert:
    mov r14, 0
.uint_div_loop:
    mov rax, r13
    xor rdx, rdx
    mov r13, 10
    div r13
    mov r13, rax
    add rdx, 48
    push rdx
    inc r14
    cmp r13, 0
    jne .uint_div_loop
.uint_print_digits:
    pop rdx
    mov byte [rel fmt_buffer + r12], dl
    inc r12
    dec r14
    jnz .uint_print_digits
    jmp .uint_done
.uint_zero:
    mov byte [rel fmt_buffer + r12], '0'
    inc r12
.uint_done:
    pop rdx
    pop rsi
    pop rdi
    add rsi, 8
    inc rbx
    jmp .fmt_loop

.spec_long:
    push rdi
    push rsi
    push rdx
    mov rdi, [rsi]
    mov r14, 0
    cmp rdi, 0
    je .long_zero
    mov r13, rdi
    mov r15, 0
    cmp r13, 0
    jge .long_convert
    mov r15, 1
    neg r13
.long_convert:
    mov r14, 0
.long_div_loop:
    mov rax, r13
    xor rdx, rdx
    mov r13, 10
    div r13
    mov r13, rax
    add rdx, 48
    push rdx
    inc r14
    cmp r13, 0
    jne .long_div_loop
    cmp r15, 1
    je .long_print_minus
.long_print_digits:
    pop rdx
    mov byte [rel fmt_buffer + r12], dl
    inc r12
    dec r14
    jnz .long_print_digits
    jmp .long_done
.long_print_minus:
    mov byte [rel fmt_buffer + r12], '-'
    inc r12
    jmp .long_print_digits
.long_zero:
    mov byte [rel fmt_buffer + r12], '0'
    inc r12
.long_done:
    pop rdx
    pop rsi
    pop rdi
    add rsi, 8
    inc rbx
    jmp .fmt_loop

.spec_ulong:
    push rdi
    push rsi
    push rdx
    mov rdi, [rsi]
    mov r14, 0
    cmp rdi, 0
    je .ulong_zero
    mov r13, rdi
.ulong_convert:
    mov r14, 0
.ulong_div_loop:
    mov rax, r13
    xor rdx, rdx
    mov r13, 10
    div r13
    mov r13, rax
    add rdx, 48
    push rdx
    inc r14
    cmp r13, 0
    jne .ulong_div_loop
.ulong_print_digits:
    pop rdx
    mov byte [rel fmt_buffer + r12], dl
    inc r12
    dec r14
    jnz .ulong_print_digits
    jmp .ulong_done
.ulong_zero:
    mov byte [rel fmt_buffer + r12], '0'
    inc r12
.ulong_done:
    pop rdx
    pop rsi
    pop rdi
    add rsi, 8
    inc rbx
    jmp .fmt_loop

.spec_hex:
    push rdi
    push rsi
    push rdx
    mov rdi, [rsi]

    mov byte [rel fmt_buffer + r12], '0'
    inc r12
    mov byte [rel fmt_buffer + r12], 'x'
    inc r12

    cmp rdi, 0
    je .hex_zero
    mov r13, rdi
    mov r14, 0
.hex_convert:
    mov rax, r13
    xor rdx, rdx
    mov r13, 16
    div r13
    mov r13, rax
    cmp rdx, 10
    jb .hex_digit
    add rdx, 55
    jmp .hex_store
.hex_digit:
    add rdx, 48
.hex_store:
    push rdx
    inc r14
    cmp r13, 0
    jne .hex_convert
.hex_print:
    pop rdx
    mov byte [rel fmt_buffer + r12], dl
    inc r12
    dec r14
    jnz .hex_print
    jmp .hex_done
.hex_zero:
    mov byte [rel fmt_buffer + r12], '0'
    inc r12
.hex_done:
    pop rdx
    pop rsi
    pop rdi
    add rsi, 8
    inc rbx
    jmp .fmt_loop

.spec_char:
    push rdi
    push rsi
    push rdx
    mov rdi, [rsi]
    mov byte [rel fmt_buffer + r12], dil
    inc r12
    pop rdx
    pop rsi
    pop rdi
    add rsi, 8
    inc rbx
    jmp .fmt_loop

.fmt_done:
    mov rax, SYS_WRITE
    mov rdi, STDOUT_FD
    lea rsi, [rel fmt_buffer]
    mov rdx, r12
    syscall

    pop rbx
    pop r15
    pop r14
    pop r13
    pop r12
    add rsp, 16
    pop rbp
    ret
