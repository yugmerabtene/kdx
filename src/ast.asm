; KodPix Compiler - AST Module
; x86-64 NASM Assembly
; Abstract Syntax Tree for KodPix source code

section .data
    ; Node type constants
    NODE_PROGRAM    equ 0
    NODE_CLASS      equ 1
    NODE_FUNCTION   equ 2
    NODE_PARAM      equ 3
    NODE_BLOCK      equ 4
    NODE_IF         equ 5
    NODE_WHILE      equ 6
    NODE_FOR        equ 7
    NODE_RETURN     equ 8
    NODE_BREAK      equ 9
    NODE_CONTINUE   equ 10
    NODE_LET        equ 11
    NODE_ASSIGN     equ 12
    NODE_BINARY     equ 13
    NODE_UNARY      equ 14
    NODE_CALL       equ 15
    NODE_NEW        equ 16
    NODE_MEMBER     equ 17
    NODE_IDENT      equ 18
    NODE_NUMBER     equ 19
    NODE_STRING     equ 20

    ; Node structure size (4 qwords = 32 bytes)
    NODE_SIZE       equ 32

    ; Field offsets
    OFFSET_TYPE     equ 0
    OFFSET_CHILD    equ 8
    OFFSET_SIBLING  equ 16
    OFFSET_DATA     equ 24

    ; Pool configuration
    POOL_CAPACITY   equ 2048

    ; Node type names for printing
    node_type_names:
        db 'PROGRAM',0
        db 'CLASS',0
        db 'FUNCTION',0
        db 'PARAM',0
        db 'BLOCK',0
        db 'IF',0
        db 'WHILE',0
        db 'FOR',0
        db 'RETURN',0
        db 'BREAK',0
        db 'CONTINUE',0
        db 'LET',0
        db 'ASSIGN',0
        db 'BINARY',0
        db 'UNARY',0
        db 'CALL',0
        db 'NEW',0
        db 'MEMBER',0
        db 'IDENT',0
        db 'NUMBER',0
        db 'STRING',0
        db 0

section .bss
    ; AST node pool
    ast_pool:       resb NODE_SIZE * POOL_CAPACITY
    ast_pool_end:   

    ; Pool management
    ast_pool_ptr:   resq 1
    ast_node_count: resq 1
    ast_capacity:   resq 1

    ; Print buffer
    print_buffer:   resb 1024
    print_pos:      resq 1

section .text
    global ast_init, ast_alloc, ast_add_child, ast_print
    global ast_free, ast_get_child, ast_get_sibling
    extern malloc, free, strlen, memcpy

; Initialize AST pool
ast_init:
    push rbp
    mov rbp, rsp
    
    lea rax, [ast_pool]
    mov qword [ast_pool_ptr], rax
    mov qword [ast_node_count], 0
    mov rax, POOL_CAPACITY
    mov qword [ast_capacity], rax
    
    pop rbp
    ret

; Allocate a new AST node
; Input: rdi = node type
; Output: rax = node pointer (0 on failure)
ast_alloc:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    
    mov r12, rdi                    ; Save node type
    
    ; Check if pool has space
    mov rax, [ast_pool_ptr]
    lea rbx, [ast_pool + NODE_SIZE * POOL_CAPACITY]
    cmp rax, rbx
    jge .failure
    
    ; Initialize node fields
    mov [rax + OFFSET_TYPE], r12   ; node_type
    mov qword [rax + OFFSET_CHILD], 0
    mov qword [rax + OFFSET_SIBLING], 0
    mov qword [rax + OFFSET_DATA], 0
    
    ; Advance pool pointer
    add qword [ast_pool_ptr], NODE_SIZE
    inc qword [ast_node_count]
    
    pop r12
    pop rbx
    pop rbp
    ret
    
.failure:
    xor rax, rax
    pop r12
    pop rbx
    pop rbp
    ret

