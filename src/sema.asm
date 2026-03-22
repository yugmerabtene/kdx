; KodPix Compiler - Semantic Analysis Module
; x86-64 NASM Assembly - Type checking, symbol resolution, semantic validation

section .data
TYPE_I8 equ 1
TYPE_I16 equ 2
TYPE_I32 equ 3
TYPE_I64 equ 4
TYPE_U8 equ 5
TYPE_U16 equ 6
TYPE_U32 equ 7
TYPE_U64 equ 8
TYPE_F32 equ 9
TYPE_F64 equ 10
TYPE_BOOL equ 11
TYPE_STRING equ 12
TYPE_CHAR equ 13
TYPE_VOID equ 14
TYPE_CLASS equ 15
TYPE_ARRAY equ 16
NODE_PROGRAM equ 0
NODE_CLASS equ 1
NODE_FUNCTION equ 2
NODE_PARAM equ 3
NODE_BLOCK equ 4
NODE_IF equ 5
NODE_WHILE equ 6
NODE_FOR equ 7
NODE_RETURN equ 8
NODE_BREAK equ 9
NODE_CONTINUE equ 10
NODE_LET equ 11
NODE_ASSIGN equ 12
NODE_BINARY equ 13
NODE_UNARY equ 14
NODE_CALL equ 15
NODE_NEW equ 16
NODE_MEMBER equ 17
NODE_IDENT equ 18
NODE_NUMBER equ 19
NODE_STRING equ 20
ERR_OK equ 0
ERR_TYPE_MISMATCH equ 1
ERR_UNDEFINED_VAR equ 2
ERR_DUPLICATE_DEF equ 3
ERR_INVALID_OP equ 4
ERR_INVALID_ACCESS equ 5
ERR_INVALID_COND equ 8
OP_ADD equ 0
OP_SUB equ 1
OP_MUL equ 2
OP_DIV equ 3
OP_MOD equ 4
OP_EQ equ 5
OP_NE equ 6
OP_LT equ 7
OP_LE equ 8
OP_GT equ 9
OP_GE equ 10
OP_AND equ 11
OP_OR equ 12
OP_NEG equ 0
OP_NOT equ 1

section .bss
sema_error_count resq 1
sema_error_msg resq 1
sema_current_class resq 1
sema_current_func resq 1
sema_in_loop resq 1
sema_return_type resq 1
sema_temp_type resq 1

section .text
global sema_init, sema_check_program, sema_check_class, sema_check_function
global sema_check_statement, sema_check_expression, sema_check_types
global sema_add_builtin_symbols, sema_get_error
extern symbol_init, symbol_insert, symbol_lookup, symbol_enter_scope
extern symbol_exit_scope, symbol_get_type, ast_get_child, ast_get_sibling
extern ast_get_type, ast_get_data
extern get_child_at
extern SYM_VARIABLE

sema_init:
    push rbp
    mov rbp, rsp
    xor rax, rax
    mov [sema_error_count], rax
    mov [sema_error_msg], rax
    mov [sema_current_class], rax
    mov [sema_current_func], rax
    mov [sema_in_loop], rax
    mov [sema_return_type], rax
    call symbol_init
    call sema_add_builtin_symbols
    xor rax, rax
    pop rbp
    ret

sema_add_builtin_symbols:
    push rbp
    mov rbp, rsp
    lea rdi, [t8]; mov rsi, TYPE_I8; mov rdx, 0; xor rcx, rcx; call symbol_insert
    lea rdi, [t16]; mov rsi, TYPE_I16; mov rdx, 0; xor rcx, rcx; call symbol_insert
    lea rdi, [t32]; mov rsi, TYPE_I32; mov rdx, 0; xor rcx, rcx; call symbol_insert
    lea rdi, [t64]; mov rsi, TYPE_I64; mov rdx, 0; xor rcx, rcx; call symbol_insert
    lea rdi, [tu8]; mov rsi, TYPE_U8; mov rdx, 0; xor rcx, rcx; call symbol_insert
    lea rdi, [tu16]; mov rsi, TYPE_U16; mov rdx, 0; xor rcx, rcx; call symbol_insert
    lea rdi, [tu32]; mov rsi, TYPE_U32; mov rdx, 0; xor rcx, rcx; call symbol_insert
    lea rdi, [tu64]; mov rsi, TYPE_U64; mov rdx, 0; xor rcx, rcx; call symbol_insert
    lea rdi, [tf32]; mov rsi, TYPE_F32; mov rdx, 0; xor rcx, rcx; call symbol_insert
    lea rdi, [tf64]; mov rsi, TYPE_F64; mov rdx, 0; xor rcx, rcx; call symbol_insert
    lea rdi, [tbool]; mov rsi, TYPE_BOOL; mov rdx, 0; xor rcx, rcx; call symbol_insert
    lea rdi, [tstr]; mov rsi, TYPE_STRING; mov rdx, 0; xor rcx, rcx; call symbol_insert
    lea rdi, [tchar]; mov rsi, TYPE_CHAR; mov rdx, 0; xor rcx, rcx; call symbol_insert
    lea rdi, [tvoid]; mov rsi, TYPE_VOID; mov rdx, 0; xor rcx, rcx; call symbol_insert
    xor rax, rax
    pop rbp
    ret

