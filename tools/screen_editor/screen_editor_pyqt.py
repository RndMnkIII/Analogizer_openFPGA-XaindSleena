
import sys
from PyQt5.QtWidgets import (QApplication, QWidget, QMainWindow, QPushButton,
                             QFileDialog, QVBoxLayout, QHBoxLayout, QMessageBox, QLabel)
from PyQt5.QtGui import QPainter, QColor, QFont
from PyQt5.QtCore import Qt, QRect

PIXEL_SIZE = 2
CHAR_WIDTH = 8
CHAR_HEIGHT = 8
SCREEN_COLS = 48
SCREEN_ROWS = 32

class Font:
    def __init__(self):
        self.chars = [[0] * 8 for _ in range(256)]

    def load(self, path):
        with open(path, "r") as f:
            lines = [line.strip() for line in f.readlines()]
        if len(lines) != 2048:
            raise ValueError("La fuente debe tener 2048 líneas.")
        for i in range(256):
            for j in range(8):
                self.chars[i][j] = int(lines[i * 8 + j], 16)

    def mirror_horizontal(self):
        def reverse_byte(b):
            return int('{:08b}'.format(b)[::-1], 2)
        for i in range(256):
            self.chars[i] = [reverse_byte(byte) for byte in self.chars[i]]


class RAM:
    def __init__(self):
        self.data = [[32] * SCREEN_COLS for _ in range(SCREEN_ROWS)]

    def load(self, path):
        with open(path, "r") as f:
            lines = [line.strip() for line in f.readlines()]
        if len(lines) != SCREEN_COLS * SCREEN_ROWS:
            raise ValueError("RAM debe tener 1536 líneas.")
        for y in range(SCREEN_ROWS):
            for x in range(SCREEN_COLS):
                self.data[y][x] = int(lines[y * SCREEN_COLS + x], 16)

    def save(self, path):
        with open(path, "w") as f:
            for row in self.data:
                for val in row:
                    f.write(f"{val:02X}\n")

