bits 64

extern pstr, pint, pdec, pptr, phex, pbin, poct, sbrk, printf

section .text
global my_malloc:function, my_free:function, dump_mem:function,\
    my_align:function, alloc_new:function, grow_heap:function,\
    dump_values:function, compute_block_size:function

; this is a schema of the metadata used before each data:
; it consist of 16 bytes, the first 8 to store if this block is
; free or not and the next 8 to store the pointer to the next block
;
; the size of the data is grown to be a mutiple of 8 so that
; everything is aligned on a pointer size
;
; +--------+--------+-----     +--------+--------+----
; | isFree |  next  | data ... | isFree |  next  |
; +--------+--------+-----     +--------+--------+----

; %macro get_GOT 0        ; macro to get the global offset table
;     call %%getgot
; %%getgot:
;     pop rbx
;     add rbx, _GLOBAL_OFFSET_TABLE_+$$-%%getgot wrt ..gotpc
; %endmacro

;    macro is used like that:
;    get_GOT
;    mov rcx, top wrt ..gotoff
;    lea rax, [rbx + rcx]


; this function is done
my_align:               ; rdi (size_t): size, rsi (size_t): alignment
    enter 0, 0

    mov rdx, 0          ; reset rdx to contain remainder later
    mov rax, rdi        ; rax will be used as dividend
    mov rcx, rsi        ; rcx used as divisor
    div rcx             ; div with result in rax and remainder in rdx
    cmp rdx, 0          ; |
    je .already_done    ; +-> if no remainder, already aligned

    mov rbx, rdi        ; save original size in rbx
.loop:
    inc rbx             ; incremented each time to be tested as new alignment
    mov rax, rbx        ; setup dividend
    mov rdx, 0          ; setup dividend
    div rcx             ; divide (edx:eax) by rcx
    cmp rdx, 0          ; |
    jne .loop           ; +-> if rest is not 0, we continue
    mov rax, rbx        ; |
    jmp .end            ; +-> else, we've reached the next multiple of alignment

.already_done:
    mov rax, rdi        ; return value is the original parameter since already aligned
.end:
    leave
    ret


; this function is done
compute_block_size:     ; rdi (void *) pointer to a metadata
    enter 0, 0
    add rdi, 8          ; move to the pointer next in the metadata
    cmp qword [rdi], 0  ; |
    je .last_block      ; +-> if on last block, load the end of the break to know the size of the block
    mov rax, [rdi]      ; get the pointer of the next metadata
    jmp .operation

.last_block:
    mov rax, [rel info_brk wrt ..gotpc] ; |
    mov rax, [rax]                      ; +-> load the end of the break

.operation:
    sub rdi, 8          ; move back the pointer to the beginning of the metadata
    sub rax, rdi        ; get the size of the block (including metadata)
    mov rbx, [rel size_metadata wrt ..gotpc] ; |
    sub rax, [rbx]                           ; +-> substract the metadata's size

    leave
    ret


; this function is not done
find_block:             ; rdi (size_t) size of the block we want to find
    enter 0, 0

    mov r8, [rel info_start wrt ..gotpc]
    mov r8, [r8]

    leave
    ret


; this function is done
grow_heap:              ; rdi (size_t): aligned size
    enter 0, 0
    mov r8, [rel size_metadata wrt ..gotpc]
    add rdi, [r8]       ; add the size of the metadata to the size that need to be allocated
    push rdi            ; save the size
    call sbrk wrt ..plt ; after this, rax will be the beginning of the new allocated memory
    pop rdi
    cmp rax, 0          ; \
    je .ret_null        ; +-> if the break is 0 or -1, return null
    cmp rax, -1         ; |
    jne .next           ; /
    mov rax, 0

.ret_null:
    leave
    ret

.next:
    mov qword [rax], 0  ; set the metadata "is_free" to false
    add rax, 8          ; set the "cursor" to the metadata "next"
    mov qword [rax], 0  ; set the metadata "next" to null (0)
    sub rax, 8          ; come back to normal rax
    mov r9, [rel info_start wrt ..gotpc] ; load address of info_start in r9
    cmp qword [r9], 0   ;  |
    jne .start_alrdy_set ; +-> if info_start is not set, we need it the first time
    mov [r9], rax       ; store first break

