
#include <stdint.h>

#define SPI_BASE 0x80000000
#define SDRAM_BASE 0x00000000
#define SD_CS_PIN 0x01

static inline void spi_write(uint8_t b) {
    *(volatile uint8_t*)(SPI_BASE + 0) = b;
}
static inline uint8_t spi_read(void) {
    return *(volatile uint8_t*)(SPI_BASE + 4);
}

void sd_send_cmd(uint8_t cmd, uint32_t arg) {
    spi_write(0x40 | cmd);
    spi_write(arg >> 24);
    spi_write(arg >> 16);
    spi_write(arg >> 8);
    spi_write(arg);
    spi_write(0x95);
}

void load_sector_to_sdram(uint32_t lba, volatile uint16_t* dest) {
    sd_send_cmd(17, lba << 9);
    while (spi_read() != 0xFE);
    for (int i = 0; i < 512; i += 2) {
        uint8_t hi = spi_read();
        uint8_t lo = spi_read();
        *dest++ = (hi << 8) | lo;
    }
}

int main() {
    *(volatile uint8_t*)(SPI_BASE + 8) = SD_CS_PIN;
    load_sector_to_sdram(0, (volatile uint16_t*)SDRAM_BASE);
    while (1);
}
