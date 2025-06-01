@echo off
REM Script para reducir la frecuencia TCK del USB-Blaster II a 6 MHz
f:
REM Cambia al directorio de instalación de Quartus si es diferente
cd "F:\intelFPGA_lite\21.1\quartus\bin64"

REM Lista los cables disponibles (opcional)
jtagconfig

REM Establece la frecuencia JTAG a 6 MHz para el cable 1
jtagconfig --setparam 1 JtagClock 6

echo.
echo ==========================================
echo Velocidad del USB-Blaster II fijada a 6 MHz
echo ==========================================
pause
