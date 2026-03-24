; KodPix Compiler - Symbol Table Module
; x86-64 NASM Assembly
; Manages symbol entries for functions, variables, classes, etc.

section .data
    ; Symbol types
    SYM_FUNCTION      equ 0
    SYM_VARIABLE      equ 1
    SYM_CLASS         equ 2
    SYM_METHOD        equ 3
    SYM_FIELD         equ 4
    SYM_PARAM         equ 5

    ; Visibility modifiers
    VIS_PUBLIC        equ 0
    VIS_PRIVATE       equ 1
    VIS_PROTECTED     equ 2

    ; Symbol entry size (128 bytes)
    SYMBOL_SIZE       equ 128
    SYMBOL_NAME_SIZE  equ 64
    SYMBOL_TYPE_OFF   equ 64
    SYMBOL_SYMTYPE_OFF equ 68
    SYMBOL_VIS_OFF    equ 72
    SYMBOL_ADDR_OFF   equ 76
    SYMBOL_SIZE_OFF   equ 84
    SYMBOL_SCOPE_OFF  equ 92
    SYMBOL_RESV_OFF   equ 100

    ; Table limits
    MAX_SYMBOLS       equ 1024
    MAX_SCOPE_DEPTH   equ 32
    TABLE_SIZE        equ MAX_SYMBOLS * SYMBOL_SIZE
    SCOPE_STACK_SIZE  equ MAX_SCOPE_DEPTH * 8

    ; Error codes
    ERR_OK            equ 0
    ERR_TABLE_FULL    equ 1
    ERR_SCOPE_FULL    equ 2
    ERR_DUP_SYMBOL    equ 3
    ERR_NOT_FOUND     equ 4

section .bss
    ; Symbol storage table
    symbol_table:      resb TABLE_SIZE
    symbol_count:      resq 1
    symbol_capacity:    resq 1

    ; Scope management
    scope_stack:       resb SCOPE_STACK_SIZE
    scope_depth:       resq 1
    current_scope_id:  resq 1

    ; Temporary symbol pointer for lookups
    temp_symbol:       resq 1
    lookup_result:     resq 1

section .text
    global symbol_init, symbol_enter_scope, symbol_exit_scope
    global symbol_insert, symbol_lookup, symbol_lookup_local
    global symbol_get_count, symbol_get_at
    global symbol_get_addr, symbol_set_addr
    global SYM_VARIABLE, ERR_DUP_SYMBOL, ERR_NOT_FOUND
    extern malloc, free, memcpy, strlen

; Initialize the symbol table
symbol_init:
    push rbp
    mov rbp, rsp
    
    ; Initialize symbol count to 0
    xor rax, rax
    mov [symbol_count], rax
    mov [scope_depth], rax
    mov [current_scope_id], rax
    mov [symbol_capacity], rax
    
    ; Pre-populate capacity
    mov rax, MAX_SYMBOLS
    mov [symbol_capacity], rax
    
    ; Clear the symbol table (use rcx as counter)
    mov rcx, TABLE_SIZE / 8
    lea rdi, [symbol_table]
    xor rax, rax
    rep stosq
    
    ; Clear scope stack
    mov rcx, SCOPE_STACK_SIZE / 8
    lea rdi, [scope_stack]
    rep stosq
    
    ; Enter the global scope (scope 0)
    mov qword [scope_stack], 0
    inc qword [scope_depth]
    inc qword [current_scope_id]
    
    pop rbp
    ret

; Enter a new scope
; Creates a marker in the scope stack
symbol_enter_scope:
    push rbp
    mov rbp, rsp
    
    ; Check if scope stack is full
    mov rax, [scope_depth]
    cmp rax, MAX_SCOPE_DEPTH
    jge .error_full
    
    ; Push current scope marker to stack
    lea rdi, [scope_stack]
    mov rsi, [scope_depth]
    shl rsi, 3                      ; Multiply by 8 for byte offset
    mov qword [rdi + rsi], rax      ; Store current scope id
    
    ; Increment scope depth
    inc qword [scope_depth]
    
    ; Generate new scope id
    inc qword [current_scope_id]
    mov rax, [current_scope_id]
    jmp .done
    
