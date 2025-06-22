
# editor_tab_preview_dual.py
import tkinter as tk

PIXEL_SIZE = 4

class PreviewDualTab:
    def __init__(self, app):
        self.app = app
        self.frame = app.tab4

        width = 16 * 8 * PIXEL_SIZE * 2  # 2 bloques de 16x8
        height = 8 * 16 * PIXEL_SIZE     # 16 filas
        self.canvas = tk.Canvas(self.frame, width=width, height=height, bg="white")
        self.canvas.pack()
        self.refresh()

    def refresh(self):
        self.canvas.delete("all")
        for block in range(2):  # ASCII 0–127 y 128–255
            base = block * 128
            for i in range(128):
                row, col = divmod(i, 16)
                char_index = base + i
                for y in range(8):
                    for x in range(8):
                        color_index = self.app.char_data[char_index][y][x]
                        if color_index == self.app.transparent_index:
                            continue
                        r, g, b = self.app.palette[color_index]
                        color = f"#{r:02x}{g:02x}{b:02x}"
                        self.canvas.create_rectangle(
                            block*16*8*PIXEL_SIZE + col*8*PIXEL_SIZE + x*PIXEL_SIZE,
                            row*8*PIXEL_SIZE + y*PIXEL_SIZE,
                            block*16*8*PIXEL_SIZE + col*8*PIXEL_SIZE + (x+1)*PIXEL_SIZE,
                            row*8*PIXEL_SIZE + (y+1)*PIXEL_SIZE,
                            fill=color, outline="gray")
        self.canvas.update_idletasks()
