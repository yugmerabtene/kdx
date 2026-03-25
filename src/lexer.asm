; KodPix Compiler - Lexer Module
; x86-64 NASM Assembly
; Tokenizes .kdx source files with Java/PHP-like syntax

default rel

section .data
    TOKEN_EOF         equ 0
    TOKEN_KEYWORD     equ 1
    TOKEN_TYPE        equ 2
    TOKEN_IDENTIFIER  equ 3
    TOKEN_NUMBER      equ 4
    TOKEN_STRING      equ 5
    TOKEN_OPERATOR    equ 6
    TOKEN_PUNCTUATION equ 7
    TOKEN_COMMENT     equ 8

    KEYWORD_COUNT     equ 28
    TYPE_COUNT        equ 14

    kw_let        : db 'let',0
    kw_const      : db 'const',0
    kw_var        : db 'var',0
    kw_fn         : db 'fn',0
    kw_function   : db 'function',0
    kw_class      : db 'class',0
    kw_public     : db 'public',0
    kw_private    : db 'private',0
    kw_protected  : db 'protected',0
    kw_static     : db 'static',0
    kw_new        : db 'new',0
    kw_this       : db 'this',0
    kw_if         : db 'if',0
    kw_else       : db 'else',0
    kw_while      : db 'while',0
    kw_for        : db 'for',0
    kw_return     : db 'return',0
    kw_break      : db 'break',0
    kw_continue   : db 'continue',0
    kw_import     : db 'import',0
    kw_extends    : db 'extends',0
    kw_super      : db 'super',0
    kw_null       : db 'null',0
    kw_true       : db 'true',0
    kw_false      : db 'false',0
    kw_construct  : db '_construct',0
    kw_loop       : db 'loop',0
    kw_in         : db 'in',0

    tp_i8         : db 'i8',0
    tp_i16        : db 'i16',0
    tp_i32        : db 'i32',0
    tp_i64        : db 'i64',0
    tp_f32        : db 'f32',0
    tp_f64        : db 'f64',0
    tp_bool       : db 'bool',0
    tp_boolean    : db 'boolean',0
    tp_int        : db 'int',0
    tp_float      : db 'float',0
    tp_string_l   : db 'string',0
    tp_string     : db 'String',0
    tp_void       : db 'void',0
    tp_char       : db 'char',0

    keywords_ptrs:
        dq kw_let, 3
        dq kw_const, 5
        dq kw_var, 3
        dq kw_fn, 2
        dq kw_function, 8
        dq kw_class, 5
        dq kw_public, 6
        dq kw_private, 7
        dq kw_protected, 9
        dq kw_static, 6
        dq kw_new, 3
        dq kw_this, 4
        dq kw_if, 2
        dq kw_else, 4
        dq kw_while, 5
        dq kw_for, 3
        dq kw_return, 6
        dq kw_break, 5
        dq kw_continue, 8
        dq kw_import, 6
        dq kw_extends, 7
        dq kw_super, 5
        dq kw_null, 4
        dq kw_true, 4
        dq kw_false, 5
        dq kw_construct, 10
        dq kw_loop, 4
        dq kw_in, 2

    types_ptrs:
        dq tp_i8, 2
        dq tp_i16, 3
        dq tp_i32, 3
        dq tp_i64, 3
        dq tp_f32, 3
        dq tp_f64, 3
        dq tp_bool, 4
        dq tp_boolean, 7
        dq tp_int, 3
        dq tp_float, 5
        dq tp_string_l, 6
        dq tp_string, 6
        dq tp_void, 4
        dq tp_char, 4

    keywords_ptrs_ptr: dq keywords_ptrs
    types_ptrs_ptr: dq types_ptrs

section .bss
    input_buffer:  resb 16384
    buf_ptr:       resq 1
    input_len:     resq 1

    token_type:    resq 1
    token_value:   resb 512
    token_len:     resq 1
    token_line:    resq 1
    token_col:     resq 1

    pos:           resq 1
    line:          resq 1
    column:        resq 1
    saved_pos:     resq 1
    saved_line:    resq 1
    saved_col:     resq 1

