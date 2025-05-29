import hashlib
import os
import tkinter as tk
from tkinter import messagebox
from tkinterdnd2 import DND_FILES, TkinterDnD

def calcular_md5(ruta_archivo, tam_bloque=4096):
    md5 = hashlib.md5()
    try:
        with open(ruta_archivo, 'rb') as f:
            while chunk := f.read(tam_bloque):
                md5.update(chunk)
        return md5.hexdigest()
    except Exception as e:
        return f"[ERROR] {e}"

def mostrar_md5(ruta):
    md5 = calcular_md5(ruta)
    texto_completo = f"Archivo:\n{ruta}\n\nMD5:\n{md5}"

    resultado = tk.Toplevel()
    resultado.title("Resultado MD5")

    text = tk.Text(resultado, wrap="word", height=10, width=80)
    text.insert("1.0", texto_completo)
    text.config(state="normal")
    text.pack(padx=10, pady=10)

    def copiar_al_portapapeles():
        resultado.clipboard_clear()
        resultado.clipboard_append(md5)
        messagebox.showinfo("Copiado", "MD5 copiado al portapapeles.")

    btn_copiar = tk.Button(resultado, text="Copiar MD5 al portapapeles", command=copiar_al_portapapeles)
    btn_copiar.pack(pady=(0, 10))

def procesar_archivo_drop(event):
    archivo = event.data.strip().strip('{}')  # Maneja nombres con espacios
    if not os.path.isfile(archivo):
        messagebox.showerror("Error", f"No es un archivo válido:\n{archivo}")
        return
    mostrar_md5(archivo)

def crear_interfaz_drag_and_drop():
    root = TkinterDnD.Tk()
    root.title("Arrastra un archivo aquí para calcular su MD5")
    root.geometry("500x150")

    label = tk.Label(root, text="⬇️ Arrastra un archivo aquí ⬇️", font=("Arial", 14))
    label.pack(pady=20)

    drop_area = tk.Label(root, text="(Suelta el archivo en esta zona)", relief="groove", width=50, height=4)
    drop_area.pack(pady=10)
    drop_area.drop_target_register(DND_FILES)
    drop_area.dnd_bind("<<Drop>>", procesar_archivo_drop)

    root.mainloop()

if __name__ == "__main__":
    crear_interfaz_drag_and_drop()
