"""
Generador de Sprites HD Estilizados (Estilo Darkest Dungeon / Cómic Oscuro) y Normal Maps.
Convierte spritesheets de pixel art a alta resolución (factor 8x), aplicando entintado oscuro,
sombreado dramático cel/chiaroscuro, ojos y vísceras brillantes, y genera mapas normales tangenciales
para iluminación y sombras reales en Godot 4.
"""

import os
import math
import numpy as np
from PIL import Image, ImageFilter, ImageOps, ImageEnhance

def stylize_frame_comic(img_frame: Image.Image, scale: int = 8, eye_glow: bool = True) -> tuple[Image.Image, Image.Image]:
    """
    Toma un frame RGBA en pixel art y produce:
    1. Ilustración HD estilizada con contornos entintados y paleta oscura dramática.
    2. Normal map tangencial correspondiente (RGB).
    """
    orig_w, orig_h = img_frame.size
    hd_w, hd_h = orig_w * scale, orig_h * scale
    
    # 1. Separar alfa y color
    r, g, b, a = img_frame.split()
    
    # 2. Upscaling suave base con Lanczos
    hd_rgba = img_frame.resize((hd_w, hd_h), Image.Resampling.LANCZOS)
    
    # 3. Máscara de contorno entintado (Ink Outlines estilo Darkest Dungeon)
    hd_a = a.resize((hd_w, hd_h), Image.Resampling.LANCZOS)
    # Binarizar ligeramente la máscara alfa para bordes limpios sin dientes
    a_np = np.array(hd_a, dtype=np.float32) / 255.0
    a_clean = np.clip((a_np - 0.25) / 0.5, 0.0, 1.0)
    
    # Extraer bordes internos para entintado comic
    gray = hd_rgba.convert('L')
    edges = gray.filter(ImageFilter.FIND_EDGES)
    edges = edges.filter(ImageFilter.GaussianBlur(radius=1.2))
    edges_np = np.array(edges, dtype=np.float32) / 255.0
    ink_mask = np.clip(edges_np * 2.2, 0.0, 1.0)
    
    # 4. Color y Contraste Chiaroscuro
    rgb_np = np.array(hd_rgba.convert('RGB'), dtype=np.float32) / 255.0
    
    # Intensificar sombras y contraste estilizado
    # Curva tonal oscura y saturada
    shadows = np.power(rgb_np, 1.35)
    # Aplicar entintado en los bordes
    inked_rgb = shadows * (1.0 - ink_mask[:, :, np.newaxis] * 0.72)
    
    # Realce de ojos y luces (si hay rojos/amarillos intensos, darles brillo glow)
    if eye_glow:
        red_dominance = np.clip(rgb_np[:, :, 0] - (rgb_np[:, :, 1] + rgb_np[:, :, 2]) * 0.5, 0.0, 1.0)
        glow_mask = (red_dominance > 0.25).astype(np.float32) * red_dominance
        inked_rgb[:, :, 0] = np.clip(inked_rgb[:, :, 0] + glow_mask * 0.45, 0.0, 1.0)
        inked_rgb[:, :, 1] = np.clip(inked_rgb[:, :, 1] + glow_mask * 0.15, 0.0, 1.0)
    
    # Recomponer imagen RGBA HD
    final_rgba_np = np.zeros((hd_h, hd_w, 4), dtype=np.uint8)
    final_rgba_np[:, :, :3] = np.clip(inked_rgb * 255.0, 0, 255).astype(np.uint8)
    final_rgba_np[:, :, 3] = np.clip(a_clean * 255.0, 0, 255).astype(np.uint8)
    hd_img = Image.fromarray(final_rgba_np, 'RGBA')
    
    # 5. Generación de Normal Map tangencial
    # Mapa de altura H: combinación de luminancia y distancia al borde
    lum = (inked_rgb[:, :, 0] * 0.299 + inked_rgb[:, :, 1] * 0.587 + inked_rgb[:, :, 2] * 0.114)
    height_map = lum * 0.7 + a_clean * 0.3
    
    # Filtro Sobel para gradientes
    kernel_x = np.array([[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]], dtype=np.float32) / 8.0
    kernel_y = np.array([[-1, -2, -1], [0, 0, 0], [1, 2, 1]], dtype=np.float32) / 8.0
    
    # Convolución rápida con numpy
    pad_h = np.pad(height_map, 1, mode='edge')
    dx = (pad_h[:-2, 2:] - pad_h[:-2, :-2] + 2*(pad_h[1:-1, 2:] - pad_h[1:-1, :-2]) + pad_h[2:, 2:] - pad_h[2:, :-2]) / 8.0
    dy = (pad_h[2:, :-2] - pad_h[:-2, :-2] + 2*(pad_h[2:, 1:-1] - pad_h[:-2, 1:-1]) + pad_h[2:, 2:] - pad_h[:-2, 2:]) / 8.0
    
    strength = 3.5
    nx = -dx * strength
    ny = -dy * strength
    nz = np.ones_like(nx)
    norm = np.sqrt(nx*nx + ny*ny + nz*nz)
    nx /= norm
    ny /= norm
    nz /= norm
    
    # Convertir a espacio tangente RGB [0, 255]
    normal_rgb = np.zeros((hd_h, hd_w, 4), dtype=np.uint8)
    normal_rgb[:, :, 0] = np.clip((nx * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8)
    normal_rgb[:, :, 1] = np.clip((-ny * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8) # Y invertida en normal maps OpenGL/Godot
    normal_rgb[:, :, 2] = np.clip((nz * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8)
    normal_rgb[:, :, 3] = final_rgba_np[:, :, 3]
    
    normal_img = Image.fromarray(normal_rgb, 'RGBA')
    return hd_img, normal_img


def process_spritesheet(input_path: str, output_path: str, normal_path: str, frame_size: int, frame_count: int, scale: int = 8):
    if not os.path.exists(input_path):
        print(f"Skipping (not found): {input_path}")
        return
    
    src = Image.open(input_path).convert('RGBA')
    w, h = src.size
    hd_frame_size = frame_size * scale
    
    out_img = Image.new('RGBA', (hd_frame_size * frame_count, hd_frame_size), (0, 0, 0, 0))
    out_normal = Image.new('RGBA', (hd_frame_size * frame_count, hd_frame_size), (128, 128, 255, 0))
    
    for i in range(frame_count):
        box = (i * frame_size, 0, (i + 1) * frame_size, frame_size)
        frame = src.crop(box)
        hd_frame, norm_frame = stylize_frame_comic(frame, scale=scale)
        out_box = (i * hd_frame_size, 0, (i + 1) * hd_frame_size, hd_frame_size)
        out_img.paste(hd_frame, out_box)
        out_normal.paste(norm_frame, out_box)
        
    out_img.save(output_path, 'PNG')
    out_normal.save(normal_path, 'PNG')
    print(f"[OK] Generado: {output_path} ({out_img.size}) y {normal_path}")


def process_single_image(input_path: str, output_path: str, normal_path: str, scale: int = 8):
    if not os.path.exists(input_path):
        return
    src = Image.open(input_path).convert('RGBA')
    hd_img, norm_img = stylize_frame_comic(src, scale=scale)
    hd_img.save(output_path, 'PNG')
    norm_img.save(normal_path, 'PNG')
    print(f"[OK] Generado item HD: {output_path} ({hd_img.size}) y {normal_path}")


if __name__ == "__main__":
    assets_dir = r"c:\Users\ASUS\Downloads\10° CUATRIMESTRE\CREACION DE JUEGOS\JUEGO  BETA 2D\assets\generated"
    
    # Lista de spritesheets
    sheets = [
        ("zombie_walker_walk.png", "zombie_walker_walk_hd.png", "zombie_walker_walk_normal.png", 64, 6),
        ("zombie_walker_front_walk.png", "zombie_walker_front_walk_hd.png", "zombie_walker_front_walk_normal.png", 64, 4),
        ("zombie_runner_run.png", "zombie_runner_run_hd.png", "zombie_runner_run_normal.png", 64, 6),
        ("zombie_runner_front_walk.png", "zombie_runner_front_walk_hd.png", "zombie_runner_front_walk_normal.png", 64, 4),
        ("zombie_brute_walk.png", "zombie_brute_walk_hd.png", "zombie_brute_walk_normal.png", 96, 6),
        ("zombie_brute_front_walk.png", "zombie_brute_front_walk_hd.png", "zombie_brute_front_walk_normal.png", 96, 4),
        ("zombie_miniboss_walk.png", "zombie_miniboss_walk_hd.png", "zombie_miniboss_walk_normal.png", 96, 6),
        ("zombie_miniboss_front_walk.png", "zombie_miniboss_front_walk_hd.png", "zombie_miniboss_front_walk_normal.png", 96, 4),
    ]
    
    for src_name, hd_name, norm_name, f_size, f_count in sheets:
        src_p = os.path.join(assets_dir, src_name)
        hd_p = os.path.join(assets_dir, hd_name)
        norm_p = os.path.join(assets_dir, norm_name)
        process_spritesheet(src_p, hd_p, norm_p, f_size, f_count, scale=8)
        
    # Consumibles
    items = [
        ("pickup_ammo.png", "pickup_ammo_hd.png", "pickup_ammo_normal.png"),
        ("pickup_medkit.png", "pickup_medkit_hd.png", "pickup_medkit_normal.png"),
        ("pickup_weapon.png", "pickup_weapon_hd.png", "pickup_weapon_normal.png"),
    ]
    for src_name, hd_name, norm_name in items:
        src_p = os.path.join(assets_dir, src_name)
        hd_p = os.path.join(assets_dir, hd_name)
        norm_p = os.path.join(assets_dir, norm_name)
        process_single_image(src_p, hd_p, norm_p, scale=8)
