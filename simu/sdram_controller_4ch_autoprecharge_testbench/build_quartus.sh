
#!/bin/bash
# Script de compilación automática para Quartus CLI

quartus_map sdram_controller_4ch
quartus_fit sdram_controller_4ch
quartus_asm sdram_controller_4ch
quartus_sta sdram_controller_4ch