.start_alrdy_set:
    mov r10, [rel info_end wrt ..gotpc] ; load the address of info_end in r10
    cmp qword [r10], 0  ; |
    je .end_not_set     ; +-> if it's first malloc (no pointer to last block)
                        ;     skip setting the address of the last block of linked list
    mov r11, [r10]      ; get the address of the old last block
    add r11, 8          ; add 8 to use the 2nd part of the metadata
    mov [r11], rax      ; mov the address of the new last block in the 2nd part
                        ; of the metadata of the old last block

.end_not_set:
    mov [r10], rax      ; store the pointer of the new last block in info_end
    mov r11, [rel info_brk wrt ..gotpc] ; load the address of info_brk in r11
    mov [r11], rax      ; |
    add [r11], rdi      ; +-> store the new end of the break in info_brk

    leave
    ret


; this function is not done
alloc_new:              ; rdi (size_t): aligned size
    enter 0, 0
    mov r9, [rel info_start wrt ..gotpc] ; load address of info_start in r9
    ;mov r10, [rel info_end wrt ..gotpc] ; load address of info_end in r10
    cmp qword [r9], 0   ; |
    je .first_time      ; +-> if info_start is null, it's first time using malloc
                        ;       we call grow_heap, else we first try to find a block that fits

    call find_block     ; rdi is already in place
    cmp rax, 0          ; |
    jne .end            ; +-> if no block was found, grow_heap below is called else, leave

.first_time:
    call grow_heap      ; rdi is already in place

.end:                   ; when coming here after find block
    leave               ; or after grow_heap rax is already set
    ret


; this function is done
my_malloc:                 ; rdi (size_t): size of malloc
    enter 0, 0
    cmp rdi, 0          ; |
    jg .not_null        ; +-> is size > 0 does malloc, else return null

    mov rax, 0
    leave
    ret

.not_null:
    mov r8, [rel alignment wrt ..gotpc] ; load address of desired alignment
    mov rsi, [r8]       ; second arugment is the alignment we want
    call my_align
    mov rdi, rax
    call grow_heap

    cmp rax, 0
    je .null
    mov r12, [rel size_metadata wrt ..gotpc]
    add rax, [r12]

    leave
    ret

    ;mov rcx, [rel base wrt ..gotpc]    ; load the address of a data variable from the GOT

.null:
    leave
    ret


; this function is not done
my_free:                ; rdi (void *) pointer to a memory block to be freed
    enter 0, 0
    mov r8, [rel size_metadata wrt ..gotpc] ; load the size of the metadata
    sub rdi, [r8]       ; put the pointer at the beginning of the metadata
    mov qword [rdi], 1  ; set the metadata "is_free" to true
    leave
    ret


;==================;
;    DEBUG PART    ;
;==================;

; this function is done
dump_values:            ; no arguments
    enter 0, 0

    mov rdi, [rel dump_values_str wrt ..gotpc]
    call pstr wrt ..plt ; write "Dump values: "

    mov rdi, [rel info_start_str wrt ..gotpc]
    call pstr wrt ..plt ; write "\tinfo.start = "
    mov r10, [rel info_start wrt ..gotpc]   ; |
    mov rdi, [r10]                          ; +-> load and write the value
    call phex wrt ..plt                     ;       of info_start

    mov rdi, [rel info_end_str wrt ..gotpc]
    call pstr wrt ..plt
    mov r10, [rel info_end wrt ..gotpc]     ; |
    mov rdi, [r10]                          ; +-> load and write the value
    call phex wrt ..plt                     ;       of info_end

    mov rdi, [rel info_brk_str wrt ..gotpc]
    call pstr wrt ..plt
    mov r10, [rel info_brk wrt ..gotpc]     ; |
    mov rdi, [r10]                          ; +-> load and write the value
    call phex wrt ..plt                     ;       of info_brk

    mov rdi, 10         ; put the character '\n' in rdi
    push rdi            ; push it on the stack so that it has an address
    mov rax, 1          ; syscall number for write
    mov rdi, 1          ; we write on stdout
    mov rsi, rsp        ; address of the thing to write (the '\n')
    mov rdx, 1          ; one byte to write
    syscall

    leave
    ret