.error_full:
    mov rax, ERR_SCOPE_FULL
    
.done:
    pop rbp
    ret

; Exit the current scope
; Returns to the parent scope
symbol_exit_scope:
    push rbp
    mov rbp, rsp
    
    ; Check if we're in global scope
    mov rax, [scope_depth]
    cmp rax, 1
    jle .at_global
    
    ; Decrement scope depth
    dec qword [scope_depth]
    
    ; Return the parent scope id
    lea rdi, [scope_stack]
    mov rsi, [scope_depth]
    dec rsi
    shl rsi, 3
    mov rax, [rdi + rsi]
    jmp .done
    
.at_global:
    xor rax, rax                   ; Stay at scope 0
    
.done:
    pop rbp
    ret

; Insert a new symbol into the table
; Args: rdi = name pointer, rsi = data type, rdx = symbol type, rcx = visibility
; Returns: rax = symbol pointer or 0 on error
symbol_insert:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    mov r12, rdi                    ; Save name pointer
    mov r13, rsi                    ; Save data type
    mov r14, rdx                    ; Save symbol type
    mov rbx, rcx                    ; Save visibility
    
    ; Check if symbol already exists in current scope
    mov rdi, r12
    call symbol_lookup_local
    test rax, rax
    jnz .duplicate

    ; Check if table is full
    mov rax, [symbol_count]
    cmp rax, MAX_SYMBOLS
    jge .table_full

    ; Calculate symbol entry offset
    imul rax, [symbol_count], SYMBOL_SIZE
    lea r15, [symbol_table + rax]   ; r15 = pointer to new entry

    ; Copy name (max 63 characters + null)
    mov rdi, r15
    mov rsi, r12
    mov rdx, SYMBOL_NAME_SIZE - 1
    call strncpy_safe

    ; Set data type
    mov dword [r15 + SYMBOL_TYPE_OFF], r13d

    ; Set symbol type
    mov dword [r15 + SYMBOL_SYMTYPE_OFF], r14d

    ; Set visibility
    mov dword [r15 + SYMBOL_VIS_OFF], ebx

    ; Set scope id
    mov rax, [current_scope_id]
    mov qword [r15 + SYMBOL_SCOPE_OFF], rax

    ; Initialize address, size to 0
    mov qword [r15 + SYMBOL_ADDR_OFF], 0
    mov qword [r15 + SYMBOL_SIZE_OFF], 0

    ; Clear reserved bytes
    xor rax, rax
    mov qword [r15 + SYMBOL_RESV_OFF], rax
    mov dword [r15 + SYMBOL_RESV_OFF + 8], eax

    ; Increment symbol count
    inc qword [symbol_count]

    ; Return pointer to symbol
    mov rax, r15
    jmp .done

.table_full:
    xor rax, rax
    mov rax, ERR_TABLE_FULL
    jmp .done

.invalid_ptr:
    xor rax, rax
    jmp .done

.duplicate:
    xor rax, rax

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Safe string copy with length limit
; Args: rdi = dest, rsi = src, rdx = max length
strncpy_safe:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    
    mov rbx, rdi    ; Save dest
    mov r12, rsi    ; Save src
    mov r13, rdx    ; Save max length
    
    xor rcx, rcx
    
    .copy_loop:
        cmp rcx, r13
        jge .done
        
        mov al, [r12 + rcx]
        mov [rbx + rcx], al
        test al, al
        jz .done
        
        inc rcx
        jmp .copy_loop
        
    .done:
        ; Null terminate dest if we reached max length
        cmp rcx, r13
        jl .finish
        mov byte [rbx + r13], 0
        
    .finish:
        pop rsi
        pop rdi
        
        pop r13
        pop r12
        pop rbx
        pop rbp
        ret