section .text
    global lexer_init, lexer_next_token, lexer_get_value
    global get_token_type, get_token_line, get_token_col, get_token_len
    global lexer_save_pos, lexer_restore_pos
    global token_type, token_value, token_line, token_col, token_len
    global TOKEN_EOF, TOKEN_KEYWORD, TOKEN_TYPE, TOKEN_IDENTIFIER
    global TOKEN_NUMBER, TOKEN_STRING, TOKEN_OPERATOR, TOKEN_PUNCTUATION
    global get_token, input_buffer, buf_ptr, input_len, pos, line, column
    global is_type, is_keyword, keywords_ptrs, types_ptrs
    global keywords_ptrs_ptr, types_ptrs_ptr
    global string_compare_len
    extern malloc, free, memcpy

lexer_init:
    push rbp
    mov rbp, rsp

    mov [buf_ptr], rdi
    mov [input_len], rsi

    lea rax, [keywords_ptrs]
    mov [keywords_ptrs_ptr], rax
    lea rax, [types_ptrs]
    mov [types_ptrs_ptr], rax

    xor rax, rax
    mov [pos], rax
    mov [line], rax
    inc qword [line]
    mov [column], rax
    inc qword [column]
    mov [token_type], rax
    mov [token_len], rax

    pop rbp
    ret

lexer_next_token:
    push rbp
    mov rbp, rsp

    call skip_whitespace
    call skip_comments
    call skip_whitespace

    call is_eof
    test rax, rax
    jnz .eof_reached

    call peek_char
    test rax, rax
    jz .eof_reached

    movzx rdi, al
    call dispatch_token

    mov rax, [token_type]
    jmp .done

.eof_reached:
    mov qword [token_type], TOKEN_EOF
    xor rax, rax

.done:
    pop rbp
    ret

lexer_get_value:
    lea rax, [token_value]
    ret

get_token_type:
    mov rax, [token_type]
    ret

get_token_line:
    mov rax, [token_line]
    ret

get_token_col:
    mov rax, [token_col]
    ret

get_token_len:
    mov rax, [token_len]
    ret

get_token:
    push rbp
    mov rbp, rsp
    call lexer_next_token
    mov rax, [token_type]
    pop rbp
    ret

lexer_save_pos:
    mov rax, [pos]
    mov [saved_pos], rax
    mov rax, [line]
    mov [saved_line], rax
    mov rax, [column]
    mov [saved_col], rax
    ret

lexer_restore_pos:
    mov rax, [saved_pos]
    mov [pos], rax
    mov rax, [saved_line]
    mov [line], rax
    mov rax, [saved_col]
    mov [column], rax
    ret

skip_whitespace:
    push rbp
    mov rbp, rsp
    push rbx

    mov rbx, [buf_ptr]

.loop:
    mov rsi, [pos]
    cmp rsi, [input_len]
    jge .done

    movzx rax, byte [rbx + rsi]

    cmp al, ' '
    je .advance
    cmp al, 9
    je .advance
    cmp al, 13
    je .advance
    cmp al, 10
    je .newline

    jmp .done

.newline:
    inc qword [line]
    mov qword [column], 0
.advance:
    inc qword [pos]
    inc qword [column]
    jmp .loop

.done:
    pop rbx
    pop rbp
    ret

skip_comments:
    push rbp
    mov rbp, rsp
    push rbx

    call peek_char
    cmp al, '/'
    jne .done

    mov rbx, [buf_ptr]
    mov rsi, [pos]
    inc rsi
    cmp rsi, [input_len]
    jge .done

    movzx rax, byte [rbx + rsi]
    cmp al, '/'
    je .line_comment
    cmp al, '*'
    je .block_comment

    jmp .done

.line_comment:
.loop_line:
    call peek_char
    cmp al, 10
    je .done_comment
    cmp al, 0
    je .done_comment
    call next_char
    jmp .loop_line

.block_comment:
    call next_char
    call next_char
.loop_block:
    call peek_char
    cmp al, '*'
    je .check_end
    cmp al, 0
    je .done_comment
    cmp al, 10
    je .newline_skip
    call next_char
    jmp .loop_block

.check_end:
    mov rsi, [pos]
    inc rsi
    cmp rsi, [input_len]
    jge .done_comment
    mov rdx, [buf_ptr]
    movzx rax, byte [rdx + rsi]
    cmp al, '/'
    je .end_block
    call next_char
    jmp .loop_block

