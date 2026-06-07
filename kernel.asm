[bits 16]
[org 0x1000]

kernel_start:
    ; Ekranı temizle ve yeşil renk moduna al (0x03 mod, 0x0A parlak yeşil)
    mov ah, 0x00
    mov al, 0x03
    int 0x10

cli_loop:
    mov si, prompt
    call print
    mov di, buffer
    
.get_key:
    mov ah, 0x00
    int 0x16        ; Tuş bekle
    
    cmp al, 13      ; Enter mı?
    je .process
    
    cmp al, 8       ; BACKSPACE mi?
    je .handle_backspace
    
    ; Buffer taşma koruması
    mov cx, di
    sub cx, buffer
    cmp cx, 63
    jge .get_key
    
    mov ah, 0x0e
    mov bl, 0x0a    ; Yeşil yazı
    int 0x10
    stosb
    jmp .get_key

.handle_backspace:
    cmp di, buffer
    je .get_key
    dec di
    mov byte [di], 0
    mov ah, 0x0e
    mov al, 8
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 8
    int 0x10
    jmp .get_key

.process:
    mov byte [di], 0  ; String sonu
    
    mov si, buffer
    cmp byte [si], 0  ; Boş enter kontrolü
    je cli_loop
    
    ; Standart Komut Karşılaştırmaları
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

    mov si, buffer
    mov di, cmd_matrix
    call strcmp
    jnc .do_matrix

    mov si, buffer
    mov di, cmd_reboot
    call strcmp
    jnc .do_reboot

    mov si, buffer
    mov di, cmd_shutdown
    call strcmp
    jnc .do_shutdown

    ; --- PARAMETRELİ KOMUTLAR (ECHO KONTROLÜ) ---
    mov si, buffer
    mov di, cmd_echo
    mov cx, 4         ; 'echo' 4 karakter
.check_echo:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .not_echo
    inc si
    inc di
    loop .check_echo
    jmp .do_echo      ; İlk 4 harf 'echo' ise dallan
.not_echo:

    mov si, buffer
    mov di, cmd_calc
    call strcmp
    jnc .do_calc

    mov si, unknown_msg
    call print
    jmp cli_loop

; --- KOMUT FONKSİYONLARI ---

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

.do_reboot:
    mov si, reboot_msg
    call print
    ; BIOS Sıcak Yeniden Başlatma Kesmesi
    jmp 0xFFFF:0x0000

.do_shutdown:
    mov si, shutdown_msg
    call print
    ; APM (Advanced Power Management) ile Kapatma Dene
    mov ax, 0x5301
    xor bx, bx
    int 0x15         ; APM Bağlan
    mov ax, 0x530e
    mov bx, 0x0001
    mov cx, 0x0102
    int 0x15         ; APM Sürüm Ayarla
    mov ax, 0x5307
    mov bx, 0x0001
    mov cx, 0x0003
    int 0x15         ; Kapat!
    jmp $            ; Eğer APM desteklemiyorsa sistemi asılı bırak

.do_echo:
    ; 'echo ' komutundan sonraki boşluğu atla
    cmp byte [si], ' '
    jne .print_echo
    inc si
.print_echo:
    mov al, 13
    call print_char
    mov al, 10
    call print_char  ; Alt satıra geç
    call print       ; Parametreyi bas
    jmp cli_loop

.do_matrix:
    mov si, matrix_msg
    call print
.matrix_loop:
    mov ah, 0x00
    int 0x1a        ; Timer oku
    mov al, dl
    and al, 0x3F
    add al, 0x21    ; Rastgele ASCII üret
    mov ah, 0x0e
    mov bl, 0x0a
    int 0x10
    mov ah, 0x01
    int 0x16        ; Tuş kontrolü
    jz .matrix_loop
    mov ah, 0x00
    int 0x16        ; Tuşu yut
    jmp cli_loop

.do_calc:
    mov si, calc_msg
    call print
    ; 1. Sayıyı Al (Tek basamaklı kolay test)
    mov ah, 0x00
    int 0x16
    mov byte [num1], al
    mov ah, 0x0e
    int 0x10        ; Ekranda göster
    
    mov al, '+'
    int 0x10        ; Artı işareti bas
    
    ; 2. Sayıyı Al
    mov ah, 0x00
    int 0x16
    mov byte [num2], al
    mov ah, 0x0e
    int 0x10        ; Ekranda göster
    
    mov al, '='
    int 0x10        ; Eşittir bas
    
    ; Hesapla (ASCII -> Sayı -> ASCII dönüşümü)
    mov al, [num1]
    sub al, '0'     ; ASCII'den sayıya
    mov bl, [num2]
    sub bl, '0'
    add al, bl      ; Topla
    add al, '0'     ; Tekrar ASCII yap
    
    mov ah, 0x0e
    int 0x10        ; Sonucu bas
    jmp cli_loop

; --- YARDIMCI FONKSİYONLAR ---

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
    mov bl, 0x0a
.loop:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .loop
.done:
    ret

print_char:
    mov ah, 0x0e
    mov bl, 0x0a
    int 0x10
    ret

; --- DATA SEKTÖRÜ ---
prompt          db 13, 10, 'byteOS > ', 0
cmd_help        db 'help', 0
cmd_clear       db 'clear', 0
cmd_ver         db 'version', 0
cmd_matrix      db 'matrix', 0
cmd_reboot      db 'reboot', 0
cmd_shutdown    db 'shutdown', 0
cmd_echo        db 'echo', 0
cmd_calc        db 'calc', 0

help_msg        db 13, 10, 'Komutlar: help, clear, version, matrix, echo, calc, reboot, shutdown', 13, 10, 0
ver_msg         db 13, 10, 'byteOS v0.2 BETA', 13, 10, 0
unknown_msg     db 13, 10, 'Hata: Bilinmeyen komut!', 13, 10, 0
matrix_msg      db 13, 10, 'Matrix modundan cikmak icin bir tusa basin...', 13, 10, 0
reboot_msg      db 13, 10, 'Sistem yeniden baslatiliyor...', 13, 10, 0
shutdown_msg    db 13, 10, 'Sistem kapatiliyor...', 13, 10, 0
calc_msg        db 13, 10, 'Toplama Sihirbazi (Iki rakam basin): ', 0

num1            db 0
num2            db 0
buffer          times 64 db 0

