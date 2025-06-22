# editor_tab_massive.py
import tkinter as tk
from tkinter import filedialog, messagebox
from PIL import Image, ImageTk

PIXEL_SIZE = 4
WIDTH, HEIGHT = 128, 64

class MassiveTab:
    def __init__(self, app):
        self.app = app
        self.frame = app.tab3

        self.canvas = tk.Canvas(self.frame, width=WIDTH*PIXEL_SIZE, height=HEIGHT*PIXEL_SIZE, bg="white")
        self.canvas.pack(pady=5)

        control = tk.Frame(self.frame)
        control.pack()
        tk.Button(control, text="Cargar imagen de fondo", command=self.load_image).pack(side="left", padx=5)
        tk.Button(control, text="Generar desde imagen", command=self.generate_from_image).pack(side="left", padx=5)
        tk.Button(control, text="Limpiar todo", command=self.clear_all).pack(side="left", padx=5)

        self.threshold = tk.IntVar(value=128)
        tk.Label(control, text="Umbral").pack(side="left")
        tk.Scale(control, from_=0, to=255, orient="horizontal", variable=self.threshold, command=lambda e: self.refresh()).pack(side="left")

        self.invert_bits = tk.BooleanVar(value=False)
        tk.Checkbutton(control, text="Invertir bits", variable=self.invert_bits).pack(side="left")
        self.show_image = tk.BooleanVar(value=True)
        tk.Checkbutton(control, text="Mostrar plantilla", variable=self.show_image, command=self.refresh).pack(side="left")

        pos_frame = tk.Frame(self.frame)
        pos_frame.pack(pady=5)
        tk.Label(pos_frame, text="Insertar en RAM .mem desde X:").pack(side="left")
        self.pos_x_entry = tk.Entry(pos_frame, width=3)
        self.pos_x_entry.insert(0, "12")
        self.pos_x_entry.pack(side="left")
        tk.Label(pos_frame, text="Y:").pack(side="left")
        self.pos_y_entry = tk.Entry(pos_frame, width=3)
        self.pos_y_entry.insert(0, "8")
        self.pos_y_entry.pack(side="left")
        tk.Button(pos_frame, text="Insertar en RAM .mem", command=self.insert_into_mem).pack(side="left", padx=5)

        self.img = None
        self.imgtk = None

        self.canvas.bind("<Button-1>", self.toggle_pixel)
        self.refresh()

    def refresh(self):
        self.canvas.delete("all")
        if self.show_image.get() and self.imgtk:
            self.canvas.create_image(0, 0, anchor="nw", image=self.imgtk)

        for i in range(8):
            for j in range(16):
                char_index = 128 + i * 16 + j
                for y in range(8):
                    byte = self.app.char_data[char_index][y]
                    for x in range(8):
                        bit = (byte >> (7 - x)) & 1
                        color = "black" if bit else "white"
                        self.canvas.create_rectangle(
                            j*8*PIXEL_SIZE + x*PIXEL_SIZE,
                            i*8*PIXEL_SIZE + y*PIXEL_SIZE,
                            j*8*PIXEL_SIZE + (x+1)*PIXEL_SIZE,
                            i*8*PIXEL_SIZE + (y+1)*PIXEL_SIZE,
                            fill=color, outline="gray")
        self.canvas.update_idletasks()

    def toggle_pixel(self, event):
        x, y = event.x // PIXEL_SIZE, event.y // PIXEL_SIZE
        col, px = divmod(x, 8)
        row, py = divmod(y, 8)
        char_index = 128 + row * 16 + col
        if 128 <= char_index < 256 and 0 <= px < 8 and 0 <= py < 8:
            byte = self.app.char_data[char_index][py]
            mask = 1 << (7 - px)
            self.app.char_data[char_index][py] = byte ^ mask
            self.refresh()

    def load_image(self):
        path = filedialog.askopenfilename(filetypes=[("PNG", "*.png")])
        if not path:
            return
        img = Image.open(path).convert("L").resize((WIDTH, HEIGHT), Image.NEAREST)
        self.img = img
        rgba = Image.new("RGBA", img.size)
        for y in range(img.height):
            for x in range(img.width):
                val = img.getpixel((x, y))
                rgba.putpixel((x, y), (val, val, val, 128))
        self.imgtk = ImageTk.PhotoImage(rgba.resize((WIDTH*PIXEL_SIZE, HEIGHT*PIXEL_SIZE), Image.NEAREST))
        self.show_image.set(True)
        self.refresh()

    def generate_from_image(self):
        if not self.img:
            return
        thresh = self.threshold.get()
        for y in range(HEIGHT):
            for x in range(WIDTH):
                val = self.img.getpixel((x, y))
                bit = 1 if val < thresh else 0
                if self.invert_bits.get():
                    bit = 1 - bit
                col, px = divmod(x, 8)
                row, py = divmod(y, 8)
                char_index = 128 + row * 16 + col
                if bit:
                    self.app.char_data[char_index][py] |= (1 << (7 - px))
                else:
                    self.app.char_data[char_index][py] &= ~(1 << (7 - px))
        self.refresh()

    def clear_all(self):
        for i in range(128, 256):
            for j in range(8):
                self.app.char_data[i][j] = 0
        self.refresh()

    def insert_into_mem(self):
        try:
            x = int(self.pos_x_entry.get())
            y = int(self.pos_y_entry.get())
            if not (0 <= x <= 31 and 0 <= y <= 31):
                raise ValueError
        except ValueError:
            messagebox.showerror("Error", "Coordenadas X/Y inválidas (0–31, 0–31).")
            return

        mem_in_path = filedialog.askopenfilename(title="Selecciona archivo .mem de entrada", filetypes=[("Mem files", "*.mem")])
        if not mem_in_path:
            return

        try:
            with open(mem_in_path, 'r') as f:
                lines = [line.strip() for line in f.readlines()]
            if len(lines) != 1024:
                raise ValueError("El archivo debe tener exactamente 1024 líneas.")

            # Insertar los caracteres 128–255 (bitmap 128x64 → 16x8 caracteres)
            for i in range(8):
                for j in range(16):
                    char_index = 128 + i * 16 + j
                    pos = (y + i) * 48 + (x + j)
                    if 0 <= pos < len(lines):
                        lines[pos] = f"{char_index:02X}"

            mem_out_path = filedialog.asksaveasfilename(defaultextension=".mem", filetypes=[("Mem files", "*.mem")], title="Guardar archivo actualizado")
            if not mem_out_path:
                return
            with open(mem_out_path, 'w') as f:
                f.writelines(line + "\n" for line in lines)

            messagebox.showinfo("Éxito", "Bloque insertado correctamente en el archivo .mem")
        except Exception as e:
            messagebox.showerror("Error", f"Error al insertar en .mem: {e}")
