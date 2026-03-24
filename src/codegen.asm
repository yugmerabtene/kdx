; KodPix Compiler - Code Generator Module
; x86-64 NASM Assembly
; Generates optimized x86-64 NASM code from AST

section .data
    ; Output configuration
    OUTPUT_BUF_SIZE    equ 65536
    LABEL_BUF_SIZE    equ 256
    MAX_LOCALS        equ 64
    MAX_NESTING       equ 32

    ; Section headers
    section_text      db 'section .text',10,0
    section_data      db 'section .data',10,0
    section_bss       db 'section .bss',10,0
    global_prefix     db 'global ',0
    extern_prefix     db 'extern ',0
    newline           db 10,0

    ; Built-in externs
    builtins_externs:
        db 'malloc',0,'free',0,'memcpy',0,'strlen',0
        db 'puts',0,'printf',0,'scanf',0,'exit',0
        db 0

    ; Operator mappings
    op_add_str        db 'add rax, rbx',10,0
    op_sub_str        db 'sub rax, rbx',10,0
    op_mul_str        db 'imul rax, rbx',10,0
    op_div_str        db 'cqo',10,'idiv rbx',10,0
    op_mod_str        db 'cqo',10,'idiv rbx',10,'mov rax, rdx',10,0
    op_and_str        db 'and rax, rbx',10,0
    op_or_str         db 'or rax, rbx',10,0
    op_xor_str        db 'xor rax, rbx',10,0
    op_shl_str        db 'shl rax, cl',10,0
    op_shr_str        db 'shr rax, cl',10,0

    ; Type sizes
    TYPE_I8_SIZE      equ 1
    TYPE_I16_SIZE     equ 2
    TYPE_I32_SIZE     equ 4
    TYPE_I64_SIZE     equ 8
    TYPE_F32_SIZE     equ 4
    TYPE_F64_SIZE     equ 8
    TYPE_BOOL_SIZE    equ 1
    TYPE_PTR_SIZE     equ 8

; Default type
DEFAULT_TYPE_SIZE equ 8

; AST node header size
NODE_HEADER_SIZE equ 24



section .bss
    output_buffer     resb OUTPUT_BUF_SIZE
    output_pos        resq 1
    output_size       resq 1

    label_counter     resq 1
    label_buffer      resb LABEL_BUF_SIZE
    label_pool        resb 4096
    label_pool_pos    resq 1

    local_vars        resq MAX_LOCALS
    local_count       resq 1
    local_offset      resq 1
    tmp_stack_offset  resq 1

    loop_stack        resq MAX_NESTING
    loop_depth        resq 1

    current_func      resq 1
    current_func_end  resq 1
    func_return_type  resq 1

    ; Temporary labels
    temp_label_a      resb 64
    temp_label_b      resb 64

    ; String pool
    string_pool       resb 16384
    string_pool_pos   resq 1
    string_count      resq 1

section .text
    global codegen_init, codegen_program, codegen_class, codegen_function
    global codegen_statement, codegen_expression, codegen_binary_op
    global codegen_unary_op, codegen_call, codegen_new
    global codegen_emit_label, codegen_emit_instruction, codegen_get_output
    global codegen_emit_string, codegen_emit_number
    global get_child_at
extern malloc, free, memcpy, strlen, strcmp
extern symbol_lookup, symbol_lookup_local, symbol_get_addr, symbol_set_addr
extern ERR_DUP_SYMBOL, ERR_NOT_FOUND

;============================================================================
; INITIALIZATION
;============================================================================

codegen_init:
    push rbp
    mov rbp, rsp

    mov qword [output_pos], 0
    mov qword [output_size], 0
    mov qword [label_counter], 0
    mov qword [local_count], 0
    mov qword [local_offset], 0
    mov qword [loop_depth], 0
    mov qword [current_func], 0
    mov qword [current_func_end], 0
    mov qword [label_pool_pos], 0
    mov qword [string_pool_pos], 0
    mov qword [string_count], 0

    xor rax, rax
    pop rbp
    ret

codegen_get_output:
    mov rax, output_buffer
    mov rdx, [output_size]
    ret

;============================================================================
; MAIN PROGRAM GENERATION
;============================================================================

codegen_program:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi                    ; AST root node

    call emit_text_section
    call emit_externs
    
    ; Emit _start entry point
    call emit_start_entry
    
    mov qword [local_count], 0
    mov qword [local_offset], 0
    
    mov rdi, r12
    call get_child_count
    mov r14, rax                    ; child count
    
    xor r13, r13                    ; child index
    
    .process_child:
        cmp r13, r14
        jge .done
    
        mov rdi, r12
        mov rsi, r13
        call get_child_at
        mov r15, rax                    ; child node
    
        test r15, r15
        jz .next_child
    
        mov rdi, r15
        call get_node_type_value
        mov rbx, rax                    ; save node type in rbx
    
        cmp rbx, 3                      ; NODE_CLASS
        je .gen_class
        cmp rbx, 4                      ; NODE_FUNCTION
        je .gen_func
        
        ; Unknown node type, skip
        jmp .next_child
    
    .next_child:
        inc r13
        jmp .process_child
    
    .gen_class:
        mov rdi, r15                    ; class node
        call codegen_class
        jmp .next_child
    
    .gen_func:
        mov rdi, r15                    ; function node
        call codegen_function
        jmp .next_child
    
    .done:
        xor rax, rax                    ; return 0 for success
        pop r15
        pop r14
        pop r13
        pop r12
        pop rbx
        pop rbp
        ret

;============================================================================
; CLASS GENERATION
;============================================================================

codegen_class:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi                    ; class node

    mov [current_func], r12

    mov qword [local_count], 0
    mov qword [local_offset], 0

    mov rdi, r12
    call get_child_count
    mov r14, rax
    xor r13, r13

.process_method:
    cmp r13, r14
    jge .done

    mov rdi, r12
    mov rsi, r13
    call get_child_at
    mov r15, rax

    test r15, r15
    jz .next_method

    mov rdi, r15
    call get_node_type_value

    cmp rax, 4                      ; NODE_FUNCTION
    jne .next_method

    mov rdi, r15
    call codegen_function

.next_method:
    inc r13
    jmp .process_method

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

;============================================================================
; FUNCTION GENERATION
;============================================================================