.end_block:
    call next_char
    call next_char
    jmp .done_comment

.newline_skip:
    inc qword [line]
    mov qword [column], 0
    call next_char
    jmp .loop_block

.done_comment:
    call skip_whitespace
    call skip_comments

.done:
    pop rbx
    pop rbp
    ret

is_eof:
    mov rsi, [pos]
    mov rax, [input_len]
    cmp rsi, rax
    setge al
    movzx rax, al
    ret

peek_char:
    push rbx
    mov rbx, [buf_ptr]
    mov rsi, [pos]
    cmp rsi, [input_len]
    jge .eof
    movzx rax, byte [rbx + rsi]
    pop rbx
    jmp .done
.eof:
    xor rax, rax
    pop rbx
.done:
    ret

peek_char_debug:
    jmp next_char

next_char:
    push rbx
    mov rbx, [buf_ptr]
    mov rsi, [pos]
    cmp rsi, [input_len]
    jge .done

    movzx rax, byte [rbx + rsi]
    inc qword [pos]
    inc qword [column]
    jmp .return

.done:
    xor rax, rax
.return:
    pop rbx
    ret

dispatch_token:
    push rbp
    mov rbp, rsp

    cmp dil, '"'
    je .string_dq
    cmp dil, 39
    je .string_sq

    cmp dil, '/'
    je .maybe_comment

    cmp dil, '+'
    je .plus_op
    cmp dil, '-'
    je .minus_op
    cmp dil, '*'
    je .multiply_op
    cmp dil, '%'
    je .mod_op
    cmp dil, '='
    je .eq_op
    cmp dil, '!'
    je .neq_op
    cmp dil, '<'
    je .lt_op
    cmp dil, '>'
    je .gt_op
    cmp dil, '&'
    je .and_op
    cmp dil, '|'
    je .or_op
    cmp dil, '^'
    je .xor_op
    cmp dil, '~'
    je .bitnot_op

    cmp dil, '{'
    je .punct
    cmp dil, '}'
    je .punct
    cmp dil, '('
    je .punct
    cmp dil, ')'
    je .punct
    cmp dil, '['
    je .punct
    cmp dil, ']'
    je .punct
    cmp dil, ';'
    je .punct
    cmp dil, ','
    je .punct
    cmp dil, '.'
    je .punct
    cmp dil, ':'
    je .punct
    cmp dil, '?'
    je .punct

    cmp dil, '0'
    jb .check_alpha
    cmp dil, '9'
    jbe .number

.check_alpha:
    cmp dil, 'a'
    jb .check_upper
    cmp dil, 'z'
    jbe .identifier
    cmp dil, '_'
    je .identifier
    cmp dil, '$'
    je .identifier

.check_upper:
    cmp dil, 'A'
    jb .unknown
    cmp dil, 'Z'
    jbe .identifier

.unknown:
    call read_unknown
    jmp .done

.string_dq:
    call read_string_dq
    jmp .done

.string_sq:
    call read_string_sq
    jmp .done

.maybe_comment:
    mov rsi, [pos]
    inc rsi
    cmp rsi, [input_len]
    jge .read_operator

    mov r10, [buf_ptr]
    movzx rax, byte [r10 + rsi]
    cmp al, '/'
    je .line_comment
    cmp al, '*'
    je .block_comment_start

    jmp .read_operator

.line_comment:
    call read_line_comment
    jmp .done

.block_comment_start:
    call read_block_comment
    jmp .done

.read_operator:
    call read_operator
    jmp .done

.plus_op:
    call read_plus_operator
    jmp .done

.minus_op:
    call read_minus_operator
    jmp .done

.multiply_op:
    call read_operator
    jmp .done

.mod_op:
    call read_operator
    jmp .done

.eq_op:
    call read_eq_operator
    jmp .done

.neq_op:
    call read_neq_operator
    jmp .done

.lt_op:
    call read_lt_operator
    jmp .done

.gt_op:
    call read_gt_operator
    jmp .done

.and_op:
    call read_and_operator
    jmp .done

.or_op:
    call read_or_operator
    jmp .done

.xor_op:
    call read_operator
    jmp .done

.bitnot_op:
    call read_operator
    jmp .done

.number:
    call read_number
    jmp .done

.identifier:
    call read_identifier
    jmp .done

