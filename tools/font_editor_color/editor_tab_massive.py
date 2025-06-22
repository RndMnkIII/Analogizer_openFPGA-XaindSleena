
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
        tk.Button(control, text="Cargar imagen", command=self.load_image).pack(side="left", padx=5)
        tk.Button(control, text="Aplicar imagen", command=self.apply_image).pack(side="left", padx=5)

        self.img = None
        self.imgtk = None

        self.canvas.bind("<Button-1>", self.toggle_pixel)
        self.refresh()

    def refresh(self):
        self.canvas.delete("all")
        if self.imgtk:
            self.canvas.create_image(0, 0, anchor="nw", image=self.imgtk)

        for i in range(8):
            for j in range(16):
                char_index = 128 + i * 16 + j
                for y in range(8):
                    for x in range(8):
                        color_index = self.app.char_data[char_index][y][x]
                        if color_index == self.app.transparent_index:
                            continue
                        r, g, b = self.app.palette[color_index]
                        color = f"#{r:02x}{g:02x}{b:02x}"
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
            cur = self.app.char_data[char_index][py][px]
            self.app.char_data[char_index][py][px] = (cur + 1) % 16
            self.refresh()

    def load_image(self):
        path = filedialog.askopenfilename(filetypes=[("PNG files", "*.png")])
        if not path:
            return
        
        img = Image.open(path).convert("RGB").resize((WIDTH, HEIGHT), Image.NEAREST)
        img_quant = img.quantize(colors=15, method=2)

        palette_raw = img_quant.getpalette()[:15*3]
        unique_colors = [(palette_raw[i], palette_raw[i+1], palette_raw[i+2]) for i in range(0, len(palette_raw), 3)]
        self.app.palette = unique_colors + [(0, 0, 0)] * (16 - len(unique_colors))
        self.app.transparent_index = 15
        self.app.draw_palette()
    
        palette = img_quant.getpalette()[:15*3]
        unique_colors = [(palette[i], palette[i+1], palette[i+2]) for i in range(0, len(palette), 3)]
        self.app.palette = unique_colors + [(0, 0, 0)] * (16 - len(unique_colors))
        self.app.transparent_index = 15

        # Mapeo de pixeles al índice de color
        img_idx = img_quant.load()
        self.img = img_quant.convert("RGB")
        self.imgtk = ImageTk.PhotoImage(self.img.resize((WIDTH*PIXEL_SIZE, HEIGHT*PIXEL_SIZE), Image.NEAREST))
        self.refresh()

    def apply_image(self):
        if not self.img:
            return
        pixels = self.img.load()
        for y in range(HEIGHT):
            for x in range(WIDTH):
                color = pixels[x, y]
                try:
                    idx = self.app.palette.index(color)
                except ValueError:
                    idx = self.app.transparent_index
                col, px = divmod(x, 8)
                row, py = divmod(y, 8)
                char_index = 128 + row * 16 + col
                self.app.char_data[char_index][py][px] = idx
        self.refresh()
