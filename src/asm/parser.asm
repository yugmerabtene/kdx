; KodPix Compiler - Parser Module
; x86-64 NASM Assembly
; Parses .kdx source files into AST

section .data
    ; AST Node Types
    NODE_PROGRAM         equ 1
    NODE_IMPORT          equ 2
    NODE_CLASS           equ 3
    NODE_FUNCTION        equ 4
    NODE_PARAM           equ 5
    NODE_BLOCK           equ 6
    NODE_LET_DECL        equ 7
    NODE_IF_STMT         equ 8
    NODE_WHILE_STMT      equ 9
    NODE_FOR_STMT        equ 10
    NODE_RETURN_STMT     equ 11
    NODE_BREAK_STMT      equ 12
    NODE_EXPR_STMT       equ 13
    NODE_BINARY_EXPR     equ 14
    NODE_UNARY_EXPR      equ 15
    NODE_POSTFIX_EXPR    equ 16
    NODE_CALL_EXPR       equ 17
    NODE_NEW_EXPR        equ 18
    NODE_IDENTIFIER      equ 19
    NODE_NUMBER          equ 20
    NODE_STRING          equ 21
    NODE_BOOL            equ 22
    NODE_NULL            equ 23

    ; Visibility modifiers
    VIS_PUBLIC           equ 1
    VIS_PRIVATE          equ 2
    VIS_PROTECTED        equ 3

    ; Operator types
    OP_ADD               equ 1
    OP_SUB               equ 2
    OP_MUL               equ 3
    OP_DIV               equ 4
    OP_MOD               equ 5
    OP_EQ                equ 6
    OP_NEQ               equ 7
    OP_LT                equ 8
    OP_GT                equ 9
    OP_LE                equ 10
    OP_GE                equ 11
    OP_AND               equ 12
    OP_OR                equ 13
    OP_ASSIGN            equ 14

    ; Node sizes
    NODE_HEADER_SIZE     equ 24
    NODE_SIZE            equ 128
    NODE_POOL_COUNT      equ 512

section .bss
    parser_pos:          resq 1
    parser_line:         resq 1
    parser_col:          resq 1
    parser_error:        resq 1
    parser_error_msg:    resb 256
    ast_root:            resq 1
    node_pool:           resb NODE_SIZE * NODE_POOL_COUNT
    node_count:          resq 1
    node_free_head:      resq 1
    children_buf:        resq 8
    child_count:         resq 1

section .data

section .text
    global parser_init, parse_program, parse_class, parse_function
    global parse_block, parse_statement, parse_expression
    global alloc_node, parser_get_error, parser_error_exit
    global ast_root
    global ast_get_child, ast_get_sibling, ast_get_type, ast_get_data
    extern malloc, free, memcpy
    extern get_token
    extern token_type, token_value, token_line, token_col
    extern TOKEN_EOF, TOKEN_NUMBER, TOKEN_STRING, TOKEN_IDENTIFIER, TOKEN_TYPE
    extern TOKEN_KEYWORD, TOKEN_PUNCTUATION, TOKEN_OPERATOR


; Initialize parser
parser_init:
    push rbp
    mov rbp, rsp
    xor rax, rax
    mov [parser_pos], rax
    mov [parser_line], rax
    mov [parser_col], rax
    mov [parser_error], rax
    mov [ast_root], rax
    mov [node_count], rax
    mov [child_count], rax
    call init_node_pool
    pop rbp
    ret

init_node_pool:
    push rbp
    mov rbp, rsp
    lea rdi, [node_pool]
    mov rsi, NODE_POOL_COUNT
.init_loop:
    mov rax, rdi
    add rax, NODE_SIZE
    mov [rdi], rax
    add rdi, NODE_SIZE
    dec rsi
    jnz .init_loop
    mov qword [rdi - NODE_SIZE], 0
    lea rax, [node_pool]
    mov [node_free_head], rax
    pop rbp
    ret

alloc_node:
    push rbp
    mov rbp, rsp
    mov rax, [node_free_head]
    test rax, rax
    jnz .from_pool
    mov rdi, NODE_SIZE
    call malloc
    test rax, rax
    jz .fail
.from_pool:
    mov rcx, [rax]
    mov [node_free_head], rcx
    mov rdx, rax
    mov rdi, rax
    xor eax, eax
    mov rcx, NODE_SIZE / 8
    rep stosq
    mov rax, rdx
    inc qword [node_count]
    pop rbp
    ret
.fail:
    xor rax, rax
    pop rbp
    ret

set_node_type:
    mov [rdi], rsi
    ret

set_node_line:
    ; Store line at offset 32 (after data field)
    mov [rdi + 32], rsi
    ret

get_node_type:
    mov rax, [rdi]
    ret

get_node_line:
    mov rax, [rdi + 32]
    ret

; Get first child of node
; Input: rdi = node
; Output: rax = first child (0 if none)
ast_get_child:
    mov rax, [rdi + 8]
    ret

; Get next sibling of node
; Input: rdi = node
; Output: rax = next sibling (0 if none)
ast_get_sibling:
    mov rax, [rdi + 16]
    ret

; Get node type
; Input: rdi = node
; Output: rax = node type
ast_get_type:
    mov rax, [rdi]
    ret

; Get node data
; Input: rdi = node
; Output: rax = node data
ast_get_data:
    mov rax, [rdi + 24]
    ret

advance_token:
    call get_token
    mov [token_type], rax
    ret

check_token_type:
    mov rax, [token_type]
    cmp rax, rdi
    sete al
    movzx rax, al
    ret

check_token_keyword:
    push rbp
    mov rbp, rsp
    cmp qword [token_type], TOKEN_KEYWORD
    jne .fail
    lea rdi, [token_value]
    call strcmp
    test rax, rax
    jnz .fail
    pop rbp
    ret
.fail:
    pop rbp
    ret

check_token_ident:
    cmp qword [token_type], TOKEN_IDENTIFIER
    sete al
    movzx rax, al
    ret

expect_keyword:
    push rbp
    mov rbp, rsp
    push rdi
    cmp qword [token_type], TOKEN_KEYWORD
    jne .fail
    lea rdi, [token_value]
    call strcmp
    test rax, rax
    jnz .fail
    call advance_token
    pop rdi
    pop rbp
    ret
.fail:
    mov qword [parser_error], 2
    pop rdi
    pop rbp
    ret

expect_punct:
    push rbp
    mov rbp, rsp
    push rdi
    cmp qword [token_type], TOKEN_PUNCTUATION
    jne .fail
    lea rdi, [token_value]
    call strcmp
    test rax, rax
    jnz .fail
    call advance_token
    pop rdi
    pop rbp
    ret