.punct:
    call read_punctuation
    jmp .done

.done:
    pop rbp
    ret

read_string_dq:
    push rbp
    mov rbp, rsp

    mov qword [token_type], TOKEN_STRING
    mov rax, [line]
    mov [token_line], rax
    mov rax, [column]
    mov [token_col], rax

    call next_char

    lea rdi, [token_value]
    xor rdx, rdx

.loop:
    call peek_char
    test rax, rax
    jz .error_unterminated
    cmp al, '"'
    je .done_string
    cmp al, 10
    je .error_unterminated

    cmp al, '\'
    jne .store_char

    call next_char
    call peek_char

    cmp al, 'n'
    jne .not_n
    mov al, 10
    jmp .store_escaped
.not_n:
    cmp al, 't'
    jne .not_t
    mov al, 9
    jmp .store_escaped
.not_t:
    cmp al, 'r'
    jne .not_r
    mov al, 13
    jmp .store_escaped
.not_r:
    cmp al, '"'
    jne .not_quote
    jmp .store_escaped
.not_quote:
    cmp al, '\'
    jne .store_escaped

.store_escaped:
    mov byte [rdi + rdx], al
    inc rdx
    call next_char
    jmp .loop

.store_char:
    mov byte [rdi + rdx], al
    inc rdx
    call next_char
    jmp .loop

.done_string:
    call next_char
    mov byte [rdi + rdx], 0
    mov qword [token_len], rdx

    pop rbp
    ret

.error_unterminated:
    mov byte [rdi + rdx], 0
    mov qword [token_len], rdx
    pop rbp
    ret

read_string_sq:
    push rbp
    mov rbp, rsp

    mov qword [token_type], TOKEN_STRING
    mov rax, [line]
    mov [token_line], rax
    mov rax, [column]
    mov [token_col], rax

    call next_char

    lea rdi, [token_value]
    xor rdx, rdx

.loop:
    call peek_char
    test rax, rax
    jz .error_unterminated
    cmp al, 39
    je .done_string
    cmp al, 10
    je .error_unterminated

    cmp al, '\'
    jne .store_char

    call next_char
    call peek_char

    cmp al, 'n'
    jne .not_n
    mov al, 10
    jmp .store_escaped
.not_n:
    cmp al, 't'
    jne .not_t
    mov al, 9
    jmp .store_escaped
.not_t:
    cmp al, 'r'
    jne .not_r
    mov al, 13
    jmp .store_escaped
.not_r:
    cmp al, 39
    jne .not_quote
    jmp .store_escaped
.not_quote:
    cmp al, '\'
    jne .store_escaped

.store_escaped:
    mov byte [rdi + rdx], al
    inc rdx
    call next_char
    jmp .loop

.store_char:
    mov byte [rdi + rdx], al
    inc rdx
    call next_char
    jmp .loop

.done_string:
    call next_char
    mov byte [rdi + rdx], 0
    mov qword [token_len], rdx

    pop rbp
    ret

.error_unterminated:
    mov byte [rdi + rdx], 0
    mov qword [token_len], rdx
    pop rbp
    ret

read_line_comment:
    push rbp
    mov rbp, rsp

    mov qword [token_type], TOKEN_COMMENT
    mov rax, [line]
    mov [token_line], rax
    mov rax, [column]
    mov [token_col], rax

    call next_char
    call next_char

    lea rdi, [token_value]
    xor rdx, rdx

.loop:
    call peek_char
    test rax, rax
    jz .done
    cmp al, 10
    je .done

    mov byte [rdi + rdx], al
    inc rdx
    call next_char
    jmp .loop

.done:
    mov byte [rdi + rdx], 0
    mov qword [token_len], rdx

    pop rbp
    ret

read_block_comment:
    push rbp
    mov rbp, rsp

    mov qword [token_type], TOKEN_COMMENT
    mov rax, [line]
    mov [token_line], rax
    mov rax, [column]
    mov [token_col], rax

    call next_char
    call next_char

    lea rdi, [token_value]
    xor rdx, rdx

.loop:
    call peek_char
    test rax, rax
    jz .done
    cmp al, '*'
    je .check_end

    mov byte [rdi + rdx], al
    inc rdx
    call next_char
    jmp .loop

