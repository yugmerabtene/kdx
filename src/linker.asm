; KodPix Compiler - Linker Module
; x86-64 NASM Assembly - Links object files into ELF binary

section .data
    ERR_LINK_SUCCESS       equ 0
    ERR_LINK_MISSING_SYM   equ 10
    ERR_LINK_DUPLICATE_SYM equ 11
    ERR_LINK_INVALID_OBJ   equ 12
    ERR_LINK_OUT_OF_MEMORY equ 13
    ERR_LINK_FILE_IO       equ 14
    MAX_OBJECT_FILES       equ 32
    MAX_SECTIONS           equ 16
    MAX_SYMBOLS            equ 4096
    ELF_MAGIC              equ 0x464C457F
    ELF_CLASS_64BIT        equ 2
    ELF_DATA_LE            equ 1
    ELF_TYPE_EXEC          equ 2
    ELF_MACHINE_X86_64     equ 62
    SHT_PROGBITS           equ 1
    SHT_SYMTAB             equ 2
    STB_GLOBAL             equ 1
    PT_LOAD                equ 1
    R_X86_64_64            equ 1
    R_X86_64_PC32          equ 2

section .bss
    linker_state:
        .initialized:      resq 1
        .output_path:       resq 1
        .object_files:      resq MAX_OBJECT_FILES
        .object_count:     resq 1
        .section_count:    resq 1
        .symbol_count:     resq 1
        .error_code:       resq 1
        .error_message:    resb 256
    section_entries:       resb 512
    symbol_entries:       resb 16384
    output_buffer:        resb 262144
    output_size:          resq 1
    file_buffer:          resb 262144
    file_size:            resq 1

section .text
    global linker_init, linker_add_file, linker_set_output
    global linker_link, linker_cleanup, linker_get_error
    extern malloc, free, memset, memcpy, fopen, fclose, fread, fwrite

linker_init:
    push rbp
    mov rbp, rsp
    mov qword [linker_state.initialized], 1
    xor rax, rax
    mov [linker_state.object_count], rax
    mov [linker_state.section_count], rax
    mov [linker_state.symbol_count], rax
    mov [linker_state.error_code], rax
    mov [linker_state.output_path], rax
    pop rbp
    ret

linker_add_file:
    push rbp
    mov rbp, rsp
    mov r12, rdi
    cmp qword [linker_state.object_count], MAX_OBJECT_FILES
    jge .err_mem
    mov r13, [linker_state.object_count]
    imul r13, r13, 8
    lea r14, [linker_state.object_files]
    add r14, r13
    mov [r14], r12
    call read_object_file
    test rax, rax
    jnz .err
    inc qword [linker_state.object_count]
    xor rax, rax
    jmp .done
.err_mem:
    mov qword [linker_state.error_code], ERR_LINK_OUT_OF_MEMORY
    mov rax, 1
    jmp .done
.err:
    mov qword [linker_state.error_code], ERR_LINK_FILE_IO
    pop rbp
    ret
.done:
    pop rbp
    ret

linker_set_output:
    mov [linker_state.output_path], rdi
    ret

linker_cleanup:
    push rbp
    mov rbp, rsp
    xor rax, rax
    mov [linker_state.initialized], rax
    mov [linker_state.object_count], rax
    pop rbp
    ret

linker_get_error:
    mov rax, [linker_state.error_code]
    lea rdx, [linker_state.error_message]
    ret

read_object_file:
    push rbp
    mov rbp, rsp
    push r12
    mov r12, rdi
    lea rdi, [file_buffer]
    mov rsi, 1048576
    xor rdx, rdx
    call fopen
    test rax, rax
    jz .error
    mov r13, rax
    mov qword [file_buffer], rax
    mov rdi, rax
    lea rsi, [file_buffer + 8]
    mov rdx, 1048576
    call fread
    mov [file_size], rax
    mov rdi, r13
    call fclose
    mov rdi, [file_buffer + 8]
    call validate_elf
    test rax, rax
    jz .invalid
    call parse_elf_sections
    call parse_elf_symbols
    xor rax, rax
    jmp .done
.error:
    mov qword [linker_state.error_code], ERR_LINK_FILE_IO
    jmp .done
.invalid:
    mov qword [linker_state.error_code], ERR_LINK_INVALID_OBJ
.done:
    pop r12
    pop rbp
    ret

validate_elf:
    mov eax, [rdi]
    cmp eax, ELF_MAGIC
    jne .invalid
    movzx eax, byte [rdi + 4]
    cmp eax, ELF_CLASS_64BIT
    jne .invalid
    movzx eax, byte [rdi + 5]
    cmp eax, ELF_DATA_LE
    jne .invalid
    movzx eax, word [rdi + 16]
    cmp ax, ELF_MACHINE_X86_64
    jne .invalid
    mov rax, 1
    ret