.fail:
    mov qword [parser_error], 2
    pop rdi
    pop rbp
    ret

expect_token:
    push rbp
    mov rbp, rsp
    mov rsi, [token_type]
    cmp rsi, rdi
    je .match
    mov qword [parser_error], 2
    xor rax, rax
    pop rbp
    ret
.match:
    call advance_token
    mov rax, 1
    pop rbp
    ret

skip_semicolon:
    cmp qword [token_type], TOKEN_PUNCTUATION
    jne .done
    lea rdi, [token_value]
    cmp byte [rdi], ';'
    jne .done
    call advance_token
    mov rax, 1
    jmp .ret
.done:
    xor rax, rax
.ret:
    ret

add_child:
    push rbp
    mov rbp, rsp
     
    mov rcx, [child_count]
    cmp rcx, 8
    jge .done
    mov [children_buf + rcx * 8], rdi
    inc qword [child_count]
     
    .done:
    pop rbp
    ret



build_node:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    mov r12, rdi
    
    ; Link children as linked list
    cmp qword [child_count], 0
    je .no_children
    
    ; Set first child
    mov rax, [children_buf]
    mov [r12 + 8], rax
    
    ; Link remaining children as siblings
    mov rcx, 1
    mov r13, rax  ; r13 = current child
    
.link_loop:
    cmp rcx, [child_count]
    jge .done_linking
    
    ; Get next child
    mov r14, [children_buf + rcx * 8]
    
    ; Set sibling of current child
    mov [r13 + 16], r14
    
    ; Move to next
    mov r13, r14
    inc rcx
    jmp .link_loop

.done_linking:
    ; Last child has no sibling (already 0 from alloc_node)
    jmp .done

.no_children:
    mov qword [r12 + 8], 0  ; No child
    
.done:
    mov qword [child_count], 0
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

parse_program:
    push rbp
    mov rbp, rsp
    call alloc_node
    mov qword [ast_root], rax
    
    ; Check if alloc succeeded
    test rax, rax
    jz .alloc_failed
    
    mov rdi, rax
    mov rsi, NODE_PROGRAM
    call set_node_type
    mov esi, 1
    call set_node_line
    mov qword [child_count], 0
    call get_token
    mov [token_type], rax
    jmp .parse_loop

.alloc_failed:
    xor rax, rax
    pop rbp
    ret
.parse_loop:
    cmp qword [token_type], TOKEN_EOF
    je .done
    cmp qword [token_type], TOKEN_KEYWORD
    jne .parse_error
    lea rdi, [token_value]
    mov rsi, .import_str
    call strcmp
    test rax, rax
    jz .parse_import
    mov rsi, .class_str
    call strcmp
    test rax, rax
    jz .parse_class
    mov rsi, .fn_str
    call strcmp
    test rax, rax
    jz .parse_fn
    mov rsi, .fn_short_str
    call strcmp
    test rax, rax
    jz .parse_fn
    jmp .parse_error
.parse_import:
    call parse_import
    test rax, rax
    jz .parse_error
    mov rdi, rax
    call add_child
    jmp .parse_loop
.parse_class:
    call parse_class
    test rax, rax
    jz .parse_error

    ; Bridge class method entrypoint to top-level function when available.
    ; If class first member is a function, add that function directly.
    mov r10, rax
    mov r11, [r10 + 8]
    test r11, r11
    jz .add_class_node
    mov rdi, r11
    call get_node_type
    cmp rax, NODE_FUNCTION
    jne .add_class_node
    mov rdi, r11
    jmp .add_class_child

.add_class_node:
    mov rdi, r10

.add_class_child:
    call add_child
    jmp .parse_loop
.parse_fn:
    call parse_function
    test rax, rax
    jz .parse_error
    mov rdi, rax
    call add_child
    jmp .parse_loop
.parse_error:
    mov qword [parser_error], 2
.done:
    mov rdi, [ast_root]
    call build_node
    mov rax, [parser_error]
    test rax, rax
    jnz .return_error
    cmp qword [token_type], TOKEN_EOF
    jne .return_error
    xor rax, rax
    pop rbp
    ret
.return_error:
    mov rax, 1
    pop rbp
    ret
.import_str:
    db "import", 0
.class_str:
    db "class", 0
.fn_str:
    db "function", 0
.fn_short_str:
    db "fn", 0

parse_import:
    push rbp
    mov rbp, rsp
    push r12
    lea rsi, [rel .import_kw]
    call expect_keyword
    cmp qword [token_type], TOKEN_STRING
    jne .error
    call alloc_node
    mov r12, rax
    mov rdi, rax
    mov rsi, NODE_IMPORT
    call set_node_type
    mov esi, [token_line]
    call set_node_line
    lea rsi, [token_value]
    mov rdi, r12
    add rdi, 24
    mov rcx, 64
    call memcpy_str
    call advance_token
    call skip_semicolon
    mov rax, r12
    pop r12
    pop rbp
    ret
.error:
    xor rax, rax
    pop r12
    pop rbp
    ret
.import_kw:
    db "import", 0

parse_class:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    cmp qword [token_type], TOKEN_KEYWORD
    jne .error
    lea rdi, [token_value]
    mov rsi, .class_kw
    call strcmp
    test rax, rax
    jnz .error
    call advance_token
    cmp qword [token_type], TOKEN_IDENTIFIER
    jne .error
    call alloc_node
    mov r13, rax
    mov rdi, rax
    mov rsi, NODE_CLASS
    call set_node_type
    mov esi, [token_line]
    call set_node_line
    lea rsi, [token_value]
    mov rdi, r13
    add rdi, 24                     ; Store name at offset 24
    mov rcx, 64
    call memcpy_str
    call advance_token
    lea rsi, [rel .open_brace]
    call expect_punct
    mov qword [child_count], 0
.class_body:
    cmp qword [token_type], TOKEN_PUNCTUATION
    jne .check_vis
    lea rdi, [token_value]
    cmp byte [rdi], '}'
    je .close
.check_vis:
    cmp qword [token_type], TOKEN_KEYWORD
    jne .check_construct
    lea rdi, [token_value]
    mov rsi, .pub_kw
    call strcmp
    jz .parse_func_vis
    mov rsi, .priv_kw
    call strcmp
    jz .parse_func_vis
    mov rsi, .prot_kw
    call strcmp
    jnz .check_construct
.parse_func_vis:
    call advance_token
    jmp .parse_func
.check_construct:
    lea rdi, [token_value]
    mov rsi, .construct_kw
    call strcmp
    jz .parse_construct
.parse_func:
    call parse_function
    test rax, rax
    jz .close
    mov rdi, rax
    call add_child
    jmp .class_body
