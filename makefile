CC = clang
LD = ld.lld
OBJCOPY = objcopy
NASM = nasm
QEMU = qemu-system-i386

CFLAGS = --target=i386-pc-none-elf -m32 -ffreestanding -fno-pie -nostdlib -fno-stack-protector -mno-sse -mno-sse2 -mno-mmx -O0
LDFLAGS = -m elf_i386 -T linker.ld

all: byteos.img
	@echo ""
	@echo "=================================="
	@echo "  byteOS successfully compiled!  "
	@echo "=================================="
	@echo ""
	ls -lh byteos.img

byteos.img: boot.bin kernel.bin
	cat boot.bin kernel.bin > byteos.img
	truncate -s 2M byteos.img

boot.bin: boot.asm
	$(NASM) -f bin boot.asm -o boot.bin

kernel.o: kernel.c
	$(CC) $(CFLAGS) -c kernel.c -o kernel.o

kernel.elf: kernel.o linker.ld
	$(LD) $(LDFLAGS) -o kernel.elf kernel.o

kernel.bin: kernel.elf
	$(OBJCOPY) -O binary kernel.elf kernel.bin

run: byteos.img
	$(QEMU) -drive format=raw,file=byteos.img -m 64M

clean:
	rm -f boot.bin kernel.o kernel.elf kernel.bin byteos.img

.PHONY: all run clean