codegen_function:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi                    ; function node
    mov [current_func], r12

    mov qword [local_count], 0
    mov qword [local_offset], 0

    call emit_newline

    ; Emit function label: "func_"
    mov rdi, str_func_prefix
    call emit_string

    ; Emit function name from node
    mov rdi, r12
    add rdi, 24                     ; name field
    call emit_string

    mov rdi, str_colon
    call emit_string
    mov rdi, str_newline
    call emit_string

    ; Emit prologue
    mov rdi, str_push_rbp
    call emit_string
    mov rdi, str_newline
    call emit_string

    mov rdi, str_mov_rbp_rsp
    call emit_string
    mov rdi, str_newline
    call emit_string

    ; Default return value for paths without explicit expression
    call emit_instruction
    db 'xor rax, rax',10,0

    call generate_label
    mov [current_func_end], rax

    mov rdi, r12
    call spill_function_params

    mov r13, [r12 + 48]             ; function body block
    test r13, r13
    jz .emit_epilogue

    mov rdi, r13
    call codegen_block

.emit_epilogue:
    mov rdi, [current_func_end]
    call emit_label_def

    ; Emit epilogue
    mov rdi, str_pop_rbp
    call emit_string
    mov rdi, str_newline
    call emit_string

    mov rdi, str_ret
    call emit_string
    mov rdi, str_newline
    call emit_string

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

str_func_prefix: db 'func_', 0
str_colon: db ':', 0
str_pop_rbp: db 'pop rbp', 0
str_ret: db 'ret', 0

count_params:
    push rbp
    mov rbp, rsp

    mov rdi, r12
    mov rsi, 0
    call get_child_at
    mov rdi, rax
    test rdi, rdi
    jz .zero

    call get_child_count
    jmp .done

.zero:
    xor rax, rax

.done:
    pop rbp
    ret

emit_function_label:
    call emit_string
    ret

spill_function_params:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi                    ; function node
    mov r15, [r12 + 32]             ; params container
    test r15, r15
    jz .done

    mov rdi, r15
    call get_child_count
    mov r14, rax                    ; param count
    xor r13, r13                    ; param index

.param_loop:
    cmp r13, r14
    jge .done

    mov rdi, r15
    mov rsi, r13
    call get_child_at
    test rax, rax
    jz .next_param

    ; Reserve stack slot for parameter and register as local
    mov rdx, rax                    ; param node
    mov rax, [local_offset]
    add rax, 8
    mov [local_offset], rax
    mov rbx, rax
    neg rbx
    mov qword [tmp_stack_offset], rbx

    mov rax, [local_count]
    cmp rax, MAX_LOCALS
    jge .next_param
    imul rax, 16
    lea rcx, [local_vars + rax]
    lea r8, [rdx + 24]
    mov qword [rcx], r8
    mov qword [rcx + 8], rbx
    inc qword [local_count]

    ; Mirror parameter stack offset into symbol table entry when available
    lea rdi, [rdx + 24]
    call symbol_lookup
    test rax, rax
    jz .load_arg
    mov rdi, rax
    mov rsi, qword [tmp_stack_offset]
    call symbol_set_addr

.load_arg:
    cmp r13, 0
    je .arg0
    cmp r13, 1
    je .arg1
    cmp r13, 2
    je .arg2
    cmp r13, 3
    je .arg3
    cmp r13, 4
    je .arg4
    cmp r13, 5
    je .arg5
    jmp .next_param

.arg0:
    call emit_instruction
    db 'mov rax, rdi',10,0
    jmp .store_arg
.arg1:
    call emit_instruction
    db 'mov rax, rsi',10,0
    jmp .store_arg
.arg2:
    call emit_instruction
    db 'mov rax, rdx',10,0
    jmp .store_arg
.arg3:
    call emit_instruction
    db 'mov rax, rcx',10,0
    jmp .store_arg
.arg4:
    call emit_instruction
    db 'mov rax, r8',10,0
    jmp .store_arg
.arg5:
    call emit_instruction
    db 'mov rax, r9',10,0

.store_arg:
    mov rdi, qword [tmp_stack_offset]
    call emit_mov_stack

.next_param:
    inc r13
    jmp .param_loop

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

;============================================================================
; STATEMENT GENERATION
;============================================================================

codegen_statement:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi                    ; statement node
    test r12, r12
    jz .done

    mov rdi, r12
    call get_node_type_value
    mov r13, rax                    ; node type

    cmp r13, 6                      ; NODE_BLOCK
    je .gen_block

    cmp r13, 7                      ; NODE_LET_DECL
    je .gen_let

    cmp r13, 8                      ; NODE_IF_STMT
    je .gen_if

    cmp r13, 9                      ; NODE_WHILE_STMT
    je .gen_while

    cmp r13, 10                     ; NODE_FOR_STMT
    je .gen_for

    cmp r13, 11                     ; NODE_RETURN_STMT
    je .gen_return

    cmp r13, 12                     ; NODE_BREAK_STMT
    je .gen_break

    cmp r13, 13                     ; NODE_EXPR_STMT
    je .gen_expr

    jmp .done

.gen_block:
    mov rdi, r12
    call codegen_block
    jmp .done

.gen_let:
    mov rdi, r12
    call codegen_let
    jmp .done

.gen_if:
    mov rdi, r12
    call codegen_if
    jmp .done

.gen_while:
    mov rdi, r12
    call codegen_while
    jmp .done

.gen_for:
    mov rdi, r12
    call codegen_for
    jmp .done

.gen_return:
    mov rdi, r12
    call codegen_return
    jmp .done

.gen_break:
    mov rdi, r12
    call codegen_break
    jmp .done

.gen_expr:
    mov r13, [r12 + 32]
    test r13, r13
    jz .done
    mov rdi, r13
    call codegen_expression
    jmp .done

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

codegen_block:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14

    mov r12, rdi                    ; block node
    mov rdi, r12
    call get_child_count
    mov r13, rax

    xor r14, r14                    ; index

.block_loop:
    cmp r14, r13
    jge .done

    mov rdi, r12
    mov rsi, r14
    call get_child_at
    test rax, rax
    jz .next

    push r14
    push r13
    mov rdi, rax
    call codegen_statement
    pop r13
    pop r14

.next:
    inc r14
    jmp .block_loop

.done:
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

codegen_let:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8

    mov r12, rdi                    ; let node

    ; Calculate offset for this variable and update local_offset
    mov rax, [local_offset]
    add rax, 8
    mov [local_offset], rax   ; local_offset now holds positive offset for this variable
    ; rax = positive offset

    ; Compute negative offset for symbol table and address calculation
    mov rbx, rax
    neg rbx   ; rbx = negative offset
    mov qword [tmp_stack_offset], rbx

    ; Record local variable mapping (name ptr + stack offset)
    mov rax, [local_count]
    cmp rax, MAX_LOCALS
    jge .done
    imul rax, 16
    lea r14, [local_vars + rax]
    lea r15, [r12 + 24]
    mov qword [r14], r15
    mov rbx, qword [tmp_stack_offset]
    mov qword [r14 + 8], rbx
    inc qword [local_count]

    ; Mirror stack offset into symbol table entry when available
    lea rdi, [r12 + 24]
    call symbol_lookup
    test rax, rax
    jz .init_value
    mov rdi, rax
    mov rsi, qword [tmp_stack_offset]
    call symbol_set_addr