.check_end:
    mov rsi, [pos]
    inc rsi
    cmp rsi, [input_len]
    jge .done

    mov r10, [buf_ptr]
    movzx rax, byte [r10 + rsi]
    cmp al, '/'
    je .done_comment

    mov byte [rdi + rdx], al
    inc rdx
    call next_char
    jmp .loop

.done_comment:
    call next_char
    call next_char

.done:
    mov byte [rdi + rdx], 0
    mov qword [token_len], rdx

    pop rbp
    ret

read_number:
    push rbp
    mov rbp, rsp

    mov qword [token_type], TOKEN_NUMBER
    mov rax, [line]
    mov [token_line], rax
    mov rax, [column]
    mov [token_col], rax

    lea rdi, [token_value]
    xor rdx, rdx

    call peek_char
    cmp al, '0'
    jne .digit_loop

    mov byte [rdi], '0'
    inc rdx
    call next_char

    mov rsi, [pos]
    cmp rsi, [input_len]
    jge .finish

    call peek_char
    cmp al, 'x'
    je .hex_number
    cmp al, 'X'
    je .hex_number
    cmp al, 'b'
    je .binary_number
    cmp al, 'B'
    je .binary_number
    cmp al, '.'
    je .float_start
    cmp al, 'e'
    je .exponent
    cmp al, 'E'
    je .exponent

    jmp .finish

.hex_number:
    mov byte [rdi], '0'
    inc rdx
    mov byte [rdi + 1], 'x'
    inc rdx
    call next_char
    jmp .hex_loop

.binary_number:
    mov byte [rdi], '0'
    inc rdx
    mov byte [rdi + 1], 'b'
    inc rdx
    call next_char
    jmp .binary_loop

.hex_loop:
    call peek_char
    cmp al, 'a'
    jb .check_hex_digit
    cmp al, 'f'
    jbe .store_digit
    cmp al, 'A'
    jb .finish
    cmp al, 'F'
    jbe .store_digit
    jmp .finish

.check_hex_digit:
    cmp al, '0'
    jb .finish
    cmp al, '9'
    ja .finish

.store_digit:
    mov byte [rdi + rdx], al
    inc rdx
    call next_char
    jmp .hex_loop

.binary_loop:
    call peek_char
    cmp al, '0'
    jb .finish
    cmp al, '1'
    ja .finish

    mov byte [rdi + rdx], al
    inc rdx
    call next_char
    jmp .binary_loop

.float_start:
    mov byte [rdi + rdx], '.'
    inc rdx
    call next_char
    jmp .digit_loop

.digit_loop:
    call peek_char
    cmp al, '0'
    jb .check_special
    cmp al, '9'
    ja .check_special

    mov byte [rdi + rdx], al
    inc rdx
    call next_char
    jmp .digit_loop

.check_special:
    cmp al, '.'
    je .float_continue
    cmp al, 'e'
    je .exponent_start
    cmp al, 'E'
    je .exponent_start

    jmp .finish

.float_continue:
    mov byte [rdi + rdx], '.'
    inc rdx
    call next_char
    jmp .digit_loop

.exponent_start:
    mov byte [rdi + rdx], al
    inc rdx
    call next_char

    call peek_char
    cmp al, '+'
    je .exponent_sign
    cmp al, '-'
    je .exponent_sign
    jmp .exponent_digits

.exponent_sign:
    mov byte [rdi + rdx], al
    inc rdx
    call next_char

.exponent_digits:
    call peek_char
    cmp al, '0'
    jb .finish
    cmp al, '9'
    ja .finish

    mov byte [rdi + rdx], al
    inc rdx
    call next_char
    jmp .exponent_digits

.exponent:
    call next_char
    jmp .exponent_start

.finish:
    mov byte [rdi + rdx], 0
    mov qword [token_len], rdx

    pop rbp
    ret

read_identifier:
    push rbp
    mov rbp, rsp

    mov rax, [line]
    mov [token_line], rax
    mov rax, [column]
    mov [token_col], rax

    lea rdi, [token_value]
    xor rdx, rdx

.loop:
    call peek_char
    test rax, rax
    jz .finish

    cmp al, 'a'
    jb .check_upper
    cmp al, 'z'
    jbe .store
