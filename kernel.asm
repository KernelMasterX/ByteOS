[bits 16]
[org 0x1000]

; ============================================================
;  byteOS v0.4 - Built by kernelmasterX
; ============================================================

kernel_start:
    mov ah, 0x00
    mov al, 0x03
    int 0x10
    mov byte [current_color], 0x0a
    mov byte [hist_count], 0
    call boot_animation
    mov si, welcome_msg
    call print

cli_loop:
    mov byte [current_color], 0x0a
    mov si, prompt
    call print
    mov di, buffer

.get_key:
    mov ah, 0x00
    int 0x16
    cmp al, 13
    je .process
    cmp al, 8
    je .handle_backspace
    mov cx, di
    sub cx, buffer
    cmp cx, 63
    jge .get_key
    mov ah, 0x0e
    mov bl, [current_color]
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
    mov byte [di], 0
    mov si, buffer
    cmp byte [si], 0
    je cli_loop
    call add_history

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

    mov si, buffer
    mov di, cmd_whoami
    call strcmp
    jnc .do_whoami

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

    mov si, buffer
    mov di, cmd_time
    call strcmp
    jnc .do_time

    mov si, buffer
    mov di, cmd_history
    call strcmp
    jnc .do_history

    mov si, buffer
    mov di, cmd_snake
    call strcmp
    jnc .do_snake

    mov si, buffer
    mov di, cmd_calc
    call strcmp
    jnc .do_calc

    ; echo prefix check
    mov si, buffer
    mov di, cmd_echo
    mov cx, 4
.check_echo:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .not_echo
    inc si
    inc di
    loop .check_echo
    jmp .do_echo
.not_echo:

    ; color prefix check
    mov si, buffer
    mov di, cmd_color
    mov cx, 5
.check_color:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .not_color
    inc si
    inc di
    loop .check_color
    jmp .do_color
.not_color:

    mov si, unknown_msg
    call print
    jmp cli_loop

; ============================================================
;  COMMAND HANDLERS
; ============================================================

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

.do_whoami:
    mov si, whoami_msg
    call print
    jmp cli_loop

.do_reboot:
    mov si, reboot_msg
    call print
    jmp 0xFFFF:0x0000

.do_shutdown:
    mov si, shutdown_msg
    call print
    mov ax, 0x5301
    xor bx, bx
    int 0x15
    mov ax, 0x530e
    mov bx, 0x0001
    mov cx, 0x0102
    int 0x15
    mov ax, 0x5307
    mov bx, 0x0001
    mov cx, 0x0003
    int 0x15
    jmp $

.do_time:
    mov ah, 0x02
    int 0x1a
    mov si, time_msg
    call print
    mov al, ch
    call print_bcd
    mov al, ':'
    call print_char_color
    mov al, cl
    call print_bcd
    mov al, ':'
    call print_char_color
    mov al, dh
    call print_bcd
    call print_newline
    jmp cli_loop

.do_history:
    mov si, history_msg
    call print
    mov bl, 0
    mov bh, byte [hist_count]
.hist_loop:
    cmp bl, bh
    jge .hist_done
    mov al, bl
    inc al
    add al, '0'
    call print_char_color
    mov al, '.'
    call print_char_color
    mov al, ' '
    call print_char_color
    xor ah, ah
    mov al, bl
    mov cx, 64
    mul cx
    add ax, history_buf
    mov si, ax
    call print
    call print_newline
    inc bl
    jmp .hist_loop
.hist_done:
    jmp cli_loop

.do_echo:
    cmp byte [si], ' '
    jne .print_echo
    inc si
.print_echo:
    call print_newline
    call print
    call print_newline
    jmp cli_loop

.do_color:
    cmp byte [si], ' '
    jne .color_parse
    inc si
.color_parse:
    mov di, color_green
    call strcmp
    jnc .set_green
    mov si, buffer
    add si, 6
    mov di, color_red
    call strcmp
    jnc .set_red
    mov si, buffer
    add si, 6
    mov di, color_blue
    call strcmp
    jnc .set_blue
    mov si, buffer
    add si, 6
    mov di, color_white
    call strcmp
    jnc .set_white
    mov si, color_err_msg
    call print
    jmp cli_loop
.set_green:
    mov byte [current_color], 0x0a
    mov si, color_ok_msg
    call print
    jmp cli_loop