class ScreenWidget(QWidget):
    def __init__(self, font, ram, palette, owner=None, parent=None):
        super().__init__(parent)
        self.owner = owner
        self.setFocusPolicy(Qt.StrongFocus)
        self.owner = owner
        self.font = font
        self.ram = ram
        self.selected_char = 65
        self.cursor_x = 0
        self.cursor_y = 0
        self.show_grid = True
        self.setFixedSize(SCREEN_COLS * CHAR_WIDTH * PIXEL_SIZE, SCREEN_ROWS * CHAR_HEIGHT * PIXEL_SIZE)
        self.setFocusPolicy(Qt.StrongFocus)
        self.palette = palette
        self.cursor_label = QLabel(self)
        self.cursor_label.setStyleSheet('border: 2px solid red;')
        self.cursor_label.resize(CHAR_WIDTH * PIXEL_SIZE, CHAR_HEIGHT * PIXEL_SIZE)
        self.cursor_label.raise_()
        self.update_cursor_position()
        self.last_ram = [[-1 for _ in range(SCREEN_COLS)] for _ in range(SCREEN_ROWS)]
        self.grid_overlay = self.build_grid_overlay()
        self.clipboard_char = None
        self.undo_stack = []
        self.redo_stack = []
    
    def update_cursor_position(self):
        self.cursor_label.move(self.cursor_x * CHAR_WIDTH * PIXEL_SIZE,
                               self.cursor_y * CHAR_HEIGHT * PIXEL_SIZE)

    def build_grid_overlay(self):
        from PyQt5.QtGui import QPainter, QPixmap, QColor
        pixmap = QPixmap(SCREEN_COLS * CHAR_WIDTH * PIXEL_SIZE, SCREEN_ROWS * CHAR_HEIGHT * PIXEL_SIZE)
        pixmap.fill(QColor(0, 0, 0, 0))
        qp = QPainter(pixmap)
        qp.setPen(QColor(220, 220, 220, 100))
        for x in range(SCREEN_COLS + 1):
            qp.drawLine(x * CHAR_WIDTH * PIXEL_SIZE, 0,
                        x * CHAR_WIDTH * PIXEL_SIZE, SCREEN_ROWS * CHAR_HEIGHT * PIXEL_SIZE)
        for y in range(SCREEN_ROWS + 1):
            qp.drawLine(0, y * CHAR_HEIGHT * PIXEL_SIZE,
                        SCREEN_COLS * CHAR_WIDTH * PIXEL_SIZE, y * CHAR_HEIGHT * PIXEL_SIZE)
        qp.end()
        return pixmap

    def keyPressEvent(self, event):
        key = event.key()
        #Caracteres ASCII imprimibles
        char = event.text()
        if char and 32 <= ord(char) <= 126:
            value = ord(char)
            #value = event.key()

            old = self.ram.data[self.cursor_y][self.cursor_x]
            self.record_action(self.cursor_x, self.cursor_y, old, value)
            self.ram.data[self.cursor_y][self.cursor_x] = value
            print(f"[RAM] Insertado directo ASCII {value} ('{chr(value)}') en ({self.cursor_x}, {self.cursor_y})")
            if self.owner:
                self.owner.update_status()
            self.update()
            self.advance_cursor()
        # Mover el cursor
        elif key == Qt.Key_Left and self.cursor_x > 0:
            self.cursor_x -= 1
        elif key == Qt.Key_Right and self.cursor_x < SCREEN_COLS - 1:
            self.cursor_x += 1
        elif key == Qt.Key_Up and self.cursor_y > 0:
            self.cursor_y -= 1
        elif key == Qt.Key_Down and self.cursor_y < SCREEN_ROWS - 1:
            self.cursor_y += 1
        # Copiar
        elif key == Qt.Key_C and (event.modifiers() & Qt.ControlModifier):
            self.clipboard_char = self.ram.data[self.cursor_y][self.cursor_x]
            #print(f"[RAM] Copiado ASCII {self.clipboard_char} desde ({self.cursor_x}, {self.cursor_y})")
        # Pegar
        elif key == Qt.Key_V and (event.modifiers() & Qt.ControlModifier):
            if self.clipboard_char is not None:
                self.ram.data[self.cursor_y][self.cursor_x] = self.clipboard_char
                self.advance_cursor()
                #print(f"[RAM] Pegado ASCII {self.clipboard_char} en ({self.cursor_x}, {self.cursor_y})")
                if self.owner:
                    self.owner.update_status()
                self.update()
        # Tecla enter, introducir el carácter seleccionado
        elif key in (Qt.Key_Return, Qt.Key_Enter):
            if self.palette:
                value = self.palette.selected_char
                old = self.ram.data[self.cursor_y][self.cursor_x]
                self.record_action(self.cursor_x, self.cursor_y, old, value)
                self.ram.data[self.cursor_y][self.cursor_x] = value
                self.advance_cursor()
            #print(f"[RAM] Insertado ASCII {value} en ({self.cursor_x}, {self.cursor_y})")
            if self.owner: 
                self.owner.update_status()
            self.update()

        #Undo y Redo    
        elif key == Qt.Key_Z and (event.modifiers() & Qt.ControlModifier):
            if self.undo_stack:
                # Deshacer: aplicar old_value y guardar acción en redo
                x, y, old, new = self.undo_stack.pop()
                self.redo_stack.append((x, y, old, new))  # importante: en orden correcto
                self.ram.data[y][x] = old
                self.cursor_x, self.cursor_y = x, y
                #print(f"[UNDO] Revertido a ASCII {old} en ({x}, {y})")
                if self.owner:
                    self.owner.update_status()
                self.update()
        elif key == Qt.Key_Y and (event.modifiers() & Qt.ControlModifier):
            if self.redo_stack:
                # Rehacer: aplicar new_value y registrar en undo
                x, y, old, new = self.redo_stack.pop()
                self.undo_stack.append((x, y, self.ram.data[y][x], new))
                self.ram.data[y][x] = new
                self.cursor_x, self.cursor_y = x, y
                #print(f"[REDO] Reaplicado ASCII {new} en ({x}, {y})")
                if self.owner:
                    self.owner.update_status()
                self.update()
        elif key == Qt.Key_Backspace:
            if self.cursor_x > 0:
                self.cursor_x -= 1
            elif self.cursor_y > 0:
                self.cursor_y -= 1
                self.cursor_x = SCREEN_COLS - 1
            else:
                return  # no moverse más allá de (0,0)

            old = self.ram.data[self.cursor_y][self.cursor_x]
            self.record_action(self.cursor_x, self.cursor_y, old, 32)
            self.ram.data[self.cursor_y][self.cursor_x] = 32
            #print(f"[RAM] Borrado en ({self.cursor_x}, {self.cursor_y})")
            if self.owner:
                self.owner.update_status()
            self.update()
        self.update_cursor_position()

    def update_cursor_position(self):
        self.cursor_label.move(self.cursor_x * CHAR_WIDTH * PIXEL_SIZE,
                               self.cursor_y * CHAR_HEIGHT * PIXEL_SIZE)

    def paintEvent(self, event):
        qp = QPainter(self)

        # Dibujar caracteres
        for y in range(SCREEN_ROWS):
            for x in range(SCREEN_COLS):
                char = self.ram.data[y][x]
                self.draw_char(qp, char, x, y)

        # Rejilla (si está activada)
        if getattr(self, "show_grid", True):
            qp.setPen(QColor(220, 220, 220, 100))
            for x in range(SCREEN_COLS + 1):
                qp.drawLine(x * CHAR_WIDTH * PIXEL_SIZE, 0,
                            x * CHAR_WIDTH * PIXEL_SIZE, SCREEN_ROWS * CHAR_HEIGHT * PIXEL_SIZE)
            for y in range(SCREEN_ROWS + 1):
                qp.drawLine(0, y * CHAR_HEIGHT * PIXEL_SIZE,
                            SCREEN_COLS * CHAR_WIDTH * PIXEL_SIZE, y * CHAR_HEIGHT * PIXEL_SIZE)

    def draw_char(self, qp, char, cx, cy):
        base_x = cx * CHAR_WIDTH * PIXEL_SIZE
        base_y = cy * CHAR_HEIGHT * PIXEL_SIZE
        for row in range(8):
            byte = self.font.chars[char][row]
            for col in range(8):
                bit = (byte >> (7 - col)) & 1
                color = QColor("black") if bit else QColor("white")
                qp.fillRect(QRect(base_x + col * PIXEL_SIZE,
                                  base_y + row * PIXEL_SIZE,
                                  PIXEL_SIZE, PIXEL_SIZE), color)
    
    def toggle_grid(self):
        self.show_grid = not self.show_grid
        self.update_cursor_position()

    def mousePressEvent(self, event):
        self.setFocus()
        x = event.x() // (CHAR_WIDTH * PIXEL_SIZE)
        y = event.y() // (CHAR_HEIGHT * PIXEL_SIZE)
        self.cursor_x = x
        self.cursor_y = y           
        if 0 <= x < SCREEN_COLS and 0 <= y < SCREEN_ROWS:
            if self.palette:
                value = self.palette.selected_char
                old = self.ram.data[self.cursor_y][self.cursor_x]
                self.record_action(x, y, old, value)
                self.ram.data[y][x] = value
            #print(f"[RAM] Insertado ASCII {value} en ({self.cursor_x}, {self.cursor_y})")
            if self.owner: 
                self.owner.update_status()
            self.update()
            self.update_cursor_position()

    def record_action(self, x, y, old_value, new_value):
        self.undo_stack.append((x, y, old_value, new_value))
        self.redo_stack.clear()

    def advance_cursor(self):
        if self.cursor_x < SCREEN_COLS - 1:
            self.cursor_x += 1
        elif self.cursor_y < SCREEN_ROWS - 1:
            self.cursor_x = 0
            self.cursor_y += 1

    def update_status(self):
        ascii_code = self.palette.selected_char
        x, y = self.screen.cursor_x, self.screen.cursor_y
        self.status_bar.setText(f"RAM: ({x}, {y})   Carácter: ASCII {ascii_code}")