.invalid:
    xor rax, rax
    ret

parse_elf_sections:
    push rbp
    mov rbp, rsp
    mov r12, [file_buffer + 8]
    movzx r13, word [r12 + 62]
    movzx r14, word [r12 + 58]
    mov r15, [r12 + 40]
    add r15, r12
    xor rbx, rbx
.loop:
    cmp rbx, r13
    jge .done
    movzx eax, word [r15 + 4]
    cmp eax, SHT_PROGBITS
    jne .next
    mov rax, [linker_state.section_count]
    imul rax, rax, 32
    lea rcx, [section_entries]
    add rcx, rax
    mov [rcx], rbx
    movzx eax, word [r15 + 0]
    mov [rcx + 2], ax
    mov rax, [r15 + 24]
    mov [rcx + 8], rax
    mov rax, [r15 + 32]
    mov [rcx + 16], rax
    mov rax, [r15 + 40]
    mov [rcx + 24], rax
    inc qword [linker_state.section_count]
.next:
    inc rbx
    add r15, r14
    jmp .loop
.done:
    pop rbp
    ret

parse_elf_symbols:
    push rbp
    mov rbp, rsp
    mov r12, [file_buffer + 8]
    movzx r13, word [r12 + 62]
    movzx r14, word [r12 + 58]
    mov r15, [r12 + 40]
    add r15, r12
    xor rbx, rbx
.stab_loop:
    cmp rbx, r13
    jge .done
    movzx eax, word [r15 + 4]
    cmp eax, SHT_SYMTAB
    jne .next_s
    mov rdi, [r15 + 24]
    add rdi, r12
    movzx eax, word [r15 + 58]
    xor rcx, rcx
.sym_loop:
    cmp rcx, rax
    jge .next_s
    movzx r8d, byte [rdi + 4]
    cmp r8b, STB_GLOBAL
    jne .next_sym
    mov rax, [linker_state.symbol_count]
    imul rax, rax, 16
    lea rsi, [symbol_entries]
    add rsi, rax
    movzx eax, word [rdi + 8]
    mov [rsi], ax
    mov rax, [rdi + 0]
    mov [rsi + 8], rax
    inc qword [linker_state.symbol_count]
.next_sym:
    inc rcx
    add rdi, r13
    jmp .sym_loop
.next_s:
    inc rbx
    add r15, r14
    jmp .stab_loop
.done:
    pop rbp
    ret

resolve_symbols:
    push rbp
    mov rbp, rsp
    push r12
    xor r12, r12
.loop:
    cmp r12, MAX_SYMBOLS
    jge .done
    mov rax, r12
    imul rax, rax, 16
    lea r13, [symbol_entries]
    add r13, rax
    movzx eax, word [r13]
    test eax, eax
    jz .next
    mov rax, [r13 + 8]
    test rax, rax
    jz .next
    movzx eax, word [r13]
    mov rdi, rax
    call lookup_symbol
    test r14, r14
    jnz .duplicate
.next:
    inc r12
    jmp .loop
.duplicate:
    mov qword [linker_state.error_code], ERR_LINK_DUPLICATE_SYM
.done:
    pop r12
    pop rbp
    ret

lookup_symbol:
    xor r14, r14
    mov rax, [linker_state.symbol_count]
    test rax, rax
    jz .not_found
    xor r13, r13
.loop:
    cmp r13, rax
    jge .not_found
    mov rcx, r13
    imul rcx, rcx, 16
    lea rdx, [symbol_entries]
    add rdx, rcx
    movzx edx, word [rdx]
    cmp dx, [r13]
    je .found
    inc r13
    jmp .loop
.found:
    mov r14, 1
    ret
.not_found:
    xor r14, r14
    ret

merge_sections:
    push rbp
    mov rbp, rsp
    xor r12, r12
    mov r13, [linker_state.section_count]
.loop:
    cmp r12, r13
    jge .done
    mov rax, r12
    imul rax, rax, 32
    lea r14, [section_entries]
    add r14, rax
    movzx eax, word [r14 + 2]
    cmp eax, 1
    je .text_sec
    cmp eax, 2
    je .data_sec
    jmp .next
.text_sec:
    mov rax, [r14 + 16]
    jmp .next
.data_sec:
    mov rax, [r14 + 16]
.next:
    inc r12
    jmp .loop
.done:
    pop rbp
    ret

linker_link:
    push rbp
    mov rbp, rsp
    cmp qword [linker_state.initialized], 0
    je .err_init
    cmp qword [linker_state.object_count], 0
    je .err_no_files
    cmp qword [linker_state.output_path], 0
    je .err_no_output
    call resolve_symbols
    cmp qword [linker_state.error_code], ERR_LINK_SUCCESS
    jne .err_resolve
    call merge_sections
    call build_elf_binary
    xor rax, rax
    jmp .done