; Add child node to parent
; Input: rdi = parent node, rsi = child node
; Output: rax = parent node
ast_add_child:
    push rbp
    mov rbp, rsp
    
    test rdi, rdi
    jz .done
    
    test rsi, rsi
    jz .done
    
    ; If parent has no children, set first child
    mov rax, [rdi + OFFSET_CHILD]
    test rax, rax
    jnz .has_children
    
    mov [rdi + OFFSET_CHILD], rsi
    jmp .done
    
.has_children:
    ; Find last sibling
    mov rax, [rdi + OFFSET_CHILD]
    
.find_last:
    mov rdx, [rax + OFFSET_SIBLING]
    test rdx, rdx
    jz .append
    mov rax, rdx
    jmp .find_last
    
.append:
    mov [rax + OFFSET_SIBLING], rsi
    
.done:
    mov rax, rdi
    pop rbp
    ret

; Get first child of node
; Input: rdi = node
; Output: rax = first child (0 if none)
ast_get_child:
    mov rax, [rdi + OFFSET_CHILD]
    ret

; Get next sibling of node
; Input: rdi = node
; Output: rax = next sibling (0 if none)
ast_get_sibling:
    mov rax, [rdi + OFFSET_SIBLING]
    ret

; Free AST pool (reset)
ast_free:
    push rbp
    mov rbp, rsp
    
    lea rax, [ast_pool]
    mov [ast_pool_ptr], rax
    mov qword [ast_node_count], 0
    
    pop rbp
    ret

; Set node data field
; Input: rdi = node, rsi = data value
ast_set_data:
    mov [rdi + OFFSET_DATA], rsi
    ret

; Get node data field
; Input: rdi = node
; Output: rax = data value
ast_get_data:
    mov rax, [rdi + OFFSET_DATA]
    ret

; Get node type
; Input: rdi = node
; Output: rax = node type
ast_get_type:
    mov rax, [rdi + OFFSET_TYPE]
    ret

; Debug print AST tree
; Input: rdi = root node, rsi = depth (indent level)
ast_print:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    
    mov r12, rdi                    ; root node
    mov r13, rsi                    ; depth
    
    test r12, r12
    jz .done
    
    ; Print indentation
    xor r14, r14
.print_indent:
    cmp r14, r13
    jge .print_node
    mov rax, 1
    call print_char
    inc r14
    jmp .print_indent
    
.print_node:
    ; Get and print node type name
    mov rdi, r12
    call get_type_name
    mov rbx, rax                    ; Save type name pointer
    
    ; Print type name
    mov rdi, rbx
    call print_string
    
    ; Print additional info based on node type
    mov rdi, r12
    call print_node_info
    
    ; Print newline
    mov rdi, 10
    call print_char
    
    ; Recursively print children
    mov rdi, [r12 + OFFSET_CHILD]
    test rdi, rdi
    jz .print_siblings
    
    inc r13                         ; Increase depth for children
    push r13
    push rbx
    call ast_print
    pop rbx
    pop r13
    dec r13
    
.print_siblings:
    ; Print siblings
    mov r12, [r12 + OFFSET_SIBLING]
    test r12, r12
    jnz .print_node
    
.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Get type name string for node type
; Input: rdi = node
; Output: rax = pointer to type name string
get_type_name:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    push rdx
    
    mov rax, [rdi + OFFSET_TYPE]
    lea rbx, [node_type_names]
    
    xor rcx, rcx
.find_name:
    cmp rcx, rax
    je .found
    
    ; Skip to next name
    mov rdi, rbx
    call strlen
    add rbx, rax
    inc rbx                         ; Skip null terminator
    inc rcx
    jmp .find_name
    
.found:
    mov rax, rbx
    
    pop rdx
    pop rcx
    pop rbx
    pop rbp
    ret

; Print type name by index
; Input: rdi = type index
; Output: rax = pointer to type name
get_type_name_by_index:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    
    mov rax, rdi
    lea rbx, [node_type_names]
    
    xor rcx, rcx
.find_loop:
    cmp rcx, rax
    je .found
    
    mov rdi, rbx
    call strlen
    add rbx, rax
    inc rbx
    inc rcx
    jmp .find_loop
    
