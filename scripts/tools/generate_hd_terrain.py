"""
Generador de Texturas PBR HD para Escenario 3D:
Asfalto oscuro con grava, grietas y charcos reflectantes (Albedo, Normal, Roughness)
y Aceras de hormigón urbano sombrío.
"""

import os
import numpy as np
from PIL import Image, ImageFilter

def generate_asphalt_pbr(out_dir: str, size: int = 1024):
    np.random.seed(42)
    
    # 1. Base noise (grava y micro-rugosidad)
    base_noise = np.random.uniform(0.12, 0.22, (size, size)).astype(np.float32)
    
    # Suavizado para variación macro tonal
    macro_noise = np.random.uniform(0.8, 1.2, (size // 8, size // 8)).astype(np.float32)
    macro_img = Image.fromarray((macro_noise * 255).astype(np.uint8)).resize((size, size), Image.Resampling.BICUBIC)
    macro_mod = np.array(macro_img, dtype=np.float32) / 255.0
    
    # Albedo: Asfalto muy oscuro, azulado-grisáceo estilo noche lluviosa
    albedo = np.zeros((size, size, 3), dtype=np.float32)
    tone = base_noise * macro_mod
    albedo[:, :, 0] = tone * 0.28 # R
    albedo[:, :, 1] = tone * 0.31 # G
    albedo[:, :, 2] = tone * 0.38 # B (ligeramente más azul noche)
    
    # Grietas y marcas sutiles
    grid_marks = np.random.uniform(0.0, 1.0, (size, size))
    cracks = (grid_marks > 0.992).astype(np.float32)
    cracks_img = Image.fromarray((cracks * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.0))
    cracks_np = np.array(cracks_img, dtype=np.float32) / 255.0
    albedo *= (1.0 - cracks_np[:, :, np.newaxis] * 0.6)
    
    albedo_img = Image.fromarray(np.clip(albedo * 255.0, 0, 255).astype(np.uint8), 'RGB')
    albedo_path = os.path.join(out_dir, "asphalt_hd_albedo.png")
    albedo_img.save(albedo_path, 'PNG')
    
    # 2. Normal Map
    height = tone + cracks_np * -0.5
    pad_h = np.pad(height, 1, mode='wrap')
    dx = (pad_h[:-2, 2:] - pad_h[:-2, :-2] + 2*(pad_h[1:-1, 2:] - pad_h[1:-1, :-2]) + pad_h[2:, 2:] - pad_h[2:, :-2]) / 8.0
    dy = (pad_h[2:, :-2] - pad_h[:-2, :-2] + 2*(pad_h[2:, 1:-1] - pad_h[:-2, 1:-1]) + pad_h[2:, 2:] - pad_h[:-2, 2:]) / 8.0
    
    strength = 4.0
    nx = -dx * strength
    ny = -dy * strength
    nz = np.ones_like(nx)
    norm = np.sqrt(nx*nx + ny*ny + nz*nz)
    nx /= norm
    ny /= norm
    nz /= norm
    
    normal_rgb = np.zeros((size, size, 3), dtype=np.uint8)
    normal_rgb[:, :, 0] = np.clip((nx * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8)
    normal_rgb[:, :, 1] = np.clip((-ny * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8)
    normal_rgb[:, :, 2] = np.clip((nz * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8)
    normal_img = Image.fromarray(normal_rgb, 'RGB')
    normal_path = os.path.join(out_dir, "asphalt_hd_normal.png")
    normal_img.save(normal_path, 'PNG')
    
    # 3. Roughness Map: alta rugosidad en general (0.85), con parches húmedos brillantes (0.35)
    roughness = np.clip(0.85 - macro_mod * 0.25 - (1.0 - base_noise) * 0.2, 0.2, 0.95)
    rough_img = Image.fromarray((roughness * 255).astype(np.uint8), 'L')
    rough_path = os.path.join(out_dir, "asphalt_hd_roughness.png")
    rough_img.save(rough_path, 'PNG')
    
    print("[OK] Texturas PBR Asfalto generadas en", out_dir)


def generate_sidewalk_pbr(out_dir: str, size: int = 1024):
    np.random.seed(101)
    # Baldosas de hormigón urbano con juntas
    tiles = 8
    tile_size = size // tiles
    
    concrete = np.random.uniform(0.35, 0.45, (size, size)).astype(np.float32)
    # Variación por losa
    for ty in range(tiles):
        for tx in range(tiles):
            var = np.random.uniform(0.88, 1.12)
            concrete[ty*tile_size:(ty+1)*tile_size, tx*tile_size:(tx+1)*tile_size] *= var
            
    # Ranuras entre losas
    grooves = np.zeros((size, size), dtype=np.float32)
    groove_w = 4
    for i in range(tiles):
        idx = i * tile_size
        grooves[max(0, idx - groove_w):min(size, idx + groove_w), :] = 1.0
        grooves[:, max(0, idx - groove_w):min(size, idx + groove_w)] = 1.0
        
    albedo = np.zeros((size, size, 3), dtype=np.float32)
    base_col = concrete * (1.0 - grooves * 0.65)
    albedo[:, :, 0] = base_col * 0.65 # Piedra neutra fría
    albedo[:, :, 1] = base_col * 0.68
    albedo[:, :, 2] = base_col * 0.72
    
    albedo_img = Image.fromarray(np.clip(albedo * 255.0, 0, 255).astype(np.uint8), 'RGB')
    albedo_img.save(os.path.join(out_dir, "sidewalk_hd_albedo.png"), 'PNG')
    
    # Normal Map acera
    height = concrete - grooves * 0.8
    pad_h = np.pad(height, 1, mode='wrap')
    dx = (pad_h[:-2, 2:] - pad_h[:-2, :-2] + 2*(pad_h[1:-1, 2:] - pad_h[1:-1, :-2]) + pad_h[2:, 2:] - pad_h[2:, :-2]) / 8.0
    dy = (pad_h[2:, :-2] - pad_h[:-2, :-2] + 2*(pad_h[2:, 1:-1] - pad_h[:-2, 1:-1]) + pad_h[2:, 2:] - pad_h[:-2, 2:]) / 8.0
    
    strength = 5.0
    nx = -dx * strength
    ny = -dy * strength
    nz = np.ones_like(nx)
    norm = np.sqrt(nx*nx + ny*ny + nz*nz)
    nx /= norm
    ny /= norm
    nz /= norm
    
    normal_rgb = np.zeros((size, size, 3), dtype=np.uint8)
    normal_rgb[:, :, 0] = np.clip((nx * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8)
    normal_rgb[:, :, 1] = np.clip((-ny * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8)
    normal_rgb[:, :, 2] = np.clip((nz * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8)
    normal_img = Image.fromarray(normal_rgb, 'RGB')
    normal_img.save(os.path.join(out_dir, "sidewalk_hd_normal.png"), 'PNG')
    
    roughness = np.clip(0.7 + grooves * 0.25, 0.5, 0.95)
    rough_img = Image.fromarray((roughness * 255).astype(np.uint8), 'L')
    rough_img.save(os.path.join(out_dir, "sidewalk_hd_roughness.png"), 'PNG')
    print("[OK] Texturas PBR Acera generadas en", out_dir)


if __name__ == "__main__":
    assets_dir = r"c:\Users\ASUS\Downloads\10° CUATRIMESTRE\CREACION DE JUEGOS\JUEGO  BETA 2D\assets\generated"
    generate_asphalt_pbr(assets_dir)
    generate_sidewalk_pbr(assets_dir)