.check_upper:
    cmp al, 'A'
    jb .check_digit
    cmp al, 'Z'
    jbe .store
.check_digit:
    cmp al, '0'
    jb .finish
    cmp al, '9'
    ja .check_special
.store:
    mov byte [rdi + rdx], al
    inc rdx
    call next_char
    jmp .loop

.check_special:
    cmp al, '_'
    je .store
    cmp al, '$'
    je .store
    jmp .finish

.finish:
    mov byte [rdi + rdx], 0
    mov qword [token_len], rdx

    mov qword [token_type], TOKEN_IDENTIFIER
    call is_type
    test rax, rax
    jnz .done

    call is_keyword
    test rax, rax
    jnz .done

    jmp .return

.done:
    mov qword [token_type], rax

.return:
    pop rbp
    ret

is_keyword:
    push rbx
    push rcx
    push rdx
    push rsi

    mov rbx, [keywords_ptrs_ptr]
    mov rcx, KEYWORD_COUNT

.loop:
    test rcx, rcx
    jz .not_found

    mov rsi, [rbx]
    movzx rdx, byte [rbx + 8]

    lea rdi, [token_value]
    push rcx
    push rbx
    call string_compare_len
    pop rbx
    pop rcx
    
    test rax, rax
    jz .found

    add rbx, 16
    dec rcx
    jmp .loop

.not_found:
    xor rax, rax
    jmp .done

.found:
    mov rax, TOKEN_KEYWORD

.done:
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

is_type:
    push rbx
    push rcx
    push rdx
    push rsi

    mov rbx, [types_ptrs_ptr]
    mov rcx, TYPE_COUNT

.loop:
    test rcx, rcx
    jz .not_found

    mov rsi, [rbx]
    movzx rdx, byte [rbx + 8]

    lea rdi, [token_value]
    push rcx
    push rbx
    call string_compare_len
    pop rbx
    pop rcx
    
    test rax, rax
    jz .found

    add rbx, 16
    dec rcx
    jmp .loop

.not_found:
    xor rax, rax
    jmp .done

.found:
    mov rax, TOKEN_TYPE

.done:
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

string_compare_len:
    xor rax, rax
.loop:
    cmp rax, rdx
    je .equal
    movzx rcx, byte [rdi + rax]
    movzx r8, byte [rsi + rax]
    cmp cl, r8b
    jne .not_equal
    inc rax
    jmp .loop
.equal:
    xor rax, rax
    ret
.not_equal:
    mov rax, -1
    ret

read_operator:
    push rbp
    mov rbp, rsp

    mov qword [token_type], TOKEN_OPERATOR
    mov rax, [line]
    mov [token_line], rax
    mov rax, [column]
    mov [token_col], rax

    lea rdi, [token_value]
    call peek_char
    mov byte [rdi], al
    mov byte [rdi + 1], 0

    call next_char
    mov qword [token_len], 1

    pop rbp
    ret

read_plus_operator:
    push rbp
    mov rbp, rsp

    mov qword [token_type], TOKEN_OPERATOR
    mov rax, [line]
    mov [token_line], rax
    mov rax, [column]
    mov [token_col], rax

    mov rsi, [pos]
    inc rsi
    cmp rsi, [input_len]
    jge .single

    lea rdi, [token_value]
    mov r10, [buf_ptr]
    movzx rax, byte [r10 + rsi]
    mov byte [rdi + 1], al

    cmp al, '+'
    je .inc
    cmp al, '='
    je .plus_eq

    jmp .single

.inc:
    mov byte [rdi], '+'
    mov byte [rdi + 1], '+'
    mov byte [rdi + 2], 0
    call next_char
    call next_char
    mov qword [token_len], 2
    jmp .done

.plus_eq:
    mov byte [rdi], '+'
    mov byte [rdi + 1], '='
    mov byte [rdi + 2], 0
    call next_char
    call next_char
    mov qword [token_len], 2
    jmp .done

.single:
    lea rdi, [token_value]
    call peek_char
    mov byte [rdi], al
    mov byte [rdi + 1], 0
    call next_char
    mov qword [token_len], 1

.done:
    pop rbp
    ret

