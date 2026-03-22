; KodPix Compiler - Main Entry Point
; x86-64 NASM Assembly
; Orchestrates the compilation pipeline

section .data
    program_name db 'kdx', 0
    usage_msg    db 'Usage: kdx [options] <input.kdx>', 10
                db 'Options:', 10
                db '  -c         Compile only, do not link', 10
                db '  -S         Output assembly, do not assemble', 10
                db '  -x         Execute after compilation', 10
                db '  -o <file>  Output filename', 10
                db '  -O0/1/2    Optimization level', 10
                db '  -h, --help Show this help', 10, 0
    error_prefix db 'kdx: error: ', 0
    warning_prefix db 'kdx: warning: ', 0
    nasm_cmd     db 'nasm', 0
    nasm_args    dq 0
    ld_cmd       db 'ld', 0
    ld_args      dq 0
    shell_cmd    db '/bin/sh', 0
    shell_args   db '-c', 0
    null_ptr     dq 0
    nasm_fmt     db 'nasm -f elf64 %s -o %s.o', 0
    ld_fmt       db 'ld -o %s build/*.o', 0
    exec_fmt     db '%s', 0

section .bss
    argc         resq 1
    argv         resq 1
    input_file   resq 1
    output_file  resq 1
    source_buf   resq 1
    source_len   resq 1
    asm_buf      resq 1
    asm_len      resq 1
    compile_only resb 1
    asm_only     resb 1
    exec_after   resb 1
    opt_level    resb 1
    file_fd      resq 1
    nasm_cmd_buf resb 512
    ld_cmd_buf   resb 512
    exec_cmd_buf resb 512

section .text
    global _start
    global main

_start:
    mov rdi, [rsp]          ; argc
    lea rsi, [rsp + 8]      ; argv
    call main
    mov rdi, rax
    mov rax, 60
    syscall

main:
    push rbp
    mov rbp, rsp
    sub rsp, 128

    mov [argc], rdi
    mov [argv], rsi

    xor rax, rax
    mov [compile_only], al
    mov [asm_only], al
    mov [exec_after], al
    mov byte [opt_level], 1

    call parse_args
    test rax, rax
    jnz .args_error

    cmp qword [input_file], 0
    je .no_input

    mov rdi, [input_file]
    mov rsi, input_buffer
    call read_file
    test rax, rax
    jnz .read_error

    mov rdi, input_buffer
    mov rsi, [source_len]
    call lexer_init
    test rax, rax
    jnz .lex_error

    call parser_init
    call parse_program
    test rax, rax
    jnz .parse_error

    ; Semantic analysis
    call sema_init
    test rax, rax
    jnz .sema_error
    
    mov rdi, [ast_root]
    call sema_check_program
    test rax, rax
    jnz .sema_error

    ; Code generation
    call codegen_init
    test rax, rax
    jnz .codegen_error

    ; Pass AST root to codegen_program
    mov rdi, [ast_root]
    call codegen_program
    test rax, rax
    jnz .codegen_error

    ; Get the generated assembly
    call codegen_get_output
    mov [asm_buf], rax
    mov [asm_len], rdx

    call write_asm_file
    test rax, rax
    jnz .write_error

    ; Assemble with NASM
    call assemble_with_nasm
    test rax, rax
    jnz .asm_error

    ; Link with LD
    call link_with_ld
    test rax, rax
    jnz .link_error

    ; Success
    jmp .success

    call codegen_program
    test rax, rax
    jnz .codegen_error

    call write_asm_file
    test rax, rax
    jnz .write_error

    cmp byte [asm_only], 1
    je .success

    call assemble_with_nasm
    test rax, rax
    jnz .asm_error

    cmp byte [compile_only], 1
    je .success

    call link_with_ld
    test rax, rax
    jnz .link_error

    cmp byte [exec_after], 1
    je .execute_binary

.success:
    xor rax, rax
    jmp .cleanup

.args_error:
    lea rdi, [rel usage_msg]
    call print_error
    mov rax, 1
    jmp .cleanup

.no_input:
    lea rdi, [rel .no_input_msg]
    call print_error
    mov rax, 5
    jmp .cleanup

.read_error:
    lea rdi, [rel .read_error_msg]
    call print_error
    mov rax, 5
    jmp .cleanup

.lex_error:
    lea rdi, [rel .lex_error_msg]
    call print_error
    mov rax, 2
    jmp .cleanup

.parse_error:
    lea rdi, [rel .parse_error_msg]
    call print_error
    mov rax, 2
    jmp .cleanup