.parse_construct:
    call parse_constructor
    test rax, rax
    jz .close
    mov rdi, rax
    call add_child
    jmp .class_body
.close:
    lea rsi, [rel .close_brace]
    call expect_punct
    mov rdi, r13
    call build_node
    mov rax, r13
    pop r13
    pop r12
    pop rbp
    ret
.error:
    xor rax, rax
    pop r13
    pop r12
    pop rbp
    ret
.class_kw:
    db "class", 0
.pub_kw:
    db "public", 0
.priv_kw:
    db "private", 0
.prot_kw:
    db "protected", 0
.construct_kw:
    db "_construct", 0
.open_brace:
    db "{", 0
.close_brace:
    db "}", 0

parse_constructor:
    push rbp
    mov rbp, rsp
    cmp qword [token_type], TOKEN_KEYWORD
    jne .error
    lea rdi, [token_value]
    mov rsi, .construct_str
    call strcmp
    test rax, rax
    jnz .error
    call alloc_node
    mov rdi, rax
    mov rsi, NODE_FUNCTION
    call set_node_type
    mov esi, [token_line]
    call set_node_line
    mov qword [rdi + 32], 0
    mov qword [rdi + 40], 0
    mov byte [rdi + 48], 1
    call advance_token
    call parse_params
    test rax, rax
    jz .error
    mov qword [rdi + 32], rax
    call parse_block
    test rax, rax
    jz .error
    mov qword [rdi + 48], rax
    pop rbp
    ret
.error:
    xor rax, rax
    pop rbp
    ret
.construct_str:
    db "_construct", 0

parse_function:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    sub rsp, 16
    mov qword [rbp - 8], 0          ; function node
    mov qword [rbp - 16], 0         ; pre-parsed return type for type-first headers
    xor r13, r13
.check_vis:
    cmp qword [token_type], TOKEN_KEYWORD
    jne .check_header
    lea rdi, [token_value]
    mov rsi, .pub_str
    call strcmp
    jnz .check_priv
    mov r13, VIS_PUBLIC
    call advance_token
    jmp .check_header
.check_priv:
    mov rsi, .priv_str
    call strcmp
    jnz .check_prot
    mov r13, VIS_PRIVATE
    call advance_token
    jmp .check_header
.check_prot:
    mov rsi, .prot_str
    call strcmp
    jnz .check_header
    mov r13, VIS_PROTECTED
    call advance_token

.check_header:
    ; Header forms supported:
    ; 1) function name(params) -> type
    ; 2) function type name(params)
    ; 3) type name(params)              (class method style)

    cmp qword [token_type], TOKEN_KEYWORD
    jne .header_type_first
    lea rdi, [token_value]
    mov rsi, .fn_str
    call strcmp
    test rax, rax
    jz .after_fn_kw
    lea rdi, [token_value]
    mov rsi, .fn_short_str
    call strcmp
    test rax, rax
    jz .after_fn_kw
    jmp .header_type_first

.after_fn_kw:
    call advance_token

    ; Legacy form: function name(...)
    cmp qword [token_type], TOKEN_IDENTIFIER
    je .have_name

    ; New form: function <type> <name>(...)
    call parse_type
    test rax, rax
    jz .error
    mov qword [rbp - 16], rax
    cmp qword [token_type], TOKEN_IDENTIFIER
    jne .error
    jmp .have_name

.header_type_first:
    call parse_type
    test rax, rax
    jz .error
    mov qword [rbp - 16], rax
    cmp qword [token_type], TOKEN_IDENTIFIER
    jne .error

.have_name:
    call alloc_node
    mov r14, rax
    mov qword [rbp - 8], r14
    mov rdi, rax
    mov rsi, NODE_FUNCTION
    call set_node_type
    mov esi, [token_line]
    call set_node_line
    mov qword [rdi + 32], r13
    mov qword [rdi + 40], 0
    mov qword [rdi + 48], 0
    mov byte [rdi + 56], 0
    lea rsi, [token_value]
    mov rdi, r14
    add rdi, 24                     ; Store name at offset 24
    mov rcx, 64
    call memcpy_str
    call advance_token
    call parse_params
    test rax, rax
    jz .error
    mov rdi, qword [rbp - 8]
    mov qword [rdi + 32], rax

    ; If return type was already parsed from type-first header, store it now.
    mov rax, qword [rbp - 16]
    test rax, rax
    jz .check_arrow_return
    mov rdi, qword [rbp - 8]
    mov qword [rdi + 40], rax
    jmp .parse_body

.check_arrow_return:
    ; Check for optional return type "-> type"
    cmp qword [token_type], TOKEN_OPERATOR
    jne .parse_body
    lea rdi, [token_value]
    cmp byte [rdi], '-'
    jne .parse_body

    ; Support both combined "->" and split "-" ">" tokens
    cmp byte [rdi + 1], '>'
    je .arrow_combined
    cmp byte [rdi + 1], 0
    jne .parse_body

    call advance_token
    cmp qword [token_type], TOKEN_OPERATOR
    jne .error
    lea rdi, [token_value]
    cmp byte [rdi], '>'
    jne .error

.arrow_combined:
    call advance_token
    call parse_type
    test rax, rax
    jz .error
    mov rdi, qword [rbp - 8]
    mov qword [rdi + 40], rax

.parse_body:
    call parse_block
    test rax, rax
    jz .error
    mov rdi, qword [rbp - 8]
    mov qword [rdi + 48], rax
    mov rax, qword [rbp - 8]
    add rsp, 16
    pop r14
    pop r13
    pop r12
    pop rbp
    ret
.error:
    xor rax, rax
    add rsp, 16
    pop r14
    pop r13
    pop r12
    pop rbp
    ret
.pub_str:
    db "public", 0
.priv_str:
    db "private", 0
.prot_str:
    db "protected", 0
.fn_str:
    db "function", 0
.fn_short_str:
    db "fn", 0

parse_params:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    cmp qword [token_type], TOKEN_PUNCTUATION
    jne .error
    lea rdi, [token_value]
    cmp byte [rdi], '('
    jne .error
    call advance_token
    call alloc_node
    mov r12, rax
    mov rdi, rax
    mov rsi, NODE_PARAM
    call set_node_type
    xor esi, esi
    mov qword [rdi + 16], rsi
    mov qword [r12 + 8], 0
    xor r13, r13                    ; last param child
    cmp qword [token_type], TOKEN_PUNCTUATION
    jne .check_param
    lea rdi, [token_value]
    cmp byte [rdi], ')'
    je .close
.check_param:
    call parse_single_param
    test rax, rax
    jz .close
    test r13, r13
    jz .append_first
    mov [r13 + 16], rax
    jmp .append_set_last
