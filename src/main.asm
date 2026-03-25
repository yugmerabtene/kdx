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
nasm_fmt     db 'nasm -f elf64 "%s" -o "%s"', 0
ld_fmt       db 'ld -o "%s" "%s" -lc --dynamic-linker /lib64/ld-linux-x86-64.so.2', 0
exec_fmt     db '"%s"', 0
default_bin_file db 'test_output', 0
default_asm_file db 'test_output.s', 0
default_obj_file db 'test_output.o', 0
tmp_asm_file db 'test_output.s', 0
tmp_obj_file db 'test_output.o', 0
no_input_msg db 'no input file specified', 10, 0
multiple_inputs_msg db 'multiple input files specified', 10, 0
invalid_flag_msg db 'invalid command line option', 10, 0
flag_combo_msg db 'incompatible option combination', 10, 0
exec_error_msg db 'execution failed', 10, 0
read_error_msg db 'failed to read input file', 10, 0
parse_error_msg db 'syntax error', 10, 0
sema_error_msg db 'semantic error', 10, 0
codegen_error_msg db 'code generation error', 10, 0
asm_error_msg db 'assembly failed', 10, 0
link_error_msg db 'linking failed', 10, 0

section .bss
    argc         resq 1
    argv         resq 1
    input_file   resq 1
    output_file  resq 1
    source_buf   resq 1
    source_len   resq 1
    asm_buf      resq 1
    asm_len      resq 1
    asm_file     resq 1
    obj_file     resq 1
    compile_only resb 1
    asm_only     resb 1
    exec_after   resb 1
    help_only    resb 1
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

    xor rax, rax
    mov [input_file], rax
    mov [output_file], rax
    mov [asm_file], rax
    mov [obj_file], rax
    mov byte [compile_only], 0
    mov byte [asm_only], 0
    mov byte [exec_after], 0
    mov byte [help_only], 0
    mov byte [opt_level], 1

    mov rcx, rdi                    ; argc
    mov rbx, rsi                    ; argv
    cmp rcx, 1
    jle .after_parse
    add rbx, 8                      ; skip argv[0]
    dec rcx

.parse_loop:
    test rcx, rcx
    jz .after_parse

    mov rdi, [rbx]
    cmp byte [rdi], '-'
    jne .input_arg

    inc rdi
    movzx rax, byte [rdi]
    cmp al, '-'
    je .long_flag

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
    je .flag_h
    jmp .invalid_flag

.long_flag:
    inc rdi
    cmp byte [rdi], 'h'
    jne .invalid_flag
    cmp byte [rdi + 1], 'e'
    jne .invalid_flag
    cmp byte [rdi + 2], 'l'
    jne .invalid_flag
    cmp byte [rdi + 3], 'p'
    jne .invalid_flag
    cmp byte [rdi + 4], 0
    jne .invalid_flag
    jmp .flag_h

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
    jz .invalid_flag
    add rbx, 8
    mov rax, [rbx]
    cmp byte [rax], '-'
    je .invalid_flag
    mov [output_file], rax
    jmp .next_arg

.flag_O:
    inc rdi
    movzx eax, byte [rdi]
    sub al, '0'
    cmp al, 0
    jl .invalid_flag
    cmp al, 2
    jg .invalid_flag
    mov [opt_level], al
    jmp .next_arg

.flag_h:
    mov byte [help_only], 1
    jmp .next_arg

.input_arg:
    cmp qword [input_file], 0
    jne .multiple_inputs
    mov [input_file], rdi
    jmp .next_arg

.next_arg:
    add rbx, 8
    dec rcx
    jmp .parse_loop

.after_parse:
    cmp byte [help_only], 1
    jne .check_flag_combo
    lea rdi, [rel usage_msg]
    call print_string
    xor rax, rax
    jmp .exit

.check_flag_combo:
    cmp byte [asm_only], 1
    jne .check_input
    cmp byte [compile_only], 1
    je .invalid_combo
    cmp byte [exec_after], 1
    je .invalid_combo

.check_input:
    cmp byte [compile_only], 1
    jne .check_input_file
    cmp byte [exec_after], 1
    je .invalid_combo

.check_input_file:
    cmp qword [input_file], 0
    jne .pipeline
    lea rdi, [rel no_input_msg]
    call print_error
    mov rax, 1
    jmp .exit

.pipeline:
    ; Read source into lexer buffer
    mov rdi, [input_file]
    lea rsi, [rel input_buffer]
    call read_file
    test rax, rax
    jz .lex_init
    lea rdi, [rel read_error_msg]
    call print_error
    mov rax, 5
    jmp .exit

.lex_init:
    lea rdi, [rel input_buffer]
    mov rsi, [source_len]
    call lexer_init

    call parser_init
    call parse_program
    test rax, rax
    jz .sema_phase
    lea rdi, [rel parse_error_msg]
    call print_error
    mov rax, 2
    jmp .exit

.sema_phase:
    call sema_init
    mov rdi, [ast_root]
    call sema_check_program
    test rax, rax
    jz .codegen_phase
    lea rdi, [rel sema_error_msg]
    call print_error
    mov rax, 3
    jmp .exit