read_minus_operator:
    push rbp
    mov rbp, rsp

    mov qword [token_type], TOKEN_OPERATOR
    mov rax, [line]
    mov [token_line], rax
    mov rax, [column]
    mov [token_col], rax

    mov rsi, [pos]
    inc rsi
    cmp rsi, [input_len]
    jge .single

    lea rdi, [token_value]
    mov r10, [buf_ptr]
    movzx rax, byte [r10 + rsi]
    mov byte [rdi + 1], al

    cmp al, '-'
    je .dec
    cmp al, '='
    je .minus_eq
    cmp al, '>'
    je .arrow

    jmp .single

.dec:
    mov byte [rdi], '-'
    mov byte [rdi + 1], '-'
    mov byte [rdi + 2], 0
    call next_char
    call next_char
    mov qword [token_len], 2
    jmp .done

.minus_eq:
    mov byte [rdi], '-'
    mov byte [rdi + 1], '='
    mov byte [rdi + 2], 0
    call next_char
    call next_char
    mov qword [token_len], 2
    jmp .done

.arrow:
    mov byte [rdi], '-'
    mov byte [rdi + 1], '>'
    mov byte [rdi + 2], 0
    call next_char
    call next_char
    mov qword [token_len], 2
    jmp .done

.single:
    lea rdi, [token_value]
    call peek_char
    mov byte [rdi], al
    mov byte [rdi + 1], 0
    call next_char
    mov qword [token_len], 1

.done:
    pop rbp
    ret

read_eq_operator:
    push rbp
    mov rbp, rsp

    mov qword [token_type], TOKEN_OPERATOR
    mov rax, [line]
    mov [token_line], rax
    mov rax, [column]
    mov [token_col], rax

    mov rsi, [pos]
    inc rsi
    cmp rsi, [input_len]
    jge .single

    lea rdi, [token_value]
    mov r10, [buf_ptr]
    movzx rax, byte [r10 + rsi]
    mov byte [rdi + 1], al

    cmp al, '='
    je .eq_eq

    jmp .single

.eq_eq:
    mov byte [rdi], '='
    mov byte [rdi + 1], '='
    mov byte [rdi + 2], 0
    call next_char
    call next_char
    mov qword [token_len], 2
    jmp .done

.single:
    lea rdi, [token_value]
    call peek_char
    mov byte [rdi], al
    mov byte [rdi + 1], 0
    call next_char
    mov qword [token_len], 1

.done:
    pop rbp
    ret

read_neq_operator:
    push rbp
    mov rbp, rsp

    mov qword [token_type], TOKEN_OPERATOR
    mov rax, [line]
    mov [token_line], rax
    mov rax, [column]
    mov [token_col], rax

    mov rsi, [pos]
    inc rsi
    cmp rsi, [input_len]
    jge .single

    lea rdi, [token_value]
    mov r10, [buf_ptr]
    movzx rax, byte [r10 + rsi]
    mov byte [rdi + 1], al

    cmp al, '='
    je .neq_eq

    jmp .single

.neq_eq:
    mov byte [rdi], '!'
    mov byte [rdi + 1], '='
    mov byte [rdi + 2], 0
    call next_char
    call next_char
    mov qword [token_len], 2
    jmp .done

.single:
    lea rdi, [token_value]
    call peek_char
    mov byte [rdi], al
    mov byte [rdi + 1], 0
    call next_char
    mov qword [token_len], 1

.done:
    pop rbp
    ret

read_lt_operator:
    push rbp
    mov rbp, rsp

    mov qword [token_type], TOKEN_OPERATOR
    mov rax, [line]
    mov [token_line], rax
    mov rax, [column]
    mov [token_col], rax

    mov rsi, [pos]
    inc rsi
    cmp rsi, [input_len]
    jge .single

    lea rdi, [token_value]
    mov r10, [buf_ptr]
    movzx rax, byte [r10 + rsi]
    mov byte [rdi + 1], al

    cmp al, '='
    je .le
    cmp al, '<'
    je .shift_left

    jmp .single

.le:
    mov byte [rdi], '<'
    mov byte [rdi + 1], '='
    mov byte [rdi + 2], 0
    call next_char
    call next_char
    mov qword [token_len], 2
    jmp .done

.shift_left:
    mov byte [rdi], '<'
    mov byte [rdi + 1], '<'
    mov byte [rdi + 2], 0
    call next_char
    call next_char
    mov qword [token_len], 2
    jmp .done