t8 db 'i8', 0
t16 db 'i16', 0
t32 db 'i32', 0
t64 db 'i64', 0
tu8 db 'u8', 0
tu16 db 'u16', 0
tu32 db 'u32', 0
tu64 db 'u64', 0
tf32 db 'f32', 0
tf64 db 'f64', 0
tbool db 'bool', 0
tstr db 'string', 0
tchar db 'char', 0
tvoid db 'void', 0

sema_check_program:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    mov r12, rdi
    test r12, r12
    je .p0
    call ast_get_child
    mov r12, rax
    test r12, r12
    je .p0
.lp:
    mov rdi, r12
    call ast_get_type
    cmp rax, NODE_CLASS
    je .pcl
    cmp rax, NODE_FUNCTION
    je .pfn
.pnx:
    mov r12, [r12 + 16]
    test r12, r12
    jne .lp
.p0:
    mov rax, [sema_error_count]
    test rax, rax
    jne .pf
    xor rax, rax
    jmp .pd
.pcl:
    mov rdi, r12
    call sema_check_class
    test rax, rax
    jne .pf
    jmp .pnx
.pfn:
    mov rdi, r12
    call sema_check_function
    test rax, rax
    jne .pf
    jmp .pnx
.pf:
    mov rax, 1
.pd:
    pop r12
    pop rbx
    pop rbp
    ret

sema_check_class: push rbp; mov rbp, rsp; push rbx; push r12; mov r12, rdi; mov [sema_current_class], r12; call symbol_enter_scope; mov rdi, r12; call ast_get_child; test rax, rax; je .ce; mov rbx, rax; mov rdi, rbx; mov rsi, TYPE_CLASS; mov rdx, 2; xor rcx, rcx; call symbol_insert; test rax, rax; je .ce; mov r12, [r12 + 16]; test r12, r12; je .cx; .ml: mov rdi, r12; call ast_get_type; cmp rax, NODE_FUNCTION; je .cm; cmp rax, NODE_LET; je .cf; .cmx: mov r12, [r12 + 16]; test r12, r12; jne .ml; jmp .cx; .cm: push r12; call sema_check_function; pop r12; test rax, rax; jne .ce; jmp .cmx; .cf: push r12; call sema_check_field; pop r12; test rax, rax; jne .ce; jmp .cmx; .cx: call symbol_exit_scope; mov qword [sema_current_class], 0; xor rax, rax; jmp .cd; .ce: mov rax, ERR_TYPE_MISMATCH; .cd: pop r12; pop rbx; pop rbp; ret

sema_check_field: push rbp; mov rbp, rsp; mov rdi, [rdi]; call ast_get_child; test rax, rax; je .fe; mov rdi, rax; mov rsi, TYPE_I64; mov rdx, 4; xor rcx, rcx; call symbol_insert; xor rax, rax; pop rbp; ret; .fe: mov rax, ERR_TYPE_MISMATCH; pop rbp; ret

sema_check_function: push rbp; mov rbp, rsp; push rbx; push r12; mov r12, rdi; mov [sema_current_func], r12; call symbol_enter_scope; mov rdi, r12; call ast_get_child; mov rbx, rax; mov rdi, rbx; mov rsi, TYPE_I64; mov rdx, 0; xor rcx, rcx; call symbol_insert; test rax, rax; je .fe; mov qword [sema_return_type], TYPE_I64; mov r12, [rbx + 16]; test r12, r12; je .fb; .pl: mov rdi, r12; call ast_get_child; test rax, rax; je .pn; mov rdi, rax; mov rsi, TYPE_I64; mov rdx, 5; xor rcx, rcx; call symbol_insert; .pn: mov r12, [r12 + 16]; test r12, r12; jne .pl; .fb: mov rdi, [sema_current_func]; call ast_get_sibling; test rax, rax; je .fx; mov rdi, rax; call sema_check_block; test rax, rax; jne .fe; .fx: xor rax, rax; jmp .fxit; .fe: mov rax, ERR_TYPE_MISMATCH; .fxit: call symbol_exit_scope; mov qword [sema_current_func], 0; mov qword [sema_return_type], 0; pop r12; pop rbx; pop rbp; ret

