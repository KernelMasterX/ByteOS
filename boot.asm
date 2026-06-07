[bits 16]
[org 0x7c00]

start:
    mov [BOOT_DRIVE], dl
    mov bp, 0x9000
    mov sp, bp

    ; BIOS okuma ayarları
    mov bx, 0x1000          ; Kernel'ın yükleneceği adres
    mov ah, 0x02            ; BIOS okuma modu
    mov al, 16              ; İlk 16 sektörü oku (daha güvenli)
    mov ch, 0               ; Silindir 0
    mov cl, 2               ; 2. sektörden başla
    mov dh, 0               ; Kafa 0
    mov dl, [BOOT_DRIVE]
    int 0x13                ; OKU!

    jc disk_error           ; Hata varsa git

    jmp 0x1000              ; Kernel'a atla

disk_error:
    mov si, err_text
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

err_text db 'Disk Error!', 0
BOOT_DRIVE db 0

times 510-($-$$) db 0
dw 0xaa55

