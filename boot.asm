[bits 16]
[org 0x7c00]
start:
    mov [BOOT_DRIVE], dl
    mov bp, 0x9000
    mov sp, bp
    xor ax, ax
    mov es, ax
    mov ds, ax
    mov ss, ax
    mov si, msg_loading
    call print
    xor bx, bx
    mov es, bx
    mov bx, 0x1000
    mov cx, 30
    mov di, 2
.read_loop:
    push cx
    push bx
    push di
    mov ah, 0x02
    mov al, 1
    mov cx, di
    mov dh, 0
    mov dl, [BOOT_DRIVE]
    int 0x13
    jc disk_error
    pop di
    pop bx
    pop cx
    add bx, 512
    inc di
    loop .read_loop
    mov si, msg_ok
    call print
    in al, 0x92
    or al, 2
    out 0x92, al
    cli
    lgdt [gdt_descriptor]
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp CODE_SEG:init_pm
[bits 32]
init_pm:
    mov ax, DATA_SEG
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ebp, 0x90000
    mov esp, ebp
    call 0x1000
    jmp $
[bits 16]
disk_error:
    mov si, msg_err
    call print
    jmp $
print:
    mov ah, 0x0e
.loop:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .loop
.done:
    ret
msg_loading db 'Loading byteOS...', 13, 10, 0
msg_ok db 'Kernel loaded! Jumping...', 13, 10, 0
msg_err db 'Disk Error!', 0
BOOT_DRIVE db 0
gdt_start:
    dq 0x0000000000000000
gdt_code:
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 10011010b
    db 11001111b
    db 0x00
gdt_data:
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 10010010b
    db 11001111b
    db 0x00
gdt_end:
gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start
CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start
times 510-($-$$) db 0
dw 0xaa55