.init_value:

    ; Parser stores initializer at +48
    mov r13, [r12 + 48]

    test r13, r13
    jz .done   ; no initializer, just store zero? but we should have an initializer

    mov rdi, r13
    call codegen_expression

    ; Store result to stack at the variable's offset (which we have in rbx as negative offset)
    mov rdi, qword [tmp_stack_offset]
    call emit_mov_stack

.done:
    xor rax, rax                    ; return success
    jmp .exit

.exit:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

codegen_if:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi                    ; if node

    call generate_label
    mov r14, rax                    ; else label

    mov r13, [r12 + 32]             ; condition

    test r13, r13
    jz .gen_else

    mov rdi, r13
    call codegen_expression

    call emit_instruction
    db 'test rax, rax',10,0
    mov rsi, r14
    call emit_je_label

    mov r13, [r12 + 40]             ; then block

    test r13, r13
    jz .gen_else

    mov rdi, r13
    call codegen_block

.gen_else:
    mov r13, [r12 + 48]             ; else block

    test r13, r13
    jnz .has_else

    mov rdi, r14
    call emit_label_def
    jmp .done

.has_else:
    call generate_label
    mov r15, rax                    ; end label

    mov rsi, r15
    call emit_jmp_label
    mov rdi, r14
    call emit_label_def

    mov rdi, r13
    call codegen_block

    mov rdi, r15
    call emit_label_def

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

codegen_while:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi                    ; while node

    call generate_label
    mov r14, rax                    ; loop start
    call generate_label
    mov r15, rax                    ; loop end

    mov rdi, r15
    call push_loop

    mov rdi, r14
    call emit_label_def

    mov r13, [r12 + 32]             ; condition

    test r13, r13
    jz .loop_body

    mov rdi, r13
    call codegen_expression

    call emit_instruction
    db 'test rax, rax',10,0
    mov rsi, r15
    call emit_je_label

.loop_body:
    mov r13, [r12 + 40]             ; body

    test r13, r13
    jz .end_loop

    mov rdi, r13
    call codegen_block

.end_loop:
    mov rsi, r14
    call emit_jmp_label
    mov rdi, r15
    call emit_label_def

    call pop_loop

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

codegen_for:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi                    ; for node

    call generate_label
    mov r14, rax                    ; loop start
    call generate_label
    mov r15, rax                    ; loop end

    mov rdi, r15
    call push_loop

    mov r13, [r12 + 32]             ; initializer

    test r13, r13
    jz .check_cond

    mov rdi, r13
    call codegen_statement

.check_cond:
    mov rdi, r14
    call emit_label_def

    mov r13, [r12 + 40]             ; condition

    test r13, r13
    jz .loop_body

    mov rdi, r13
    call codegen_expression

    call emit_instruction
    db 'test rax, rax',10,0
    mov rsi, r15
    call emit_je_label

.loop_body:
    mov r13, [r12 + 56]             ; body

    test r13, r13
    jz .increment

    mov rdi, r13
    call codegen_block

.increment:
    mov r13, [r12 + 48]             ; increment

    test r13, r13
    jz .end_loop

    mov rdi, r13
    call codegen_statement

.end_loop:
    mov rsi, r14
    call emit_jmp_label
    mov rdi, r15
    call emit_label_def

    call pop_loop

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

codegen_return:
    push rbp
    mov rbp, rsp

    mov rax, [rdi + 32]             ; optional return expression
    test rax, rax
    jz .void_return

    mov rdi, rax
    call codegen_expression
    jmp .epilogue

.void_return:
    xor rax, rax

.epilogue:
    mov rsi, [current_func_end]
    test rsi, rsi
    jz .done
    call emit_jmp_label

.done:
    pop rbp
    ret

codegen_break:
    push rbp
    mov rbp, rsp

    mov rdi, [loop_depth]
    test rdi, rdi
    jz .done

    dec rdi
    shl rdi, 3
    mov rdi, [loop_stack + rdi]

    mov rsi, rdi
    call emit_jmp_label

.done:
    pop rbp
    ret

;============================================================================
; EXPRESSION GENERATION
;============================================================================

codegen_expression:
    push rbp
    mov rbp, rsp
    push r12
    push r13

    mov r12, rdi                    ; expression node
    test r12, r12
    jz .done

    mov rdi, r12
    call get_node_type_value
    mov r13, rax

    cmp r13, 14                     ; NODE_BINARY_EXPR
    je .gen_binary

    cmp r13, 15                     ; NODE_UNARY_EXPR
    je .gen_unary

    cmp r13, 16                     ; NODE_POSTFIX_EXPR
    je .gen_postfix

    cmp r13, 17                     ; NODE_CALL_EXPR
    je .gen_call

    cmp r13, 18                     ; NODE_NEW_EXPR
    je .gen_new

    cmp r13, 19                     ; NODE_IDENTIFIER
    je .gen_ident

    cmp r13, 20                     ; NODE_NUMBER
    je .gen_number

    cmp r13, 21                     ; NODE_STRING
    je .gen_string

    cmp r13, 22                     ; NODE_BOOL
    je .gen_bool

    cmp r13, 23                     ; NODE_NULL
    je .gen_null

.done:
    pop r13
    pop r12
    pop rbp
    ret

.gen_binary:
    mov rdi, r12
    call codegen_binary_expr
    jmp .done

.gen_unary:
    mov rdi, r12
    call codegen_unary_expr
    jmp .done

.gen_postfix:
    mov rdi, r12
    call codegen_postfix_expr
    jmp .done

.gen_call:
    mov rdi, r12
    call codegen_call
    jmp .done

.gen_new:
    mov rdi, r12
    call codegen_new
    jmp .done

.gen_ident:
    mov rdi, r12
    call codegen_identifier
    jmp .done

.gen_number:
    mov rdi, r12
    call codegen_number
    jmp .done

.gen_string:
    mov rdi, r12
    call codegen_string
    jmp .done

.gen_bool:
    mov rdi, r12
    call codegen_bool
    jmp .done

.gen_null:
    xor rax, rax
    jmp .done

codegen_binary_expr:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14

    mov r12, rdi                    ; binary node
    mov r13, [r12 + 32]             ; operator
    mov r14, [r12 + 40]             ; left operand

    test r14, r14
    jz .eval_right

    mov rdi, r14
    call codegen_expression

    call emit_instruction
    db 'push rax',10,0

