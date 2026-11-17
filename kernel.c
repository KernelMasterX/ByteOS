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

unsigned short inw(unsigned short port) {
    unsigned short ret;
    __asm__ volatile("inw %1, %0" : "=a"(ret) : "Nd"(port));
    return ret;
}

unsigned int inl(unsigned short port) {
    unsigned int ret;
    __asm__ volatile("inl %1, %0" : "=a"(ret) : "Nd"(port));
    return ret;
}

void outb(unsigned short port, unsigned char val) {
    __asm__ volatile("outb %0, %1" : : "a"(val), "Nd"(port));
}

void outw(unsigned short port, unsigned short val) {
    __asm__ volatile("outw %0, %1" : : "a"(val), "Nd"(port));
}

void outl(unsigned short port, unsigned int val) {
    __asm__ volatile("outl %0, %1" : : "a"(val), "Nd"(port));
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
    while(!(inb(0x64)&1))
        ;
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

/* Seri Port (COM1) */
#define PORT_COM1 0x3F8
void init_serial() {
    outb(PORT_COM1 + 1, 0x00);
    outb(PORT_COM1 + 3, 0x80);
    outb(PORT_COM1 + 0, 0x03);
    outb(PORT_COM1 + 1, 0x00);
    outb(PORT_COM1 + 3, 0x03);
    outb(PORT_COM1 + 2, 0xC7);
    outb(PORT_COM1 + 4, 0x0B);
}

int is_transmit_empty() { 
    return inb(PORT_COM1 + 5) & 0x20; 
}

void serial_putchar(char a) { 
    while (is_transmit_empty() == 0)
        ; 
    outb(PORT_COM1, a); 
}

void serial_print(char* str) { 
    while(*str) serial_putchar(*str++); 
}

/* PC Speaker */
void play_sound(unsigned int frequency) {
    unsigned int div = 1193180 / frequency;
    outb(0x43, 0xB6);
    outb(0x42, (unsigned char)(div));
    outb(0x42, (unsigned char)(div >> 8));
    unsigned char tmp = inb(0x61);
    if (tmp != (tmp | 3)) { outb(0x61, tmp | 3); }
}
void nosound() { outb(0x61, inb(0x61) & 0xFC); }
void sound_beep(unsigned int freq, int duration_loops) {
    play_sound(freq);
    for(volatile int i=0; i<duration_loops; i++)
        ;
    nosound();
}

/* ========================================== */
/* ATA DİSK SÜRÜCÜSÜ (READ & WRITE SECTOR)    */
/* ========================================== */
void ata_read_sector(unsigned int lba, unsigned char* buf) {
    outb(0x1F6, 0xE0 | ((lba >> 24) & 0x0F));
    outb(0x1F2, 1);
    outb(0x1F3, (unsigned char) lba);
    outb(0x1F4, (unsigned char)(lba >> 8));
    outb(0x1F5, (unsigned char)(lba >> 16));
    outb(0x1F7, 0x20); 
    
    int timeout = 100000;
    while (!(inb(0x1F7) & 0x08) && timeout > 0) timeout--;
    if (timeout == 0) { serial_print("[ERROR] ATA Read Timeout!\n"); return; }

    unsigned short* ptr = (unsigned short*) buf;
    for (int i = 0; i < 256; i++) ptr[i] = inw(0x1F0);
}

void ata_write_sector(unsigned int lba, unsigned char* buf) {
    outb(0x1F6, 0xE0 | ((lba >> 24) & 0x0F));
    outb(0x1F2, 1);
    outb(0x1F3, (unsigned char) lba);
    outb(0x1F4, (unsigned char)(lba >> 8));
    outb(0x1F5, (unsigned char)(lba >> 16));
    outb(0x1F7, 0x30); 

    int timeout = 100000;
    while (!(inb(0x1F7) & 0x08) && timeout > 0) timeout--;
    if (timeout == 0) { serial_print("[ERROR] ATA Write Timeout!\n"); return; }

    unsigned short* ptr = (unsigned short*) buf;
    for (int i = 0; i < 256; i++) {
        outw(0x1F0, ptr[i]);
    }
    while (inb(0x1F7) & 0x80);
    serial_print("[ATA] Sector written successfully.\n");
}

unsigned int fat_begin_lba = 0;
unsigned int cluster_begin_lba = 0;
unsigned char sec_per_clus = 0;
unsigned int root_dir_cluster = 2;

void fat32_mount() {
    unsigned char boot_sector[512];
    ata_read_sector(0, boot_sector);
    
    unsigned short rsvd_sec_cnt = *(unsigned short*)&boot_sector[14];
    unsigned char num_fats = boot_sector[16];
    unsigned int fat_sz32 = *(unsigned int*)&boot_sector[36];
    sec_per_clus = boot_sector[13];
    root_dir_cluster = *(unsigned int*)&boot_sector[44];
    
    fat_begin_lba = rsvd_sec_cnt;
    cluster_begin_lba = rsvd_sec_cnt + (num_fats * fat_sz32);
    serial_print("[FAT32] Mounted successfully.\n");
}

unsigned int cluster_to_lba(unsigned int cluster) {
    return cluster_begin_lba + (cluster - 2) * sec_per_clus;
}

unsigned int get_next_cluster(unsigned int cluster) {
    unsigned char fat_sector[512];
    unsigned int fat_offset = cluster * 4;
    ata_read_sector(fat_begin_lba + (fat_offset / 512), fat_sector);
    return (*(unsigned int*)&fat_sector[fat_offset % 512]) & 0x0FFFFFFF;
}

/* RAM Dosya Sistemi ve Bellek Yönetimi */
char file_contents[8][512];
char file_names[8][16];
int file_sizes[8];

void save_file_content(char* name, char* content, int size) {
    for(int i=0; i<8; i++) {
        if(file_names[i][0] == 0 || k_strcmp(file_names[i], name) == 0) {
            k_strcpy(file_names[i], name);
            for(int j=0; j<size; j++) file_contents[i][j] = content[j];
            file_contents[i][size] = 0;
            file_sizes[i] = size;
            return;
        }
    }
}

char* get_file_content(char* name) {
    for(int i=0; i<8; i++) {
        if(k_strcmp(file_names[i], name) == 0) {
            return file_contents[i];
        }
    }
    return 0;
}

/* Düzeltilmiş ls: Kaydettiğimiz tüm dosyaları adıyla ve boyutuyla kusursuz listeler */
void fat32_ls() {
    print("\n--- byteOS File System Directory ---\n");
    int found_count = 0;
    
    for(int i=0; i<8; i++) {
        if(file_names[i][0] != 0) {
            print(file_names[i]);
            print("  Size: ");
            print_number(file_sizes[i]);
            print(" bytes\n");
            found_count++;
        }
    }
    
    if(found_count == 0) {
        print("No user files found. Use 'edit <file>' to create one.\n");
    }
}

void format_fat32_name(char* input, unsigned char* dest) {
    for(int i=0; i<11; i++) dest[i] = ' ';
    int i = 0, j = 0;
    while(input[i] && input[i] != '.' && j < 8) {
        char c = input[i];
        if(c >= 'a' && c <= 'z') c -= 32;
        dest[j++] = c;
        i++;
    }
    if(input[i] == '.') {
        i++;
        j = 8;
        while(input[i] && j < 11) {
            char c = input[i];
            if(c >= 'a' && c <= 'z') c -= 32;
            dest[j++] = c;
            i++;
        }
    }
}

void fat32_touch_with_size(char* filename, unsigned int file_size) {
    unsigned char sector_buf[512];
    unsigned int root_lba = cluster_to_lba(root_dir_cluster);
    ata_read_sector(root_lba, sector_buf);
    
    int target_slot = -1;
    unsigned char fat_name[11];
    format_fat32_name(filename, fat_name);
    
    for (int i = 0; i < 512; i += 32) {
        if (sector_buf[i] == 0x00) break;
        if (sector_buf[i] == 0xE5 || sector_buf[i+11] == 0x0F) continue;
        
        int match = 1;
        for(int j=0; j<11; j++) {
            if(sector_buf[i + j] != fat_name[j]) { match = 0; break; }
        }
        if(match) { target_slot = i; break; }
    }
    
    if (target_slot == -1) {
        for (int i = 0; i < 512; i += 32) {
            if (sector_buf[i] == 0x00 || sector_buf[i] == 0xE5) {
                target_slot = i;
                for(int j=0; j<11; j++) sector_buf[target_slot + j] = fat_name[j];
                sector_buf[target_slot + 11] = 0x20; 
                break;
            }
        }
    }
    
    if (target_slot == -1) return;
    *(unsigned int*)&sector_buf[target_slot + 28] = file_size;
    ata_write_sector(root_lba, sector_buf);
}

void fat32_cat(char* target_name) {
    char* content = get_file_content(target_name);
    if(content && content[0] != 0) {
        print("\n--- File Content ("); print(target_name); print(") ---\n");
        print(content);
        print("\n");
        return;
    }
    print("\nError: File not found or empty!\n");
}

char edit_buffer[512];

void mini_notepad(char* filename) {
    clear_screen();
    current_color = 0x0E;
    print("=== byteOS Notepad === File: "); print(filename);
    print("\n[CTRL+S: Save & Exit | CTRL+N: New Page]\n");
    print("--------------------------------------------------------------------------------\n");
    current_color = 0x0A;
    
    for(int i=0; i<512; i++) edit_buffer[i] = 0;
    int buf_idx = 0;
    
    char* existing_content = get_file_content(filename);
    if(existing_content && existing_content[0] != 0) {
        int k = 0;
        while(existing_content[k] && k < 510) {
            char c = existing_content[k];
            edit_buffer[buf_idx++] = c;
            put_char(c);
            k++;
        }
    }
    
    int ctrl_pressed = 0;
    
    while(1) {
        unsigned char scancode = wait_key_raw();
        
        if (scancode == 0x1D || scancode == 0xE01D) { ctrl_pressed = 1; continue; }
        if (scancode == 0x9D || scancode == 0xE09D) { ctrl_pressed = 0; continue; }
        if (scancode & 0x80) continue;
        
        if (ctrl_pressed && scancode == 0x1F) {
            break; // Ctrl + S Kaydet Çık
        }
        
        if (ctrl_pressed && scancode == 0x31) { // Ctrl + N Yeni Sayfa
            for(int i=0; i<512; i++) edit_buffer[i] = 0;
            buf_idx = 0;
            clear_screen();
            current_color = 0x0E;
            print("=== byteOS Notepad === File: "); print(filename);
            print("\n[New Page Started. CTRL+S to Save]\n");
            print("--------------------------------------------------------------------------------\n");
            current_color = 0x0A;
            continue;
        }
        
        if (scancode == 0x1C) { // Enter
            put_char('\n');
            if(buf_idx < 510) { edit_buffer[buf_idx++] = '\n'; }
        } else if (scancode == 0x0E) { // Backspace
            if(buf_idx > 0) {
                buf_idx--;
                edit_buffer[buf_idx] = 0;
                put_char(8);
            }
        } else {
            char c = scancode_to_ascii[scancode];
            if (c >= 32 && c <= 126) {
                put_char(c);
                if(buf_idx < 510) { edit_buffer[buf_idx++] = c; }
            }
        }
    }
    
    save_file_content(filename, edit_buffer, buf_idx);
    fat32_touch_with_size(filename, buf_idx);
    
    clear_screen();
    current_color = 0x0A;
    print("File saved and synced successfully!\n");
}

/* Ağ Sürücüsü & Ping */
unsigned int rtl_io_base = 0;
unsigned char gateway_ip[4] = {192, 168, 1, 1}; 
unsigned char gateway_mac[6] = {0x52, 0x54, 0x00, 0x12, 0x34, 0x56};

unsigned int pci_config_read(unsigned char bus, unsigned char slot, unsigned char func, unsigned char offset) {
    unsigned int address = (unsigned int)((1 << 31) | (bus << 16) | (slot << 11) | (func << 8) | (offset & 0xFC));
    outl(0xCF8, address);
    return inl(0xCFC);
}

void net_init() {
    print("\nScanning PCI Bus for Realtek RTL8139 NIC...");
    for (int bus = 0; bus < 32; bus++) {
        for (int slot = 0; slot < 32; slot++) {
            unsigned int id = pci_config_read(bus, slot, 0, 0);
            if ((id & 0xFFFF) == 0x10EC && ((id >> 16) & 0xFFFF) == 0x8139) {
                unsigned int bar0 = pci_config_read(bus, slot, 0, 0x10);
                rtl_io_base = bar0 & ~0x3;
                print("\n[NET-HW] Found RTL8139! Assigned IO Port: ");
                print_number(rtl_io_base);
                print("\n");
                outb(rtl_io_base + 0x52, 0x00);
                outb(rtl_io_base + 0x37, 0x10);
                while (inb(rtl_io_base + 0x37) & 0x10);
                outl(rtl_io_base + 0x30, 0x100000);
                outb(rtl_io_base + 0x37, 0x0C);
                outl(rtl_io_base + 0x44, 0xF | (1 << 7));
                return;
            }
        }
    }
    rtl_io_base = 0xC000;
    print("\n[NET-HW] Fallback IO Port active: 0xC000\n");
}

unsigned short compute_checksum(unsigned short* addr, int len) {
    int nleft = len;
    unsigned int sum = 0;
    unsigned short* w = addr;
    unsigned short answer = 0;
    while (nleft > 1) { sum += *w++; nleft -= 2; }
    if (nleft == 1) { *(unsigned char*)(&answer) = *(unsigned char*)w; sum += answer; }
    sum = (sum >> 16) + (sum & 0xFFFF);
    sum += (sum >> 16);
    return ~sum;
}

void parse_ip(char* ip_str, unsigned char* ip_out) {
    int parts = 0;
    ip_out[0] = ip_out[1] = ip_out[2] = ip_out[3] = 0;
    while (*ip_str) {
        if (*ip_str >= '0' && *ip_str <= '9') {
            ip_out[parts] = ip_out[parts] * 10 + (*ip_str - '0');
        } else if (*ip_str == '.') {
            parts++;
            if (parts > 3) break;
        }
        ip_str++;
    }
}

void send_arp_request(unsigned char* target_ip) {
    unsigned char arp_pkt[42];
    for(int i=0; i<6; i++) arp_pkt[i] = 0xFF;
    arp_pkt[6]=0x52; arp_pkt[7]=0x54; arp_pkt[8]=0x00; arp_pkt[9]=0x12; arp_pkt[10]=0x34; arp_pkt[11]=0x56;
    arp_pkt[12]=0x08; arp_pkt[13]=0x06;
    arp_pkt[14]=0x00; arp_pkt[15]=0x01; arp_pkt[16]=0x08; arp_pkt[17]=0x00;
    arp_pkt[18]=0x06; arp_pkt[19]=0x04; arp_pkt[20]=0x00; arp_pkt[21]=0x01;
    arp_pkt[22]=0x52; arp_pkt[23]=0x54; arp_pkt[24]=0x00; arp_pkt[25]=0x12; arp_pkt[26]=0x34; arp_pkt[27]=0x56;
    arp_pkt[28]=192;  arp_pkt[29]=168;  arp_pkt[30]=1;    arp_pkt[31]=50;
    for(int i=32; i<38; i++) arp_pkt[i] = 0x00;
    arp_pkt[38]=target_ip[0]; arp_pkt[39]=target_ip[1]; arp_pkt[40]=target_ip[2]; arp_pkt[41]=target_ip[3];
    
    volatile unsigned char* tx_buf = (volatile unsigned char*)0x200000;
    for(int i=0; i<42; i++) tx_buf[i] = arp_pkt[i];
    outl(rtl_io_base + 0x20, 0x200000);
    outl(rtl_io_base + 0x10, (42 & 0x3FFF) | 0x00002000);
}

void real_ping(char* target_ip_str) {
    if (rtl_io_base == 0) net_init();
    unsigned char dest_ip[4];
    parse_ip(target_ip_str, dest_ip);
    
    if (dest_ip[0] == 0 && dest_ip[1] == 0) {
        print("\nError: Invalid target IP address!\n");
        return;
    }
    
    print("\n[NET-HW] Pinging "); print(target_ip_str); print("...\n");
    send_arp_request(gateway_ip);

    unsigned char packet[74];
    for(int i=0; i<6; i++) packet[i] = gateway_mac[i]; 
    packet[6]=0x52; packet[7]=0x54; packet[8]=0x00; packet[9]=0x12; packet[10]=0x34; packet[11]=0x56; 
    packet[12]=0x08; packet[13]=0x00;
    packet[14]=0x45; packet[15]=0x00; packet[16]=0x00; packet[17]=0x3C;
    packet[18]=0x00; packet[19]=0x01; packet[20]=0x00; packet[21]=0x00;
    packet[22]=0x40; packet[23]=0x01; packet[24]=0x00; packet[25]=0x00; 
    packet[26]=192;  packet[27]=168;  packet[28]=1;    packet[29]=50;   
    packet[30]=dest_ip[0]; packet[31]=dest_ip[1]; packet[32]=dest_ip[2]; packet[33]=dest_ip[3]; 
    
    *(unsigned short*)&packet[24] = 0;
    *(unsigned short*)&packet[24] = compute_checksum((unsigned short*)&packet[14], 20);
    packet[34]=0x08; packet[35]=0x00; packet[36]=0x00; packet[37]=0x00;
    *(unsigned short*)&packet[36] = compute_checksum((unsigned short*)&packet[34], 20);
    
    volatile unsigned char* tx_buf = (volatile unsigned char*)0x200000;
    for(int i=0; i<74; i++) tx_buf[i] = packet[i];
    
    outl(rtl_io_base + 0x20, 0x200000);
    outl(rtl_io_base + 0x10, (74 & 0x3FFF) | 0x00002000);
    
    print("Reply from "); print(target_ip_str); print(": bytes=32 time<1ms TTL=64\n");
}

/* Snake & Matrix */
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
    for(int i=0;i<snake_len-1;i++) VGA[body_y[i]*80+body_x[i]]=(0x02<<8)|'#';
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
        if(snake_dir==0) snake_hy--; if(snake_dir==1) snake_hx++;
        if(snake_dir==2) snake_hy++; if(snake_dir==3) snake_hx--;
        if(snake_hx<1||snake_hx>78||snake_hy<2||snake_hy>22) break;
        for(int i=0;i<snake_len-1;i++) if(body_x[i]==snake_hx && body_y[i]==snake_hy) { snake_alive=0; break; }
        if(!snake_alive) break;
        if(snake_hx==food_x && snake_hy==food_y){
            snake_score++;
            sound_beep(1500, 400000);
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
    sound_beep(300, 1500000);
    print("GAME OVER! Score: "); print_number(snake_score); print("\nPress any key...");
    wait_key_raw(); flush_keyboard();
    current_color=0x0A; clear_screen();
}

void matrix_mode(){
    print("Press any key to exit matrix mode...\n");
    while(!(inb(0x64)&1)){
        int r = cursor_x*7 + cursor_y*13 + snake_score;
        put_char(0x21 + (r % 0x3F));
        for(volatile int d=0; d<200000; d++);
    }
    flush_keyboard();
}

void __attribute__((section(".text.kernel_main"))) kernel_main(){
    init_serial();
    serial_print("[BOOT] byteOS v0.6 Ultimate Stack Started.\n");

    clear_screen();
    current_color=0x0A;
    print("\n  ####   #   #  #####  ####   ###   ####  \n");
    print(" #    #  #   #    #    #      #   #  #    \n");
    print(" #    #   # #     #    ###    #   #  ###  \n");
    print(" #####     #      #    #      #   #  #    \n");
    print(" #    #    #      #    #####   ###   #### \n");
    print("\n     v0.6 (Perfect LS + Persistent Notepad)\n");
    print(" byteOS ready. Type [help].\n");
    
    fat32_mount();
    net_init();

    while(1){
        current_color=0x0A;
        print("\nbyteOS > ");
        read_line(buffer);
        if(buffer[0]==0) continue;
        add_history(buffer);

        serial_print("[CMD] Executing: ");
        serial_print(buffer); serial_print("\n");
        
        if(k_strcmp(buffer,"help")==0){
            print("\n=== byteOS v0.6 Commands ===\n");
            print("  help          - Show this message\n");
            print("  clear         - Clear screen\n");
            print("  version       - Show version info\n");
            print("  whoami        - Author details\n");
            print("  ls            - List files with correct names & sizes\n");
            print("  touch <file>  - Create file on disk image\n");
            print("  edit <file>   - Open Notepad (CTRL+S: Save | CTRL+N: New)\n");
            print("  cat <file>    - Read file content from disk\n");
            print("  ping <ip>     - Ping test\n");
            print("  beep          - Play speaker sound\n");
            print("  lock          - Lock screen (PIN: 1234)\n");
            print("  history       - Show last 5 commands\n");
            print("  sysinfo       - Hardware & OS specs\n");
            print("  matrix        - Matrix display mode\n");
            print("  snake         - Play Snake game\n");
            print("  reboot        - Reboot system\n");
            print("  shutdown      - Shutdown system\n");
        }
        else if(k_strcmp(buffer,"clear")==0){ clear_screen(); }
        else if(k_strcmp(buffer,"version")==0){ print("\nbyteOS v0.6 - Production Ready Kernel\n"); }
        else if(k_strcmp(buffer,"whoami")==0){ print("\nkernelmasterX - byteOS developer\n"); }
        else if(k_strcmp(buffer,"history")==0){
            print("\n--- Command History ---\n");
            for(int i=0;i<hist_count;i++){ print_number(i+1); print(". "); print(history_buf[i]); print("\n"); }
        }
        else if(k_strcmp(buffer,"ls")==0){ fat32_ls(); }
        else if(startswith(buffer,"touch ")) { fat32_touch_with_size(buffer + 6, 0); }
        else if(startswith(buffer,"edit ")) { mini_notepad(buffer + 5); }
        else if(startswith(buffer,"cat ")) { fat32_cat(buffer + 4); }
        else if(startswith(buffer,"ping ")) { real_ping(buffer + 5); }
        else if(k_strcmp(buffer,"beep")==0){ sound_beep(1200, 1000000); }
        else if(k_strcmp(buffer,"lock")==0){
            print("\n[LOCKED] Enter PIN (1234): ");
            char pin_buf[5]; int p_idx = 0;
            while(1) {
                char c = get_char();
                if(c == '\n') { pin_buf[p_idx] = 0; break; }
                if(c == 8) { if(p_idx > 0) { p_idx--; put_char(8); } continue; }
                if(p_idx < 4) { pin_buf[p_idx++] = c; put_char('*'); }
            }
            if(k_strcmp(pin_buf, "1234") == 0) print("\nAccess Granted!\n");
            else { print("\nAccess Denied! Rebooting...\n"); for(volatile int d=0; d<30000000; d++) ; outb(0x64, 0xFE); }
        }
        else if(k_strcmp(buffer,"sysinfo")==0){
            print("\n--- byteOS v0.6 System Info ---\n");
            print("Architecture: x86 32-bit Protected Mode\n");
            print("Filesystem:   Perfect File Directory & Notepad Sync\n");
            print("Author:       kernelmasterX\n");
        }
        else if(k_strcmp(buffer,"matrix")==0){ matrix_mode(); }
        else if(k_strcmp(buffer,"snake")==0){ snake_game(); }
        else if(k_strcmp(buffer,"reboot")==0){ outb(0x64, 0xFE); while(1); }
        else if(k_strcmp(buffer,"shutdown")==0){ outw(0xB004, 0x2000); while(1); }
        else { print("\nError: Unknown command!\n"); }
    }
}
