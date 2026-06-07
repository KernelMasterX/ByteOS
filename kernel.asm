[bits 16]
[org 0x1000]

kernel_start:
    mov ah, 0x00
    mov al, 0x03
    int 0x10
    ; Default color: green (0x0a)
    mov byte [current_color], 0x0a
    ; Reset history index
    mov byte [hist_count], 0

    mov si, welcome_msg
    call print

cli_loop:
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

    ; Buffer overflow protection
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

    ; Add to history
    call add_history

    ; --- COMMAND MATCHING ---

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

    ; --- PARAMETERIZED COMMANDS ---

    ; echo check
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

    ; color check
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

    ; calc check
    mov si, buffer
    mov di, cmd_calc
    call strcmp
    jnc .do_calc

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

; --- TIME ---
.do_time:
    mov ah, 0x02
    int 0x1a           ; CH=hours BCD, CL=minutes BCD, DH=seconds BCD
    mov si, time_msg
    call print
    ; Hours
    mov al, ch
    call print_bcd
    mov al, ':'
    call print_char_color
    ; Minutes
    mov al, cl
    call print_bcd
    mov al, ':'
    call print_char_color
    ; Seconds
    mov al, dh
    call print_bcd
    call print_newline
    jmp cli_loop

; --- HISTORY ---
.do_history:
    mov si, history_msg
    call print
    mov bl, 0
    mov bh, byte [hist_count]
.hist_loop:
    cmp bl, bh
    jge cli_loop
    ; Each command is 64 bytes
    mov al, bl
    inc al
    add al, '0'        ; Print number (1-9)
    call print_char_color
    mov al, '.'
    call print_char_color
    mov al, ' '
    call print_char_color
    ; Calculate history[bl] address
    xor ah, ah
    mov al, bl
    mov cx, 64
    mul cx             ; ax = bl * 64
    add ax, history_buf
    mov si, ax
    call print
    call print_newline
    inc bl
    jmp .hist_loop

; --- ECHO ---
.do_echo:
    cmp byte [si], ' '
    jne .print_echo
    inc si
.print_echo:
    call print_newline
    call print
    call print_newline
    jmp cli_loop

; --- COLOR ---
.do_color:
    ; si points past "color "
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

; --- MATRIX ---
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

