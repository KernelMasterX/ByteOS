#define VGA_WIDTH 80
#define VGA_HEIGHT 25
#define VGA_ADDR 0xB8000
#define VGA ((volatile unsigned short*)0xB8000)
unsigned char current_color = 0x0A;
int cursor_x = 0, cursor_y = 0;
char buffer[64];
char history_buf[5][64];
int hist_count = 0;
unsigned char inb(unsigned short port) {
    unsigned char ret;
    __asm__ volatile("inb %1, %0" : "=a"(ret) : "Nd"(port));
    return ret;
}
void outb(unsigned short port, unsigned char val) {
    __asm__ volatile("outb %0, %1" : : "a"(val), "Nd"(port));
}
void outw(unsigned short port, unsigned short val) {
    __asm__ volatile("outw %0, %1" : : "a"(val), "Nd"(port));
}
void clear_screen() {
    for(int y=0; y<VGA_HEIGHT; y++)
        for(int x=0; x<VGA_WIDTH; x++)
            VGA[y*VGA_WIDTH+x] = (current_color<<8) | ' ';
    cursor_x=0; cursor_y=0;
}
void put_char(char c) {
    if(c=='\n') { cursor_x=0; cursor_y++; }
    else if(c=='\r') { cursor_x=0; }
    else if(c==8) {
        if(cursor_x>0) { cursor_x--; VGA[cursor_y*VGA_WIDTH+cursor_x]=(current_color<<8)|' '; }
    }
    else {
        VGA[cursor_y*VGA_WIDTH+cursor_x]=(current_color<<8)|c;
        cursor_x++;
        if(cursor_x>=VGA_WIDTH){cursor_x=0; cursor_y++;}
    }
    if(cursor_y>=VGA_HEIGHT){
        for(int y=1;y<VGA_HEIGHT;y++)
            for(int x=0;x<VGA_WIDTH;x++)
                VGA[(y-1)*VGA_WIDTH+x]=VGA[y*VGA_WIDTH+x];
        for(int x=0;x<VGA_WIDTH;x++) VGA[(VGA_HEIGHT-1)*VGA_WIDTH+x]=(current_color<<8)|' ';
        cursor_y=VGA_HEIGHT-1;
    }
}
void print(char* s){ while(*s) put_char(*s++); }
void print_number(int n){
    if(n==0){ put_char('0'); return; }
    if(n<0){ put_char('-'); n=-n; }
    char buf[16]; int i=0;
    while(n>0){ buf[i++]='0'+(n%10); n/=10; }
    for(int j=i-1;j>=0;j--) put_char(buf[j]);
}
int k_strcmp(char* a, char* b){
    while(*a && *a==*b){a++;b++;}
    return *a-*b;
}
void k_strcpy(char* d, char* s){ while((*d++=*s++)); }
int startswith(char* s, char* p){ while(*p){ if(*s!=*p) return 0; s++;p++; } return 1; }
char scancode_to_ascii[256]={
0,0,'1','2','3','4','5','6','7','8','9','0','-','=','\b',0,
'q','w','e','r','t','y','u','i','o','p','[',']','\n',0,'a','s',
'd','f','g','h','j','k','l',';','\'','`',0,'\\','z','x','c','v',
'b','n','m',',','.','/',0,'*',0,' ',0
};
unsigned char wait_key_raw(){
    while(!(inb(0x64)&1));
    return inb(0x60);
}
void flush_keyboard(){
    while(inb(0x64)&1) inb(0x60);
}
char get_char(){
    static int shift = 0;
    while(1){
        unsigned char code = wait_key_raw();
        if(code==0x2A || code==0x36) { shift=1; continue; }
        if(code==0xAA || code==0xB6) { shift=0; continue; }
        if(code & 0x80) continue;
        if(code==0x0E) return 8;
        if(code==0x1C) return '\n';
        char c = scancode_to_ascii[code];
        if(shift && c>='a' && c<='z') c = c - 32;
        if(c) return c;
    }
}
void read_line(char* buf){
    int i=0;
    while(1){
        char c=get_char();
        if(c=='\n'){ put_char('\n'); buf[i]=0; return; }
        if(c==8){ if(i>0){ i--; put_char(8); } continue; }
        if(i<63){ buf[i++]=c; put_char(c); }
    }
}
void add_history(char* cmd){
    if(hist_count<5){ k_strcpy(history_buf[hist_count], cmd); hist_count++; }
    else{
        for(int i=0;i<4;i++) k_strcpy(history_buf[i], history_buf[i+1]);
        k_strcpy(history_buf[4], cmd);
    }
}
int snake_hx, snake_hy, snake_len, snake_dir, snake_alive, snake_score, snake_growing;
int body_x[64], body_y[64], food_x, food_y;
void snake_draw_border(){
    clear_screen();
    for(int x=0;x<80;x++){ VGA[1*80+x]=(0x0E<<8)|0xCD; VGA[23*80+x]=(0x0E<<8)|0xCD; }
    for(int y=2;y<23;y++){ VGA[y*80+0]=(0x0E<<8)|0xBA; VGA[y*80+79]=(0x0E<<8)|0xBA; }
    cursor_x=28; cursor_y=0; unsigned char old=current_color; current_color=0x0E;
    print(" byteOS SNAKE v2 ");
    cursor_x=5; cursor_y=24; current_color=0x07;
    print("Arrows=move  Q=quit  O=head  #=body  @=food");
    current_color=old;
}
void snake_draw_all(){
    for(int i=0;i<snake_len-1;i++){
        VGA[body_y[i]*80+body_x[i]]=(0x02<<8)|'#';
    }
    VGA[snake_hy*80+snake_hx]=(0x0A<<8)|'O';
}
void snake_place_food(){ VGA[food_y*80+food_x]=(0x0C<<8)|'@'; }
void snake_game(){
    clear_screen();
    snake_len=3; snake_dir=1; snake_alive=1; snake_score=0; snake_growing=0;
    snake_hx=40; snake_hy=12; body_x[0]=39; body_y[0]=12; body_x[1]=38; body_y[1]=12;
    food_x=20; food_y=8;
    snake_draw_border(); snake_draw_all(); snake_place_food();
    while(snake_alive){
        for(volatile int d=0; d<8000000; d++);
        if(inb(0x64)&1){
            unsigned char code=inb(0x60);
            if(code==0x48 && snake_dir!=2) snake_dir=0;
            if(code==0x50 && snake_dir!=0) snake_dir=2;
            if(code==0x4B && snake_dir!=1) snake_dir=3;
            if(code==0x4D && snake_dir!=3) snake_dir=1;
            if(code==0x10) { flush_keyboard(); break; }
        }
        if(!snake_growing){
            int lx=body_x[snake_len-2], ly=body_y[snake_len-2];
            VGA[ly*80+lx]=(0x00<<8)|' ';
        } else snake_growing=0;
        for(int i=snake_len-2;i>=1;i--){ body_x[i]=body_x[i-1]; body_y[i]=body_y[i-1]; }
        body_x[0]=snake_hx; body_y[0]=snake_hy;
        if(snake_dir==0) snake_hy--;
        if(snake_dir==1) snake_hx++;
        if(snake_dir==2) snake_hy++;
        if(snake_dir==3) snake_hx--;
        if(snake_hx<1||snake_hx>78||snake_hy<2||snake_hy>22) break;
        for(int i=0;i<snake_len-1;i++) if(body_x[i]==snake_hx && body_y[i]==snake_hy) { snake_alive=0; break; }
        if(!snake_alive) break;
        if(snake_hx==food_x && snake_hy==food_y){
            snake_score++;
            if(snake_len<62) { snake_len++; snake_growing=1; }
            food_x = 3 + (snake_score*7 % 70);
            food_y = 3 + (snake_score*5 % 18);
            snake_place_food();
        }
        snake_draw_all();
        cursor_x=55; cursor_y=0; unsigned char old=current_color; current_color=0x0E;
        print("Score: "); print_number(snake_score);
        current_color=old;
    }
    clear_screen();
    current_color=0x0C;
    print("GAME OVER! Score: "); print_number(snake_score); print("\nPress any key...");
    wait_key_raw(); flush_keyboard();
    current_color=0x0A;
    clear_screen();
}
void matrix_mode(){
    print("Press any key to exit matrix mode...\n");
    while(!(inb(0x64)&1)){
        int r = cursor_x*7 + cursor_y*13 + snake_score;
        char c = 0x21 + (r % 0x3F);
        put_char(c);
        for(volatile int d=0; d<200000; d++);
    }
    flush_keyboard();
}
void __attribute__((section(".text.kernel_main"))) kernel_main(){
    clear_screen();
    current_color=0x0A;
    print("\n  ####   #   #  #####  ####   ###   ####  \n");
    print(" #    #  #   #    #    #      #   #  #    \n");
    print(" #    #   # #     #    ###    #   #  ###  \n");
    print(" #####     #      #    #      #   #  #    \n");
    print(" #    #    #      #    #####   ###   #### \n");
    print("\n     v0.5 - C Kernel - Built by kernelmasterX\n");
    print(" byteOS v0.5 ready. Type [help].\n");
    while(1){
        current_color=0x0A;
        print("\nbyteOS > ");
        read_line(buffer);
        if(buffer[0]==0) continue;
        add_history(buffer);
        if(k_strcmp(buffer,"help")==0){
            print("\n=== byteOS v0.5 Commands ===\n");
            print("  help      - Show this message\n");
            print("  clear     - Clear the screen\n");
            print("  version   - Show version info\n");
            print("  whoami    - Who are you?\n");
            print("  time      - Show current time\n");
            print("  history   - Show last 5 commands\n");
            print("  color X   - Change color (green/red/blue/white)\n");
            print("  echo X    - Print text\n");
            print("  calc      - Calculator (+/-/*)\n");
            print("  matrix    - Matrix mode\n");
            print("  snake     - Snake game (arrows, q=quit)\n");
            print("  reboot    - Reboot system\n");
            print("  shutdown  - Shutdown system\n");
        }
        else if(k_strcmp(buffer,"clear")==0){ clear_screen(); }
        else if(k_strcmp(buffer,"version")==0){
            print("\nbyteOS v0.5 - C Kernel - Built by kernelmasterX :)\n");
            print("Snake v2, C Kernel, 32-bit Protected Mode.\n");
        }
        else if(k_strcmp(buffer,"whoami")==0){ print("\nkernelmasterX - byteOS developer\n"); }
        else if(k_strcmp(buffer,"history")==0){
            print("\n--- Command History ---\n");
            for(int i=0;i<hist_count;i++){ print_number(i+1); print(". "); print(history_buf[i]); print("\n"); }
        }
        else if(k_strcmp(buffer,"time")==0){
            outb(0x70, 0x04); int h=inb(0x71);
            outb(0x70, 0x02); int m=inb(0x71);
            outb(0x70, 0x00); int s=inb(0x71);
            print("\nTime: ");
            put_char('0'+((h>>4)&0xF)); put_char('0'+(h&0xF)); put_char(':');
            put_char('0'+((m>>4)&0xF)); put_char('0'+(m&0xF)); put_char(':');
            put_char('0'+((s>>4)&0xF)); put_char('0'+(s&0xF)); print("\n");
        }
        else if(startswith(buffer,"echo ")){
            print("\n"); print(buffer+5); print("\n");
        }
        else if(startswith(buffer,"color ")){
            char* c=buffer+6;
            if(k_strcmp(c,"green")==0) current_color=0x0A;
            else if(k_strcmp(c,"red")==0) current_color=0x0C;
            else if(k_strcmp(c,"blue")==0) current_color=0x09;
            else if(k_strcmp(c,"white")==0) current_color=0x0F;
            else { print("\nError: Use green/red/blue/white\n"); continue; }
            print("\nColor changed!\n");
        }
        else if(k_strcmp(buffer,"calc")==0){
            print("\nCalc: ");
            int n1=0, n2=0; char op=0;
            while(1){ char ch=get_char(); if(ch=='\n') break; if(ch>='0'&&ch<='9'){ put_char(ch); n1=n1*10+(ch-'0'); } if(ch=='+'||ch=='-'||ch=='*'){ op=ch; put_char(ch); break; } }
            while(1){ char ch=get_char(); if(ch=='\n') break; if(ch>='0'&&ch<='9'){ put_char(ch); n2=n2*10+(ch-'0'); } }
            put_char('='); int res=0;
            if(op=='+') res=n1+n2;
            if(op=='-') res=n1-n2;
            if(op=='*') res=n1*n2;
            print_number(res); print("\n");
        }
        else if(k_strcmp(buffer,"matrix")==0){ matrix_mode(); }
        else if(k_strcmp(buffer,"snake")==0){ snake_game(); }
        else if(k_strcmp(buffer,"reboot")==0){
            print("\nRebooting...\n");
            outb(0x64, 0xFE);
            while(1);
        }
        else if(k_strcmp(buffer,"shutdown")==0){
            print("\nShutting down...\n");
            outw(0xB004, 0x2000);
            while(1);
        }
        else {
            print("\nError: Unknown command! (type help)\n");
        }
    }
}