.append_first:
    mov [r12 + 8], rax
.append_set_last:
    mov r13, rax
.param_loop:
    cmp qword [token_type], TOKEN_PUNCTUATION
    jne .close
    lea rdi, [token_value]
    cmp byte [rdi], ','
    jne .close
    call advance_token
    call parse_single_param
    test rax, rax
    jz .close
    test r13, r13
    jz .append_first_loop
    mov [r13 + 16], rax
    jmp .append_set_last_loop
.append_first_loop:
    mov [r12 + 8], rax
.append_set_last_loop:
    mov r13, rax
    jmp .param_loop
.close:
    cmp qword [token_type], TOKEN_PUNCTUATION
    jne .done
    lea rdi, [token_value]
    cmp byte [rdi], ')'
    jne .done
    call advance_token
    mov rax, r12
    pop r13
    pop r12
    pop rbp
    ret
.done:
    mov qword [parser_error], 2
    xor rax, rax
    pop r13
    pop r12
    pop rbp
    ret
.error:
    xor rax, rax
    pop r13
    pop r12
    pop rbp
    ret

parse_single_param:
    push rbp
    mov rbp, rsp
    push r12
    push r13

    ; New style: type name
    cmp qword [token_type], TOKEN_KEYWORD
    je .type_first
    cmp qword [token_type], TOKEN_TYPE
    je .type_first
    jmp .name_first

.type_first:
    call parse_type
    test rax, rax
    jz .error
    mov r13, rax
    cmp qword [token_type], TOKEN_IDENTIFIER
    jne .error
    call alloc_node
    mov r12, rax
    mov rdi, rax
    mov rsi, NODE_PARAM
    call set_node_type
    mov esi, [token_line]
    call set_node_line
    lea rsi, [token_value]
    mov rdi, r12
    add rdi, 24
    mov rcx, 64
    call memcpy_str
    mov qword [r12 + 40], r13
    call advance_token
    mov rax, r12
    pop r13
    pop r12
    pop rbp
    ret

.name_first:
    cmp qword [token_type], TOKEN_IDENTIFIER
    jne .error
    call alloc_node
    mov r12, rax
    mov rdi, rax
    mov rsi, NODE_PARAM
    call set_node_type
    mov esi, [token_line]
    call set_node_line
    lea rsi, [token_value]
    mov rdi, r12
    add rdi, 24
    mov rcx, 64
    call memcpy_str
    call advance_token
    cmp qword [token_type], TOKEN_PUNCTUATION
    jne .error
    lea rdi, [token_value]
    cmp byte [rdi], ':'
    jne .error
    call advance_token
    call parse_type
    test rax, rax
    jz .error
    mov qword [r12 + 40], rax
    mov rax, r12
    pop r13
    pop r12
    pop rbp
    ret
.error:
    xor rax, rax
    pop r13
    pop r12
    pop rbp
    ret

parse_type:
    push rbp
    mov rbp, rsp
    push r12
    cmp qword [token_type], TOKEN_KEYWORD
    je .alloc
    cmp qword [token_type], TOKEN_TYPE
    je .alloc
    cmp qword [token_type], TOKEN_IDENTIFIER
    jne .error
.alloc:
    call alloc_node
    mov r12, rax
    mov rdi, rax
    xor esi, esi
    mov qword [rdi], rsi
    mov qword [rdi + 32], rsi
    mov qword [rdi + 40], rsi
    mov qword [rdi + 48], rsi
    lea rsi, [token_value]
    mov rdi, r12
    add rdi, 24
    mov rcx, 64
    call memcpy_str
    call advance_token
    mov rax, r12
    pop r12
    pop rbp
    ret
.error:
    xor rax, rax
    pop r12
    pop rbp
    ret

parse_block:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    cmp qword [token_type], TOKEN_PUNCTUATION
    jne .error
    lea rdi, [token_value]
    cmp byte [rdi], '{'
    jne .error
    call advance_token
    call alloc_node
    mov r12, rax
    mov rdi, rax
    mov rsi, NODE_BLOCK
    call set_node_type
    mov esi, [token_line]
    call set_node_line
    mov qword [r12 + 8], 0
    xor r13, r13                    ; last block child
.block_loop:
    cmp qword [token_type], TOKEN_PUNCTUATION
    jne .check_stmt
    lea rdi, [token_value]
    cmp byte [rdi], '}'
    je .close
.check_stmt:
    cmp qword [token_type], TOKEN_EOF
    je .close
    push r13
    call parse_statement
    pop r13
    test rax, rax
    jz .close
    test r13, r13
    jz .append_first
    mov [r13 + 16], rax
    jmp .append_set_last
.append_first:
    mov [r12 + 8], rax
.append_set_last:
    mov r13, rax
    jmp .block_loop
.close:
    cmp qword [token_type], TOKEN_PUNCTUATION
    jne .done
    lea rdi, [token_value]
    cmp byte [rdi], '}'
    jne .done
    call advance_token
    mov rax, r12
    pop r13
    pop r12
    pop rbp
    ret
.done:
    mov qword [parser_error], 2
    xor rax, rax
    pop r13
    pop r12
    pop rbp
    ret
.error:
    xor rax, rax
    pop r13
    pop r12
    pop rbp
    ret

parse_statement:
    push rbp
    mov rbp, rsp
    push r12
    mov r12, rax
    cmp qword [token_type], TOKEN_TYPE
    je .parse_typed
    cmp qword [token_type], TOKEN_KEYWORD
    jne .parse_expr
    lea rdi, [token_value]
    mov rsi, .let_str
    call strcmp
    jz .parse_let
    mov rsi, .if_str
    call strcmp
    jz .parse_if
    mov rsi, .while_str
    call strcmp
    jz .parse_while
    mov rsi, .for_str
    call strcmp
    jz .parse_for
    mov rsi, .return_str
    call strcmp
    jz .parse_return
    mov rsi, .break_str
    call strcmp
    jz .parse_break
    jmp .parse_expr
.parse_let:
    call parse_let_decl
    mov r12, rax
    jmp .done
.parse_typed:
    call parse_typed_decl
    mov r12, rax
    jmp .done
.parse_if:
    call parse_if_stmt
    mov r12, rax
    jmp .done
.parse_while:
    call parse_while_stmt
    mov r12, rax
    jmp .done
.parse_for:
    call parse_for_stmt
    mov r12, rax
    jmp .done
.parse_return:
    call parse_return_stmt
    mov r12, rax
    jmp .done
.parse_break:
    call parse_break_stmt
    mov r12, rax
    jmp .done