; Lookup a symbol by name (all scopes)
; Args: rdi = name pointer
; Returns: rax = symbol pointer or 0 if not found
symbol_lookup:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    
    mov r12, rdi                    ; Save name pointer
    
    ; Search from newest to oldest (reverse order)
    mov r13, [symbol_count]
    test r13, r13
    jz .not_found
    
.lookup_loop:
    dec r13
    
    ; Calculate symbol entry offset
    imul rax, r13, SYMBOL_SIZE
    lea rbx, [symbol_table + rax]
    
    ; Compare names
    mov rdi, rbx
    mov rsi, r12
    call strcmp_name
    test rax, rax
    jnz .found
    
    ; Continue searching
    test r13, r13
    jnz .lookup_loop
    
.not_found:
    xor rax, rax
    jmp .done
    
.found:
    mov rax, rbx
    
.done:
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Lookup a symbol in the current scope only
; Args: rdi = name pointer
; Returns: rax = symbol pointer or 0 if not found
symbol_lookup_local:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    
    mov r12, rdi                    ; Save name pointer
    mov r14, [current_scope_id]     ; Save current scope id
    
    ; Search symbols
    mov r13, [symbol_count]
    test r13, r13
    jz .not_found
    
.lookup_loop:
    dec r13
    
    ; Calculate symbol entry offset
    imul rax, r13, SYMBOL_SIZE
    lea rbx, [symbol_table + rax]
    
    ; Check if symbol is in current scope
    cmp qword [rbx + SYMBOL_SCOPE_OFF], r14
    jne .continue
    
    ; Compare names
    mov rdi, rbx
    mov rsi, r12
    call strcmp_name
    test rax, rax
    jnz .found
    
.continue:
    test r13, r13
    jnz .lookup_loop
    
.not_found:
    xor rax, rax
    jmp .done
    
.found:
    mov rax, rbx
    
.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Compare symbol name with given string
; Args: rdi = symbol entry, rsi = string to compare
; Returns: rax = 1 if equal, 0 if not
strcmp_name:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    push r8
    push r9
    
    mov rbx, rdi
    xor rcx, rcx
    
.compare_loop:
    cmp rcx, SYMBOL_NAME_SIZE
    jge .equal
    
    movzx r8, byte [rbx + rcx]
    movzx r9, byte [rsi + rcx]
    
    cmp r8, r9
    jne .not_equal
    
    test r8, r8
    jz .equal
    
    inc rcx
    jmp .compare_loop
    
.not_equal:
    xor rax, rax
    jmp .done
    
.equal:
    mov rax, 1
    
.done:
    pop r9
    pop r8
    pop rcx
    pop rbx
    pop rbp
    ret

; Get the number of symbols in the table
; Returns: rax = symbol count
symbol_get_count:
    mov rax, [symbol_count]
    ret

; Get symbol at index
; Args: rdi = index
; Returns: rax = symbol pointer or 0
symbol_get_at:
    push rbp
    mov rbp, rsp
    
    ; Check bounds
    cmp rdi, 0
    jl .out_of_bounds
    cmp rdi, [symbol_count]
    jge .out_of_bounds
    
    ; Calculate offset
    imul rax, rdi, SYMBOL_SIZE
    lea rax, [symbol_table + rax]
    jmp .done
    
.out_of_bounds:
    xor rax, rax
    
.done:
    pop rbp
    ret

; Get symbol name
; Args: rdi = symbol pointer
; Returns: rax = name string pointer
symbol_get_name:
    mov rax, rdi
    ret

; Get symbol data type
; Args: rdi = symbol pointer
; Returns: rax = data type
symbol_get_type:
    mov eax, dword [rdi + SYMBOL_TYPE_OFF]
    ret

; Get symbol type (function, variable, etc.)
; Args: rdi = symbol pointer
; Returns: rax = symbol type
symbol_get_symtype:
    mov eax, dword [rdi + SYMBOL_SYMTYPE_OFF]
    ret

