"""
Generador de Assets HD para el HUD Estilizado:
- Marco metálico desgastado hueco (centro 100% transparente) para barra de salud
- Viñeta radial oscura y roja para bordes de pantalla al recibir daño
- Iconos de silueta estilizada y nítida para el selector de armas (Pistola, SMG, Escopeta)
"""

import os
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

def generate_hud_hp_frame(out_path: str, w: int = 320, h: int = 36):
    # Imagen totalmente transparente
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Borde exterior metálico reforzado con biseles oscuros (SIN relleno central)
    draw.rounded_rectangle([0, 0, w - 1, h - 1], radius=6, outline=(30, 34, 42, 255), width=3)
    # Reborde interior plateado cepillado
    draw.rounded_rectangle([3, 3, w - 4, h - 4], radius=4, outline=(145, 155, 175, 220), width=2)
    # Línea sutil de desgaste
    draw.line([(6, 4), (w - 7, 4)], fill=(220, 230, 245, 180), width=1)
    
    # Remaches metálicos en las esquinas
    for rx, ry in [(8, 8), (w - 9, 8), (8, h - 9), (w - 9, h - 9)]:
        draw.ellipse([rx - 3, ry - 3, rx + 3, ry + 3], fill=(190, 200, 220, 255), outline=(15, 18, 24, 255), width=1)
        draw.ellipse([rx - 1, ry - 1, rx + 1, ry + 1], fill=(240, 245, 255, 255))
        
    img.save(out_path, 'PNG')
    print("[OK] Generado marco hueco:", out_path)


def generate_vignette(out_path: str, w: int = 960, h: int = 540):
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    center_x, center_y = w / 2.0, h / 2.0
    
    y, x = np.ogrid[:h, :w]
    dist_from_center = np.sqrt(((x - center_x) / (w * 0.5))**2 + ((y - center_y) / (h * 0.5))**2)
    vignette = np.clip((dist_from_center - 0.65) / 0.75, 0.0, 1.0)
    
    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    rgba[:, :, 0] = 210 # Rojo sangre intenso
    rgba[:, :, 1] = 12
    rgba[:, :, 2] = 18
    rgba[:, :, 3] = (vignette * 230).astype(np.uint8)
    
    res = Image.fromarray(rgba, 'RGBA')
    res.save(out_path, 'PNG')
    print("[OK] Generada viñeta sangrienta:", out_path)


def generate_silhouette_icons(out_dir: str):
    size = 96
    
    # 1. PISTOLA 9MM
    p_img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    p_draw = ImageDraw.Draw(p_img)
    # Cañón y corredera
    p_draw.polygon([(14, 40), (74, 40), (76, 56), (52, 56), (46, 80), (28, 77), (34, 56), (14, 56)], fill=(245, 248, 255, 255), outline=(15, 18, 24, 255), width=2)
    # Guardamonte con hueco interior
    p_draw.arc([30, 52, 46, 68], start=0, end=180, fill=(245, 248, 255, 255), width=2)
    # Mira delantera
    p_draw.rectangle([16, 36, 20, 40], fill=(245, 248, 255, 255))
    p_img.save(os.path.join(out_dir, "icon_pistol_silhouette.png"), 'PNG')
    
    # 2. SUBFUSIL RÁPIDO (SMG)
    s_img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(s_img)
    # Receptor y cañón
    s_draw.polygon([(10, 40), (22, 40), (22, 34), (72, 34), (78, 52), (54, 52), (48, 76), (36, 74), (40, 52), (20, 52), (10, 48)], fill=(245, 248, 255, 255), outline=(15, 18, 24, 255), width=2)
    # Cargador largo vertical
    s_draw.polygon([(48, 52), (56, 52), (54, 86), (46, 86)], fill=(245, 248, 255, 255), outline=(15, 18, 24, 255), width=2)
    # Mira holográfica superior
    s_draw.rectangle([34, 28, 48, 34], fill=(245, 248, 255, 255), outline=(15, 18, 24, 255), width=1)
    s_img.save(os.path.join(out_dir, "icon_smg_silhouette.png"), 'PNG')
    
    # 3. ESCOPETA DE COMBATE
    sg_img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    sg_draw = ImageDraw.Draw(sg_img)
    # Cañón largo y receptor
    sg_draw.polygon([(6, 42), (72, 42), (84, 52), (80, 68), (62, 60), (54, 76), (42, 73), (48, 56), (6, 50)], fill=(245, 248, 255, 255), outline=(15, 18, 24, 255), width=2)
    # Corredera delantera de bombeo
    sg_draw.rectangle([20, 50, 38, 56], fill=(245, 248, 255, 255), outline=(15, 18, 24, 255), width=1)
    sg_img.save(os.path.join(out_dir, "icon_shotgun_silhouette.png"), 'PNG')
    
    print("[OK] Iconos nítidos de armas generados en", out_dir)


if __name__ == "__main__":
    assets_dir = r"c:\Users\ASUS\Downloads\10° CUATRIMESTRE\CREACION DE JUEGOS\JUEGO  BETA 2D\assets\generated"
    generate_hud_hp_frame(os.path.join(assets_dir, "hud_hp_frame_metal.png"))
    generate_vignette(os.path.join(assets_dir, "hud_vignette_blood.png"))
    generate_silhouette_icons(assets_dir)