; this function is done
dump_mem:               ; no arguments
    enter 0, 0
    mov r8, [rel info_start wrt ..gotpc] ; for this function, the address of successive
    push r8                              ;      blocks will be in r8 and in the stack
    xor rcx, rcx        ; |
    push rcx            ; +-> rcx will contain the number of the block to be printed

    ; we pushed two values on the stack, so it looks like that;
    ;
    ; rsp                           rbp
    ;  |                             |
    ;  V                             V
    ;  +--------------+--------------+-------- - - -
    ;  | value of rcx | value of r8  | the stack
    ;  +--------------+--------------+-------- - - -
    ;
    ; To access the value of rcx: [rsp]
    ;        and the value of r8: [rsp+8]

.loop:
    mov rdi, [rel block wrt ..gotpc] ; |
    call pstr wrt ..plt              ; +-> print things (see below the string)
    mov rdi, [rsp]      ; |
    call pint wrt ..plt ; +-> get the counter to print the block number
    add qword [rsp], 1  ; update the counter
    mov rdi, [rel colon_free wrt ..gotpc] ; |
    call pstr wrt ..plt                   ; +-> print things (see the string below)

    mov r9, [rsp+8]
    mov r9, [r9]
    cmp qword [r9], 0
    je .is_not_free

.is_free:
    mov rdi, [rel true wrt ..gotpc] ; |
    call pstr wrt ..plt             ; +-> print things (see the string below)
    jmp .done_free

.is_not_free:
    mov rdi, [rel false wrt ..gotpc] ; |
    call pstr wrt ..plt              ; +-> print things (see string below)

.done_free:
    mov rdi, [rel size wrt ..gotpc] ; |
    call pstr wrt ..plt             ; +-> print things (see string below)

    mov r9, [rsp+8]     ; r9 contains the beginning of the block
    mov r9, [r9]
    add r9, 8           ; move the "cursor" to the second part of the metadata
    mov r10, [r9]       ; r10 contains the address of the next block
    sub r9, 8           ; move the "cursor" back
    cmp r10, 0          ; |
    je .endblock        ; +-> if the adress of next block is null, end of function
    sub r10, r9

    mov r9, [rsp+8]
    add [r9], r10    ; move the adress in r8 to the next block

    mov r11, [rel size_metadata]
    sub r10, r11        ; 
    mov rdi, r10        ; |
    call pint wrt ..plt ; +-> print the size of the block

    mov rdi, [rel nl wrt ..gotpc] ; |
    call pstr wrt ..plt           ; +-> print newline

    jmp .loop

.endblock:
    mov r10, [rel info_brk wrt ..gotpc]
    mov r11, [r10]
    sub r11, r9
    mov r12, [rel size_metadata]
    sub r11, r12
    mov rdi, r11
    call pint wrt ..plt
    ; pop rcx
    ; pop r8

    mov rdi, [rel nl wrt ..gotpc] ; |
    call pstr wrt ..plt           ; +-> print newline

    leave
    ret


; Variables stored in memory, their adresses can be loaded in a register:
;   mov r9, [rel info_start wrt ..gotpc]
section .data
global alignment, new_size
alignment dq 8
new_size dq 0

global info_start, info_end, info_brk
info_start dq 0 ; contains the beginning of the heap
info_end dq 0   ; contains the beginning of the metadata of the last block
info_brk dq 0   ; contains the end of the heap


section .rodata
global size_metadata, block, colon_free, true, false, size, nl
size_metadata dq 16

; These strings are used to print blocks in the debug mode
block: db "Block ", 0
colon_free: db ":", 0xa, 9, "is_free: ", 0
true: db "true", 0xa, 0
false: db "false", 0xa, 0
size: db 9, "size: ", 0
nl: db 0xa, 0

global dump_values_str, info_start_str, info_end_str, info_brk_str
dump_values_str: db "Dump values:", 0
info_start_str: db 0xa, 9, "info.start = ", 0
info_end_str: db 0xa, 9, "info.end   = ", 0
info_brk_str: db 0xa, 9, "info.brk   = ", 0

; Debug blocks are printed like this:
; Block 0:
;     is_free: true
;     size: 16
;
; Block 1:
;     is_free: false
;     size: 24