sema_check_block: push rbp; mov rbp, rsp; push rbx; mov rbx, rdi; call ast_get_child; test rax, rax; je .bk; mov rbx, rax; .bl: push rbx; mov rdi, rbx; call sema_check_statement; pop rbx; test rax, rax; jne .bf; mov rbx, [rbx + 16]; test rbx, rbx; jne .bl; .bk: xor rax, rax; jmp .bd; .bf: mov rax, ERR_TYPE_MISMATCH; .bd: pop rbx; pop rbp; ret

sema_check_statement: push rbp; mov rbp, rsp; push rbx; mov rbx, rdi; mov rdi, rbx; call ast_get_type; cmp rax, NODE_BLOCK; je .sblk; cmp rax, NODE_IF; je .sif; cmp rax, NODE_WHILE; je .swh; cmp rax, NODE_FOR; je .sfr; cmp rax, NODE_RETURN; je .sret; cmp rax, NODE_BREAK; je .sbrk; cmp rax, NODE_CONTINUE; je .scnt; cmp rax, NODE_LET; je .slet; cmp rax, NODE_ASSIGN; je .sasn; cmp rax, NODE_CALL; je .scal; jmp .sok; .sblk: mov rdi, rbx; call sema_check_block; jmp .sd; .sif: mov rdi, rbx; call sema_check_if; jmp .sd; .swh: mov rdi, rbx; call sema_check_while; jmp .sd; .sfr: mov rdi, rbx; call sema_check_for; jmp .sd; .sret: mov rdi, rbx; call sema_check_return; jmp .sd; .sbrk: call sema_check_break; jmp .sd; .scnt: call sema_check_continue; jmp .sd; .slet: mov rdi, rbx; call sema_check_let; jmp .sd; .sasn: mov rdi, rbx; call sema_check_assign; jmp .sd; .scal: mov rdi, rbx; call sema_check_call; jmp .sd; .sok: xor rax, rax; .sd: pop rbx; pop rbp; ret

sema_check_if: push rbp; mov rbp, rsp; push r12; mov r12, rdi; mov rdi, [r12 + 8]; test rdi, rdi; je .ie; push r12; call sema_check_expression; pop r12; cmp rax, TYPE_BOOL; jne .ie; mov rdi, [r12 + 16]; test rdi, rdi; je .ie; push r12; call sema_check_statement; pop r12; test rax, rax; jne .ie; mov rdi, [r12 + 16]; mov rdi, [rdi + 16]; test rdi, rdi; je .iok; push r12; call sema_check_statement; pop r12; .iok: xor rax, rax; jmp .id; .ie: mov rax, ERR_INVALID_COND; .id: pop r12; pop rbp; ret

sema_check_while: push rbp; mov rbp, rsp; push r12; mov r12, rdi; mov rdi, [r12 + 8]; test rdi, rdi; je .we; push r12; call sema_check_expression; pop r12; cmp rax, TYPE_BOOL; jne .we; mov qword [sema_in_loop], 1; mov rdi, [r12 + 16]; test rdi, rdi; je .we; push r12; call sema_check_statement; pop r12; mov qword [sema_in_loop], 0; xor rax, rax; jmp .wd; .we: mov qword [sema_in_loop], 0; mov rax, ERR_INVALID_COND; .wd: pop r12; pop rbp; ret

sema_check_for: push rbp; mov rbp, rsp; push r12; mov r12, rdi; call symbol_enter_scope; mov qword [sema_in_loop], 1; mov rdi, [r12 + 8]; test rdi, rdi; je .fc; push r12; call sema_check_statement; pop r12; .fc: mov rdi, [r12 + 16]; test rdi, rdi; je .fe; push r12; call sema_check_expression; pop r12; mov rdi, [r12 + 24]; test rdi, rdi; je .fe; push r12; call sema_check_statement; pop r12; mov qword [sema_in_loop], 0; call symbol_exit_scope; xor rax, rax; jmp .fd; .fe: mov qword [sema_in_loop], 0; call symbol_exit_scope; mov rax, ERR_TYPE_MISMATCH; .fd: pop r12; pop rbp; ret