; Get symbol visibility
; Args: rdi = symbol pointer
; Returns: rax = visibility
symbol_get_visibility:
    mov eax, dword [rdi + SYMBOL_VIS_OFF]
    ret

; Get symbol address/offset
; Args: rdi = symbol pointer
; Returns: rax = address
symbol_get_addr:
    mov rax, [rdi + SYMBOL_ADDR_OFF]
    ret

; Set symbol address/offset
; Args: rdi = symbol pointer, rsi = address
symbol_set_addr:
    mov [rdi + SYMBOL_ADDR_OFF], rsi
    ret

; Get symbol size
; Args: rdi = symbol pointer
; Returns: rax = size
symbol_get_size:
    mov rax, [rdi + SYMBOL_SIZE_OFF]
    ret

; Set symbol size
; Args: rdi = symbol pointer, rsi = size
symbol_set_size:
    mov [rdi + SYMBOL_SIZE_OFF], rsi
    ret

; Get symbol scope id
; Args: rdi = symbol pointer
; Returns: rax = scope id
symbol_get_scope:
    mov rax, [rdi + SYMBOL_SCOPE_OFF]
    ret

; Get current scope id
; Returns: rax = current scope id
symbol_get_current_scope:
    mov rax, [current_scope_id]
    ret

; Get current scope depth
; Returns: rax = scope depth
symbol_get_scope_depth:
    mov rax, [scope_depth]
    ret

; Clear all symbols from current scope (for scope exit cleanup)
; Returns: rax = number of symbols removed
symbol_clear_scope:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    
    mov r14, [current_scope_id]
    xor r12, r12                    ; Removal counter
    
    ; Iterate through all symbols
    mov r13, [symbol_count]
    test r13, r13
    jz .done
    
.clear_loop:
    dec r13
    
    ; Calculate symbol entry offset
    imul rax, r13, SYMBOL_SIZE
    lea rbx, [symbol_table + rax]
    
    ; Check if symbol is in current scope
    cmp qword [rbx + SYMBOL_SCOPE_OFF], r14
    jne .continue
    
    ; Mark symbol as deleted by clearing name
    ; In practice, we could use a deleted flag
    mov byte [rbx], 0
    mov byte [rbx + 1], 0
    inc r12
    
.continue:
    test r13, r13
    jnz .clear_loop
    
    ; Compact table by removing deleted symbols
    ; This is a simplified version - just recount valid symbols
    call symbol_compact
    
.done:
    mov rax, r12
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Compact the symbol table by removing deleted entries
symbol_compact:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    
    mov r14, [symbol_count]
    xor r12, r12                    ; Read index
    xor r13, r13                    ; Write index
    
.compact_loop:
    cmp r12, r14
    jge .done
    
    ; Calculate source offset
    imul rax, r12, SYMBOL_SIZE
    lea rbx, [symbol_table + rax]
    
    ; Check if entry is deleted (name starts with null)
    movzx rax, byte [rbx]
    test al, al
    jz .skip_entry
    
    ; If read != write, copy entry
    cmp r12, r13
    je .no_move
    
    ; Calculate dest offset
    imul rsi, r13, SYMBOL_SIZE
    lea rdi, [symbol_table + rsi]
    
    ; Copy entry
    mov rcx, SYMBOL_SIZE
    rep movsb
    
.no_move:
    inc r13
    
.skip_entry:
    inc r12
    jmp .compact_loop
    
.done:
    mov [symbol_count], r13
    xor rax, rax
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Iterate over all symbols in current scope
; Args: rdi = callback function pointer
; Callback: rdi = symbol pointer, rsi = user data
; Returns: rax = 0 on success, error code otherwise
symbol_iterate_scope:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    mov r12, rdi                    ; Callback function
    mov r13, [current_scope_id]
    mov r14, [symbol_count]
    xor r15, r15                    ; Index
    