.parse_expr:
    call parse_expression
    test rax, rax
    jz .error
    mov r12, rax
    call alloc_node
    mov rdi, rax
    mov rsi, NODE_EXPR_STMT
    call set_node_type
    mov esi, [token_line]
    call set_node_line
    mov qword [rdi + 32], r12
    mov r12, rax
.done:
    call skip_semicolon
    mov rax, r12
    pop r12
    pop rbp
    ret
.error:
    xor rax, rax
    pop r12
    pop rbp
    ret
.let_str:
    db "let", 0
.if_str:
    db "if", 0
.while_str:
    db "while", 0
.for_str:
    db "for", 0
.return_str:
    db "return", 0
.break_str:
    db "break", 0

parse_let_decl:
    push rbp
    mov rbp, rsp
    push r12
    cmp qword [token_type], TOKEN_KEYWORD
    jne .error
    lea rdi, [token_value]
    mov rsi, .let_kw
    call strcmp
    test rax, rax
    jnz .error
    call advance_token
    cmp qword [token_type], TOKEN_IDENTIFIER
    jne .error
    call alloc_node
    mov r12, rax
    mov rdi, rax
    mov rsi, NODE_LET_DECL
    call set_node_type
    mov esi, [token_line]
    call set_node_line
    lea rsi, [token_value]
    mov rdi, r12
    add rdi, 24
    mov rcx, 64
    call memcpy_str
    call advance_token
    cmp qword [token_type], TOKEN_PUNCTUATION
    jne .check_eq
    lea rdi, [token_value]
    cmp byte [rdi], ':'
    jne .check_eq
    call advance_token
    call parse_type
    test rax, rax
    jnz .has_type
    jmp .check_eq
.has_type:
    mov qword [r12 + 40], rax
.check_eq:
    cmp qword [token_type], TOKEN_OPERATOR
    jne .done
    lea rdi, [token_value]
    cmp byte [rdi], '='
    jne .done
    call advance_token
    call parse_expression
    test rax, rax
    jz .done
    mov qword [r12 + 48], rax
.done:
    mov rax, r12
    pop r12
    pop rbp
    ret
.error:
    xor rax, rax
    pop r12
    pop rbp
    ret
.let_kw:
    db "let", 0

parse_typed_decl:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    cmp qword [token_type], TOKEN_TYPE
    jne .error
    call parse_type
    test rax, rax
    jz .error
    mov r13, rax
    cmp qword [token_type], TOKEN_IDENTIFIER
    jne .error
    call alloc_node
    mov r12, rax
    mov rdi, rax
    mov rsi, NODE_LET_DECL
    call set_node_type
    mov esi, [token_line]
    call set_node_line
    lea rsi, [token_value]
    mov rdi, r12
    add rdi, 24
    mov rcx, 64
    call memcpy_str
    mov qword [r12 + 40], r13
    call advance_token
    cmp qword [token_type], TOKEN_OPERATOR
    jne .done
    lea rdi, [token_value]
    cmp byte [rdi], '='
    jne .done
    call advance_token
    call parse_expression
    test rax, rax
    jz .done
    mov qword [r12 + 48], rax
.done:
    mov rax, r12
    pop r13
    pop r12
    pop rbp
    ret
.error:
    xor rax, rax
    pop r13
    pop r12
    pop rbp
    ret

parse_if_stmt:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    cmp qword [token_type], TOKEN_KEYWORD
    jne .error
    lea rdi, [token_value]
    mov rsi, .if_kw
    call strcmp
    test rax, rax
    jnz .error
    call advance_token
    lea rsi, [rel .open_paren]
    call expect_punct
    call parse_expression
    test rax, rax
    jz .error
    mov r12, rax
    lea rsi, [rel .close_paren]
    call expect_punct
    call parse_block
    test rax, rax
    jz .error
    mov r13, rax
    xor r14, r14
    cmp qword [token_type], TOKEN_KEYWORD
    jne .done
    lea rdi, [token_value]
    mov rsi, .else_kw
    call strcmp
    test rax, rax
    jnz .done
    call advance_token
    call parse_block
    test rax, rax
    jz .done
    mov r14, rax
.done:
    call alloc_node
    mov rdi, rax
    mov rsi, NODE_IF_STMT
    call set_node_type
    mov esi, [token_line]
    call set_node_line
    mov qword [rdi + 32], r12
    mov qword [rdi + 40], r13
    mov qword [rdi + 48], r14
    pop r14
    pop r13
    pop r12
    pop rbp
    ret
.error:
    xor rax, rax
    pop r14
    pop r13
    pop r12
    pop rbp
    ret
.if_kw:
    db "if", 0
.else_kw:
    db "else", 0
.open_paren:
    db "(", 0
.close_paren:
    db ")", 0

parse_while_stmt:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    cmp qword [token_type], TOKEN_KEYWORD
    jne .error
    lea rdi, [token_value]
    mov rsi, .while_kw
    call strcmp
    test rax, rax
    jnz .error
    call advance_token
    lea rsi, [rel .open_paren]
    call expect_punct
    call parse_expression
    test rax, rax
    jz .error
    mov r12, rax
    lea rsi, [rel .close_paren]
    call expect_punct
    call parse_block
    test rax, rax
    jz .error
    mov r13, rax
    call alloc_node
    mov rdi, rax
    mov rsi, NODE_WHILE_STMT
    call set_node_type
    mov esi, [token_line]
    call set_node_line
    mov qword [rdi + 32], r12
    mov qword [rdi + 40], r13
    pop r13
    pop r12
    pop rbp
    ret
.error:
    xor rax, rax
    pop r13
    pop r12
    pop rbp
    ret
.while_kw:
    db "while", 0
.open_paren:
    db "(", 0
.close_paren:
    db ")", 0

parse_for_stmt:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    push r15
    cmp qword [token_type], TOKEN_KEYWORD
    jne .error
    lea rdi, [token_value]
    mov rsi, .for_kw
    call strcmp
    test rax, rax
    jnz .error
    call advance_token
    lea rsi, [rel .open_paren]
    call expect_punct
    cmp qword [token_type], TOKEN_TYPE
    je .for_typed_init
    call parse_let_decl
    jmp .for_init_done
.for_typed_init:
    call parse_typed_decl
.for_init_done:
    test rax, rax
    jz .error
    mov r12, rax
    lea rsi, [rel .semi]
    call expect_punct
    call parse_expression
    test rax, rax
    jz .error
    mov r13, rax
    lea rsi, [rel .semi]
    call expect_punct
    call parse_expression
    test rax, rax
    jz .error
    mov r14, rax
    lea rsi, [rel .close_paren]
    call expect_punct
    call parse_block
    test rax, rax
    jz .error
    mov r15, rax
    call alloc_node
    mov rdi, rax
    mov rsi, NODE_FOR_STMT
    call set_node_type
    mov esi, [token_line]
    call set_node_line
    mov qword [rdi + 32], r12
    mov qword [rdi + 40], r13
    mov qword [rdi + 48], r14
    mov qword [rdi + 56], r15
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret
.error:
    xor rax, rax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret
