
import tkinter as tk

PIXEL_SIZE = 4

class PreviewDualTab:
    def __init__(self, app):
        self.app = app
        self.frame = app.tab4

        width = 16 * 8 * PIXEL_SIZE * 2  # 2 columnas de 16x8 caracteres
        height = 8 * 16 * PIXEL_SIZE     # 16 filas de 8 pixeles

        self.canvas = tk.Canvas(self.frame, width=width, height=height, bg="white")
        self.canvas.pack()

        self.refresh()

    def refresh(self):
        self.canvas.delete("all")
        for block in range(2):  # 0 = ASCII 0–127, 1 = ASCII 128–255
            base = block * 128
            for i in range(128):
                row, col = divmod(i, 16)
                char_index = base + i
                for y in range(8):
                    byte = self.app.char_data[char_index][y]
                    for x in range(8):
                        bit = (byte >> (7 - x)) & 1
                        color = "black" if bit else "white"
                        self.canvas.create_rectangle(
                            block*16*8*PIXEL_SIZE + col*8*PIXEL_SIZE + x*PIXEL_SIZE,
                            row*8*PIXEL_SIZE + y*PIXEL_SIZE,
                            block*16*8*PIXEL_SIZE + col*8*PIXEL_SIZE + (x+1)*PIXEL_SIZE,
                            row*8*PIXEL_SIZE + (y+1)*PIXEL_SIZE,
                            fill=color, outline="gray"
                        )
        self.canvas.update_idletasks()