.set_red:
    mov byte [current_color], 0x0c
    mov si, color_ok_msg
    call print
    jmp cli_loop
.set_blue:
    mov byte [current_color], 0x09
    mov si, color_ok_msg
    call print
    jmp cli_loop
.set_white:
    mov byte [current_color], 0x0f
    mov si, color_ok_msg
    call print
    jmp cli_loop

.do_matrix:
    mov si, matrix_msg
    call print
.matrix_loop:
    mov ah, 0x00
    int 0x1a
    mov al, dl
    and al, 0x3F
    add al, 0x21
    mov ah, 0x0e
    mov bl, 0x0a
    int 0x10
    mov ah, 0x01
    int 0x16
    jz .matrix_loop
    mov ah, 0x00
    int 0x16
    jmp cli_loop

.do_calc:
    mov si, calc_prompt
    call print
    call read_number
    mov word [calc_num1], ax
    mov ah, 0x00
    int 0x16
    mov byte [calc_op], al
    call print_char_color
    call read_number
    mov word [calc_num2], ax
    mov al, '='
    call print_char_color
    mov al, byte [calc_op]
    cmp al, '+'
    je .calc_add
    cmp al, '-'
    je .calc_sub
    cmp al, '*'
    je .calc_mul
    mov si, calc_op_err
    call print
    jmp cli_loop
.calc_add:
    mov ax, word [calc_num1]
    add ax, word [calc_num2]
    jmp .calc_show
.calc_sub:
    mov ax, word [calc_num1]
    sub ax, word [calc_num2]
    jmp .calc_show
.calc_mul:
    mov ax, word [calc_num1]
    mul word [calc_num2]
    jmp .calc_show
.calc_show:
    call print_number
    call print_newline
    jmp cli_loop

; ============================================================
;  SNAKE GAME v2 - Real body
; ============================================================
.do_snake:
    mov ah, 0x00
    mov al, 0x03
    int 0x10

    mov byte [snake_len], 3
    mov byte [snake_dir], 1
    mov byte [snake_alive], 1
    mov word [snake_score], 0

    ; Head at (40,12), body at (39,12),(38,12)
    mov word [snake_hx], 40
    mov word [snake_hy], 12

    ; body_x/body_y store tail segments (index 0 = segment behind head)
    mov byte [body_x + 0], 39
    mov byte [body_y + 0], 12
    mov byte [body_x + 1], 38
    mov byte [body_y + 1], 12

    mov byte [food_x], 20
    mov byte [food_y], 8

    call snake_draw_border
    call snake_draw_all
    call snake_place_food

.snake_loop:
    ; Delay
    mov cx, 0x0018
.sdelay1:
    mov dx, 0xFFFF
.sdelay2:
    dec dx
    jnz .sdelay2
    loop .sdelay1

    ; Key check
    mov ah, 0x01
    int 0x16
    jz .snake_tick
    mov ah, 0x00
    int 0x16
    cmp ah, 0x48
    je .sdir_up
    cmp ah, 0x50
    je .sdir_down
    cmp ah, 0x4B
    je .sdir_left
    cmp ah, 0x4D
    je .sdir_right
    cmp al, 'q'
    je .snake_exit
    jmp .snake_tick
.sdir_up:
    cmp byte [snake_dir], 2
    je .snake_tick
    mov byte [snake_dir], 0
    jmp .snake_tick
.sdir_down:
    cmp byte [snake_dir], 0
    je .snake_tick
    mov byte [snake_dir], 2
    jmp .snake_tick
.sdir_left:
    cmp byte [snake_dir], 1
    je .snake_tick
    mov byte [snake_dir], 3
    jmp .snake_tick
.sdir_right:
    cmp byte [snake_dir], 3
    je .snake_tick
    mov byte [snake_dir], 1

.snake_tick:
    call snake_step
    cmp byte [snake_alive], 0
    je .snake_dead
    jmp .snake_loop

.snake_dead:
    mov ah, 0x02
    mov bh, 0
    mov dh, 12
    mov dl, 25
    int 0x10
    mov si, snake_dead_msg
    mov byte [current_color], 0x0c
    call print
    mov ax, word [snake_score]
    call print_number
    call print_newline
    mov si, snake_anykey
    call print
    mov ah, 0x00
    int 0x16
    mov ah, 0x00
    mov al, 0x03
    int 0x10
    jmp cli_loop

