
# font_editor_color.py
import tkinter as tk
from tkinter import ttk, filedialog, messagebox
from PIL import Image, ImageTk
import sys

FONT_WIDTH = 8
FONT_HEIGHT = 8
NUM_CHARS = 256

class FontEditor:
    def __init__(self, root, memfile=None):
        self.root = root
        self.root.title("Editor de fuente 8x8 con color (4 bits por píxel)")
        self.char_data = [[[0 for _ in range(FONT_WIDTH)] for _ in range(FONT_HEIGHT)] for _ in range(NUM_CHARS)]
        self.palette = [(0, 0, 0)] * 16
        self.transparent_index = 15

        # Crear pestañas
        self.notebook = ttk.Notebook(root)
        self.notebook.pack(fill="both", expand=True)

        self.tab_frames = []
        self.tab1 = tk.Frame(self.notebook)
        self.tab2 = tk.Frame(self.notebook)
        self.tab3 = tk.Frame(self.notebook)
        self.tab4 = tk.Frame(self.notebook)
        self.tab_frames.extend([self.tab1, self.tab2, self.tab3, self.tab4])
        self.notebook.add(self.tab1, text="ASCII 0–127")
        self.notebook.add(self.tab2, text="ASCII 128–255")
        self.notebook.add(self.tab3, text="Vista 128x64")
        self.notebook.add(self.tab4, text="Vista completa")

        self.build_tab1()
        self.build_tab2()
        self.build_tab3()
        self.build_tab4()

        self.button_frame = tk.Frame(root)
        self.button_frame.pack(fill="x")
        tk.Button(self.button_frame, text="Cargar .mem", command=self.load_mem).pack(side="left", padx=5)
        tk.Button(self.button_frame, text="Guardar .mem", command=self.save_mem).pack(side="left", padx=5)
        tk.Button(self.button_frame, text="Cargar paleta", command=self.load_palette).pack(side="left", padx=5)
        tk.Button(self.button_frame, text="Guardar paleta", command=self.save_palette).pack(side="left", padx=5)

        self.palette_frame = tk.Frame(root)
        self.palette_frame.pack(pady=3)
        self.draw_palette()

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

    def draw_palette(self):
        for widget in self.palette_frame.winfo_children():
            widget.destroy()
        for i, (r, g, b) in enumerate(self.palette):
            hex_color = f"#{r:02x}{g:02x}{b:02x}"
            border = 3 if i == self.transparent_index else 1
            cv = tk.Canvas(self.palette_frame, width=24, height=24, bg=hex_color, highlightthickness=border)
            cv.pack(side="left", padx=2)

    def load_mem(self, path=None):
        if not path:
            path = filedialog.askopenfilename(filetypes=[("MEM files", "*.mem")])
        if not path:
            return
        try:
            with open(path, 'r') as f:
                lines = [line.strip() for line in f.readlines()]
            if len(lines) != NUM_CHARS * FONT_HEIGHT:
                raise ValueError("El archivo debe tener 2048 líneas (256x8).")
            for i in range(NUM_CHARS):
                for j in range(FONT_HEIGHT):
                    self.char_data[i][j] = [int(ch, 16) for ch in lines[i * FONT_HEIGHT + j]]
            self.classic_tab.refresh()
            self.extended_tab.refresh()
            self.massive_tab.refresh()
            self.preview_tab.refresh()
        except Exception as e:
            messagebox.showerror("Error al cargar .mem", str(e))

    def save_mem(self):
        file_path = filedialog.asksaveasfilename(defaultextension=".mem", filetypes=[("MEM files", "*.mem")])
        if not file_path:
            return
        try:
            with open(file_path, 'w') as f:
                for i in range(NUM_CHARS):
                    for j in range(FONT_HEIGHT):
                        f.write("".join(f"{c:X}" for c in self.char_data[i][j]) + "\n")
                messagebox.showinfo("Guardado", "Archivo .mem guardado correctamente.")
        except Exception as e:
            messagebox.showerror("Error al guardar .mem", str(e))

    def load_palette(self):
        path = filedialog.askopenfilename(filetypes=[("Palette MEM", "*.mem")])
        if not path:
            return
        try:
            with open(path, 'r') as f:
                lines = [line.strip() for line in f.readlines()]
            if len(lines) != 16:
                raise ValueError("La paleta debe tener exactamente 16 líneas.")
            self.palette = [tuple(int(lines[i][j:j+2], 16) for j in (0, 2, 4)) for i in range(16)]
            self.draw_palette()
            self.classic_tab.refresh()
            self.extended_tab.refresh()
            self.massive_tab.refresh()
            self.preview_tab.refresh()
        except Exception as e:
            messagebox.showerror("Error al cargar paleta", str(e))

    def save_palette(self):
        path = filedialog.asksaveasfilename(defaultextension=".mem", filetypes=[("Palette MEM", "*.mem")])
        if not path:
            return
        try:
            with open(path, "w") as f:
                for (r, g, b) in self.palette:
                    f.write(f"{r:02X}{g:02X}{b:02X}\n")
            messagebox.showinfo("Guardado", "Paleta guardada correctamente.")
        except Exception as e:
            messagebox.showerror("Error al guardar paleta", str(e))

def main():
    root = tk.Tk()
    root.geometry("1280x800")
    app = FontEditor(root)
    root.mainloop()

if __name__ == "__main__":
    main()