.err_init:
.err_no_files:
.err_no_output:
    mov qword [linker_state.error_code], ERR_LINK_INVALID_OBJ
    jmp .err_exit
.err_resolve:
.err_exit:
    mov rax, 1
.done:
    pop rbp
    ret

build_elf_binary:
    push rbp
    mov rbp, rsp
    push r12
    lea rdi, [output_buffer]
    mov rsi, 1048576
    xor rax, rax
    call memset
    call write_elf_header
    call write_program_headers
    call write_sections
    call write_output_file
    pop r12
    pop rbp
    ret

write_elf_header:
    mov dword [output_buffer + 0], ELF_MAGIC
    mov byte [output_buffer + 4], ELF_CLASS_64BIT
    mov byte [output_buffer + 5], ELF_DATA_LE
    mov byte [output_buffer + 6], 1
    mov byte [output_buffer + 7], 0
    mov word [output_buffer + 16], ELF_TYPE_EXEC
    mov word [output_buffer + 18], ELF_MACHINE_X86_64
    mov dword [output_buffer + 20], 1
    mov qword [output_buffer + 32], 64
    mov qword [output_buffer + 40], 56
    mov qword [output_buffer + 48], 0
    mov qword [output_buffer + 56], 0
    ret

write_program_headers:
    lea rdi, [output_buffer + 64]
    mov rsi, 56
    xor rax, rax
    call memset
    mov dword [output_buffer + 64], PT_LOAD
    mov dword [output_buffer + 68], 5
    mov qword [output_buffer + 72], 0
    mov qword [output_buffer + 80], 4096
    mov qword [output_buffer + 88], 4096
    mov qword [output_buffer + 96], 1048576
    mov qword [output_buffer + 104], 1048576
    mov qword [output_buffer + 112], 4096
    ret

write_sections:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    push r15
    mov r12, [linker_state.section_count]
    test r12, r12
    jz .done
    xor r13, r13
    lea r14, [output_buffer + 128]
    mov [output_size], r14
.loop:
    cmp r13, r12
    jge .done
    mov rax, r13
    imul rax, rax, 32
    lea r15, [section_entries]
    add r15, rax
    mov rax, [r15 + 16]
    test rax, rax
    jz .next
    mov rcx, [r15 + 24]
    mov rdi, [r15 + 8]
    add rdi, [file_buffer + 8]
    mov rsi, [output_size]
    call memcpy
    mov rax, [r15 + 16]
    add [output_size], rax
.next:
    inc r13
    jmp .loop
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

write_output_file:
    push rbp
    mov rbp, rsp
    push r12
    mov r12, [linker_state.output_path]
    lea rdi, [r12]
    mov rsi, 1
    call fopen
    test rax, rax
    jz .error
    mov r13, rax
    mov rdi, r13
    lea rsi, [output_buffer]
    mov rdx, [output_size]
    call fwrite
    mov rdi, r13
    call fclose
    xor rax, rax
    jmp .done
.error:
    mov qword [linker_state.error_code], ERR_LINK_FILE_IO
    mov rax, 1
.done:
    pop r12
    pop rbp
    ret

calculate_total_size:
    push rbp
    mov rbp, rsp
    xor rax, rax
    mov rcx, [linker_state.section_count]
    test rcx, rcx
    jz .done
    xor r8, r8
.loop:
    cmp r8, rcx
    jge .done
    mov rdi, r8
    imul rdi, rdi, 32
    lea rsi, [section_entries + rdi]
    add rax, [rsi + 16]
    inc r8
    jmp .loop
.done:
    pop rbp
    ret

align_value:
    push rbp
    mov rbp, rsp
    mov rax, rdi
    mov rcx, rsi
    dec rcx
    add rax, rcx
    not rcx
    and rax, rcx
    pop rbp
    ret

update_relocation:
    push rbp
    mov rbp, rsp
    mov rax, [linker_state.section_count]
    imul rax, rax, 24
    lea rcx, [section_entries]
    add rcx, rax
    mov [rcx + 0], rdi
    mov [rcx + 8], rsi
    mov [rcx + 16], rdx
    inc qword [linker_state.section_count]
    pop rbp
    ret

get_section_by_type:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    mov r12, rdi
    mov r13, [linker_state.section_count]
    xor r14, r14
.loop:
    cmp r14, r13
    jge .not_found
    mov rdi, r14
    imul rdi, rdi, 32
    lea rdi, [section_entries + rdi]
    movzx eax, word [rdi + 2]
    cmp eax, r12d
    je .found
    inc r14
    jmp .loop
.found:
    mov rax, r14
    imul rax, rax, 32
    lea rax, [section_entries + rax]
    jmp .done
.not_found:
    xor rax, rax
.done:
    pop r13
    pop r12
    pop rbp
    ret
