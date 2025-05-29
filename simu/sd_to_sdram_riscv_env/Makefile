
CC=riscv32-unknown-elf-gcc
CFLAGS=-Wall -Os -march=rv32i -mabi=ilp32 -nostdlib -ffreestanding
LDFLAGS=-T sections.ld

all: firmware.bin

firmware.elf: main.c
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

firmware.bin: firmware.elf
	riscv32-unknown-elf-objcopy -O binary $< $@

clean:
	rm -f *.elf *.bin