.for_kw:
    db "for", 0
.open_paren:
    db "(", 0
.close_paren:
    db ")", 0
.semi:
    db ";", 0

parse_return_stmt:
    push rbp
    mov rbp, rsp
    push r12
    cmp qword [token_type], TOKEN_KEYWORD
    jne .error
    lea rdi, [token_value]
    mov rsi, .return_kw
    call strcmp
    test rax, rax
    jnz .error
    call advance_token
    call alloc_node
    mov r12, rax
    mov rdi, rax
    mov rsi, NODE_RETURN_STMT
    call set_node_type
    mov esi, [token_line]
    call set_node_line
    mov qword [r12 + 32], 0
    cmp qword [token_type], TOKEN_PUNCTUATION
    jne .parse_expr
    lea rdi, [token_value]
    cmp byte [rdi], ';'
    je .no_expr
    cmp byte [rdi], '}'
    je .no_expr
.parse_expr:
    call parse_expression
    test rax, rax
    jz .no_expr
    mov qword [r12 + 32], rax
.no_expr:
    mov rax, r12
    pop r12
    pop rbp
    ret
.error:
    xor rax, rax
    pop r12
    pop rbp
    ret
.return_kw:
    db "return", 0

parse_break_stmt:
    push rbp
    mov rbp, rsp
    cmp qword [token_type], TOKEN_KEYWORD
    jne .error
    lea rdi, [token_value]
    mov rsi, .break_kw
    call strcmp
    test rax, rax
    jnz .error
    call alloc_node
    mov rdi, rax
    mov rsi, NODE_BREAK_STMT
    call set_node_type
    mov esi, [token_line]
    call set_node_line
    call advance_token
    pop rbp
    ret
.error:
    xor rax, rax
    pop rbp
    ret
.break_kw:
    db "break", 0

parse_expression:
    jmp parse_assignment

parse_assignment:
    push rbp
    mov rbp, rsp
    push r12
    call parse_logical_or
    mov r12, rax
    test r12, r12
    jz .done
    cmp qword [token_type], TOKEN_OPERATOR
    jne .done
    lea rdi, [token_value]
    cmp byte [rdi], '='
    jne .done
    push r12
    call advance_token
    pop r13
    call parse_expression
    test rax, rax
    jz .done
    mov r14, rax
    call alloc_node
    mov rdi, rax
    mov rsi, NODE_BINARY_EXPR
    call set_node_type
    mov dword [rdi + 32], OP_ASSIGN
    mov qword [rdi + 40], r13
    mov qword [rdi + 48], r14
    mov r12, rax
.done:
    mov rax, r12
    pop r12
    pop rbp
    ret

parse_logical_or:
    push rbp
    mov rbp, rsp
    push r12
    call parse_logical_and
    mov r12, rax
    test r12, r12
    jz .done
.loop:
    cmp qword [token_type], TOKEN_OPERATOR
    jne .done
    lea rdi, [token_value]
    cmp byte [rdi], '|'
    jne .done
    cmp byte [rdi + 1], '|'
    jne .done
    push r12
    call advance_token
    pop r13
    call parse_logical_and
    test rax, rax
    jz .done
    mov r14, rax
    call alloc_node
    mov rdi, rax
    mov rsi, NODE_BINARY_EXPR
    call set_node_type
    mov dword [rdi + 32], OP_OR
    mov qword [rdi + 40], r13
    mov qword [rdi + 48], r14
    mov r12, rax
    jmp .loop
.done:
    mov rax, r12
    pop r12
    pop rbp
    ret

parse_logical_and:
    push rbp
    mov rbp, rsp
    push r12
    call parse_equality
    mov r12, rax
    test r12, r12
    jz .done
.loop:
    cmp qword [token_type], TOKEN_OPERATOR
    jne .done
    lea rdi, [token_value]
    cmp byte [rdi], '&'
    jne .done
    cmp byte [rdi + 1], '&'
    jne .done
    push r12
    call advance_token
    pop r13
    call parse_equality
    test rax, rax
    jz .done
    mov r14, rax
    call alloc_node
    mov rdi, rax
    mov rsi, NODE_BINARY_EXPR
    call set_node_type
    mov dword [rdi + 32], OP_AND
    mov qword [rdi + 40], r13
    mov qword [rdi + 48], r14
    mov r12, rax
    jmp .loop
.done:
    mov rax, r12
    pop r12
    pop rbp
    ret

parse_equality:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    call parse_comparison
    mov r12, rax
    test r12, rax
    jz .done
.loop:
    cmp qword [token_type], TOKEN_OPERATOR
    jne .done
    lea rdi, [token_value]
    movzx rax, byte [rdi]
    cmp al, '='
    je .found_eq
    cmp al, '!'
    jne .done
    cmp byte [rdi + 1], '='
    jne .done
    mov r13, OP_NEQ
    jmp .found_op
.found_eq:
    cmp byte [rdi + 1], '='
    jne .done
    mov r13, OP_EQ
.found_op:
    push r12
    push r13
    call advance_token
    pop r13
    pop r12
    call parse_comparison
    test rax, rax
    jz .done
    mov r14, rax
    call alloc_node
    mov rdi, rax
    mov rsi, NODE_BINARY_EXPR
    call set_node_type
    mov dword [rdi + 32], r13d
    mov qword [rdi + 40], r12
    mov qword [rdi + 48], r14
    mov r12, rax
    jmp .loop
.done:
    mov rax, r12
    pop r13
    pop r12
    pop rbp
    ret

parse_comparison:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    call parse_term
    mov r12, rax
    test r12, rax
    jz .done
.loop:
    cmp qword [token_type], TOKEN_OPERATOR
    jne .done
    lea rdi, [token_value]
    movzx rax, byte [rdi]
    cmp al, '<'
    je .found_lt
    cmp al, '>'
    je .found_gt
    cmp al, 'l'
    jne .done
    cmp byte [rdi + 1], 'e'
    jne .done
    mov r13, OP_LE
    jmp .found_op
.found_lt:
    cmp byte [rdi + 1], '='
    je .found_le
    mov r13, OP_LT
    jmp .found_op
.found_le:
    mov r13, OP_LE
    jmp .found_op
.found_gt:
    cmp byte [rdi + 1], '='
    je .found_ge
    mov r13, OP_GT
    jmp .found_op
