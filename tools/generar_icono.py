import os
import math
from PIL import Image, ImageDraw

def generar_icono(ruta_salida="assets/icon/icon.png", tamano=(1024, 1024)):
    os.makedirs(os.path.dirname(ruta_salida), exist_ok=True)
    
    # Color de fondo azul agua #0E7FB8
    color_fondo = (14, 127, 184, 255)
    img = Image.new("RGBA", tamano, color_fondo)
    draw = ImageDraw.Draw(img)

    cx, cy = tamano[0] // 2, tamano[1] // 2 - 40
    
    # 1. Dibujar gota de agua blanca estilizada
    # La gota se forma mediante un arco circular en la base y dos líneas tangentes hacia la cúspide
    radio_base = 210
    centro_base_y = cy + 110
    cuspide_y = cy - 280
    
    puntos_gota = []
    
    # Cúspide de la gota
    puntos_gota.append((cx, cuspide_y))
    
    # Lado derecho hacia el arco base
    # Arco desde ángulo -30° hasta 210°
    pasos = 60
    for i in range(pasos + 1):
        # Ángulos desde -25° a 205° (en radianes)
        theta = math.radians(-25 + (230 * i / pasos))
        px = cx + radio_base * math.cos(theta)
        py = centro_base_y + radio_base * math.sin(theta)
        puntos_gota.append((px, py))
        
    puntos_gota.append((cx, cuspide_y))
    
    # Rellenar la gota en blanco puro
    draw.polygon(puntos_gota, fill=(255, 255, 255, 255))
    
    # Suavizar el círculo de la base
    draw.ellipse(
        [cx - radio_base, centro_base_y - radio_base, cx + radio_base, centro_base_y + radio_base],
        fill=(255, 255, 255, 255)
    )
    
    # Detalle interno sutil en la gota (reflejo estilizado)
    radio_reflejo = 140
    draw.arc(
        [cx - radio_reflejo, centro_base_y - radio_reflejo - 20, cx + radio_reflejo - 40, centro_base_y + radio_reflejo - 40],
        start=190,
        end=260,
        fill=(14, 127, 184, 180),
        width=22
    )

    # 2. Línea de caudal estilizada en la parte inferior (onda de flujo de agua)
    y_onda = cy + 350
    puntos_linea_caudal = []
    amplitud = 28
    longitud_onda = 180
    ancho_onda = 580
    x_inicio = cx - ancho_onda // 2
    
    for x_offset in range(0, ancho_onda + 1, 4):
        x = x_inicio + x_offset
        y = y_onda + amplitud * math.sin((x_offset / longitud_onda) * 2 * math.pi)
        puntos_linea_caudal.append((x, y))
        
    # Dibujar línea de caudal principal (blanca con terminaciones redondeadas)
    draw.line(puntos_linea_caudal, fill=(255, 255, 255, 240), width=32, joint="curve")
    
    # Segunda línea de caudal más corta debajo
    y_onda_sec = y_onda + 60
    puntos_linea_sec = []
    ancho_sec = 360
    x_inicio_sec = cx - ancho_sec // 2
    for x_offset in range(0, ancho_sec + 1, 4):
        x = x_inicio_sec + x_offset
        y = y_onda_sec + (amplitud * 0.7) * math.sin(((x_offset + 40) / longitud_onda) * 2 * math.pi)
        puntos_linea_sec.append((x, y))
        
    draw.line(puntos_linea_sec, fill=(255, 255, 255, 180), width=20, joint="curve")

    img.save(ruta_salida, format="PNG")
    print(f"Icono generado exitosamente en: {ruta_salida}")

if __name__ == "__main__":
    generar_icono()

