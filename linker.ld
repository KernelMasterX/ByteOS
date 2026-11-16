ENTRY(kernel_main)
SECTIONS
{
    . = 0x1000;
    .text : {
        *(.text.kernel_main)
        *(.text) *(.text.*)
    }
    .rodata : { *(.rodata) *(.rodata.*) }
    .data : { *(.data) *(.data.*) }
    .bss : { *(.bss) *(.bss.*) *(COMMON) }
    /DISCARD/ : { *(.eh_frame) *(.comment) *(.note*) }
}