.found_ge:
    mov r13, OP_GE
.found_op:
    push r12
    push r13
    call advance_token
    pop r13
    pop r12
    call parse_term
    test rax, rax
    jz .done
    mov r14, rax
    call alloc_node
    mov rdi, rax
    mov rsi, NODE_BINARY_EXPR
    call set_node_type
    mov dword [rdi + 32], r13d
    mov qword [rdi + 40], r12
    mov qword [rdi + 48], r14
    mov r12, rax
    jmp .loop
.done:
    mov rax, r12
    pop r13
    pop r12
    pop rbp
    ret

parse_term:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    call parse_factor
    mov r12, rax
    test r12, rax
    jz .done
.loop:
    cmp qword [token_type], TOKEN_OPERATOR
    jne .done
    lea rdi, [token_value]
    movzx rax, byte [rdi]
    cmp al, '+'
    je .found_add
    cmp al, '-'
    je .found_sub
    jmp .done
.found_add:
    mov r13, OP_ADD
    jmp .found_op
.found_sub:
    mov r13, OP_SUB
.found_op:
    push r12
    push r13
    call advance_token
    pop r13
    pop r12
    call parse_factor
    test rax, rax
    jz .done
    mov r14, rax
    call alloc_node
    mov rdi, rax
    mov rsi, NODE_BINARY_EXPR
    call set_node_type
    mov dword [rdi + 32], r13d
    mov qword [rdi + 40], r12
    mov qword [rdi + 48], r14
    mov r12, rax
    jmp .loop
.done:
    mov rax, r12
    pop r13
    pop r12
    pop rbp
    ret

parse_factor:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    call parse_unary
    mov r12, rax
    test r12, rax
    jz .done
.loop:
    cmp qword [token_type], TOKEN_OPERATOR
    jne .done
    lea rdi, [token_value]
    movzx rax, byte [rdi]
    cmp al, '*'
    je .found_mul
    cmp al, '/'
    je .found_div
    cmp al, '%'
    je .found_mod
    jmp .done
.found_mul:
    mov r13, OP_MUL
    jmp .found_op
.found_div:
    mov r13, OP_DIV
    jmp .found_op
.found_mod:
    mov r13, OP_MOD
.found_op:
    push r12
    push r13
    call advance_token
    pop r13
    pop r12
    call parse_unary
    test rax, rax
    jz .done
    mov r14, rax
    call alloc_node
    mov rdi, rax
    mov rsi, NODE_BINARY_EXPR
    call set_node_type
    mov dword [rdi + 32], r13d
    mov qword [rdi + 40], r12
    mov qword [rdi + 48], r14
    mov r12, rax
    jmp .loop
.done:
    mov rax, r12
    pop r13
    pop r12
    pop rbp
    ret

parse_unary:
    push rbp
    mov rbp, rsp
    push r12
    cmp qword [token_type], TOKEN_OPERATOR
    jne .parse_postfix
    lea rdi, [token_value]
    movzx rax, byte [rdi]
    cmp al, '-'
    je .found_neg
    cmp al, '!'
    je .found_not
    jmp .parse_postfix
.found_neg:
    call advance_token
    call parse_unary
    test rax, rax
    jz .error
    mov r12, rax
    call alloc_node
    mov rdi, rax
    mov rsi, NODE_UNARY_EXPR
    call set_node_type
    xor esi, esi
    mov dword [rdi + 32], 0
    mov qword [rdi + 40], r12
    pop r12
    pop rbp
    ret
.found_not:
    call advance_token
    call parse_unary
    test rax, rax
    jz .error
    mov r12, rax
    call alloc_node
    mov rdi, rax
    mov rsi, NODE_UNARY_EXPR
    call set_node_type
    mov dword [rdi + 32], 1
    mov qword [rdi + 40], r12
    pop r12
    pop rbp
    ret
.parse_postfix:
    call parse_postfix
    pop r12
    pop rbp
    ret
.error:
    xor rax, rax
    pop r12
    pop rbp
    ret

parse_postfix:
    push rbp
    mov rbp, rsp
    push r12
    call parse_primary
    mov r12, rax
    test r12, rax
    jz .done
.loop:
    cmp qword [token_type], TOKEN_PUNCTUATION
    jne .check_incdec
    lea rdi, [token_value]
    cmp byte [rdi], '('
    je .parse_call
    jmp .done
.check_incdec:
    cmp qword [token_type], TOKEN_OPERATOR
    jne .done
    lea rdi, [token_value]
    cmp byte [rdi], '+'
    je .check_inc
    cmp byte [rdi], '-'
    jne .done
    cmp byte [rdi + 1], '-'
    jne .done
    jmp .found_postfix
.check_inc:
    cmp byte [rdi + 1], '+'
    jne .done
.found_postfix:
    movzx r14, byte [rdi]
    push r12
    call advance_token
    pop r13
    call alloc_node
    mov rdi, rax
    mov rsi, NODE_POSTFIX_EXPR
    call set_node_type
    cmp r14b, '+'
    jne .postfix_dec
    mov dword [rdi + 32], 1
    jmp .postfix_set_operand
.postfix_dec:
    mov dword [rdi + 32], 2
.postfix_set_operand:
    mov qword [rdi + 40], r13
    mov r12, rax
    jmp .done
.parse_call:
    push r12
    mov rdi, r12
    call parse_call_expr
    pop r13
    test rax, rax
    jz .done
    mov r12, rax
    jmp .loop
.done:
    mov rax, r12
    pop r12
    pop rbp
    ret

parse_call_expr:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    mov r13, rdi
    call alloc_node
    mov r12, rax
    mov rdi, rax
    mov rsi, NODE_CALL_EXPR
    call set_node_type
    mov qword [r12 + 8], 0
    xor r14, r14                    ; last call child
    test r13, r13
    jz .after_callee
    mov [r12 + 8], r13
    mov r14, r13
.after_callee:
    call advance_token
    cmp qword [token_type], TOKEN_PUNCTUATION
    jne .check_args
    lea rdi, [token_value]
    cmp byte [rdi], ')'
    je .close
.check_args:
    push r14
    call parse_expression
    pop r14
    test rax, rax
    jz .close
    test r14, r14
    jz .append_arg_first
    mov [r14 + 16], rax
    jmp .append_arg_set_last
.append_arg_first:
    mov [r12 + 8], rax
.append_arg_set_last:
    mov r14, rax