.found:
    mov rax, rbx
    
    pop rcx
    pop rbx
    pop rbp
    ret

; Print additional info for a node type
; Input: rdi = node
print_node_info:
    push rbp
    mov rbp, rsp
    
    mov rax, [rdi + OFFSET_TYPE]
    
    cmp rax, NODE_IDENT
    je .ident
    
    cmp rax, NODE_NUMBER
    je .number
    
    cmp rax, NODE_STRING
    je .string
    
    cmp rax, NODE_BINARY
    je .binary
    
    cmp rax, NODE_UNARY
    je .unary
    
    jmp .done
    
.ident:
    mov rax, [rdi + OFFSET_DATA]
    test rax, rax
    jz .done
    
    push rdi
    mov rdi, 32                     ; ' '
    call print_char
    pop rdi
    
    mov rdi, [rdi + OFFSET_DATA]
    call print_string
    jmp .done
    
.number:
    mov rax, [rdi + OFFSET_DATA]
    test rax, rax
    jz .done
    
    push rdi
    mov rdi, 32                     ; ' '
    call print_char
    pop rdi
    
    mov rdi, [rdi + OFFSET_DATA]
    call print_number
    jmp .done
    
.string:
    mov rax, [rdi + OFFSET_DATA]
    test rax, rax
    jz .done
    
    push rdi
    mov rdi, 32                     ; ' '
    call print_char
    mov rdi, 34                     ; '"'
    call print_char
    pop rdi
    
    mov rdi, [rdi + OFFSET_DATA]
    call print_string
    
    mov rdi, 34                     ; '"'
    call print_char
    jmp .done
    
.binary:
    mov rax, [rdi + OFFSET_DATA]
    test rax, rax
    jz .done
    
    push rdi
    mov rdi, 32                     ; ' '
    mov rdi, 40                     ; '('
    call print_char
    pop rdi
    
    mov rdi, [rdi + OFFSET_DATA]
    call print_char
    
    mov rdi, 41                     ; ')'
    call print_char
    jmp .done
    
.unary:
    mov rax, [rdi + OFFSET_DATA]
    test rax, rax
    jz .done
    
    push rdi
    mov rdi, 32                     ; ' '
    mov rdi, 40                     ; '('
    call print_char
    pop rdi
    
    mov rdi, [rdi + OFFSET_DATA]
    call print_char
    
    mov rdi, 41                     ; ')'
    call print_char
    
.done:
    pop rbp
    ret

; Print character to stdout
; Input: rdi = character
print_char:
    push rax
    push rdi
    push rsi
    push rdx
    
    mov rax, 1                      ; sys_write
    mov rdi, 1                      ; stdout
    lea rsi, [print_buffer]
    mov [rsi], dil
    mov rdx, 1                      ; length = 1
    syscall
    
    pop rdx
    pop rsi
    pop rdi
    pop rax
    ret

; Print string to stdout
; Input: rdi = string pointer
print_string:
    push rbp
    mov rbp, rsp
    push rbx
    push rdx
    
    mov rbx, rdi
    call strlen
    mov rdx, rax
    
    mov rax, 1                      ; sys_write
    mov rdi, 1                      ; stdout
    mov rsi, rbx
    syscall
    
    pop rdx
    pop rbx
    pop rbp
    ret

; Print number to stdout
; Input: rdi = number
print_number:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    
    mov r12, rdi
    mov r13, 0                      ; digit count
    mov rbx, 10
    
    test r12, r12
    jnz .convert
    
    mov rdi, 48                     ; '0'
    call print_char
    jmp .done
    
.convert:
    push rax
    mov rax, r12
    xor rdx, rdx
    div rbx
    mov r12, rax
    
    add dl, 48                      ; Convert to ASCII
    push rdx
    inc r13
    
    test r12, r12
    jnz .convert
    pop rax
    
.print_digits:
    mov rdi, [rsp]
    call print_char
    dec r13
    jnz .print_digits
    
    jmp .skip_push
    
.done:
    pop rax
    jmp .skip_push
    