.eval_right:
    mov r14, [r12 + 48]             ; right operand

    test r14, r14
    jz .apply_op

    mov rdi, r14
    call codegen_expression

    call emit_instruction
    db 'mov rbx, rax',10,0
    call emit_instruction
    db 'pop rax',10,0

.apply_op:
    cmp r13, 1                      ; OP_ADD
    je .op_add
    cmp r13, 2                      ; OP_SUB
    je .op_sub
    cmp r13, 3                      ; OP_MUL
    je .op_mul
    cmp r13, 4                      ; OP_DIV
    je .op_div
    cmp r13, 5                      ; OP_MOD
    je .op_mod
    cmp r13, 6                      ; OP_EQ
    je .op_eq
    cmp r13, 7                      ; OP_NEQ
    je .op_neq
    cmp r13, 8                      ; OP_LT
    je .op_lt
    cmp r13, 9                      ; OP_GT
    je .op_gt
    cmp r13, 10                     ; OP_LE
    je .op_le
    cmp r13, 11                     ; OP_GE
    je .op_ge
    cmp r13, 12                     ; OP_AND
    je .op_and
    cmp r13, 13                     ; OP_OR
    je .op_or

    jmp .done

.op_add:
    call emit_instruction
    db 'add rax, rbx',10,0
    jmp .done

.op_sub:
    call emit_instruction
    db 'sub rax, rbx',10,0
    jmp .done

.op_mul:
    call emit_instruction
    db 'imul rax, rbx',10,0
    jmp .done

.op_div:
    call emit_instruction
    db 'cqo',10,'idiv rbx',10,0
    jmp .done

.op_mod:
    call emit_instruction
    db 'cqo',10,'idiv rbx',10,'mov rax, rdx',10,0
    jmp .done

.op_eq:
    call emit_instruction
    db 'cmp rax, rbx',10,0
    call emit_instruction
    db 'sete al',10,0
    call emit_instruction
    db 'movzx rax, al',10,0
    jmp .done

.op_neq:
    call emit_instruction
    db 'cmp rax, rbx',10,0
    call emit_instruction
    db 'setne al',10,0
    call emit_instruction
    db 'movzx rax, al',10,0
    jmp .done

.op_lt:
    call emit_instruction
    db 'cmp rax, rbx',10,0
    call emit_instruction
    db 'setl al',10,0
    call emit_instruction
    db 'movzx rax, al',10,0
    jmp .done

.op_gt:
    call emit_instruction
    db 'cmp rax, rbx',10,0
    call emit_instruction
    db 'setg al',10,0
    call emit_instruction
    db 'movzx rax, al',10,0
    jmp .done

.op_le:
    call emit_instruction
    db 'cmp rax, rbx',10,0
    call emit_instruction
    db 'setle al',10,0
    call emit_instruction
    db 'movzx rax, al',10,0
    jmp .done

.op_ge:
    call emit_instruction
    db 'cmp rax, rbx',10,0
    call emit_instruction
    db 'setge al',10,0
    call emit_instruction
    db 'movzx rax, al',10,0
    jmp .done

.op_and:
    call emit_instruction
    db 'and rax, rbx',10,0
    jmp .done

.op_or:
    call emit_instruction
    db 'or rax, rbx',10,0
    jmp .done

.done:
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

codegen_unary_expr:
    push rbp
    mov rbp, rsp
    push r12
    push r13

    mov r12, rdi                    ; unary node
    mov r13, [r12 + 32]             ; operator (0=neg, 1=not)
    mov r12, [r12 + 40]             ; operand

    test r12, r12
    jz .done

    mov rdi, r12
    call codegen_expression

    cmp r13, 0                      ; negation
    je .op_neg
    cmp r13, 1                      ; logical not
    je .op_not

    jmp .done

.op_neg:
    call emit_instruction
    db 'neg rax',10,0
    jmp .done

.op_not:
    call emit_instruction
    db 'test rax, rax',10,0
    call emit_instruction
    db 'sete al',10,0
    call emit_instruction
    db 'movzx rax, al',10,0
    jmp .done

.done:
    pop r13
    pop r12
    pop rbp
    ret

codegen_postfix_expr:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14

    mov r12, rdi                    ; postfix node
    mov r13, [r12 + 32]             ; 1=++, 2=--
    mov r12, [r12 + 40]             ; operand node

    test r12, r12
    jz .done

    mov rdi, r12
    call get_node_type_value
    cmp rax, 19                     ; NODE_IDENTIFIER
    jne .done

    mov rdi, r12
    add rdi, 24
    mov rsi, rdi
    call symbol_lookup
    test rax, rax
    jz .fallback_local

    mov rdi, rax
    call symbol_get_addr
    mov r14, rax                    ; stack offset
    test r14, r14
    jz .fallback_local
    jmp .have_offset

.fallback_local:
    mov r14, [local_offset]
    test r14, r14
    jz .done
    neg r14

.have_offset:

    mov rdi, r12
    call codegen_identifier

    cmp r13, 1
    je .inc
    cmp r13, 2
    je .dec
    jmp .store

.inc:
    call emit_instruction
    db 'add rax, 1',10,0
    jmp .store

.dec:
    call emit_instruction
    db 'sub rax, 1',10,0

.store:
    mov rdi, r14
    call emit_mov_stack

.done:
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

codegen_identifier:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    
    mov r12, rdi                    ; identifier node
    
    ; Get the identifier name (at offset 24)
    lea r13, [r12 + 24]

    ; First lookup in codegen local table
    xor r14, r14
.local_loop:
    cmp r14, [local_count]
    jge .fallback_symbol
    mov r15, r14
    shl r15, 4
    lea r15, [local_vars + r15]
    mov rsi, [r15]
    mov rdi, r13
    call strcmp
    test rax, rax
    jz .found_local
    inc r14
    jmp .local_loop

.found_local:
    mov rax, [r15 + 8]              ; offset (negative for stack locals)
    jmp .emit_load

.fallback_symbol:
    mov rdi, r13
    mov rsi, rdi
    call symbol_lookup
    test rax, rax
    jz .not_found

    mov rdi, rax
    call symbol_get_addr
    test rax, rax
    jz .not_found

.emit_load:
    mov r14, rax
    
    ; Generate code: mov rax, [rbp + offset]
    ; Since offset is negative, this becomes: mov rax, [rbp - offset]
    call emit_instruction
    db 'mov rax, [rbp', 0
    
    ; Check if offset is negative (it should be for stack variables)
    test r14, r14
    jns .positive_offset
    ; Negative offset: emit minus
    call emit_instruction
    db '-', 0
    mov rax, r14
    neg rax
    jmp .emit_offset_value