.snake_exit:
    mov ah, 0x00
    mov al, 0x03
    int 0x10
    jmp cli_loop

; ============================================================
;  HELPER FUNCTIONS
; ============================================================

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
    push ax
    push bx
    mov ah, 0x0e
.loop:
    lodsb
    cmp al, 0
    je .done
    mov bl, [current_color]
    int 0x10
    jmp .loop
.done:
    pop bx
    pop ax
    ret

print_char_color:
    push ax
    push bx
    mov ah, 0x0e
    mov bl, [current_color]
    int 0x10
    pop bx
    pop ax
    ret

print_newline:
    push ax
    mov al, 13
    call print_char_color
    mov al, 10
    call print_char_color
    pop ax
    ret

print_bcd:
    push ax
    push bx
    mov bl, al
    shr al, 4
    add al, '0'
    call print_char_color
    mov al, bl
    and al, 0x0f
    add al, '0'
    call print_char_color
    pop bx
    pop ax
    ret

print_number:
    push ax
    push bx
    push cx
    push dx
    mov bx, 10
    mov cx, 0
    cmp ax, 0
    jne .divide
    mov al, '0'
    call print_char_color
    jmp .done_num
.divide:
    cmp ax, 0
    je .print_stack
    xor dx, dx
    div bx
    push dx
    inc cx
    jmp .divide
.print_stack:
    pop dx
    mov al, dl
    add al, '0'
    call print_char_color
    loop .print_stack
.done_num:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

read_number:
    push bx
    push cx
    xor ax, ax
.rn_loop:
    push ax
    mov ah, 0x00
    int 0x16
    cmp al, 13
    je .rn_enter
    cmp al, '+'
    je .rn_op
    cmp al, '-'
    je .rn_op
    cmp al, '*'
    je .rn_op
    cmp al, '0'
    jl .rn_ignore
    cmp al, '9'
    jg .rn_ignore
    call print_char_color
    mov bl, al
    sub bl, '0'
    pop ax
    mov cx, 10
    mul cx
    xor bh, bh
    add ax, bx
    jmp .rn_loop
.rn_ignore:
    pop ax
    jmp .rn_loop
.rn_enter:
    pop ax
    jmp .rn_exit
.rn_op:
    mov byte [calc_op], al
    call print_char_color
    pop ax
.rn_exit:
    pop cx
    pop bx
    ret

; FIX: add_history - correct shift direction (copy src THEN dst, not mix)
add_history:
    push ax
    push bx
    push cx
    push si
    push di
    mov al, byte [hist_count]
    cmp al, 5
    jl .has_room
    ; Shift 1->0, 2->1, 3->2, 4->3
    xor bx, bx
.shift_loop:
    cmp bl, 4
    jge .shift_done
    ; src = history_buf + (bl+1)*64
    xor ah, ah
    mov al, bl
    inc al
    mov cx, 64
    mul cx
    add ax, history_buf
    mov si, ax
    ; dst = history_buf + bl*64
    xor ah, ah
    mov al, bl
    mov cx, 64
    mul cx
    add ax, history_buf
    mov di, ax
    mov cx, 64
    rep movsb
    inc bl
    jmp .shift_loop
.shift_done:
    mov byte [hist_count], 5
    ; Write to slot 4
    mov ax, 4 * 64
    add ax, history_buf
    mov di, ax
    mov si, buffer
    mov cx, 64
    rep movsb
    jmp .hist_add_done
.has_room:
    ; Write to slot hist_count
    xor ah, ah
    mov al, byte [hist_count]
    mov cx, 64
    mul cx
    add ax, history_buf
    mov di, ax
    mov si, buffer
    mov cx, 64
    rep movsb
    inc byte [hist_count]
.hist_add_done:
    pop di
    pop si
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
;  BOOT ANIMATION
; ============================================================
boot_animation:
    push ax
    push bx
    push cx
    mov si, boot_logo
.boot_loop:
    lodsb
    cmp al, 0
    je .boot_done
    mov ah, 0x0e
    mov bl, 0x0a
    int 0x10
    push cx
    mov cx, 0x0003
.dly_out:
    mov bx, 0xFFFF