.sema_error:
    lea rdi, [rel .sema_error_msg]
    call print_error
    mov rax, 3
    jmp .cleanup

.codegen_error:
    lea rdi, [rel .codegen_error_msg]
    call print_error
    mov rax, 1
    jmp .cleanup

.asm_error:
    lea rdi, [rel .asm_error_msg]
    call print_error
    mov rax, 1
    jmp .cleanup

.link_error:
    lea rdi, [rel .link_error_msg]
    call print_error
    mov rax, 4
    jmp .cleanup

.write_error:
    mov rdi, 5
    call print_error
    mov rdi, .write_error_msg
    call print_string
    mov rax, 5
    jmp .cleanup

.execute_binary:
    call execute_binary
    mov rax, 0

.cleanup:
    mov rsp, rbp
    pop rbp
    ret

.no_input_msg      db 'no input file specified', 10, 0
.read_error_msg    db 'failed to read input file', 10, 0
.lex_error_msg     db 'lexical error', 10, 0
.parse_error_msg   db 'syntax error', 10, 0
.success_msg        db 'OK', 10, 0
.sema_error_msg    db 'semantic error', 10, 0
.codegen_error_msg db 'code generation error', 10, 0
.asm_error_msg     db 'assembly failed', 10, 0
.link_error_msg    db 'linking failed', 10, 0
.write_error_msg   db 'failed to write output', 10, 0
nasm_simple_cmd db 'nasm -f elf64 test_output -o test_output.o', 0
ld_simple_cmd db 'ld -o test_output test_output.o', 0

parse_args:
    push rbp
    mov rbp, rsp

    mov rcx, [argc]
    mov rsi, [argv]
    add rsi, 8

.parse_loop:
    dec rcx
    jz .done

    mov rdi, [rsi]
    cmp byte [rdi], '-'
    jne .input_file

    inc rdi
    movzx rax, byte [rdi]
    
    cmp al, '-'
    je .skip_second_dash

.parse_flag:
    cmp al, 'c'
    je .flag_c
    cmp al, 'S'
    je .flag_S
    cmp al, 'x'
    je .flag_x
    cmp al, 'o'
    je .flag_o
    cmp al, 'O'
    je .flag_O
    cmp al, 'h'
    je .flag_help

    cmp word [rdi], 'no'
    je .flag_help

    jmp .invalid_flag

.skip_second_dash:
    inc rdi
    movzx rax, byte [rdi]
    jmp .parse_flag

.flag_c:
    mov byte [compile_only], 1
    jmp .next_arg

.flag_S:
    mov byte [asm_only], 1
    jmp .next_arg

.flag_x:
    mov byte [exec_after], 1
    jmp .next_arg

.flag_o:
    dec rcx
    jz .error
    add rsi, 8
    mov rax, qword [rsi]
    mov qword [output_file], rax
    jmp .next_arg

.flag_O:
    inc rdi
    movzx rax, byte [rdi]
    sub al, '0'
    cmp al, 0
    jl .error
    cmp al, 2
    jg .error
    mov [opt_level], al
    jmp .next_arg

.flag_help:
    mov rax, 1
    jmp .exit

.next_arg:
    add rsi, 8
    jmp .parse_loop

.input_file:
    cmp qword [input_file], 0
    jne .multiple_inputs
    mov [input_file], rdi
    jmp .next_arg

.multiple_inputs:
    lea rdi, [rel .multiple_inputs_msg]
    call print_error
    jmp .error

.multiple_inputs_msg db 'multiple input files specified', 10, 0

.invalid_flag:
    lea rdi, [rel .invalid_flag_msg]
    call print_error
    jmp .error

.invalid_flag_msg db 'invalid command line option', 10, 0

.error:
    mov rax, 1
    jmp .exit

.done:
    xor rax, rax

.exit:
    pop rbp
    ret

read_file:
    push rbp
    mov rbp, rsp
    mov r15, rdi
    mov r14, rsi

    mov rdi, r15
    xor rsi, rsi
    mov rdx, 0
    mov rax, 2
    syscall
    cmp rax, 0
    js .error
    mov [file_fd], rax

    mov rdi, [file_fd]
    xor rsi, rsi
    mov rdx, 2
    mov rax, 8
    syscall
    mov [source_len], rax
    
    mov rdi, [file_fd]
    xor rsi, rsi
    xor rdx, rdx
    mov rax, 8
    syscall

    mov rdi, [file_fd]
    mov rsi, r14
    mov rdx, [source_len]
    mov rax, 0
    syscall

    mov rdi, [file_fd]
    mov rax, 3
    syscall

    xor rax, rax
    jmp .exit