.positive_offset:
    ; Positive offset: emit plus (shouldn't happen for locals, but handle anyway)
    call emit_instruction
    db '+', 0
    mov rax, r14
.emit_offset_value:
    mov rdi, rax
    call emit_number_imm
    call emit_instruction
    db ']', 10, 0
    
    jmp .done
    
.not_found:
    mov r14, [local_offset]
    test r14, r14
    jz .load_zero
    neg r14
    jmp .emit_load

.load_zero:
    xor rax, rax
    
.done:
    pop r13
    pop r12
    pop rbp
    ret

codegen_number:
    push rbp
    mov rbp, rsp
    push r12

    mov r12, rdi                    ; number node

    call emit_instruction
    db 'mov rax, ',0
    lea rdi, [r12 + NODE_HEADER_SIZE]
    call emit_node_name
    call emit_newline

    pop r12
    pop rbp
    ret

codegen_string:
    push rbp
    mov rbp, rsp
    push r12
    push r13

    mov r12, rdi                    ; string node

    lea rdi, [r12 + NODE_HEADER_SIZE]
    call add_string_constant
    mov r13, rax

    xor rdi, rdi                    ; rax register id
    mov rsi, r13
    call emit_mov_imm

    pop r13
    pop r12
    pop rbp
    ret

codegen_bool:
    push rbp
    mov rbp, rsp

    mov edi, [rdi + 32]
    mov rax, rdi

    pop rbp
    ret

;============================================================================
; FUNCTION CALLS
;============================================================================

codegen_call:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8

    mov r12, rdi                    ; call node

    mov rdi, r12
    call get_child_count
    test rax, rax
    jz .done
    mov r14, rax                    ; total children
    dec r14                         ; arg count (exclude callee)
    mov qword [rbp - 8], r14

    ; Fast path for builtins that are currently no-op
    mov rdi, r12
    xor rsi, rsi
    call get_child_at
    mov r13, rax
    test r13, r13
    jz .arg_prep

    mov rdi, r13
    call get_node_type_value
    cmp rax, 19                     ; NODE_IDENTIFIER
    jne .arg_prep

    lea rdi, [r13 + 24]
    cmp byte [rdi], 'p'
    jne .arg_prep
    cmp byte [rdi + 1], 'r'
    jne .arg_prep
    cmp byte [rdi + 2], 'i'
    jne .arg_prep
    cmp byte [rdi + 3], 'n'
    jne .arg_prep
    cmp byte [rdi + 4], 't'
    jne .arg_prep
    cmp byte [rdi + 5], 'l'
    jne .arg_prep
    cmp byte [rdi + 6], 'n'
    jne .arg_prep
    cmp byte [rdi + 7], 0
    jne .arg_prep

    xor rax, rax
    jmp .done

.arg_prep:

    xor r15, r15                    ; arg index

.arg_loop:
    mov r14, qword [rbp - 8]
    cmp r15, r14
    jge .call_func

    mov rdi, r12
    mov rsi, r15
    inc rsi                         ; child index starts at 1
    call get_child_at
    mov r13, rax
    test r13, r13
    jz .call_func

    mov rdi, r13
    call codegen_expression

    cmp r15, 0
    je .arg0
    cmp r15, 1
    je .arg1
    cmp r15, 2
    je .arg2
    cmp r15, 3
    je .arg3
    cmp r15, 4
    je .arg4
    cmp r15, 5
    je .arg5

    jmp .push_arg

.arg0:
    call emit_instruction
    db 'mov rdi, rax',10,0
    jmp .next_arg

.arg1:
    call emit_instruction
    db 'mov rsi, rax',10,0
    jmp .next_arg

.arg2:
    call emit_instruction
    db 'mov rdx, rax',10,0
    jmp .next_arg

.arg3:
    call emit_instruction
    db 'mov rcx, rax',10,0
    jmp .next_arg

.arg4:
    call emit_instruction
    db 'mov r8, rax',10,0
    jmp .next_arg

.arg5:
    call emit_instruction
    db 'mov r9, rax',10,0
    jmp .next_arg

.push_arg:
    call emit_instruction
    db 'push rax',10,0

.next_arg:
    inc r15
    jmp .arg_loop

.call_func:
    mov rdi, r12
    xor rsi, rsi
    call get_child_at
    mov r13, rax

    test r13, r13
    jz .done

    mov rdi, r13
    call get_node_type_value
    cmp rax, 19                     ; NODE_IDENTIFIER
    jne .cleanup_stack

    lea rdi, [r13 + 24]             ; callee name

    ; println(x) -> puts(x) bridge for now
    cmp byte [rdi], 'p'
    jne .call_user
    cmp byte [rdi + 1], 'r'
    jne .call_user
    cmp byte [rdi + 2], 'i'
    jne .call_user
    cmp byte [rdi + 3], 'n'
    jne .call_user
    cmp byte [rdi + 4], 't'
    jne .call_user
    cmp byte [rdi + 5], 'l'
    jne .call_user
    cmp byte [rdi + 6], 'n'
    jne .call_user
    cmp byte [rdi + 7], 0
    jne .call_user

    call emit_instruction
    db 'call puts',10,0
    jmp .cleanup_stack

.call_user:
    mov r15, rdi                    ; preserve callee name pointer
    call emit_instruction
    db 'call func_',0
    mov rdi, r15
    call emit_node_name
    call emit_newline

.cleanup_stack:
    mov r14, qword [rbp - 8]
    cmp r14, 6
    jle .done

    mov rsi, r14
    sub rsi, 6
    imul rsi, 8
    call emit_add

.done:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

;============================================================================
; OBJECT CREATION
;============================================================================

codegen_new:
    push rbp
    mov rbp, rsp
    push r12
    push r13

    mov r12, rdi                    ; new node

    mov edi, 16                     ; Allocate 16 bytes for object
    mov esi, 16
    mov edi, edi
    call emit_mov_imm
    call emit_instruction
    db 'call malloc',10,0

    mov rdi, r12
    call get_child_count
    mov r13, rax

    test r13, r13
    jz .done

    mov rdi, r12
    mov rsi, 0
    call get_child_at

    test rax, rax
    jz .done

    mov rdi, r12
    mov rsi, 0
    call get_child_at
    mov r13, rax

    call emit_instruction
    db 'push rax',10,0

    xor r14, r14
.arg_loop:
    cmp r14, r13
    jge .call_ctor

    mov rdi, r12
    mov rsi, r14
    inc rsi
    call get_child_at
    test rax, rax
    jz .call_ctor

    mov rdi, rax
    call codegen_expression

    cmp r14, 0
    je .arg0
    cmp r14, 1
    je .arg1
    cmp r14, 2
    je .arg2
    cmp r14, 3
    je .arg3
    cmp r14, 4
    je .arg4
    cmp r14, 5
    je .arg5

    jmp .push_arg

.arg0:
    mov rdi, rax
    jmp .next_arg

.arg1:
    mov rsi, rax
    jmp .next_arg

.arg2:
    mov rdx, rax
    jmp .next_arg

.arg3:
    mov rcx, rax
    jmp .next_arg

.arg4:
    mov r8, rax
    jmp .next_arg

.arg5:
    mov r9, rax
    jmp .next_arg

.push_arg:
    push rax

.next_arg:
    inc r14
    jmp .arg_loop

.call_ctor:
    call emit_instruction
    db 'pop rdi',10,0

    call emit_instruction
    db 'call ',0
    call emit_node_name
    db '_construct',10,0

.done:
    pop r13
    pop r12
    pop rbp
    ret

;============================================================================
; BINARY AND UNARY OPERATIONS
;============================================================================

codegen_binary_op:
    push rbp
    mov rbp, rsp

    mov r12, rdi                    ; operator
    mov r13, rsi                    ; left
    mov r14, rdx                    ; right

    mov rdi, r13
    call codegen_expression

    call emit_instruction
    db 'push rax',10,0

    mov rdi, r14
    call codegen_expression

    call emit_instruction
    db 'mov rbx, rax',10,0
    call emit_instruction
    db 'pop rax',10,0

    cmp r12, 1                      ; OP_ADD
    je .add
    cmp r12, 2                      ; OP_SUB
    je .sub
    cmp r12, 3                      ; OP_MUL
    je .mul
    cmp r12, 4                      ; OP_DIV
    je .div
    cmp r12, 5                      ; OP_MOD
    je .mod
    cmp r12, 6                      ; OP_EQ
    je .eq
    cmp r12, 7                      ; OP_NEQ
    je .neq
    cmp r12, 8                      ; OP_LT
    je .lt
    cmp r12, 9                      ; OP_GT
    je .gt
    cmp r12, 10                     ; OP_LE
    je .le
    cmp r12, 11                     ; OP_GE
    je .ge
    cmp r12, 12                     ; OP_AND
    je .and
    cmp r12, 13                     ; OP_OR
    je .or

    jmp .done

.add:
    call emit_instruction
    db 'add rax, rbx',10,0
    jmp .done

.sub:
    call emit_instruction
    db 'sub rax, rbx',10,0
    jmp .done

.mul:
    call emit_instruction
    db 'imul rax, rbx',10,0
    jmp .done

.div:
    call emit_instruction
    db 'cqo',10,'idiv rbx',10,0
    jmp .done

.mod:
    call emit_instruction
    db 'cqo',10,'idiv rbx',10,'mov rax, rdx',10,0
    jmp .done

.eq:
    call emit_instruction
    db 'cmp rax, rbx',10,'sete al',10,'movzx rax, al',10,0
    jmp .done

.neq:
    call emit_instruction
    db 'cmp rax, rbx',10,'setne al',10,'movzx rax, al',10,0
    jmp .done

.lt:
    call emit_instruction
    db 'cmp rax, rbx',10,'setl al',10,'movzx rax, al',10,0
    jmp .done

.gt:
    call emit_instruction
    db 'cmp rax, rbx',10,'setg al',10,'movzx rax, al',10,0
    jmp .done

.le:
    call emit_instruction
    db 'cmp rax, rbx',10,'setle al',10,'movzx rax, al',10,0
    jmp .done

.ge:
    call emit_instruction
    db 'cmp rax, rbx',10,'setge al',10,'movzx rax, al',10,0
    jmp .done

.and:
    call emit_instruction
    db 'and rax, rbx',10,0
    jmp .done

.or:
    call emit_instruction
    db 'or rax, rbx',10,0

.done:
    pop rbp
    ret

codegen_unary_op:
    push rbp
    mov rbp, rsp

    mov r12, rdi                    ; operator
    mov r13, rsi                    ; operand

    mov rdi, r13
    call codegen_expression

    cmp r12, 0                      ; negation
    je .neg
    cmp r12, 1                      ; logical not
    je .not

    jmp .done

.neg:
    call emit_instruction
    db 'neg rax',10,0
    jmp .done

.not:
    call emit_instruction
    db 'test rax, rax',10,0
    call emit_instruction
    db 'sete al',10,0
    call emit_instruction
    db 'movzx rax, al',10,0

.done:
    pop rbp
    ret

;============================================================================
; LABEL AND INSTRUCTION EMISSION
;============================================================================

codegen_emit_label:
    push rbp
    mov rbp, rsp

    mov rdi, rsi
    call emit_label_name

    pop rbp
    ret

codegen_emit_instruction:
emit_instruction:
    ; Get the return address which points to inline string
    pop rcx                         ; rcx = return address (points to string)
    
    ; Emit the string starting at rcx
    mov rdi, rcx
    
.emit_loop:
    movzx rax, byte [rdi]
    test al, al
    jz .found_end
    
    ; Emit character
    push rcx
    push rdi
    mov dil, al
    call emit_char
    pop rdi
    pop rcx
    inc rdi
    jmp .emit_loop
.found_end:
    inc rdi                         ; skip null terminator
    
    ; Jump to the address after the string
    push rdi
    ret

emit_label_name:
    push rbp
    mov rbp, rsp

    mov rax, rdi
    call emit_string

    pop rbp
    ret

emit_label_def:
    push rbp
    mov rbp, rsp

    call emit_label_name
    call emit_instruction
    db ':',10,0

    pop rbp
    ret

generate_label:
    push rbp
    mov rbp, rsp
    push rbx
    push r12

    mov rax, [label_counter]
    inc qword [label_counter]

    mov rbx, [label_pool_pos]
    lea r12, [label_pool + rbx]

    mov byte [r12], 'L'
    lea rdi, [r12 + 1]
    call int_to_str

    xor rcx, rcx
.len_loop:
    cmp byte [r12 + rcx], 0
    je .len_done
    inc rcx
    jmp .len_loop

.len_done:
    cmp qword [label_pool_pos], 4000
    jl .store_len
    mov qword [label_pool_pos], 0
    mov rbx, 0
    lea r12, [label_pool]
    mov byte [r12], 'L'
    lea rdi, [r12 + 1]
    call int_to_str
    xor rcx, rcx
.reset_len_loop:
    cmp byte [r12 + rcx], 0
    je .store_len
    inc rcx
    jmp .reset_len_loop

.store_len:
    add [label_pool_pos], rcx
    inc qword [label_pool_pos]

    mov rax, r12

    pop r12
    pop rbx

    pop rbp
    ret

emit_text_section:
    push rbp
    mov rbp, rsp

    ; Use emit_string instead of emit_instruction for now
    mov rdi, str_section_text
    call emit_string
    mov rdi, str_newline
    call emit_string

    pop rbp
    ret

emit_start_entry:
    push rbp
    mov rbp, rsp

    mov rdi, str_global_start
    call emit_string
    mov rdi, str_newline
    call emit_string
    
    mov rdi, str_start_label
    call emit_string
    mov rdi, str_newline
    call emit_string

    ; Call main function
    mov rdi, str_call_main
    call emit_string
    mov rdi, str_newline
    call emit_string

    ; Exit with return value from main
    mov rdi, str_exit_prog
    call emit_string
    mov rdi, str_newline
    call emit_string

    pop rbp
    ret

str_section_text: db 'section .text', 0
str_global_start: db 'global _start', 0
str_start_label: db '_start:', 0
str_call_main: db '    call func_main', 0
str_exit_prog: db '    mov rdi, rax', 10, '    mov rax, 60', 10, '    syscall', 0
str_push_rbp: db 'push rbp', 0
str_mov_rbp_rsp: db 'mov rbp, rsp', 0
str_newline: db 10, 0

emit_externs:
    push rbp
    mov rbp, rsp

    mov rdi, str_extern1
    call emit_string
    mov rdi, str_newline
    call emit_string
    
    mov rdi, str_extern2
    call emit_string
    mov rdi, str_newline
    call emit_string

    pop rbp
    ret

str_extern1: db 'extern malloc, free, memcpy, strlen', 0
str_extern2: db 'extern puts, printf, exit', 0

emit_newline:
    call emit_instruction
    db '',10,0
    ret

emit_jmp_label:
    push rbp
    mov rbp, rsp

    call emit_instruction
    db 'jmp ',0
    mov rdi, rsi
    call emit_label_name
    call emit_newline

    pop rbp
    ret

emit_je_label:
    push rbp
    mov rbp, rsp

    call emit_instruction
    db 'je ',0
    mov rdi, rsi
    call emit_label_name
    call emit_newline

    pop rbp
    ret

emit_jne_label:
    push rbp
    mov rbp, rsp

    call emit_instruction
    db 'jne ',0
    mov rdi, rsi
    call emit_label_name
    call emit_newline

    pop rbp
    ret

emit_sub:
    push rbp
    mov rbp, rsp

    call emit_instruction
    db 'sub rsp, ',0
    mov rdi, rsi
    call emit_number_imm
    call emit_newline

    pop rbp
    ret

emit_add:
    push rbp
    mov rbp, rsp

    call emit_instruction
    db 'add rsp, ',0
    mov rdi, rsi
    call emit_number_imm
    call emit_newline

    pop rbp
    ret

emit_mov_stack:
    push rbp
    mov rbp, rsp
    push r12

    mov r12, rdi

    call emit_instruction
    db 'mov [rbp',0
    cmp r12, 0
    jg .positive
    je .zero

    call emit_instruction
    db '-',0
    mov rax, r12
    neg rax
    mov rdi, rax
    call emit_number_imm
    jmp .close
.positive:
    call emit_instruction
    db '+',0
    mov rdi, r12
    call emit_number_imm
.zero:
.close:
    call emit_instruction
    db '], rax',10,0

    pop r12
    pop rbp
    ret

emit_mov_imm:
    push rbp
    mov rbp, rsp

    mov r13, rdi
    mov r14, rsi

    call emit_instruction
    db 'mov ',0
    mov rdi, r13
    call emit_reg_name
    call emit_instruction
    db ', ',0
    mov rdi, r14
    call emit_value
    call emit_newline

    pop rbp
    ret

emit_number_imm:
    push rbp
    mov rbp, rsp
    push r12
    mov r12, rdi

    cmp r12, 0
    jge .encode
    mov dil, '-'
    call emit_char
    neg r12

.encode:
    mov rax, r12
    lea rdi, [temp_label_a]
    call int_to_str
    lea rdi, [temp_label_a]
    call emit_string

.done:
    pop r12
    pop rbp
    ret

emit_value:
    push rbp
    mov rbp, rsp

    cmp rdi, 0
    je .zero
    call emit_number_imm
    jmp .done

.zero:
    mov dil, '0'
    call emit_char

.done:
    pop rbp
    ret

emit_reg_name:
    push rbp
    mov rbp, rsp

    cmp rdi, 0
    je .rax
    cmp rdi, 1
    je .rcx
    cmp rdi, 2
    je .rdx
    cmp rdi, 3
    je .rbx
    cmp rdi, 4
    je .rsp
    je .rbp
    cmp rdi, 5
    je .rsi
    cmp rdi, 6
    je .rdi
    cmp rdi, 7
    je .r8
    cmp rdi, 8
    je .r9
    cmp rdi, 9
    je .r10
    cmp rdi, 10
    je .r11
    cmp rdi, 12
    je .r12
    cmp rdi, 13
    je .r13
    cmp rdi, 14
    je .r14
    cmp rdi, 15
    je .r15

    jmp .done

.rax:
    call emit_instruction
    db 'rax',0
    jmp .done
.rcx:
    call emit_instruction
    db 'rcx',0
    jmp .done
.rdx:
    call emit_instruction
    db 'rdx',0
    jmp .done
.rbx:
    call emit_instruction
    db 'rbx',0
    jmp .done
.rsp:
    call emit_instruction
    db 'rsp',0
    jmp .done
.rbp:
    call emit_instruction
    db 'rbp',0
    jmp .done
.rsi:
    call emit_instruction
    db 'rsi',0
    jmp .done
.rdi:
    call emit_instruction
    db 'rdi',0
    jmp .done
.r8:
    call emit_instruction
    db 'r8',0
    jmp .done
.r9:
    call emit_instruction
    db 'r9',0
    jmp .done
.r10:
    call emit_instruction
    db 'r10',0
    jmp .done
.r11:
    call emit_instruction
    db 'r11',0
    jmp .done
.r12:
    call emit_instruction
    db 'r12',0
    jmp .done
.r13:
    call emit_instruction
    db 'r13',0
    jmp .done
.r14:
    call emit_instruction
    db 'r14',0
    jmp .done
.r15:
    call emit_instruction
    db 'r15',0

.done:
    pop rbp
    ret

emit_char:
    push rbp
    mov rbp, rsp

    mov rax, [output_pos]
    cmp rax, OUTPUT_BUF_SIZE
    jge .overflow
    
    mov byte [output_buffer + rax], dil
    inc qword [output_pos]
    inc qword [output_size]
    xor rax, rax
    jmp .done

.overflow:
    mov rax, 1

.done:
    pop rbp
    ret

;============================================================================
; STRING AND NODE UTILITIES
;============================================================================

emit_string:
    push rbp
    mov rbp, rsp
    push r12

    mov r12, rdi                    ; string pointer

.test_null:
    movzx rax, byte [r12]
    test al, al
    jz .done

    mov dil, al                     ; character for emit_char
    call emit_char

    inc r12
    jmp .test_null

.done:
    pop r12
    pop rbp
    ret

emit_node_name:
    push rbp
    mov rbp, rsp
    push r12

    mov r12, rdi

.copy_loop:
    movzx rax, byte [r12]
    test al, al
    jz .done

    mov dil, al
    call emit_char
    inc r12
    jmp .copy_loop

.done:
    pop r12
    pop rbp
    ret

add_string_constant:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14

    mov r12, rdi                    ; string pointer
    mov r13, [string_pool_pos]

    mov rdi, r12
    call strlen
    mov r14, rax                    ; string length

    inc r14                         ; include null terminator
    add r14, 16                     ; alignment + length prefix

    mov rdi, [string_pool_pos]
    add rdi, string_pool
    mov [rdi], r14                  ; store length

    add rdi, 8
    mov rsi, r12
    call memcpy

    mov rax, r13
    add rax, string_pool

    add [string_pool_pos], r14
    inc qword [string_count]

    pop r14
    pop r13
    pop r12
    pop rbp
    ret

emit_data_section:
    push rbp
    mov rbp, rsp

    call emit_instruction
    db 'section .data',10,0

    cmp qword [string_count], 0
    je .done

    mov rdi, string_pool
    call emit_strings

.done:
    pop rbp
    ret

emit_strings:
    push rbp
    mov rbp, rsp

    cmp qword [string_count], 0
    je .done

    mov rdi, [string_pool_pos]
    test rdi, rdi
    jz .done

    call emit_instruction
    db '.string0: db ',0

    xor r14, r14
.string_loop:
    cmp r14, [string_pool_pos]
    jge .done

    mov rax, string_pool
    add rax, r14
    movzx rdi, byte [rax]
    call emit_number_imm

    inc r14
    cmp r14, [string_pool_pos]
    jge .close

    mov dil, ','
    call emit_char
    jmp .string_loop

.close:
    call emit_instruction
    db ', 0',10,0

.done:
    pop rbp
    ret

int_to_str:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi                    ; buffer
    mov r13, rax                    ; number
    mov r14, 0                      ; digit count

    test r13, r13
    jnz .convert

    mov byte [r12], '0'
    inc r12
    jmp .done

.convert:
    mov rax, r13
    mov r15, 10
.div_loop:
    xor rdx, rdx
    div r15
    add dl, '0'
    push rdx
    inc r14
    test rax, rax
    jnz .div_loop

.print_loop:
    pop rax
    mov [r12], al
    inc r12
    dec r14
    jnz .print_loop

.done:
    mov byte [r12], 0

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

;============================================================================
; LOOP STACK MANAGEMENT
;============================================================================

push_loop:
    push rbp
    mov rbp, rsp

    mov rax, [loop_depth]
    shl rax, 3
    mov [loop_stack + rax], rdi
    inc qword [loop_depth]

    pop rbp
    ret

pop_loop:
    push rbp
    mov rbp, rsp

    dec qword [loop_depth]
    mov rax, [loop_depth]
    shl rax, 3
    mov rax, [loop_stack + rax]

    pop rbp
    ret

;============================================================================
; NODE ACCESS HELPERS
;============================================================================

get_child_count:
    ; Count children in linked list
    push rbp
    mov rbp, rsp
    push rbx
    
    xor rax, rax                    ; count = 0
    mov rbx, [rdi + 8]              ; first child
    test rbx, rbx
    jz .done
    
.count_loop:
    inc rax
    mov rbx, [rbx + 16]             ; next sibling
    test rbx, rbx
    jnz .count_loop
    
.done:
    pop rbx
    pop rbp
    ret

get_child_at:
    ; Get child at index from linked list
    push rbp
    mov rbp, rsp
    push rbx
    push r12

    mov r12, rdi                    ; node
    mov rcx, rsi                    ; index

    mov rbx, [r12 + 8]              ; first child
    test rbx, rbx
    jz .not_found
    
    ; If index is 0, return first child
    test rcx, rcx
    jz .found

.traverse:
    mov rbx, [rbx + 16]             ; next sibling
    test rbx, rbx
    jz .not_found
    dec rcx
    jnz .traverse

.found:
    mov rax, rbx
    jmp .done

.not_found:
    xor rax, rax

.done:
    pop r12
    pop rbx
    pop rbp
    ret

get_node_type_value:
    mov rax, [rdi]
    ret

get_node_line:
    mov eax, [rdi + 32]
    ret

;============================================================================
; CONSTANT STRINGS
;============================================================================

section .data
    emit_str_imm:
        db 'imm',0
    emit_str_str:
        db 'str',0
    debug_enter_codegen: db 'enter codegen', 10, 0
    debug_before_text: db 'before text section', 10, 0
    debug_after_text: db 'after text section', 10, 0
    debug_in_emit_text: db 'in emit_text', 10, 0
    debug_after_first_emit: db 'after first emit', 10, 0
    debug_enter_emit: db 'enter emit', 10, 0
    debug_got_retaddr: db 'got retaddr', 10, 0
    debug_before_loop: db 'before loop', 10, 0
    debug_in_loop: db 'in loop', 10, 0
    debug_about_to_jump: db 'about to jump', 10, 0
    debug_bad_return: db 'bad return addr', 10, 0
    debug_before_externs: db 'before externs', 10, 0
    debug_after_externs: db 'after externs', 10, 0
    debug_before_get_child_count: db 'before get_child_count', 10, 0
    debug_after_get_child_count: db 'after get_child_count', 10, 0
    debug_processing_child: db 'processing child', 10, 0
    debug_next_child: db 'next child', 10, 0
    debug_after_get_type: db 'after get_type', 10, 0
    debug_r12_null: db 'r12 is null', 10, 0
    debug_r12_nonnull: db 'r12 not null', 10, 0
    debug_checking_type: db 'checking type', 10, 0
    debug_gen_func: db 'gen func', 10, 0
    debug_gen_class: db 'gen class', 10, 0
    debug_enter_codegen_init: db 'enter codegen_init', 10, 0
    debug_codegen_init_done: db 'codegen_init done', 10, 0