.dly_in:
    dec bx
    jnz .dly_in
    loop .dly_out
    pop cx
    jmp .boot_loop
.boot_done:
    mov cx, 0x0008
.final_dly:
    push cx
    mov bx, 0xFFFF
.fd_in:
    dec bx
    jnz .fd_in
    pop cx
    loop .final_dly
    mov ah, 0x00
    mov al, 0x03
    int 0x10
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
;  SNAKE BODY FUNCTIONS
; ============================================================

; snake_draw_all: Draw all body segments + head
; body_x/body_y: indices 0..snake_len-2 are tail segments
; head is at snake_hx, snake_hy
snake_draw_all:
    push ax
    push bx
    push cx
    push dx

    ; Draw tail segments
    xor cx, cx
    mov cl, byte [snake_len]
    dec cl                  ; cl = number of tail segments
    cmp cl, 0
    je .draw_head_only
    xor bx, bx
.draw_tail_loop:
    ; Get body_x[bx], body_y[bx] via SI
    mov si, body_x
    add si, bx
    mov dl, byte [si]       ; dl = x
    mov si, body_y
    add si, bx
    mov dh, byte [si]       ; dh = y
    mov ah, 0x02
    push bx
    mov bh, 0
    int 0x10
    pop bx
    mov al, '#'
    mov ah, 0x0e
    push bx
    mov bl, 0x02
    int 0x10
    pop bx
    inc bx
    loop .draw_tail_loop

.draw_head_only:
    ; Draw head
    mov dl, byte [snake_hx]
    mov dh, byte [snake_hy]
    mov ah, 0x02
    mov bh, 0
    int 0x10
    mov al, 'O'
    mov ah, 0x0e
    mov bl, 0x0a
    int 0x10

    pop dx
    pop cx
    pop bx
    pop ax
    ret

; snake_erase_last: Erase the last tail segment
snake_erase_last:
    push ax
    push bx
    push dx
    mov al, byte [snake_len]
    dec al
    dec al                  ; index of last tail segment
    xor ah, ah
    mov si, body_x
    add si, ax
    mov dl, byte [si]
    mov si, body_y
    add si, ax
    mov dh, byte [si]
    mov ah, 0x02
    mov bh, 0
    int 0x10
    mov al, ' '
    mov ah, 0x0e
    mov bl, 0x00
    int 0x10
    pop dx
    pop bx
    pop ax
    ret

; snake_step: advance snake one frame
snake_step:
    push ax
    push bx
    push cx
    push dx

    ; Only erase tail if not growing
    cmp byte [snake_growing], 0
    jne .skip_erase
    call snake_erase_last
    jmp .do_shift
.skip_erase:
    mov byte [snake_growing], 0

.do_shift:
    ; Shift body backwards: body[i] = body[i-1] for i=len-2 down to 1
    ; body[0] gets old head position
    mov cl, byte [snake_len]
    dec cl                  ; cl = tail count = snake_len - 1
    cmp cl, 0
    je .shift_done
    ; shift from index cl-1 down to 1: body[i] = body[i-1]
    ; do it from high to low to avoid overwrite
.shift_loop:
    cmp cl, 1
    jl .shift_done
    xor bx, bx
    mov bl, cl
    dec bl                  ; bl = cl-1 (source index)
    mov si, body_x
    add si, bx
    mov al, byte [si]
    mov si, body_x
    add si, cx
    ; cx is dest index (cl)... wait, cl IS cx low byte
    ; Use DI for dest
    mov di, body_x
    xor ah, ah
    mov al, cl
    add di, ax
    ; source was bl
    mov si, body_x
    xor ah, ah
    mov al, bl
    add si, ax
    mov al, byte [si]
    mov byte [di], al
    mov si, body_y
    xor ah, ah
    mov al, bl
    add si, ax
    mov al, byte [si]
    mov di, body_y
    xor ah, ah
    mov al, cl
    add di, ax
    mov byte [di], al
    dec cl
    jmp .shift_loop
.shift_done:
    ; body[0] = old head
    mov al, byte [snake_hx]
    mov byte [body_x], al
    mov al, byte [snake_hy]
    mov byte [body_y], al

    ; Move head
    mov al, byte [snake_hx]
    mov bl, byte [snake_hy]
    mov dl, byte [snake_dir]
    cmp dl, 0
    je .go_up
    cmp dl, 1
    je .go_right
    cmp dl, 2
    je .go_down
    dec al
    jmp .set_head