.single:
    lea rdi, [token_value]
    call peek_char
    mov byte [rdi], al
    mov byte [rdi + 1], 0
    call next_char
    mov qword [token_len], 1

.done:
    pop rbp
    ret

read_gt_operator:
    push rbp
    mov rbp, rsp

    mov qword [token_type], TOKEN_OPERATOR
    mov rax, [line]
    mov [token_line], rax
    mov rax, [column]
    mov [token_col], rax

    mov rsi, [pos]
    inc rsi
    cmp rsi, [input_len]
    jge .single

    lea rdi, [token_value]
    mov r10, [buf_ptr]
    movzx rax, byte [r10 + rsi]
    mov byte [rdi + 1], al

    cmp al, '='
    je .ge
    cmp al, '>'
    je .shift_right

    jmp .single

.ge:
    mov byte [rdi], '>'
    mov byte [rdi + 1], '='
    mov byte [rdi + 2], 0
    call next_char
    call next_char
    mov qword [token_len], 2
    jmp .done

.shift_right:
    mov byte [rdi], '>'
    mov byte [rdi + 1], '>'
    mov byte [rdi + 2], 0
    call next_char
    call next_char
    mov qword [token_len], 2
    jmp .done

.single:
    lea rdi, [token_value]
    call peek_char
    mov byte [rdi], al
    mov byte [rdi + 1], 0
    call next_char
    mov qword [token_len], 1

.done:
    pop rbp
    ret

read_and_operator:
    push rbp
    mov rbp, rsp

    mov qword [token_type], TOKEN_OPERATOR
    mov rax, [line]
    mov [token_line], rax
    mov rax, [column]
    mov [token_col], rax

    mov rsi, [pos]
    inc rsi
    cmp rsi, [input_len]
    jge .single

    lea rdi, [token_value]
    mov r10, [buf_ptr]
    movzx rax, byte [r10 + rsi]
    mov byte [rdi + 1], al

    cmp al, '&'
    je .logical_and

    jmp .single

.logical_and:
    mov byte [rdi], '&'
    mov byte [rdi + 1], '&'
    mov byte [rdi + 2], 0
    call next_char
    call next_char
    mov qword [token_len], 2
    jmp .done

.single:
    lea rdi, [token_value]
    call peek_char
    mov byte [rdi], al
    mov byte [rdi + 1], 0
    call next_char
    mov qword [token_len], 1

.done:
    pop rbp
    ret

read_or_operator:
    push rbp
    mov rbp, rsp

    mov qword [token_type], TOKEN_OPERATOR
    mov rax, [line]
    mov [token_line], rax
    mov rax, [column]
    mov [token_col], rax

    mov rsi, [pos]
    inc rsi
    cmp rsi, [input_len]
    jge .single

    lea rdi, [token_value]
    mov r10, [buf_ptr]
    movzx rax, byte [r10 + rsi]
    mov byte [rdi + 1], al

    cmp al, '|'
    je .logical_or

    jmp .single

.logical_or:
    mov byte [rdi], '|'
    mov byte [rdi + 1], '|'
    mov byte [rdi + 2], 0
    call next_char
    call next_char
    mov qword [token_len], 2
    jmp .done

.single:
    lea rdi, [token_value]
    call peek_char
    mov byte [rdi], al
    mov byte [rdi + 1], 0
    call next_char
    mov qword [token_len], 1

.done:
    pop rbp
    ret

read_punctuation:
    push rbp
    mov rbp, rsp

    mov qword [token_type], TOKEN_PUNCTUATION
    mov rax, [line]
    mov [token_line], rax
    mov rax, [column]
    mov [token_col], rax

    lea rdi, [token_value]
    call peek_char
    mov byte [rdi], al
    mov byte [rdi + 1], 0

    call next_char
    mov qword [token_len], 1

    pop rbp
    ret

read_unknown:
    push rbp
    mov rbp, rsp

    mov qword [token_type], TOKEN_OPERATOR
    mov rax, [line]
    mov [token_line], rax
    mov rax, [column]
    mov [token_col], rax

    lea rdi, [token_value]
    call peek_char
    mov byte [rdi], al
    mov byte [rdi + 1], 0
    mov qword [token_len], 1

    call next_char

    pop rbp
    ret
