# editor_tab_classic.py
import tkinter as tk
from tkinter import messagebox

FONT_WIDTH = 8
FONT_HEIGHT = 8
PIXEL_SIZE = 16
GRID_COLS = 4
GRID_ROWS = 4
VISIBLE_CHARS = GRID_COLS * GRID_ROWS

class ClassicTab:
    def __init__(self, app):
        self.app = app
        self.frame = app.tab1
        self.canvas = tk.Canvas(self.frame, width=GRID_COLS*FONT_WIDTH*PIXEL_SIZE,
                                height=GRID_ROWS*FONT_HEIGHT*PIXEL_SIZE + GRID_ROWS*20,
                                bg="white")
        self.canvas.pack()

        self.button_frame = tk.Frame(self.frame)
        self.button_frame.pack()
        tk.Button(self.button_frame, text="Anterior", command=self.prev_page).pack(side="left")
        tk.Button(self.button_frame, text="Siguiente", command=self.next_page).pack(side="left")
        tk.Button(self.button_frame, text="Copiar", command=self.copy_char).pack(side="left")
        tk.Button(self.button_frame, text="Pegar", command=self.paste_char).pack(side="left")

        self.base_char = 0
        self.selected_char = 0
        self.clipboard = None

        self.canvas.bind("<Button-1>", self.toggle_pixel)
        self.refresh()

    def refresh(self):
        self.canvas.delete("all")
        for idx in range(VISIBLE_CHARS):
            char_index = self.base_char + idx
            if char_index >= 128:
                continue
            col = idx % GRID_COLS
            row = idx // GRID_COLS
            x0 = col * FONT_WIDTH * PIXEL_SIZE
            y0 = row * (FONT_HEIGHT * PIXEL_SIZE + 20)
            self.canvas.create_text(x0 + 2, y0, anchor="nw", text=f"{char_index:03}", font=("Courier", 10))
            y0 += 16
            for y in range(FONT_HEIGHT):
                byte = self.app.char_data[char_index][y]
                for x in range(FONT_WIDTH):
                    bit = (byte >> (7 - x)) & 1
                    color = "black" if bit else "white"
                    self.canvas.create_rectangle(
                        x0 + x * PIXEL_SIZE, y0 + y * PIXEL_SIZE,
                        x0 + (x + 1) * PIXEL_SIZE, y0 + (y + 1) * PIXEL_SIZE,
                        fill=color, outline="gray")
        self.canvas.update_idletasks()

    def get_char_from_event(self, event):
        col = event.x // (FONT_WIDTH * PIXEL_SIZE)
        row = event.y // (FONT_HEIGHT * PIXEL_SIZE + 20)
        if col >= GRID_COLS or row >= GRID_ROWS:
            return None
        return self.base_char + row * GRID_COLS + col

    def toggle_pixel(self, event):
        char = self.get_char_from_event(event)
        if char is None or char >= 128:
            return
        col = (event.x % (FONT_WIDTH * PIXEL_SIZE)) // PIXEL_SIZE
        row = ((event.y % (FONT_HEIGHT * PIXEL_SIZE + 20)) - 16) // PIXEL_SIZE
        if 0 <= col < FONT_WIDTH and 0 <= row < FONT_HEIGHT:
            byte = self.app.char_data[char][row]
            mask = 1 << (7 - col)
            self.app.char_data[char][row] = byte ^ mask
            self.selected_char = char
            self.refresh()

    def prev_page(self):
        self.base_char = max(0, self.base_char - VISIBLE_CHARS)
        self.refresh()

    def next_page(self):
        self.base_char = min(128 - VISIBLE_CHARS, self.base_char + VISIBLE_CHARS)
        self.refresh()

    def copy_char(self):
        self.clipboard = list(self.app.char_data[self.selected_char])
        messagebox.showinfo("Copiado", f"Carácter {self.selected_char} copiado")

    def paste_char(self):
        if self.clipboard:
            self.app.char_data[self.selected_char] = list(self.clipboard)
            self.refresh()
        else:
            messagebox.showwarning("Vacío", "No hay carácter copiado")