sema_check_return: push rbp; mov rbp, rsp; mov rbx, [rdi + 8]; test rbx, rbx; je .rv; call sema_check_expression; mov r12, rax; mov rdi, r12; mov rsi, [sema_return_type]; call sema_check_types; test rax, rax; jne .rok; jmp .re; .rv: cmp qword [sema_return_type], TYPE_VOID; je .rok; .re: mov rax, ERR_TYPE_MISMATCH; jmp .rd; .rok: xor rax, rax; .rd: pop rbp; ret

sema_check_break: push rbp; mov rbp, rsp; cmp qword [sema_in_loop], 0; je .be; xor rax, rax; pop rbp; ret; .be: mov rax, ERR_INVALID_OP; pop rbp; ret

sema_check_continue: push rbp; mov rbp, rsp; cmp qword [sema_in_loop], 0; je .ce; xor rax, rax; pop rbp; ret; .ce: mov rax, ERR_INVALID_OP; pop rbp; ret

sema_check_let:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    push r15
    
    mov r12, rdi                    ; let node
    
    ; Get variable name (child 0)
    mov rdi, r12
    mov rsi, 0
    call get_child_at
    mov r13, rax                    ; name node
    test r13, r13
    jz .error
    
    ; Get initializer expression (child 2)
    mov rdi, r12
    mov rsi, 2
    call get_child_at
    mov r14, rax                    ; initializer node
    
    ; Get type annotation (child 1) - may be null
    mov rdi, r12
    mov rsi, 1
    call get_child_at
    mov r15, rax                    ; type node or 0
    
    ; Determine variable type
    test r15, r15
    jz .infer_type                  ; No type annotation, infer from initializer
    
    ; Has explicit type annotation - extract type from type node
    mov rdi, r15
    mov rsi, 24                     ; type name string is at offset 24 in type node
    add rdi, rsi
    mov rsi, rdi                    ; rsi = type name string
    call get_type_id_from_name      ; rax = type ID
    jmp .store_var
    
.infer_type:
    ; No explicit type - infer from initializer expression
    test r14, r14
    jz .default_i64                 ; No initializer, default to i64
    
    ; Check initializer expression type
    mov rdi, r14
    call sema_check_expression      ; rax = type of initializer
    jmp .store_var
    
.default_i64:
    mov rax, TYPE_I64               ; Default to 64-bit integer
    
.store_var:
    ; rax contains the type to use
    ; Insert symbol with name, type, SYM_VARIABLE, PUBLIC visibility
    mov rdi, r13                    ; name node
    add rdi, 24                     ; name string
    mov rsi, rax                    ; type
    mov rdx, SYM_VARIABLE           ; symbol type
    xor rcx, rcx                    ; visibility (PUBLIC)
    call symbol_insert              ; rax = symbol pointer or 0
    
    test rax, rax
    jz .error                       ; Failed to insert symbol
    
    .ok:
    xor rax, rax                    ; Success
    jmp .done
    
.error:
    mov rax, 1                      ; Error
    
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

sema_check_assign: push rbp; mov rbp, rsp; push r12; mov r12, rdi; mov rdi, [r12 + 8]; test rdi, rdi; je .ae; push r12; call sema_check_expression; pop r12; mov rbx, rax; mov rdi, [r12 + 16]; test rdi, rdi; je .ae; push r12; call sema_check_expression; pop r12; mov r12, rax; mov rdi, rbx; mov rsi, r12; call sema_check_types; test rax, rax; jne .aok; .ae: mov rax, ERR_TYPE_MISMATCH; jmp .ad; .aok: xor rax, rax; .ad: pop r12; pop rbp; ret

sema_check_call: push rbp; mov rbp, rsp; push r12; mov r12, rdi; mov rdi, [r12 + 8]; test rdi, rdi; je .ce; mov rdi, [rdi + 24]; call symbol_lookup; test rax, rax; je .ce; call symbol_get_type; mov [sema_temp_type], rax; mov rdi, [r12 + 16]; test rdi, rdi; je .cok; mov rbx, rdi; .cal: test rbx, rbx; je .cok; push rbx; call sema_check_expression; pop rbx; mov rbx, [rbx + 16]; jmp .cal; .cok: mov rax, [sema_temp_type]; jmp .cd; .ce: mov rax, ERR_UNDEFINED_VAR; .cd: pop r12; pop rbp; ret