.go_up:
    dec bl
    jmp .set_head
.go_right:
    inc al
    jmp .set_head
.go_down:
    inc bl
.set_head:
    mov byte [snake_hx], al
    mov byte [snake_hy], bl

    ; Wall collision
    cmp al, 1
    jl .die
    cmp al, 78
    jg .die
    cmp bl, 2
    jl .die
    cmp bl, 22
    jg .die

    ; Self collision: head vs body[0..snake_len-2]
    xor cx, cx
    mov cl, byte [snake_len]
    dec cl
    cmp cl, 0
    je .no_self
    xor bx, bx
.self_loop:
    mov si, body_x
    add si, bx
    mov dl, byte [si]
    cmp al, dl
    jne .self_next
    mov si, body_y
    add si, bx
    mov dl, byte [si]
    cmp bl, dl
    je .die
.self_next:
    inc bx
    loop .self_loop
.no_self:

    ; Food?
    cmp al, byte [food_x]
    jne .draw_frame
    cmp bl, byte [food_y]
    jne .draw_frame
    ; Eaten!
    inc word [snake_score]
    mov cl, byte [snake_len]
    cmp cl, 62
    jge .draw_frame
    inc byte [snake_len]
    mov byte [snake_growing], 1
    ; New food position
    mov ah, 0x00
    int 0x1a
    mov al, dl
    and al, 0x47
    add al, 3
    cmp al, 77
    jl .fx_ok
    mov al, 10
.fx_ok:
    mov byte [food_x], al
    mov al, dh
    and al, 0x0d
    add al, 3
    cmp al, 21
    jl .fy_ok
    mov al, 5
.fy_ok:
    mov byte [food_y], al
    call snake_place_food

.draw_frame:
    call snake_draw_all
    ; Score display
    mov ah, 0x02
    mov bh, 0
    mov dh, 0
    mov dl, 55
    int 0x10
    mov si, score_label
    mov byte [current_color], 0x0e
    call print
    mov ax, word [snake_score]
    call print_number

    pop dx
    pop cx
    pop bx
    pop ax
    ret

.die:
    mov byte [snake_alive], 0
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; FIX: snake_draw_border - correct push/pop order
snake_draw_border:
    push ax
    push bx
    push cx
    push dx
    ; Top border row 1
    mov ah, 0x02
    mov bh, 0
    mov dh, 1
    mov dl, 0
    int 0x10
    mov cx, 80
.top_b:
    mov al, 0xCD
    mov ah, 0x0e
    mov bl, 0x0e
    int 0x10
    loop .top_b
    ; Bottom border row 23
    mov ah, 0x02
    mov bh, 0
    mov dh, 23
    mov dl, 0
    int 0x10
    mov cx, 80
.bot_b:
    mov al, 0xCD
    mov ah, 0x0e
    mov bl, 0x0e
    int 0x10
    loop .bot_b
    ; Side borders rows 2-22
    mov cx, 21
    mov dh, 2
.side_b:
    push cx
    push dx
    mov ah, 0x02
    mov bh, 0
    mov dl, 0
    int 0x10
    mov al, 0xBA
    mov ah, 0x0e
    mov bl, 0x0e
    int 0x10
    mov ah, 0x02
    mov bh, 0
    mov dl, 79
    int 0x10
    mov al, 0xBA
    mov ah, 0x0e
    mov bl, 0x0e
    int 0x10
    pop dx          ; FIX: correct pop order
    inc dh
    pop cx
    loop .side_b
    ; Title
    mov ah, 0x02
    mov bh, 0
    mov dh, 0
    mov dl, 28
    int 0x10
    mov si, snake_title
    mov byte [current_color], 0x0e
    call print
    ; Controls row 24
    mov ah, 0x02
    mov bh, 0
    mov dh, 24
    mov dl, 5
    int 0x10
    mov si, snake_help
    mov byte [current_color], 0x07
    call print
    pop dx
    pop cx
    pop bx
    pop ax
    ret

snake_place_food:
    push ax
    push bx
    push dx
    mov ah, 0x02
    mov bh, 0
    mov dh, byte [food_y]
    mov dl, byte [food_x]
    int 0x10
    mov al, '@'
    mov ah, 0x0e
    mov bl, 0x0c
    int 0x10
    pop dx
    pop bx
    pop ax
    ret

