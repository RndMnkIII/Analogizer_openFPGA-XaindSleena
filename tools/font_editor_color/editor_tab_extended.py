# editor_tab_extended.py
import tkinter as tk
from tkinter import filedialog, messagebox
from PIL import Image, ImageTk
from collections import Counter


PIXEL_SIZE = 4
WIDTH, HEIGHT = 128, 32

class ExtendedTab:
    def __init__(self, app):
        self.app = app
        self.frame = app.tab2

        self.upper_canvas = tk.Canvas(self.frame, width=WIDTH*PIXEL_SIZE, height=HEIGHT*PIXEL_SIZE, bg="white")
        self.upper_canvas.pack(pady=5)
        self.lower_canvas = tk.Canvas(self.frame, width=WIDTH*PIXEL_SIZE, height=HEIGHT*PIXEL_SIZE, bg="white")
        self.lower_canvas.pack(pady=5)

        self.upper_img = None
        self.lower_img = None
        self.upper_imgtk = None
        self.lower_imgtk = None

        control_frame = tk.Frame(self.frame)
        control_frame.pack()
        tk.Button(control_frame, text="Cargar plantilla superior", command=self.load_upper_image).pack(side="left", padx=5)
        tk.Button(control_frame, text="Cargar plantilla inferior", command=self.load_lower_image).pack(side="left", padx=5)
        tk.Button(control_frame, text="Aplicar imagen", command=self.apply_images_to_char_data).pack(side="left", padx=10)
        self.show_upper = tk.BooleanVar(value=True)
        self.show_lower = tk.BooleanVar(value=True)
        tk.Checkbutton(control_frame, text="Mostrar superior", variable=self.show_upper, command=self.refresh).pack(side="left")
        tk.Checkbutton(control_frame, text="Mostrar inferior", variable=self.show_lower, command=self.refresh).pack(side="left")

        self.upper_canvas.bind("<Button-1>", lambda e: self.toggle_pixel(e, upper=True))
        self.lower_canvas.bind("<Button-1>", lambda e: self.toggle_pixel(e, upper=False))

        self.refresh()

    def refresh(self):
        self.draw_grid(self.upper_canvas, 128, 191, self.upper_imgtk if self.show_upper.get() else None)
        self.draw_grid(self.lower_canvas, 192, 255, self.lower_imgtk if self.show_lower.get() else None)
        self.upper_canvas.update_idletasks()
        self.lower_canvas.update_idletasks()

    def draw_grid(self, canvas, start_char, end_char, background=None):
        canvas.delete("all")
        if background:
            canvas.create_image(0, 0, anchor="nw", image=background)

        k = 0
        for char_index in range(start_char, end_char + 1):
            i, j = divmod(k, 16)
            for y in range(8):
                for x in range(8):
                    color_index = self.app.char_data[char_index][y][x]
                    if color_index == self.app.transparent_index:
                        continue
                    r, g, b = self.app.palette[color_index]
                    color = f"#{r:02x}{g:02x}{b:02x}"
                    canvas.create_rectangle(
                        j*8*PIXEL_SIZE + x*PIXEL_SIZE,
                        i*8*PIXEL_SIZE + y*PIXEL_SIZE,
                        j*8*PIXEL_SIZE + (x+1)*PIXEL_SIZE,
                        i*8*PIXEL_SIZE + (y+1)*PIXEL_SIZE,
                        fill=color, outline="gray")
            k += 1

    def toggle_pixel(self, event, upper):
        x, y = event.x // PIXEL_SIZE, event.y // PIXEL_SIZE
        char_col, pixel_x = divmod(x, 8)
        char_row, pixel_y = divmod(y, 8)
        char_idx = (char_row * 16 + char_col) + (128 if upper else 192)
        if 128 <= char_idx < 256 and 0 <= pixel_x < 8 and 0 <= pixel_y < 8:
            cur = self.app.char_data[char_idx][pixel_y][pixel_x]
            self.app.char_data[char_idx][pixel_y][pixel_x] = (cur + 1) % 16
            self.refresh()

    def load_upper_image(self):
        path = filedialog.askopenfilename(filetypes=[("PNG files", "*.png")])
        if not path:
            return
        img = Image.open(path).convert("RGBA").resize((WIDTH, HEIGHT), Image.NEAREST)
        self.upper_img = img
        self.upper_imgtk = ImageTk.PhotoImage(img.resize((WIDTH*PIXEL_SIZE, HEIGHT*PIXEL_SIZE), Image.NEAREST))
        self.show_upper.set(True)
        self.refresh()

    def load_lower_image(self):
        path = filedialog.askopenfilename(filetypes=[("PNG files", "*.png")])
        if not path:
            return
        img = Image.open(path).convert("RGBA").resize((WIDTH, HEIGHT), Image.NEAREST)
        self.lower_img = img
        self.lower_imgtk = ImageTk.PhotoImage(img.resize((WIDTH*PIXEL_SIZE, HEIGHT*PIXEL_SIZE), Image.NEAREST))
        self.show_lower.set(True)
        self.refresh()

    def closest_palette_index(self, rgb):
        r1, g1, b1 = rgb
        min_dist = float("inf")
        best_index = self.app.transparent_index
        for i, (r2, g2, b2) in enumerate(self.app.palette):
            dist = (r2 - r1)**2 + (g2 - g1)**2 + (b2 - b1)**2
            if dist < min_dist:
                min_dist = dist
                best_index = i
        return best_index


    def apply_images_to_char_data(self):
        count = 0
        for is_upper, img in [(True, self.upper_img), (False, self.lower_img)]:
            if img is None:
                continue

            img_rgba = img.convert("RGBA")
            arr = img_rgba.load()

            # Extraer colores opacos
            colores_opacos = []
            for y in range(HEIGHT):
                for x in range(WIDTH):
                    r, g, b, a = arr[x, y]
                    if a > 0:
                        colores_opacos.append((r, g, b))

            # Elegir 15 colores más comunes
            paleta_generada = [rgb for rgb, _ in Counter(colores_opacos).most_common(15)]

            # Añadir color para transparencia en índice 15 (magenta por ejemplo)
            color_transparente = (0, 0, 0)
            paleta_generada += [color_transparente]
            self.app.palette = paleta_generada[:16]
            self.app.transparent_index = 15

            # Asignar valores a la fuente
            for y in range(HEIGHT):
                for x in range(WIDTH):
                    r, g, b, a = arr[x, y]
                    if a == 0:
                        idx = 15  # transparente
                    else:
                        idx = self.closest_palette_index((r, g, b))
                    char_col, px = divmod(x, 8)
                    char_row, py = divmod(y, 8)
                    char_idx = (char_row * 16 + char_col) + (128 if is_upper else 192)
                    self.app.char_data[char_idx][py][px] = idx
                    count += 1

        self.refresh()
        self.app.massive_tab.refresh()
        self.app.preview_tab.refresh()
        messagebox.showinfo("Imagen aplicada", f"{count} píxeles asignados a caracteres 128–255.")
