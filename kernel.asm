[bits 16]
[org 0x1000]

kernel_start:
    mov ah, 0x00
    mov al, 0x03
    int 0x10

cli_loop:
    mov si, prompt
    call print
    mov di, buffer
    
.get_key:
    mov ah, 0x00
    int 0x16
    cmp al, 13
    je .process
    mov ah, 0x0e
    int 0x10
    stosb
    jmp .get_key

.process:
    mov byte [di], 0
    mov si, buffer
    mov di, cmd_help
    call strcmp
    jnc .do_help
    mov si, buffer
    mov di, cmd_clear
    call strcmp
    jnc .do_clear
    mov si, buffer
    mov di, cmd_ver
    call strcmp
    jnc .do_version
    mov si, unknown_msg
    call print
    jmp cli_loop

.do_help:
    mov si, help_msg
    call print
    jmp cli_loop
.do_clear:
    mov ah, 0x00
    mov al, 0x03
    int 0x10
    jmp cli_loop
.do_version:
    mov si, ver_msg
    call print
    jmp cli_loop

strcmp:
    push si
    push di
.loop:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .fail
    cmp al, 0
    je .match
    inc si
    inc di
    jmp .loop
.fail:
    pop di
    pop si
    stc
    ret
.match:
    pop di
    pop si
    clc
    ret

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

prompt      db 13, 10, 'byteOS > ', 0
cmd_help    db 'help', 0
cmd_clear   db 'clear', 0
cmd_ver     db 'version', 0
help_msg    db 13, 10, 'Komutlar: help, clear, version', 13, 10, 0
ver_msg     db 13, 10, 'byteOS v0.1', 13, 10, 0
unknown_msg db 13, 10, 'Hata: Bilinmeyen komut!', 13, 10, 0
buffer      times 64 db 0

