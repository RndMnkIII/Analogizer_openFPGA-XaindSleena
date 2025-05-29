
ENTRY(_start)

MEMORY {
  ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 64K
}

SECTIONS {
  .text : {
    *(.text*)
    *(.rodata*)
  } > ROM

  .bss : {
    *(.bss*)
    *(COMMON)
  } > ROM
}