sema_check_expression: push rbp; mov rbp, rsp; push rbx; push r12; mov r12, rdi; mov rdi, r12; call ast_get_type; cmp rax, NODE_IDENT; je .eid; cmp rax, NODE_NUMBER; je .enum; cmp rax, NODE_STRING; je .estr; cmp rax, NODE_BINARY; je .ebin; cmp rax, NODE_UNARY; je .eun; cmp rax, NODE_CALL; je .ecall; cmp rax, NODE_MEMBER; je .emem; jmp .edef; .eid: mov rdi, [r12 + 24]; call symbol_lookup; test rax, rax; je .eund; call symbol_get_type; jmp .edone; .enum: mov rax, TYPE_I64; jmp .edone; .estr: mov rax, TYPE_STRING; jmp .edone; .ebin: mov rdi, r12; call sema_check_binary; jmp .edone; .eun: mov rdi, r12; call sema_check_unary; jmp .edone; .ecall: mov rdi, r12; call sema_check_call; jmp .edone; .emem: mov rdi, r12; call sema_check_member; jmp .edone; .edef: mov rax, TYPE_I64; jmp .edone; .eund: mov rax, ERR_UNDEFINED_VAR; .edone: pop r12; pop rbx; pop rbp; ret

sema_check_binary: push rbp; mov rbp, rsp; push rbx; push r12; mov r12, rdi; mov rbx, [r12 + 24]; mov rdi, [r12 + 8]; test rdi, rdi; je .bae; call sema_check_expression; mov r12, rax; mov rdi, [r12 + 16]; test rdi, rdi; je .bae; call sema_check_expression; cmp rbx, OP_ADD; je .barith; cmp rbx, OP_SUB; je .barith; cmp rbx, OP_MUL; je .barith; cmp rbx, OP_DIV; je .barith; cmp rbx, OP_MOD; je .barith; cmp rbx, OP_EQ; je .bcmp; cmp rbx, OP_NE; je .bcmp; cmp rbx, OP_LT; je .bcmp; cmp rbx, OP_LE; je .bcmp; cmp rbx, OP_GT; je .bcmp; cmp rbx, OP_GE; je .bcmp; cmp rbx, OP_AND; je .blog; cmp rbx, OP_OR; je .blog; .barith: mov rax, TYPE_I64; jmp .bdone; .bcmp: mov rax, TYPE_BOOL; jmp .bdone; .blog: mov rax, TYPE_BOOL; jmp .bdone; .bae: mov rax, ERR_INVALID_OP; .bdone: pop r12; pop rbx; pop rbp; ret

sema_check_unary: push rbp; mov rbp, rsp; mov rbx, rdi; mov rdi, [rbx + 24]; mov rdi, [rbx + 8]; test rdi, rdi; je .ue; call sema_check_expression; mov rbx, rax; mov rdi, [rbx + 24]; cmp rdi, OP_NEG; je .unum; cmp rdi, OP_NOT; je .ubool; .ue: mov rax, ERR_INVALID_OP; jmp .udone; .unum: mov rax, rbx; jmp .udone; .ubool: mov rax, TYPE_BOOL; .udone: pop rbp; ret

sema_check_member: push rbp; mov rbp, rsp; mov rbx, rdi; mov rdi, [rbx + 8]; test rdi, rdi; je .me; call sema_check_expression; mov rax, TYPE_I64; jmp .mdone; .me: mov rax, ERR_INVALID_ACCESS; .mdone: pop rbp; ret

sema_check_types: push rbp; mov rbp, rsp; cmp rdi, rsi; je .tok; cmp rdi, TYPE_I64; je .tn; cmp rdi, TYPE_I32; je .tn; cmp rdi, TYPE_I16; je .tn; cmp rdi, TYPE_I8; je .tn; cmp rdi, TYPE_U64; je .tn; cmp rdi, TYPE_U32; je .tn; cmp rdi, TYPE_U16; je .tn; cmp rdi, TYPE_U8; je .tn; cmp rdi, TYPE_F32; je .tn; cmp rdi, TYPE_F64; je .tn; jmp .tno; .tn: cmp rsi, TYPE_I64; je .tok; cmp rsi, TYPE_I32; je .tok; cmp rsi, TYPE_I16; je .tok; cmp rsi, TYPE_I8; je .tok; cmp rsi, TYPE_U64; je .tok; cmp rsi, TYPE_U32; je .tok; cmp rsi, TYPE_U16; je .tok; cmp rsi, TYPE_U8; je .tok; cmp rsi, TYPE_F32; je .tok; cmp rsi, TYPE_F64; je .tok; .tno: xor rax, rax; jmp .tdone; .tok: mov rax, 1; .tdone: pop rbp; ret

