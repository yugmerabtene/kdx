; KodPix Compiler - Optimizer Module
; x86-64 NASM Assembly
; Implements compiler optimizations for KodPix AST

section .data
    OPT_LEVEL_NONE   equ 0
    OPT_LEVEL_BASIC   equ 1
    OPT_LEVEL_FULL    equ 2
    OPT_PASSES_BASIC  equ 2
    OPT_PASSES_FULL   equ 4
    NODE_NUMBER       equ 19
    NODE_BINARY       equ 13
    NODE_UNARY        equ 14
    NODE_LET          equ 11
    NODE_ASSIGN       equ 12
    NODE_IDENT        equ 18
    NODE_IF           equ 5
    NODE_WHILE        equ 6
    NODE_FOR          equ 7
    NODE_BLOCK        equ 4
    NODE_SIZE         equ 32
    OFFSET_TYPE       equ 0
    OFFSET_CHILD      equ 8
    OFFSET_SIBLING    equ 16
    OFFSET_DATA       equ 24
    HASH_TABLE_SIZE   equ 128

section .bss
    opt_level:        resq 1
    opt_pass_count:   resq 1
    opt_changes:      resq 1
    const_count:      resq 1
    copy_count:       resq 1
    loop_depth:       resq 1
    const_keys:       resq HASH_TABLE_SIZE
    const_vals:       resq HASH_TABLE_SIZE
    copy_src:         resq HASH_TABLE_SIZE
    copy_dst:         resq HASH_TABLE_SIZE

section .text
    global optimizer_init, optimize, fold_constants, eliminate_dead_code
    global propagate_constants, reduce_strength, copy_propagation
    global loop_invariant_motion, get_opt_stats
    extern malloc, free, memset

optimizer_init:
    push rbp
    mov rbp, rsp
    mov [opt_level], rdi
    cmp rdi, OPT_LEVEL_BASIC
    je .basic
    cmp rdi, OPT_LEVEL_FULL
    je .full
    mov qword [opt_pass_count], 1
    jmp .init_tables
.basic:
    mov qword [opt_pass_count], OPT_PASSES_BASIC
    jmp .init_tables
.full:
    mov qword [opt_pass_count], OPT_PASSES_FULL
.init_tables:
    xor rax, rax
    mov [const_count], rax
    mov [copy_count], rax
    mov [loop_depth], rax
    mov [opt_changes], rax
    pop rbp
    ret

optimize:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    mov r12, rdi
    mov r13, [opt_pass_count]
    xor r14, r14
.pass_loop:
    cmp r14, r13
    jge .done_pass
    mov qword [opt_changes], 0
    mov rdi, r12
    call propagate_constants
    mov rdi, r12
    call fold_constants
    mov rdi, r12
    call eliminate_dead_code
    mov rdi, r12
    call copy_propagation
    mov rdi, r12
    call reduce_strength
    mov rdi, r12
    call loop_invariant_motion
    inc r14
    jmp .pass_loop
.done_pass:
    mov rax, r12
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

fold_constants:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    mov r12, rdi
    test r12, r12
    jz .ret
    mov rbx, [r12 + OFFSET_TYPE]
    cmp rbx, NODE_BINARY
    je .binary
    cmp rbx, NODE_UNARY
    je .unary
.children:
    mov rbx, [r12 + OFFSET_CHILD]
    test rbx, rbx
    jz .siblings
.child_loop:
    push rbx
    call fold_constants
    pop rbx
    mov rbx, [rbx + OFFSET_SIBLING]
    test rbx, rbx
    jnz .child_loop
.siblings:
    mov r12, [r12 + OFFSET_SIBLING]
    test r12, r12
    jnz .check_type
    jmp .ret
.check_type:
    mov rbx, [r12 + OFFSET_TYPE]
    jmp .children
.binary:
    mov rdi, [r12 + OFFSET_CHILD]
    call fold_constants
    mov rdi, [r12 + OFFSET_SIBLING]
    call fold_constants
    mov rdi, r12
    call eval_binary
    test rax, rax
    jz .children
    mov [r12 + OFFSET_TYPE], rax
    mov [r12 + OFFSET_CHILD], r8
    xor r9, r9
    mov [r12 + OFFSET_SIBLING], r9
    mov [r12 + OFFSET_DATA], rdx
    inc qword [opt_changes]
    jmp .siblings