.args_loop:
    cmp qword [token_type], TOKEN_PUNCTUATION
    jne .close
    lea rdi, [token_value]
    cmp byte [rdi], ','
    jne .close
    call advance_token
    push r14
    call parse_expression
    pop r14
    test rax, rax
    jz .close
    test r14, r14
    jz .append_arg_first_loop
    mov [r14 + 16], rax
    jmp .append_arg_set_last_loop
.append_arg_first_loop:
    mov [r12 + 8], rax
.append_arg_set_last_loop:
    mov r14, rax
    jmp .args_loop
.close:
    cmp qword [token_type], TOKEN_PUNCTUATION
    jne .done
    lea rdi, [token_value]
    cmp byte [rdi], ')'
    jne .done
    call advance_token
    mov rax, r12
    pop r14
    pop r13
    pop r12
    pop rbp
    ret
.done:
    mov qword [parser_error], 2
    xor rax, rax
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

parse_primary:
    push rbp
    mov rbp, rsp
    push r12
    cmp qword [token_type], TOKEN_NUMBER
    je .parse_number
    cmp qword [token_type], TOKEN_STRING
    je .parse_string
    cmp qword [token_type], TOKEN_KEYWORD
    jne .parse_ident
    lea rdi, [token_value]
    mov rsi, .true_str
    call strcmp
    jz .parse_true
    mov rsi, .false_str
    call strcmp
    jz .parse_false
    mov rsi, .null_str
    call strcmp
    jz .parse_null
    mov rsi, .new_str
    call strcmp
    jz .parse_new
    jmp .parse_ident
.parse_number:
    call alloc_node
    mov r12, rax
    mov rdi, rax
    mov rsi, NODE_NUMBER
    call set_node_type
    mov esi, [token_line]
    call set_node_line
    lea rsi, [token_value]
    mov rdi, r12
    add rdi, 24
    mov rcx, 64
    call memcpy_str
    call advance_token
    mov rax, r12
    pop r12
    pop rbp
    ret
.parse_string:
    call alloc_node
    mov r12, rax
    mov rdi, rax
    mov rsi, NODE_STRING
    call set_node_type
    mov esi, [token_line]
    call set_node_line
    lea rsi, [token_value]
    mov rdi, r12
    add rdi, 24
    mov rcx, 64
    call memcpy_str
    call advance_token
    mov rax, r12
    pop r12
    pop rbp
    ret
.parse_true:
    call alloc_node
    mov r12, rax
    mov rdi, rax
    mov rsi, NODE_BOOL
    call set_node_type
    mov byte [rdi + 32], 1
    call advance_token
    mov rax, r12
    pop r12
    pop rbp
    ret
.parse_false:
    call alloc_node
    mov r12, rax
    mov rdi, rax
    mov rsi, NODE_BOOL
    call set_node_type
    mov byte [rdi + 32], 0
    call advance_token
    mov rax, r12
    pop r12
    pop rbp
    ret
.parse_null:
    call alloc_node
    mov r12, rax
    mov rdi, rax
    mov rsi, NODE_NULL
    call set_node_type
    call advance_token
    mov rax, r12
    pop r12
    pop rbp
    ret
.parse_new:
    call advance_token
    cmp qword [token_type], TOKEN_IDENTIFIER
    jne .error
    call alloc_node
    mov r12, rax
    mov rdi, rax
    mov rsi, NODE_NEW_EXPR
    call set_node_type
    mov esi, [token_line]
    call set_node_line
    lea rsi, [token_value]
    mov rdi, r12
    add rdi, 24
    mov rcx, 64
    call memcpy_str
    call advance_token
    cmp qword [token_type], TOKEN_PUNCTUATION
    jne .done_new
    lea rdi, [token_value]
    cmp byte [rdi], '('
    jne .done_new
    call advance_token
    cmp qword [token_type], TOKEN_PUNCTUATION
    jne .parse_new_args
    lea rdi, [token_value]
    cmp byte [rdi], ')'
    je .close_new
.parse_new_args:
    mov qword [r12 + 8], 0
    mov qword [child_count], 0       ; reuse as last-arg pointer
    call parse_expression
    test rax, rax
    jz .close_new
    mov [r12 + 8], rax
    mov [child_count], rax
.new_args_loop:
    cmp qword [token_type], TOKEN_PUNCTUATION
    jne .close_new
    lea rdi, [token_value]
    cmp byte [rdi], ','
    jne .close_new
    call advance_token
    call parse_expression
    test rax, rax
    jz .close_new
    mov rdi, [child_count]
    mov [rdi + 16], rax
    mov [child_count], rax
    jmp .new_args_loop
.close_new:
    cmp qword [token_type], TOKEN_PUNCTUATION
    jne .done_new
    lea rdi, [token_value]
    cmp byte [rdi], ')'
    jne .done_new
    call advance_token
.done_new:
    mov rax, r12
    pop r12
    pop rbp
    ret
.parse_ident:
    cmp qword [token_type], TOKEN_IDENTIFIER
    jne .parse_group
    call alloc_node
    mov r12, rax
    mov rdi, rax
    mov rsi, NODE_IDENTIFIER
    call set_node_type
    mov esi, [token_line]
    call set_node_line
    lea rsi, [token_value]
    mov rdi, r12
    add rdi, 24
    mov rcx, 64
    call memcpy_str
    call advance_token
    mov rax, r12
    pop r12
    pop rbp
    ret
.parse_group:
    cmp qword [token_type], TOKEN_PUNCTUATION
    jne .error
    lea rdi, [token_value]
    cmp byte [rdi], '('
    jne .error
    call advance_token
    call parse_expression
    test rax, rax
    jz .error
    mov r12, rax
    lea rsi, [rel .close_paren]
    call expect_punct
    mov rax, r12
    pop r12
    pop rbp
    ret
.error:
    xor rax, rax
    pop r12
    pop rbp
    ret
.true_str:
    db "true", 0
.false_str:
    db "false", 0
.null_str:
    db "null", 0
.new_str:
    db "new", 0
.close_paren:
    db ")", 0

parser_get_error:
    mov rax, [parser_error_msg]
    ret

parser_error_exit:
    mov rdi, 2
    mov rax, 60
    syscall

strcmp:
    xor rax, rax
.loop:
    movzx r8, byte [rdi + rax]
    movzx r9, byte [rsi + rax]
    cmp r8, r9
    jne .not_equal
    test r8, r8
    jz .equal
    inc rax
    jmp .loop
.not_equal:
    xor rax, rax
    dec rax
    ret
.equal:
    xor rax, rax
    ret

memcpy_str:
    xor rax, rax
.loop:
    cmp rax, rcx
    jge .done
    mov r8b, byte [rsi + rax]
    mov byte [rdi + rax], r8b
    test r8b, r8b
    jz .done
    inc rax
    jmp .loop
.done:
    ret