.skip_push:
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Count children of a node
; Input: rdi = node
; Output: rax = child count
ast_child_count:
    push rbp
    mov rbp, rsp
    push rbx
    
    xor rax, rax
    mov rbx, [rdi + OFFSET_CHILD]
    test rbx, rbx
    jz .done
    
.count_loop:
    inc rax
    mov rbx, [rbx + OFFSET_SIBLING]
    test rbx, rbx
    jnz .count_loop
    
.done:
    pop rbx
    pop rbp
    ret

; Get child at index
; Input: rdi = parent node, rsi = index
; Output: rax = child node (0 if not found)
ast_get_child_at:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    
    mov rbx, [rdi + OFFSET_CHILD]
    mov rcx, rsi
    
    test rbx, rbx
    jz .not_found
    
    xor rax, rax
.index_loop:
    cmp rax, rcx
    je .found
    mov rbx, [rbx + OFFSET_SIBLING]
    test rbx, rbx
    jz .not_found
    inc rax
    jmp .index_loop
    
.found:
    mov rax, rbx
    jmp .done
    
.not_found:
    xor rax, rax
    
.done:
    pop rcx
    pop rbx
    pop rbp
    ret

; Remove child from parent
; Input: rdi = parent node, rsi = child node to remove
ast_remove_child:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    
    mov r12, rdi
    mov rbx, [r12 + OFFSET_CHILD]
    
    test rbx, rbx
    jz .done
    
    ; Check if first child
    cmp rbx, rsi
    jne .check_siblings
    
    mov rbx, [rsi + OFFSET_SIBLING]
    mov [r12 + OFFSET_CHILD], rbx
    jmp .done
    
.check_siblings:
    ; Find previous sibling
.find_prev:
    mov r12, rbx
    mov rbx, [rbx + OFFSET_SIBLING]
    test rbx, rbx
    jz .done
    
    cmp rbx, rsi
    jne .find_prev
    
    ; Remove from sibling chain
    mov rbx, [rsi + OFFSET_SIBLING]
    mov [r12 + OFFSET_SIBLING], rbx
    
.done:
    pop r12
    pop rbx
    pop rbp
    ret

; Clone an AST subtree
; Input: rdi = node to clone
; Output: rax = cloned node (0 on failure)
ast_clone:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    
    mov r12, rdi                    ; original node
    mov r14, rsi                    ; deep clone flag
    
    test r12, r12
    jz .done
    
    ; Allocate new node
    mov rdi, [r12 + OFFSET_TYPE]
    call ast_alloc
    mov r13, rax                    ; cloned node
    
    test r13, r13
    jz .done
    
    ; Copy data field
    mov rax, [r12 + OFFSET_DATA]
    mov [r13 + OFFSET_DATA], rax
    
    ; Clone children if deep
    test r14, r14
    jz .clone_siblings
    
    mov rdi, [r12 + OFFSET_CHILD]
    test rdi, rdi
    jz .clone_siblings
    
    push r13
    call ast_clone
    pop r13
    mov [r13 + OFFSET_CHILD], rax
    
.clone_siblings:
    ; Clone siblings
    mov r12, [r12 + OFFSET_SIBLING]
    test r12, r12
    jz .done
    
    push r13
    mov rdi, r12
    mov rsi, r14
    call ast_clone
    pop r13
    mov [r13 + OFFSET_SIBLING], rax
    
    mov rax, r13
    
.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Get pool statistics
; Output: rax = node count, rdx = capacity
ast_stats:
    mov rax, [ast_node_count]
    mov rdx, [ast_capacity]
    ret

; Check if pool is empty
; Output: rax = 1 if empty, 0 otherwise
ast_is_empty:
    mov rax, [ast_node_count]
    test rax, rax
    setz al
    movzx rax, al
    ret

; Check if pool is full
; Output: rax = 1 if full, 0 otherwise
ast_is_full:
    mov rax, [ast_node_count]
    cmp rax, [ast_capacity]
    setge al
    movzx rax, al
    ret