.iterate_loop:
    cmp r15, r14
    jge .done
    
    ; Calculate symbol entry offset
    imul rax, r15, SYMBOL_SIZE
    lea rbx, [symbol_table + rax]
    
    ; Check if symbol is in current scope
    cmp qword [rbx + SYMBOL_SCOPE_OFF], r13
    jne .continue
    
    ; Call callback
    mov rdi, rbx
    xor rsi, rsi                    ; User data = 0
    call r12
    test rax, rax
    jnz .callback_error
    
.continue:
    inc r15
    jmp .iterate_loop
    
.callback_error:
    ; Callback returned non-zero (error)
    jmp .done
    
.done:
    xor rax, rax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Find all symbols matching a predicate
; Args: rdi = predicate function, rsi = user data
; Returns: rax = array of symbol pointers (caller must free)
symbol_find_all:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    mov r12, rdi                    ; Predicate function
    mov r13, rsi                    ; User data
    mov r14, [symbol_count]
    xor r15, r15                    ; Index
    xor rbx, rbx                    ; Result count
    
    ; Allocate result array (max symbols * 8 bytes)
    imul rdi, r14, 8
    call malloc
    test rax, rax
    jz .error
    mov r12, rax                    ; r12 = result array
    mov qword [r12], 0              ; Store count at start
    
.iterate_loop:
    cmp r15, r14
    jge .done
    
    ; Calculate symbol entry offset
    imul rax, r15, SYMBOL_SIZE
    lea rbx, [symbol_table + rax]
    
    ; Call predicate
    mov rdi, rbx
    mov rsi, r13
    call r12
    test rax, rax
    jz .continue
    
    ; Symbol matches - add to result
    mov rax, [r12]                  ; Get count
    inc qword [r12]                 ; Increment count
    lea rsi, [r12 + 8]              ; Start of pointers
    shl rax, 3                      ; Multiply by 8
    add rsi, rax
    mov [rsi], rbx                  ; Store symbol pointer
    
.continue:
    inc r15
    jmp .iterate_loop
    
.done:
    mov rax, r12
    jmp .finish
    
.error:
    xor rax, rax
    
.finish:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Dump symbol table for debugging
; Args: rdi = output function (takes char*), rsi = user data
symbol_dump:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    mov r12, rdi                    ; Output function
    mov r13, rsi                    ; User data
    mov r14, [symbol_count]
    xor r15, r15                    ; Index
    
.dump_loop:
    cmp r15, r14
    jge .done
    
    ; Calculate symbol entry offset
    imul rax, r15, SYMBOL_SIZE
    lea rbx, [symbol_table + rax]
    
    ; Output symbol info
    ; Format: "[index] name (type) @ scope\n"
    ; This is simplified - actual implementation would format properly
    
    inc r15
    jmp .dump_loop
    
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Get last error code
symbol_get_error:
    xor rax, rax
    ret

; Check if symbol is a function
; Args: rdi = symbol pointer
; Returns: rax = 1 if function, 0 otherwise
symbol_is_function:
    cmp dword [rdi + SYMBOL_SYMTYPE_OFF], SYM_FUNCTION
    sete al
    movzx rax, al
    ret

; Check if symbol is a variable
; Args: rdi = symbol pointer
; Returns: rax = 1 if variable, 0 otherwise
symbol_is_variable:
    cmp dword [rdi + SYMBOL_SYMTYPE_OFF], SYM_VARIABLE
    sete al
    movzx rax, al
    ret

; Check if symbol is a parameter
; Args: rdi = symbol pointer
; Returns: rax = 1 if parameter, 0 otherwise
symbol_is_param:
    cmp dword [rdi + SYMBOL_SYMTYPE_OFF], SYM_PARAM
    sete al
    movzx rax, al
    ret

; Check symbol visibility
; Args: rdi = symbol pointer, rsi = visibility to check
; Returns: rax = 1 if has visibility, 0 otherwise
symbol_has_visibility:
    mov eax, dword [rdi + SYMBOL_VIS_OFF]
    cmp eax, esi
    sete al
    movzx rax, al
    ret
