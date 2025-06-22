# font_editor.py
# Editor de fuentes bitmap 8x8 para caracteres ASCII 0-255 con GUI interactiva
# Ejecutar con: python font_editor.py [archivo.mem opcional]

import tkinter as tk
from tkinter import ttk, filedialog, messagebox
from PIL import Image, ImageTk
from tkinter import filedialog
import sys
import os

# --- Constantes generales ---
FONT_WIDTH = 8
FONT_HEIGHT = 8
NUM_CHARS = 256
MEM_LINES = NUM_CHARS * FONT_HEIGHT

# Tamaño visual para celdas en la GUI
PIXEL_SIZE = 24
GRID_SPACING = 10

# --- Clase principal del editor ---
class FontEditor:
    def __init__(self, root, memfile=None):
        self.root = root
        self.root.title("Editor de fuente 8x8")

        # Inicializar datos de los caracteres
        self.char_data = [[0 for _ in range(FONT_HEIGHT)] for _ in range(NUM_CHARS)]

        # Crear pestañas
        self.notebook = ttk.Notebook(root)
        self.notebook.pack(fill="both", expand=True)

        # Crear contenedor para pestañas
        self.tab_frames = []

        # Pestaña 1: Clásica 0–127
        self.tab1 = tk.Frame(self.notebook)
        self.tab_frames.append(self.tab1)
        self.notebook.add(self.tab1, text="ASCII 0–127")

        # Pestaña 2: Extendida 128–191 y 192–255
        self.tab2 = tk.Frame(self.notebook)
        self.tab_frames.append(self.tab2)
        self.notebook.add(self.tab2, text="ASCII 128–255")

        # Pestaña 3: Vista masiva 128–255 como 128x64
        self.tab3 = tk.Frame(self.notebook)
        self.tab_frames.append(self.tab3)
        self.notebook.add(self.tab3, text="Vista 128x64")

        # Pestaña 4: Vista Completa
        self.tab4 = tk.Frame(self.notebook)
        self.tab_frames.append(self.tab4)
        self.notebook.add(self.tab4, text="Vista Completa")

        # Botones globales para guardar/cargar
        self.button_frame = tk.Frame(root)
        self.button_frame.pack(fill="x")
        tk.Button(self.button_frame, text="Cargar .mem", command=self.load_mem).pack(side="left", padx=5, pady=5)
        tk.Button(self.button_frame, text="Guardar .mem", command=self.save_mem).pack(side="left", padx=5, pady=5)
        tk.Button(self.button_frame, text="Invertir bits H", command=self.invert_all_bits).pack(side="left", padx=5)
        tk.Button(self.button_frame, text="Exportar Fuente PNG", command=self.export_as_png).pack(side="left", padx=5)


        # Placeholder: funciones para llenar pestañas (las implementarás aparte)
        self.build_tab1()
        self.build_tab2()
        self.build_tab3()
        self.build_tab4()

        # Cargar archivo si se pasó por línea de comandos
        if memfile:
            self.load_mem(memfile)

    def build_tab1(self):
        from editor_tab_classic import ClassicTab
        self.classic_tab = ClassicTab(self)

    def build_tab2(self):
        from editor_tab_extended import ExtendedTab
        self.extended_tab = ExtendedTab(self)

    def build_tab3(self):
        from editor_tab_massive import MassiveTab
        self.massive_tab = MassiveTab(self)
    
    def build_tab4(self):
        from editor_tab_preview_dual import PreviewDualTab
        self.preview_tab = PreviewDualTab(self)

    def load_mem(self, path=None):
        if not path:
            path = filedialog.askopenfilename(filetypes=[("Mem files", "*.mem")])
        if not path:
            return
        try:
            with open(path, 'r') as f:
                raw_lines = f.readlines()

            line_count = len(raw_lines)
            if line_count not in (1024, 2048):
                raise ValueError("El archivo debe tener 1024 o 2048 líneas.")

            lines = [line.strip()[:2] for line in raw_lines]
            lines += ['00'] * (2048 - len(lines))

            chars_cargados = len(raw_lines) // FONT_HEIGHT
            errores = 0

            for i in range(NUM_CHARS):
                for j in range(FONT_HEIGHT):
                    try:
                        self.char_data[i][j] = int(lines[i * FONT_HEIGHT + j], 16)
                    except ValueError:
                        self.char_data[i][j] = 0
                        errores += 1

            messagebox.showinfo("Carga completada", f"Se cargaron {chars_cargados} caracteres.\n"
                                                    f"{errores} líneas inválidas ignoradas." if errores else 
                                                    f"Se cargaron {chars_cargados} caracteres correctamente.")
        except Exception as e:
            messagebox.showerror("Error al cargar", str(e))
            
        self.notebook.select(self.tab1)
        self.classic_tab.refresh()

        self.notebook.select(self.tab2)
        self.extended_tab.refresh()

        self.notebook.select(self.tab3)
        self.massive_tab.refresh()

        self.notebook.select(self.tab4)
        self.preview_tab.refresh()

        # Y finalmente volver a la pestaña inicial (por ejemplo, Classic)
        self.notebook.select(self.tab1)

    def save_mem(self):
        file_path = filedialog.asksaveasfilename(defaultextension=".mem", filetypes=[("Mem files", "*.mem")])
        if not file_path:
            return
        try:
            with open(file_path, 'w') as f:
                for i in range(NUM_CHARS):
                    for j in range(FONT_HEIGHT):
                        f.write(f"{self.char_data[i][j]:02X}\n")
                messagebox.showinfo("Guardado", "Archivo guardado correctamente.")
        except Exception as e:
            messagebox.showerror("Error al guardar", str(e))

    def reverse_bits(self,byte):
        return int('{:08b}'.format(byte)[::-1], 2)

    def invert_all_bits(self):
        for i in range(256):
            for j in range(8):
                self.char_data[i][j] = self.reverse_bits(self.char_data[i][j])
        self.classic_tab.refresh()
        self.extended_tab.refresh()
        self.massive_tab.refresh()
        self.preview_tab.refresh()

    def export_as_png(self):
        path = filedialog.asksaveasfilename(defaultextension=".png", filetypes=[("PNG files", "*.png")])
        if not path:
            return
        tile_w, tile_h = 8, 8
        tiles_per_row = 16
        img_w = tile_w * tiles_per_row
        img_h = tile_h * tiles_per_row
        img = Image.new("1", (img_w, img_h), color=1)
        for char_idx in range(256):
            cx = (char_idx % tiles_per_row) * tile_w
            cy = (char_idx // tiles_per_row) * tile_h
            
            for row in range(8):
                byte = self.char_data[char_idx][row]
                byte = self.reverse_bits(byte)  # invierte los bits horizontalmente

                for col in range(8):
                    if (byte >> (col)) & 1:
                        img.putpixel((cx + (col), cy + row), 0)
        img.save(path)

# --- Ejecución desde línea de comandos ---
def main():
    memfile = sys.argv[1] if len(sys.argv) > 1 else None
    root = tk.Tk()
    root.geometry("1280x800")
    app = FontEditor(root, memfile)
    root.mainloop()

if __name__ == "__main__":
    main()