.unary:
    mov rdi, [r12 + OFFSET_CHILD]
    call fold_constants
    mov rdi, r12
    call eval_unary
    test rax, rax
    jz .children
    mov [r12 + OFFSET_TYPE], rax
    xor r8, r8
    mov [r12 + OFFSET_CHILD], r8
    mov [r12 + OFFSET_DATA], rdx
    inc qword [opt_changes]
    jmp .siblings
.ret:
    pop r12
    pop rbx
    pop rbp
    ret

eval_binary:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    mov r12, rdi
    mov rdi, [r12 + OFFSET_CHILD]
    call get_const_value
    test rax, rax
    jz .bin_fail
    mov r13, rdx
    mov rdi, [r12 + OFFSET_SIBLING]
    call get_const_value
    test rax, rax
    jz .bin_fail
    mov r14, rdx
    movzx r15, byte [r12 + OFFSET_DATA]
    cmp r15b, '+'
    je .bin_add
    cmp r15b, '-'
    je .bin_sub
    cmp r15b, '*'
    je .bin_mul
    cmp r15b, '/'
    je .bin_div
    cmp r15b, '%'
    je .bin_mod
    jmp .bin_fail
.bin_add:
    mov rax, NODE_NUMBER
    mov rdx, r13
    add rdx, r14
    jmp .bin_ret
.bin_sub:
    mov rax, NODE_NUMBER
    mov rdx, r13
    sub rdx, r14
    jmp .bin_ret
.bin_mul:
    mov rax, NODE_NUMBER
    mov rdx, r13
    imul r14
    jmp .bin_ret
.bin_div:
    test r14, r14
    jz .bin_fail
    mov rax, NODE_NUMBER
    mov rdx, r13
    cqo
    idiv r14
    jmp .bin_ret
.bin_mod:
    test r14, r14
    jz .bin_fail
    mov rax, NODE_NUMBER
    mov rdx, r13
    cqo
    idiv r14
    mov rdx, rax
    mov rax, NODE_NUMBER
    jmp .bin_ret
.bin_fail:
    xor rax, rax
    xor rdx, rdx
.bin_ret:
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

get_const_value:
    push rbp
    mov rbp, rsp
    test rdi, rdi
    jz .const_no
    cmp dword [rdi + OFFSET_TYPE], NODE_NUMBER
    jne .const_no
    mov rax, 1
    mov rdx, [rdi + OFFSET_DATA]
    jmp .const_ret
.const_no:
    xor rax, rax
    xor rdx, rdx
.const_ret:
    pop rbp
    ret

eval_unary:
    push rbp
    mov rbp, rsp
    mov rbx, rdi
    mov rdi, [rbx + OFFSET_CHILD]
    call get_const_value
    test rax, rax
    jz .unary_fail
    movzx r8, byte [rbx + OFFSET_DATA]
    cmp r8b, '-'
    je .unary_neg
    cmp r8b, '!'
    je .unary_not
    jmp .unary_fail
.unary_neg:
    mov rax, NODE_NUMBER
    neg rdx
    jmp .unary_ret
.unary_not:
    mov rax, NODE_NUMBER
    cmp rdx, 0
    je .unary_false
    mov rdx, 0
    jmp .unary_ret
.unary_false:
    mov rdx, 1
.unary_ret:
    pop rbp
    ret
.unary_fail:
    xor rax, rax
    xor rdx, rdx
    pop rbp
    ret

eliminate_dead_code:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    mov r12, rdi
    test r12, r12
    jz .ret
    mov rbx, [r12 + OFFSET_TYPE]
    cmp rbx, NODE_IF
    je .if_node
    cmp rbx, NODE_WHILE
    je .while_node
.children:
    mov rbx, [r12 + OFFSET_CHILD]
    test rbx, rbx
    jz .siblings
.child_loop:
    push rbx
    call eliminate_dead_code
    pop rbx
    mov rbx, [rbx + OFFSET_SIBLING]
    test rbx, rbx
    jnz .child_loop
.siblings:
    mov r12, [r12 + OFFSET_SIBLING]
    test r12, r12
    jnz .check_type
    jmp .ret
.check_type:
    mov rbx, [r12 + OFFSET_TYPE]
    jmp .children
