byteOS

​byteOS is a custom, lightweight operating system kernel developed from scratch. This project focuses on low-level system programming, custom bootloader implementation, and core kernel mechanics on the x86 architecture.

​🛠️ Technical Specifications
​Architecture: x86 (32-bit)
​Languages: C, x86 Assembly
​Bootloader: Custom implementation
​Environment: GCC Cross-Compiler, NASM

​🚀 Getting Started
​Prerequisites
​To build this project, you will need the following tools:
​i686-elf-gcc
​nasm
​make
​qemu-system-i386
​Building and Running
# Compile the project
nasm -f bin boot.asm -o boot.bin && clang --target=i386-pc-none-elf -m32 -ffreestanding -fno-pie -nostdlib -fno-stack-protector -mno-sse -mno-sse2 -mno-mmx -O0 -c kernel.c -o kernel.o && ld.lld -m elf_i386 -T linker.ld -o kernel.elf kernel.o && objcopy -O binary kernel.elf kernel.bin && cat boot.bin kernel.bin > os.img && truncate -s 2M os.img && ls -lh os.img

🤝 Contributing
​Contributions are welcome. Feel free to open an Issue or submit a Pull Request

Developed by: KernelmasterX
