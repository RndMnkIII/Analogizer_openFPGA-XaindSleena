@echo off
rem Script para procesar archivos .mra con mra.exe

for %%f in (*.mra) do (
    rem %%~nf extrae solo el nombre del archivo sin la extensión .mra
    mra.exe -o"%%~nf.rom" "%%f"
)

echo Procesamiento completado.
pause