.error:
    mov rax, 5

.exit:
    pop rbp
    ret

write_file:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14

    ; rdi = filename
    ; rdx = buffer pointer
    ; r8 = length
    mov r12, rdi        ; save filename
    mov r13, rdx        ; save buffer
    mov r14, r8         ; save length

    ; Open file for writing
    mov rdi, r12        ; filename
    mov rsi, 0x241      ; O_WRONLY | O_CREAT | O_TRUNC
    mov rdx, 0644o      ; mode
    mov rax, 2          ; sys_open
    syscall
    test rax, rax
    js .error
    mov [file_fd], rax

    ; Write to file
    mov rdi, [file_fd]
    mov rsi, r13        ; buffer
    mov rdx, r14        ; count
    mov rax, 1          ; sys_write
    syscall

    ; Close file
    mov rdi, [file_fd]
    mov rax, 3          ; sys_close
    syscall

    xor rax, rax
    jmp .exit

.error:
    mov rax, 5

.exit:
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

write_asm_file:
    push rbp
    mov rbp, rsp

    mov rdi, [output_file]
    test rdi, rdi
    jnz .use_output

    mov rdi, [input_file]
    call replace_extension

.use_output:
    mov rdx, [asm_buf]
    mov r8, [asm_len]
    call write_file

    pop rbp
    ret

replace_extension:
    push rbp
    mov rbp, rsp
    sub rsp, 256

    mov rsi, rdi
    mov rdi, rsp
    mov rcx, 255
    rep movsb

    mov rdi, rsp
    mov al, '.'
    mov rcx, 255
    repne scasb
    jnz .no_ext

    mov byte [rdi - 1], 's'
    jmp .done

.no_ext:
    mov rdi, rsp
    mov al, 's'
    stosb

.done:
    mov rax, rsp
    pop rbp
    ret

assemble_with_nasm:
    push rbp
    mov rbp, rsp

    mov rdi, [output_file]
    test rdi, rdi
    jnz .do_assemble

    mov rdi, [input_file]
    call replace_extension
    mov [output_file], rax

.do_assemble:
    ; Use a simple hardcoded command for now
    lea rdi, [rel nasm_simple_cmd]
    call system
    test rax, rax
    jnz .error

    xor rax, rax
    jmp .exit

.error:
    mov rax, 1

.exit:
    pop rbp
    ret

link_with_ld:
    push rbp
    mov rbp, rsp

    mov rdi, [output_file]
    test rdi, rdi
    jnz .do_link

    mov rdi, [input_file]
    call replace_extension
    mov [output_file], rax

.do_link:
    ; Use a simple hardcoded command for now
    lea rdi, [rel ld_simple_cmd]
    call system
    test rax, rax
    jnz .error

    xor rax, rax
    jmp .exit

.error:
    mov rax, 4

.exit:
    pop rbp
    ret

execute_binary:
    push rbp
    mov rbp, rsp

    mov rdi, [output_file]
    test rdi, rdi
    jnz .do_exec

    mov rdi, [input_file]
    call replace_extension

.do_exec:
    mov rdi, exec_cmd_buf
    mov rsi, exec_fmt
    mov rdx, [output_file]
    call snprintf
    test rax, rax
    jz .error

    mov rdi, exec_cmd_buf
    call system

    pop rbp
    ret

.error:
    mov rax, 1
    pop rbp
    ret

print_error:
    push rbp
    mov rbp, rsp

    push rdi
    lea rdi, [rel error_prefix]
    call print_string
    pop rdi
    call print_string

    pop rbp
    ret

print_string:
    push rbx
    mov rbx, rdi
    push rdi

    xor rcx, rcx
.count_loop:
    cmp byte [rbx + rcx], 0
    je .print
    inc rcx
    jmp .count_loop

.print:
    mov rdx, rcx
    mov rsi, rbx
    mov rdi, 1
    mov rax, 1
    syscall

    pop rbx
    pop rbp
    ret

exit_with_code:
    mov rax, 60
    syscall
    ret

malloc:
    push rbp
    mov rbp, rsp
    mov rdi, rdi
    mov rax, 12
    syscall
    pop rbp
    ret

    extern lexer_init
    extern input_buffer
    extern parser_init
    extern parse_program
    extern sema_init
    extern sema_check_program
    extern sema_check_function
    extern ast_root
extern optimize
extern codegen_init
extern codegen_program
extern codegen_get_output
extern system
extern sprintf
extern snprintf