; --- CALC (multi-digit, +/-/*) ---
.do_calc:
    mov si, calc_prompt
    call print

    ; Read first number, result in AX
    call read_number
    mov word [calc_num1], ax

    ; Read operator
    mov ah, 0x00
    int 0x16
    mov byte [calc_op], al
    call print_char_color

    ; Read second number
    call read_number
    mov word [calc_num2], ax

    mov al, '='
    call print_char_color

    ; Perform operation
    mov ax, word [calc_num1]
    mov bx, word [calc_num2]
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
    mul word [calc_num2]    ; DX:AX = AX * operand
    jmp .calc_show

.calc_show:
    call print_number
    call print_newline
    jmp cli_loop

; --- SNAKE GAME ---
.do_snake:
    ; Clear screen
    mov ah, 0x00
    mov al, 0x03
    int 0x10

    ; Snake initial state: center, length 3
    mov byte [snake_len], 3
    mov word [snake_x], 40
    mov word [snake_y], 12
    mov byte [snake_dir], 1  ; 0=up 1=right 2=down 3=left
    mov word [food_x], 20
    mov word [food_y], 8
    mov byte [snake_alive], 1
    mov word [snake_score], 0

    call snake_draw_border
    call snake_place_food

.snake_game_loop:
    ; Delay
    mov cx, 0x000F
.snake_delay:
    mov dx, 0xFFFF
.snake_delay2:
    dec dx
    jnz .snake_delay2
    loop .snake_delay

    ; Check for keypress
    mov ah, 0x01
    int 0x16
    jz .snake_no_key
    mov ah, 0x00
    int 0x16
    ; Scan code is in ah
    cmp ah, 0x48  ; Up arrow
    je .dir_up
    cmp ah, 0x50  ; Down arrow
    je .dir_down
    cmp ah, 0x4B  ; Left arrow
    je .dir_left
    cmp ah, 0x4D  ; Right arrow
    je .dir_right
    cmp al, 'q'
    je .snake_quit
    jmp .snake_no_key
.dir_up:
    cmp byte [snake_dir], 2
    je .snake_no_key
    mov byte [snake_dir], 0
    jmp .snake_no_key
.dir_down:
    cmp byte [snake_dir], 0
    je .snake_no_key
    mov byte [snake_dir], 2
    jmp .snake_no_key
.dir_left:
    cmp byte [snake_dir], 1
    je .snake_no_key
    mov byte [snake_dir], 3
    jmp .snake_no_key
.dir_right:
    cmp byte [snake_dir], 3
    je .snake_no_key
    mov byte [snake_dir], 1
.snake_no_key:

    ; Move the snake
    call snake_move

    cmp byte [snake_alive], 0
    je .snake_dead

    jmp .snake_game_loop

.snake_dead:
    mov si, snake_dead_msg
    call print
    ; Print score
    mov ax, word [snake_score]
    call print_number
    call print_newline
    mov ah, 0x00
    int 0x16        ; Wait for keypress
    ; Clear screen and return
    mov ah, 0x00
    mov al, 0x03
    int 0x10
    jmp cli_loop

.snake_quit:
    mov ah, 0x00
    mov al, 0x03
    int 0x10
    jmp cli_loop

; ============================================================
;  HELPER FUNCTIONS
; ============================================================

; strcmp: Compare SI and DI, CF=0 if equal
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

; print: Print string at SI using current_color
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

; print_char_color: Print char in AL using current_color
print_char_color:
    push ax
    push bx
    mov ah, 0x0e
    mov bl, [current_color]
    int 0x10
    pop bx
    pop ax
    ret

; print_newline: Print CR+LF
print_newline:
    push ax
    mov al, 13
    call print_char_color
    mov al, 10
    call print_char_color
    pop ax
    ret

; print_bcd: Print BCD byte in AL as 2 digits
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

; print_number: Print unsigned value in AX as decimal
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

; read_number: Read multi-digit number from keyboard into AX
read_number:
    push bx
    push cx
    xor ax, ax
.rn_loop:
    push ax
    mov ah, 0x00
    int 0x16
    cmp al, 13
    je .rn_done_enter
    cmp al, '+'
    je .rn_done_op
    cmp al, '-'
    je .rn_done_op
    cmp al, '*'
    je .rn_done_op
    cmp al, '='
    je .rn_done_op
    cmp al, '0'
    jl .rn_ignore
    cmp al, '9'
    jg .rn_ignore
    ; Valid digit
    call print_char_color
    mov bl, al
    sub bl, '0'
    pop ax
    mov cx, 10
    mul cx              ; AX = AX * 10
    xor bh, bh
    add ax, bx
    jmp .rn_loop
.rn_ignore:
    pop ax
    jmp .rn_loop
.rn_done_enter:
    pop ax
    jmp .rn_exit
.rn_done_op:
    ; Save operator, print it
    mov byte [calc_op], al
    call print_char_color
    pop ax
    jmp .rn_exit
.rn_exit:
    pop cx
    pop bx
    ret

; add_history: Save buffer contents to history_buf
add_history:
    push ax
    push bx
    push cx
    push si
    push di
    mov bl, byte [hist_count]
    cmp bl, 5
    jl .has_room
    ; Shift entries: 0<-1, 1<-2, 2<-3, 3<-4
    mov bl, 0
.shift_loop:
    cmp bl, 4
    jge .shift_done
    xor bh, bh
    mov al, bl
    inc al
    mov cx, 64
    mul cx
    add ax, history_buf
    mov si, ax
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
    mov bl, 4
    jmp .do_copy
.has_room:
.do_copy:
    xor bh, bh
    mov al, bl
    mov cx, 64
    mul cx
    add ax, history_buf
    mov di, ax
    mov si, buffer
    mov cx, 64
    rep movsb
    mov bl, byte [hist_count]
    cmp bl, 5
    jge .no_inc
    inc bl
    mov byte [hist_count], bl
.no_inc:
    pop di
    pop si
    pop cx
    pop bx
    pop ax
    ret

; snake_draw_border: Draw game border
snake_draw_border:
    push ax
    push bx
    push cx
    push dx
    ; Top border (row 1)
    mov ah, 0x02
    mov bh, 0
    mov dh, 1
    mov dl, 0
    int 0x10
    mov cx, 80
.top_border:
    mov al, 0xCD        ; = double line
    mov ah, 0x0e
    mov bl, 0x0e        ; Yellow border
    int 0x10
    loop .top_border
    ; Bottom border (row 23)
    mov ah, 0x02
    mov bh, 0
    mov dh, 23
    mov dl, 0
    int 0x10
    mov cx, 80
.bot_border:
    mov al, 0xCD
    mov ah, 0x0e
    mov bl, 0x0e
    int 0x10
    loop .bot_border
    ; Left and right borders (rows 2-22)
    mov cx, 21
    mov dh, 2
.side_inner:
    push cx
    push dx
    ; Left side
    mov ah, 0x02
    mov bh, 0
    mov dl, 0
    int 0x10
    mov al, 0xBA         ; || double line
    mov ah, 0x0e
    mov bl, 0x0e
    int 0x10
    ; Right side
    mov ah, 0x02
    mov bh, 0
    mov dl, 79
    int 0x10
    mov al, 0xBA
    mov ah, 0x0e
    mov bl, 0x0e
    int 0x10
    pop dx
    inc dh
    pop cx
    loop .side_inner
    ; Print title
    mov ah, 0x02
    mov bh, 0
    mov dh, 0
    mov dl, 30
    int 0x10
    mov si, snake_title
    mov byte [current_color], 0x0e
    call print
    ; Print controls
    mov ah, 0x02
    mov bh, 0
    mov dh, 24
    mov dl, 15
    int 0x10
    mov si, snake_help
    call print
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; snake_place_food: Draw food on screen
snake_place_food:
    push ax
    push bx
    mov ah, 0x02
    mov bh, 0
    mov dh, byte [food_y]
    mov dl, byte [food_x]
    int 0x10
    mov al, '*'
    mov ah, 0x0e
    mov bl, 0x0c        ; Red food
    int 0x10
    pop bx
    pop ax
    ret

; snake_move: Move snake one step
snake_move:
    push ax
    push bx
    push dx

    ; Update head position
    mov al, byte [snake_dir]
    cmp al, 0
    je .move_up
    cmp al, 1
    je .move_right
    cmp al, 2
    je .move_down
    ; left
    dec word [snake_x]
    jmp .check_bounds
.move_up:
    dec word [snake_y]
    jmp .check_bounds
.move_right:
    inc word [snake_x]
    jmp .check_bounds
.move_down:
    inc word [snake_y]

.check_bounds:
    ; Wall collision check
    cmp word [snake_x], 1
    jl .die
    cmp word [snake_x], 78
    jg .die
    cmp word [snake_y], 2
    jl .die
    cmp word [snake_y], 22
    jg .die

    ; Food eaten?
    mov ax, word [snake_x]
    cmp ax, word [food_x]
    jne .draw_head
    mov ax, word [snake_y]
    cmp ax, word [food_y]
    jne .draw_head
    ; Food eaten!
    inc word [snake_score]
    ; New food position (timer-based)
    mov ah, 0x00
    int 0x1a
    mov al, dl
    and al, 0x4f
    add al, 2
    cmp al, 78
    jl .fx_ok
    mov al, 10
.fx_ok:
    mov byte [food_x], al
    mov al, dh
    and al, 0x0f
    add al, 3
    cmp al, 22
    jl .fy_ok
    mov al, 5
.fy_ok:
    mov byte [food_y], al
    call snake_place_food

.draw_head:
    ; Draw head
    mov ah, 0x02
    mov bh, 0
    mov dh, byte [snake_y]
    mov dl, byte [snake_x]
    int 0x10
    mov al, 'O'
    mov ah, 0x0e
    mov bl, 0x0a        ; Green snake
    int 0x10

    ; Update score display
    mov ah, 0x02
    mov bh, 0
    mov dh, 0
    mov dl, 60
    int 0x10
    mov si, score_label
    mov byte [current_color], 0x0e
    call print
    mov ax, word [snake_score]
    call print_number

    pop dx
    pop bx
    pop ax
    ret

.die:
    mov byte [snake_alive], 0
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

welcome_msg     db 13, 10, '  ____        _       ___  ____  ', 13, 10
                db ' |  _ \      | |     / _ \/ ___| ', 13, 10
                db ' | |_) |_   _| |_ __| | | \___ \ ', 13, 10
                db ' |  _ <| | | | __/ _ \ |_| |___) |', 13, 10
                db ' |_| \_\\_, |\__\___/\___/|____/ ', 13, 10
                db '         __/ |   v0.3 BETA         ', 13, 10
                db '        |___/  [help] to start      ', 13, 10, 0

help_msg        db 13, 10, '=== byteOS v0.3 Commands ===', 13, 10
                db '  help      - Show this message', 13, 10
                db '  clear     - Clear the screen', 13, 10
                db '  version   - Show version info', 13, 10
                db '  time      - Show current time', 13, 10
                db '  history   - Show last 5 commands', 13, 10
                db '  color X   - Change color (green/red/blue/white)', 13, 10
                db '  echo X    - Print text', 13, 10
                db '  calc      - Calculator (+/-/*)', 13, 10
                db '  matrix    - Matrix mode', 13, 10
                db '  snake     - Snake game (arrows + q=quit)', 13, 10
                db '  reboot    - Reboot system', 13, 10
                db '  shutdown  - Shutdown system', 13, 10, 0

ver_msg         db 13, 10, 'byteOS v0.3 BETA - Built by kernelmasterX :)', 13, 10, 0
unknown_msg     db 13, 10, 'Error: Unknown command! (type help)', 13, 10, 0
matrix_msg      db 13, 10, 'Press any key to exit matrix mode...', 13, 10, 0
reboot_msg      db 13, 10, 'Rebooting system...', 13, 10, 0
shutdown_msg    db 13, 10, 'Shutting down...', 13, 10, 0
time_msg        db 13, 10, 'Time: ', 0
history_msg     db 13, 10, '--- Command History ---', 13, 10, 0
calc_prompt     db 13, 10, 'Calc: ', 0
calc_op_err     db 13, 10, 'Error: Only +, -, * are supported!', 13, 10, 0
color_ok_msg    db 13, 10, 'Color changed!', 13, 10, 0
color_err_msg   db 13, 10, 'Error: Use green / red / blue / white', 13, 10, 0

snake_title     db ' byteOS SNAKE ', 0
snake_help      db 'Arrow keys=move  Q=quit  Score: ', 0
snake_dead_msg  db 13, 10, 'GAME OVER! Score: ', 0
score_label     db 'Score:', 0

current_color   db 0x0a
calc_num1       dw 0
calc_num2       dw 0
calc_op         db 0
hist_count      db 0
snake_x         dw 40
snake_y         dw 12
snake_dir       db 1
snake_alive     db 1
snake_score     dw 0
food_x          dw 20
food_y          dw 8
snake_len       db 3

history_buf     times 320 db 0   ; 5 commands * 64 bytes
buffer          times 64  db 0
