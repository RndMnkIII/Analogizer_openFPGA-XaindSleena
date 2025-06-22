from PIL import Image
import numpy as np

def analizar_png(path):
    img = Image.open(path)
    print(f"📄 Archivo: {path}")
    print(f"🖼️  Modo de imagen: {img.mode}")

    if "bit" in img.info:
        print(f"🧠 Profundidad de bits declarada: {img.info['bit']}")

    if img.mode == "RGBA":
        print("✅ Tiene canal alfa (RGBA)")
        arr = np.array(img)
        alpha = arr[:, :, 3]
        num_transparent = np.sum(alpha == 0)
        print(f"🔍 Píxeles con alfa = 0 (total transparente): {num_transparent}")
        if num_transparent > 0:
            print("✔️ Imagen contiene transparencia real (canal alfa)")
        else:
            print("❌ Canal alfa presente, pero no hay píxeles transparentes")
    
    elif img.mode == "P":
        print("ℹ️ Imagen en modo indexado (paleta)")
        if "transparency" in img.info:
            transparency = img.info["transparency"]
            if isinstance(transparency, int):
                print(f"✅ Transparencia en paleta: índice transparente = {transparency}")
                arr = np.array(img)
                num_transparent = np.sum(arr == transparency)
                print(f"🔍 Píxeles con índice transparente: {num_transparent}")
            elif isinstance(transparency, bytes):
                print("✅ Transparencia parcial por índice (tRNS con múltiples entradas)")
                transparent_indices = [i for i, alpha in enumerate(transparency) if alpha == 0]
                print(f"Índices con alpha=0: {transparent_indices}")
                arr = np.array(img)
                mask = np.isin(arr, transparent_indices)
                print(f"🔍 Píxeles transparentes detectados: {np.sum(mask)}")
            else:
                print("❓ Chunk tRNS presente pero formato no reconocido")
        else:
            print("❌ No hay chunk de transparencia (tRNS)")
    
    else:
        print("❌ No tiene canal alfa ni paleta indexada con transparencia detectada")

# --- USO ---
analizar_png("Analogizer_graffitti128_64_01.png")