.if_node:
    mov rdi, [r12 + OFFSET_CHILD]
    call eval_bool_cond
    cmp rax, -1
    je .children
    test rax, rax
    jnz .keep_then
    mov qword [r12 + OFFSET_CHILD], 0
    inc qword [opt_changes]
    jmp .siblings
.keep_then:
    mov qword [r12 + OFFSET_SIBLING], 0
    inc qword [opt_changes]
    jmp .siblings
.while_node:
    mov rdi, [r12 + OFFSET_CHILD]
    call eval_bool_cond
    cmp rax, -1
    je .children
    test rax, rax
    jnz .children
    mov dword [r12 + OFFSET_TYPE], NODE_BLOCK
    mov qword [r12 + OFFSET_CHILD], 0
    mov qword [r12 + OFFSET_SIBLING], 0
    mov qword [r12 + OFFSET_DATA], 0
    inc qword [opt_changes]
    jmp .siblings
.ret:
    pop r12
    pop rbx
    pop rbp
    ret

eval_bool_cond:
    push rbp
    mov rbp, rsp
    test rdi, rdi
    jz .bool_unknown
    cmp dword [rdi + OFFSET_TYPE], NODE_NUMBER
    jne .bool_unknown
    mov rax, [rdi + OFFSET_DATA]
    test rax, rax
    jnz .bool_true
    xor rax, rax
    jmp .bool_ret
.bool_true:
    mov rax, 1
    jmp .bool_ret
.bool_unknown:
    mov rax, -1
.bool_ret:
    pop rbp
    ret

propagate_constants:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    mov r12, rdi
    test r12, r12
    jz .ret
    mov rbx, [r12 + OFFSET_TYPE]
    cmp rbx, NODE_LET
    je .let_node
    cmp rbx, NODE_ASSIGN
    je .assign_node
    cmp rbx, NODE_IDENT
    je .ident_node
.children:
    mov rbx, [r12 + OFFSET_CHILD]
    test rbx, rbx
    jz .siblings
.child_loop:
    push rbx
    call propagate_constants
    pop rbx
    mov rbx, [rbx + OFFSET_SIBLING]
    test rbx, rbx
    jnz .child_loop
.siblings:
    mov r12, [r12 + OFFSET_SIBLING]
    test r12, r12
    jnz .check_type
    jmp .ret
.check_type:
    mov rbx, [r12 + OFFSET_TYPE]
    jmp .children
.let_node:
    mov rdi, [r12 + OFFSET_CHILD]
    mov rsi, [r12 + OFFSET_SIBLING]
    call add_const_binding
    jmp .siblings
.assign_node:
    call add_copy_binding
    jmp .siblings
.ident_node:
    mov rdi, r12
    call try_replace_with_const
    jmp .siblings
.ret:
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

add_const_binding:
    test rdi, rdi
    jz .ret
    test rsi, rsi
    jz .ret
    cmp dword [rsi + OFFSET_TYPE], NODE_NUMBER
    jne .ret
    mov rax, [rdi + OFFSET_DATA]
    and rax, 127
    mov [const_keys + rax * 8], rdi
    mov [const_vals + rax * 8], rsi
    inc qword [const_count]
    inc qword [opt_changes]
.ret:
    ret

add_copy_binding:
    inc qword [copy_count]
    inc qword [opt_changes]
    ret

try_replace_with_const:
    test rdi, rdi
    jz .ret
    cmp dword [rdi + OFFSET_TYPE], NODE_IDENT
    jne .ret
    cmp qword [const_count], 0
    je .ret
    mov rax, [rdi + OFFSET_DATA]
    and rax, 127
    mov rbx, [const_keys + rax * 8]
    test rbx, rbx
    jz .ret
    mov rbx, [const_vals + rax * 8]
    test rbx, rbx
    jz .ret
    mov rax, [rbx + OFFSET_DATA]
    mov dword [rdi + OFFSET_TYPE], NODE_NUMBER
    mov [rdi + OFFSET_DATA], rax
    inc qword [opt_changes]
.ret:
    ret

copy_propagation:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    mov r12, rdi
    test r12, r12
    jz .ret
    cmp dword [r12 + OFFSET_TYPE], NODE_IDENT
    jne .children
    cmp qword [copy_count], 0
    je .children
    inc qword [opt_changes]
