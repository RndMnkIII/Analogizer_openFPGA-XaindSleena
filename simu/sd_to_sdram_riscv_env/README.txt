Proyecto: Carga de sector SD a SDRAM con PicoRV32

Contenido:
- top.v: integración de PicoRV32, SPI y SDRAM
- picorv32.v: núcleo CPU RISC-V
- spi_controller.v: controlador SPI mapeado
- sdram_ctrl.v: controlador SDRAM multicanal
- main.c: firmware C que lee sector SD y lo copia a SDRAM
- Makefile: compila con riscv32-unknown-elf-gcc
- sections.ld: linker script para BRAM/SRAM/SDRAM

Uso:
$ make
Carga el firmware binario resultante en FPGA y observa cómo se copia sector 0 a SDRAM.