class PaletteWidget(QWidget):
    def __init__(self, font, owner=None, parent=None):
        super().__init__(parent)
        self.owner = owner
        self.font = font

        self.cursor_x = 0
        self.cursor_y = 0
        self.show_grid = True

        self.setFixedSize(16 * CHAR_WIDTH * PIXEL_SIZE, 16 * CHAR_HEIGHT * PIXEL_SIZE)

        self.cursor_label = QLabel(self)
        self.cursor_label.setStyleSheet('border: 2px solid red;')
        self.cursor_label.resize(CHAR_WIDTH * PIXEL_SIZE, CHAR_HEIGHT * PIXEL_SIZE)
        self.cursor_label.raise_()
        self.update_cursor_position()

    @property
    def selected_char(self):
        return self.cursor_y * 16 + self.cursor_x

    def update_cursor_position(self):
        self.cursor_label.move(
            self.cursor_x * CHAR_WIDTH * PIXEL_SIZE,
            self.cursor_y * CHAR_HEIGHT * PIXEL_SIZE
        )

    def build_grid_overlay(self):
        from PyQt5.QtGui import QPainter, QPixmap, QColor
        pixmap = QPixmap(16 * CHAR_WIDTH * PIXEL_SIZE, 16 * CHAR_HEIGHT * PIXEL_SIZE)
        pixmap.fill(QColor(0, 0, 0, 0))
        qp = QPainter(pixmap)
        qp.setPen(QColor(220, 220, 220, 100))
        for x in range(17):
            qp.drawLine(x * CHAR_WIDTH * PIXEL_SIZE, 0,
                        x * CHAR_WIDTH * PIXEL_SIZE, 16 * CHAR_HEIGHT * PIXEL_SIZE)
        for y in range(17):
            qp.drawLine(0, y * CHAR_HEIGHT * PIXEL_SIZE,
                        16 * CHAR_WIDTH * PIXEL_SIZE, y * CHAR_HEIGHT * PIXEL_SIZE)
        qp.end()
        return pixmap

    def paintEvent(self, event):
        qp = QPainter(self)
        for i in range(256):
            row, col = divmod(i, 16)
            self.draw_char(qp, i, col, row)

        if self.show_grid:
            qp.setPen(QColor(220, 220, 220, 180))
            for x in range(17):
                qp.drawLine(x * CHAR_WIDTH * PIXEL_SIZE, 0,
                            x * CHAR_WIDTH * PIXEL_SIZE, 16 * CHAR_HEIGHT * PIXEL_SIZE)
            for y in range(17):
                qp.drawLine(0, y * CHAR_HEIGHT * PIXEL_SIZE,
                            16 * CHAR_WIDTH * PIXEL_SIZE, y * CHAR_HEIGHT * PIXEL_SIZE)

    def draw_char(self, qp, char, cx, cy):
        base_x = cx * CHAR_WIDTH * PIXEL_SIZE
        base_y = cy * CHAR_HEIGHT * PIXEL_SIZE
        for row in range(8):
            byte = self.font.chars[char][row]
            for col in range(8):
                bit = (byte >> (7 - col)) & 1
                color = QColor("black") if bit else QColor("white")
                qp.fillRect(QRect(base_x + col * PIXEL_SIZE,
                                  base_y + row * PIXEL_SIZE,
                                  PIXEL_SIZE, PIXEL_SIZE), color)

    def toggle_grid(self):
        self.show_grid = not self.show_grid
        self.update()

    def mousePressEvent(self, event):
        self.setFocus()
        x = event.pos().x() // (CHAR_WIDTH * PIXEL_SIZE)
        y = event.pos().y() // (CHAR_HEIGHT * PIXEL_SIZE)
        if 0 <= x < 16 and 0 <= y < 16:
            self.cursor_x = x
            self.cursor_y = y
            print(f"[PALETA] Seleccionado ({x}, {y}) -> ASCII {self.selected_char}")
        self.update_cursor_position()
        if self.owner:
            self.owner.update_status()
            # 🔽 MANDAR FOCO A LA RAM
            if hasattr(self.owner, "screen"):
                self.owner.screen.setFocus()
                