; ============================================================
;  DATA SECTION
; ============================================================

prompt          db 13, 10, 'byteOS > ', 0
cmd_help        db 'help', 0
cmd_clear       db 'clear', 0
cmd_ver         db 'version', 0
cmd_whoami      db 'whoami', 0
cmd_matrix      db 'matrix', 0
cmd_reboot      db 'reboot', 0
cmd_shutdown    db 'shutdown', 0
cmd_echo        db 'echo', 0
cmd_calc        db 'calc', 0
cmd_time        db 'time', 0
cmd_history     db 'history', 0
cmd_snake       db 'snake', 0
cmd_color       db 'color', 0

color_green     db 'green', 0
color_red       db 'red', 0
color_blue      db 'blue', 0
color_white     db 'white', 0

boot_logo       db 13, 10
                db '  ####   #   #  #####  ####   ###   ####  ', 13, 10
                db ' #    #  #   #    #    #      #   #  #    ', 13, 10
                db ' #    #   # #     #    ###    #   #  ###  ', 13, 10
                db ' #####     #      #    #      #   #  #    ', 13, 10
                db ' #    #    #      #    #####   ###   #### ', 13, 10
                db 13, 10
                db '     v0.4 - Built by kernelmasterX', 13, 10
                db '     Loading', 0

welcome_msg     db 13, 10, ' byteOS v0.4 ready. Type [help].', 13, 10, 0

help_msg        db 13, 10, '=== byteOS v0.4 Commands ===', 13, 10
                db '  help      - Show this message', 13, 10
                db '  clear     - Clear the screen', 13, 10
                db '  version   - Show version info', 13, 10
                db '  whoami    - Who are you?', 13, 10
                db '  time      - Show current time', 13, 10
                db '  history   - Show last 5 commands', 13, 10
                db '  color X   - Change color (green/red/blue/white)', 13, 10
                db '  echo X    - Print text', 13, 10
                db '  calc      - Calculator (+/-/*)', 13, 10
                db '  matrix    - Matrix mode', 13, 10
                db '  snake     - Snake game (arrows, q=quit)', 13, 10
                db '  reboot    - Reboot system', 13, 10
                db '  shutdown  - Shutdown system', 13, 10, 0

ver_msg         db 13, 10, 'byteOS v0.4 - Built by kernelmasterX :)', 13, 10
                db 'Snake v2 (real body), boot animation, whoami.', 13, 10, 0
whoami_msg      db 13, 10, 'kernelmasterX - byteOS developer', 13, 10, 0
unknown_msg     db 13, 10, 'Error: Unknown command! (type help)', 13, 10, 0
matrix_msg      db 13, 10, 'Press any key to exit matrix mode...', 13, 10, 0
reboot_msg      db 13, 10, 'Rebooting...', 13, 10, 0
shutdown_msg    db 13, 10, 'Shutting down...', 13, 10, 0
time_msg        db 13, 10, 'Time: ', 0
history_msg     db 13, 10, '--- Command History ---', 13, 10, 0
calc_prompt     db 13, 10, 'Calc: ', 0
calc_op_err     db 13, 10, 'Error: Only +, -, * supported!', 13, 10, 0
color_ok_msg    db 13, 10, 'Color changed!', 13, 10, 0
color_err_msg   db 13, 10, 'Error: Use green/red/blue/white', 13, 10, 0

snake_title     db ' byteOS SNAKE v2 ', 0
snake_help      db 'Arrows=move  Q=quit  O=head  #=body  @=food', 0
snake_dead_msg  db 'GAME OVER! Score: ', 0
snake_anykey    db '  Press any key...', 13, 10, 0
score_label     db 'Score: ', 0

current_color   db 0x0a
calc_num1       dw 0
calc_num2       dw 0
calc_op         db 0
hist_count      db 0
snake_dir       db 1
snake_alive     db 1
snake_growing   db 0
snake_score     dw 0
snake_len       db 3
snake_hx        dw 40       ; head x (word for safety)
snake_hy        dw 12       ; head y
food_x          db 20
food_y          db 8

body_x          times 64 db 0
body_y          times 64 db 0

history_buf     times 320 db 0
buffer          times 64  db 0