.codegen_phase:
    call codegen_init
    mov rdi, [ast_root]
    call codegen_program
    test rax, rax
    jz .collect_output
    lea rdi, [rel codegen_error_msg]
    call print_error
    mov rax, 1
    jmp .exit

.collect_output:
    call codegen_get_output
    mov [asm_buf], rax
    mov [asm_len], rdx

    ; Resolve output paths
    cmp byte [asm_only], 1
    jne .prepare_compile_paths
    mov rax, [output_file]
    test rax, rax
    jnz .set_asm_out
    lea rax, [rel default_asm_file]
.set_asm_out:
    mov [asm_file], rax
    jmp .write_asm

.prepare_compile_paths:
    lea rax, [rel tmp_asm_file]
    mov [asm_file], rax

    cmp byte [compile_only], 1
    jne .set_link_paths
    mov rax, [output_file]
    test rax, rax
    jnz .set_obj_only
    lea rax, [rel default_obj_file]
.set_obj_only:
    mov [obj_file], rax
    jmp .write_asm

.set_link_paths:
    lea rax, [rel tmp_obj_file]
    mov [obj_file], rax
    mov rax, [output_file]
    test rax, rax
    jnz .write_asm
    lea rax, [rel default_bin_file]
    mov [output_file], rax

.write_asm:
    call write_asm_file
    test rax, rax
    jz .maybe_stop_after_asm
    lea rdi, [rel asm_error_msg]
    call print_error
    mov rax, 5
    jmp .exit

.maybe_stop_after_asm:
    cmp byte [asm_only], 1
    jne .assemble_phase
    xor rax, rax
    jmp .exit

.assemble_phase:
    call assemble_with_nasm
    test rax, rax
    jz .maybe_stop_after_obj
    lea rdi, [rel asm_error_msg]
    call print_error
    mov rax, 1
    jmp .exit

.maybe_stop_after_obj:
    cmp byte [compile_only], 1
    jne .link_phase
    xor rax, rax
    jmp .exit

.link_phase:
    call link_with_ld
    test rax, rax
    jz .maybe_exec
    lea rdi, [rel link_error_msg]
    call print_error
    mov rax, 4
    jmp .exit

.maybe_exec:
    cmp byte [exec_after], 1
    jne .success
    call execute_binary
    test rax, rax
    jz .success
    lea rdi, [rel exec_error_msg]
    call print_error
    mov rax, 1
    jmp .exit

.success:
    xor rax, rax
    jmp .exit

.multiple_inputs:
    lea rdi, [rel multiple_inputs_msg]
    call print_error
    mov rax, 1
    jmp .exit

.invalid_flag:
    lea rdi, [rel invalid_flag_msg]
    call print_error
    mov rax, 1
    jmp .exit

.invalid_combo:
    lea rdi, [rel flag_combo_msg]
    call print_error
    mov rax, 1

.exit:
    pop rbp
    ret

read_file:
    push rbp
    mov rbp, rsp
    push r12
    push r14
    push r15
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

    cmp rax, 16383
    jg .error
    
    mov rdi, [file_fd]
    xor rsi, rsi
    xor rdx, rdx
    mov rax, 8
    syscall

    xor r12, r12

.read_loop:
    cmp r12, [source_len]
    jge .read_done

    mov rdi, [file_fd]
    mov rsi, r14
    add rsi, r12
    mov rdx, [source_len]
    sub rdx, r12
    mov rax, 0
    syscall
    cmp rax, 0
    jle .read_error

    add r12, rax
    jmp .read_loop

.read_done:
    mov [source_len], r12
    mov byte [r14 + r12], 0

    mov rdi, [file_fd]
    mov rax, 3
    syscall

    xor rax, rax
    jmp .exit

.read_error:
    mov rdi, [file_fd]
    mov rax, 3
    syscall
    jmp .error

.error:
    mov rax, 5

.exit:
    pop r15
    pop r14
    pop r12
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

    mov rdi, [asm_file]
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

.do_assemble:
    ; Build nasm command: nasm -f elf64 <asm_file> -o <obj_file>
    mov rdi, nasm_cmd_buf
    mov rsi, 512
    mov rdx, nasm_fmt
    mov rcx, [asm_file]
    mov r8, [obj_file]
    xor eax, eax
    call snprintf
    cmp rax, 0
    jl .error
    cmp rax, 511
    jge .error

    mov rdi, nasm_cmd_buf
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

.do_link:
    ; Build ld command: ld -o <output> <obj_file>
    mov rdi, ld_cmd_buf
    mov rsi, 512
    mov rdx, ld_fmt
    mov rcx, [output_file]
    mov r8, [obj_file]
    xor eax, eax
    call snprintf
    cmp rax, 0
    jl .error
    cmp rax, 511
    jge .error

    mov rdi, ld_cmd_buf
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
    mov [output_file], rax

.do_exec:
    mov rdi, exec_cmd_buf
    mov rsi, 512
    mov rdx, exec_fmt
    mov rcx, [output_file]
    xor eax, eax
    call snprintf
    cmp rax, 0
    jl .error
    cmp rax, 511
    jge .error

    mov rdi, exec_cmd_buf
    call system
    test rax, rax
    jnz .error

    xor rax, rax

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
    push rbp
    mov rbp, rsp
    push rbx
    mov rbx, rdi

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