.children:
    mov rbx, [r12 + OFFSET_CHILD]
    test rbx, rbx
    jz .siblings
.child_loop:
    push rbx
    call copy_propagation
    pop rbx
    mov rbx, [rbx + OFFSET_SIBLING]
    test rbx, rbx
    jnz .child_loop
.siblings:
    mov r12, [r12 + OFFSET_SIBLING]
    test r12, r12
    jnz .check_type
    jmp .ret
.check_type:
    cmp dword [r12 + OFFSET_TYPE], NODE_IDENT
    jmp .children
.ret:
    pop r12
    pop rbx
    pop rbp
    ret

reduce_strength:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    mov r12, rdi
    test r12, r12
    jz .ret
    cmp dword [r12 + OFFSET_TYPE], NODE_BINARY
    jne .children
    movzx rbx, byte [r12 + OFFSET_DATA]
    cmp bl, '*'
    je .multiply
    cmp bl, '/'
    je .divide
.children:
    mov rbx, [r12 + OFFSET_CHILD]
    test rbx, rbx
    jz .siblings
.child_loop:
    push rbx
    call reduce_strength
    pop rbx
    mov rbx, [rbx + OFFSET_SIBLING]
    test rbx, rbx
    jnz .child_loop
.siblings:
    mov r12, [r12 + OFFSET_SIBLING]
    test r12, r12
    jnz .check_type
    jmp .ret
.check_type:
    cmp dword [r12 + OFFSET_TYPE], NODE_BINARY
    jmp .children
.multiply:
    mov rbx, [r12 + OFFSET_SIBLING]
    test rbx, rbx
    jz .children
    cmp dword [rbx + OFFSET_TYPE], NODE_NUMBER
    jne .children
    mov rax, [rbx + OFFSET_DATA]
    cmp rax, 2
    je .replace_mult
    cmp rax, 4
    je .replace_mult
    cmp rax, 8
    je .replace_mult
    jmp .children
.replace_mult:
    mov byte [r12 + OFFSET_DATA], '+'
    inc qword [opt_changes]
    jmp .children
.divide:
    mov rbx, [r12 + OFFSET_SIBLING]
    test rbx, rbx
    jz .children
    cmp dword [rbx + OFFSET_TYPE], NODE_NUMBER
    jne .children
    mov rax, [rbx + OFFSET_DATA]
    cmp rax, 2
    je .replace_div
    cmp rax, 4
    je .replace_div
    cmp rax, 8
    je .replace_div
    jmp .children
.replace_div:
    mov byte [r12 + OFFSET_DATA], '>'
    inc qword [opt_changes]
    jmp .children
.ret:
    pop r12
    pop rbx
    pop rbp
    ret

loop_invariant_motion:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    mov r12, rdi
    test r12, r12
    jz .ret
    mov rbx, [r12 + OFFSET_TYPE]
    cmp rbx, NODE_WHILE
    je .while_loop
    cmp rbx, NODE_FOR
    je .for_loop
    jmp .children
.while_loop:
    inc qword [loop_depth]
    mov rbx, [r12 + OFFSET_CHILD]
    test rbx, rbx
    jz .dec_depth
    cmp dword [rbx + OFFSET_TYPE], NODE_BLOCK
    jne .dec_depth
    call move_loop_invariants
.dec_depth:
    dec qword [loop_depth]
    jmp .children
.for_loop:
    inc qword [loop_depth]
    dec qword [loop_depth]
.children:
    mov rbx, [r12 + OFFSET_CHILD]
    test rbx, rbx
    jz .siblings
.child_loop:
    push rbx
    call loop_invariant_motion
    pop rbx
    mov rbx, [rbx + OFFSET_SIBLING]
    test rbx, rbx
    jnz .child_loop
.siblings:
    mov r12, [r12 + OFFSET_SIBLING]
    test r12, r12
    jnz .check_type
    jmp .ret
.check_type:
    mov rbx, [r12 + OFFSET_TYPE]
    jmp .children
.ret:
    pop r12
    pop rbx
    pop rbp
    ret

move_loop_invariants:
    inc qword [opt_changes]
    ret

get_opt_stats:
    mov rax, [opt_changes]
    mov rdx, [const_count]
    ret
