bits 64

extern strlen

section .text
global pstr:function, pint:function, pdec:function, pptr:function,\
    phex:function, pbin:function, poct:function, pnbr_base:function


pstr:               ; rdi (char *) string to print
    enter 0, 0

    call strlen wrt ..plt

    mov rsi, rdi    ; set 2nd argument to the string
    mov rdi, 1      ; set 1st argument to stdout
    mov rdx, rax    ; move length to 3rd argument (rdx)
    mov rax, 1      ; write syscall
    syscall

    leave
    ret


pint:
pdec:               ; rdi (int) number to prin
    enter 0, 0
    mov rsi, 10     ; set the base to print the number in (2nd arg)
    mov rdx, [rel dec_digits wrt ..gotpc] ; load the digits of the base to print (3rd arg)
    call pnbr_base
    leave
    ret


pptr:
phex:               ; rdi (size_t) number to print
    enter 0, 0
    push rdi        ; save the number
    mov rdi, [rel hex_begin wrt ..gotpc] ; load "0x" to print it
    call pstr       ; print it (see comment above for the meaning of "it")
    pop rdi         ; restore the number
    mov rsi, 16     ; set the base to print the number in (2nd arg)
    mov rdx, [rel hex_digits wrt ..gotpc] ; load the digits of the base to print (3rd arg)
    call pnbr_base
    leave
    ret


pbin:
    enter 0, 0
    push rdi
    mov rdi, [rel bin_begin wrt ..gotpc] ; load "0b" to print it
    call pstr       ; print it (see comment above for the meaning of "it")
    pop rdi         ; restore the number
    mov rsi, 2      ; set the base to print the number in (2nd arg)
    mov rdx, [rel bin_digits wrt ..gotpc] ; load the digits of the base to print (3rd arg)
    call pnbr_base
    leave
    ret


poct:
    enter 0, 0
    push rdi
    mov rdi, [rel oct_begin wrt ..gotpc] ; load "0o" to print it
    call pstr       ; print it (see comment above for the meaning of "it")
    pop rdi         ; restore the number
    mov rsi, 8      ; set the base to print the number in (2nd arg)
    mov rdx, [rel oct_digits wrt ..gotpc] ; load the digits of the base to print (3rd arg)
    call pnbr_base
    leave
    ret


pnbr_base:          ; rdi (size_t) number, rsi (int) base, rdx (char *) base digits
    enter 0, 0

    push rdx
    cmp rdi, 0      ; test if number is negative or not
    jge .no_minus   ; if not, don't print the minus sign

    push rdi        ; save the number
    push rsi        ; save the base
    mov rdi, [rel minus wrt ..gotpc] ; |
    call pstr                        ; +-> load and print a minus sign
    pop rsi         ; restore the base
    pop rdi         ; restore the number
    neg rdi         ; nb *= -1

.no_minus:
    mov r8, 1       ; fact = 1

.find_max_fact:
    mov rax, rdi    ; put the number in rax
    xor rdx, rdx    ; reset rdx
    div r8          ; divide (rdx:rax) by r8, result in rax, rem in rdx
    pop rdx
    push rdx
    cmp rax, rsi    ; |
    jl .fact_done   ; +-> if number / fact < base, we know the maximum factor
                    ;     that can divide our number
    imul r8, rsi    ; factor *= base
    jmp .find_max_fact

; rdi = number, r8 = max factor
.fact_done:
    cmp r8, 0       ; |
    jle .end        ; +-> check if the factor is exhausted
    xor rdx, rdx
    mov rax, rdi
    div r8          ; get first digit of the number

    pop rdx         ; restore the address of the digit string
    push rdx        ; save the digit string
    push rsi        ; save the base
    mov rsi, rdx    ; load the digit string as 2nd argument for the next write
    add rsi, rax    ; jump to the digit we want to print in the digit string

    push rdi        ; save the number
    mov rdi, 1      ; write on stdout
    mov rdx, 1      ; one byte to write
    mov rax, 1      ; syscall code for write
    syscall
    pop rdi         ; restore original argument
    pop rsi         ; restore the base
    mov rax, rdi    ; rax = nb
    xor rdx, rdx
    div r8          ; nb / factor
    mov rbx, rdi    ; rbx = nb
    sub rbx, rdx    ; rbx -= rdx où rdx = nb % factor
    sub rdi, rbx    ; nb -= rbx où rbx = nb - nb % fact
    xor rdx, rdx
    mov rax, r8
    mov r9, rsi
    div r9          ; divide factor by base
    mov r8, rax     ; and put it back into r8
    jmp .fact_done

.end:
    leave
    ret


section .rodata
global minus, dec_digits, hex_begin, hex_digits, bin_begin, bin_digits,\
    oct_begin, oct_digits
minus db "-", 0

dec_digits db "0123456789", 0

hex_begin db "0x", 0
hex_digits db "0123456789ABCDEF", 0

bin_begin db "0b", 0
bin_digits db "01", 0

oct_begin db "0o", 0
oct_digits db "01234567", 0