class EditorWindow(QMainWindow):
    def __init__(self):
        super().__init__()  # ✅ sin parámetros
        self.setWindowTitle("Analogizer OSD Screen Editor")
        self.font = Font()
        self.ram = RAM()

        self.palette = PaletteWidget(self.font, owner=self)
        #print("PALETA:", type(self.palette))
        self.screen = ScreenWidget(self.font, self.ram, self.palette, owner=self)

        btn_load_font = QPushButton("Cargar fuente")
        btn_load_font.clicked.connect(self.load_font)
        btn_load_ram = QPushButton("Cargar RAM")
        btn_load_ram.clicked.connect(self.load_ram)
        btn_save_ram = QPushButton("Guardar RAM")
        btn_save_ram.clicked.connect(self.save_ram)

        buttons = QHBoxLayout()
        buttons.addWidget(btn_load_font)
        buttons.addWidget(btn_load_ram)
        buttons.addWidget(btn_save_ram)
        btn_mirror_font = QPushButton("Reflejar fuente")
        btn_mirror_font.clicked.connect(self.mirror_font)
        self.btn_toggle_grid = QPushButton("Ocultar rejilla")
        self.btn_toggle_grid.clicked.connect(self.toggle_grid)
        buttons.addWidget(btn_mirror_font)
        buttons.addWidget(self.btn_toggle_grid)


        layout = QVBoxLayout()
        row = QHBoxLayout()
        row.addWidget(self.screen)
        row.addWidget(self.palette)
        layout.addLayout(row)
        layout.addLayout(buttons)
        self.status_bar = QLabel("Listo")
        layout.addWidget(self.status_bar)

        container = QWidget()
        container.setLayout(layout)
        self.setCentralWidget(container)
        self.screen.setFocus()

    
    def set_selected_char(self, char):
        self.screen.selected_char = char
        self.screen.update()

    def toggle_grid(self):
        self.screen.toggle_grid()       # Cambia estado de visibilidad
        self.palette.show_grid = self.screen.show_grid
        self.palette.update()           # Refresca visualmente la paleta
        if self.screen.show_grid:
            self.btn_toggle_grid.setText("Ocultar rejilla")
        else:
            self.btn_toggle_grid.setText("Mostrar rejilla")

    def load_font(self):
        path, _ = QFileDialog.getOpenFileName(self, "Abrir fuente", "", "Archivos MEM (*.mem)")
        if path:
            try:
                self.font.load(path)
                self.screen.update()
                self.palette.update()
            except Exception as e:
                QMessageBox.critical(self, "Error", str(e))

    def load_ram(self):
        path, _ = QFileDialog.getOpenFileName(self, "Abrir RAM", "", "Archivos MEM (*.mem)")
        if path:
            try:
                self.ram.load(path)
                self.screen.update()
            except Exception as e:
                QMessageBox.critical(self, "Error", str(e))

    def save_ram(self):
        path, _ = QFileDialog.getSaveFileName(self, "Guardar RAM", "", "Archivos MEM (*.mem)")
        if path:
            try:
                self.ram.save(path)
                QMessageBox.information(self, "Éxito", "RAM guardada correctamente.")
            except Exception as e:
                QMessageBox.critical(self, "Error", str(e))
                
    def mirror_font(self):
        self.font.mirror_horizontal()
        self.screen.update()
        self.palette.update()

    def update_status(self):
        ascii_code = self.palette.selected_char
        x, y = self.screen.cursor_x, self.screen.cursor_y
        self.status_bar.setText(f"RAM: ({x}, {y})   Carácter: ASCII {ascii_code}")

def main():
    app = QApplication(sys.argv)
    win = EditorWindow()
    win.show()
    sys.exit(app.exec_())

if __name__ == "__main__":
    main()