; Convert type name string to type ID constant
; Input: rsi = pointer to null-terminated type name string
; Output: rax = type ID constant
get_type_id_from_name:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    
    mov r12, rsi
    
    ; Check against known type names
    lea rbx, [str_i8]
    call string_equal
    test rax, rax
    jnz .type_i8
    
    lea rbx, [str_i16]
    call string_equal
    test rax, rax
    jnz .type_i16
    
    lea rbx, [str_i32]
    call string_equal
    test rax, rax
    jnz .type_i32
    
    lea rbx, [str_i64]
    call string_equal
    test rax, rax
    jnz .type_i64
    
    lea rbx, [str_u8]
    call string_equal
    test rax, rax
    jnz .type_u8
    
    lea rbx, [str_u16]
    call string_equal
    test rax, rax
    jnz .type_u16
    
    lea rbx, [str_u32]
    call string_equal
    test rax, rax
    jnz .type_u32
    
    lea rbx, [str_u64]
    call string_equal
    test rax, rax
    jnz .type_u64
    
    lea rbx, [str_f32]
    call string_equal
    test rax, rax
    jnz .type_f32
    
    lea rbx, [str_f64]
    call string_equal
    test rax, rax
    jnz .type_f64
    
    lea rbx, [str_bool]
    call string_equal
    test rax, rax
    jnz .type_bool
    
    lea rbx, [str_string]
    call string_equal
    test rax, rax
    jnz .type_string
    
    lea rbx, [str_char]
    call string_equal
    test rax, rax
    jnz .type_char
    
    lea rbx, [str_void]
    call string_equal
    test rax, rax
    jnz .type_void
    
    ; Default to i64 if unknown
    mov rax, TYPE_I64
    jmp .done
    
.type_i8:
    mov rax, TYPE_I8
    jmp .done
.type_i16:
    mov rax, TYPE_I16
    jmp .done
.type_i32:
    mov rax, TYPE_I32
    jmp .done
.type_i64:
    mov rax, TYPE_I64
    jmp .done
.type_u8:
    mov rax, TYPE_U8
    jmp .done
.type_u16:
    mov rax, TYPE_U16
    jmp .done
.type_u32:
    mov rax, TYPE_U32
    jmp .done
.type_u64:
    mov rax, TYPE_U64
    jmp .done
.type_f32:
    mov rax, TYPE_F32
    jmp .done
.type_f64:
    mov rax, TYPE_F64
    jmp .done
.type_bool:
    mov rax, TYPE_BOOL
    jmp .done
.type_string:
    mov rax, TYPE_STRING
    jmp .done
.type_char:
    mov rax, TYPE_CHAR
    jmp .done
.type_void:
    mov rax, TYPE_VOID
    jmp .done
    
.done:
    pop r12
    pop rbx
    pop rbp
    ret

; Helper: string equality check
; Input: rsi = string1, rbx = string2
; Output: rax = 1 if equal, 0 otherwise
string_equal:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    
    mov r12, rsi
    mov r13, rbx
    xor rax, rax
    
.compare_loop:
    movzx r8, byte [r12 + rax]
    movzx r9, byte [r13 + rax]
    cmp r8, r9
    jne .not_equal
    test r8, r8
    jz .equal
    inc rax
    jmp .compare_loop
    
.equal:
    mov rax, 1
    jmp .done
    
.not_equal:
    xor rax, rax
    
.done:
    pop r13
    pop r12
    pop rbp
    ret

sema_get_error: mov rax, [sema_error_msg]; ret

sema_error: push rbp; mov rbp, rsp; inc qword [sema_error_count]; mov [sema_error_msg], rsi; pop rbp; ret

; Type name strings for get_type_id_from_name
str_i8:      db 'i8', 0
str_i16:     db 'i16', 0
str_i32:     db 'i32', 0
str_i64:     db 'i64', 0
str_u8:      db 'u8', 0
str_u16:     db 'u16', 0
str_u32:     db 'u32', 0
str_u64:     db 'u64', 0
str_f32:     db 'f32', 0
str_f64:     db 'f64', 0
str_bool:    db 'bool', 0
str_string:  db 'str', 0
str_char:    db 'char', 0
str_void:    db 'void', 0