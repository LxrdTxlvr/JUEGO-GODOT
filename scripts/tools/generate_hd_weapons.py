"""
Generador de Sprites HD 2.5D en Primera Persona (FPS Viewmodels) de Alta Calidad:
- Pistola 9mm (Idle, Fire con destello volumétrico, Reload con cambio de cargador)
- Subfusil Rápido (Idle con mira holográfica, Fire con ráfaga, Reload)
- Escopeta de Combate (Idle robusta, Fire brutal, Reload)
- Navaja Táctica (Slash dinámico)
Estilo Ilustración HD Cómic Sombrío / Darkest Dungeon / Left 4 Dead.
"""

import os
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

def create_canvas(w: int = 512, h: int = 512) -> Image.Image:
    return Image.new('RGBA', (w, h), (0, 0, 0, 0))

def draw_shaded_polygon(draw: ImageDraw.ImageDraw, points: list[tuple[int, int]], base_color: tuple, outline_color=(12, 14, 18, 255), outline_width=3):
    draw.polygon(points, fill=base_color, outline=outline_color)
    if outline_width > 1:
        for i in range(len(points)):
            p1 = points[i]
            p2 = points[(i + 1) % len(points)]
            draw.line([p1, p2], fill=outline_color, width=outline_width)

def draw_player_arm(draw: ImageDraw.ImageDraw, elbow: tuple[int, int], wrist: tuple[int, int], hand: tuple[int, int]):
    # Manga táctica azul noche con pliegues sombreados
    draw.line([elbow, wrist], fill=(12, 16, 24, 255), width=74)
    draw.line([elbow, wrist], fill=(32, 42, 58, 255), width=66)
    draw.line([elbow, wrist], fill=(48, 62, 85, 255), width=48)
    draw.line([elbow, wrist], fill=(65, 82, 110, 200), width=18)
    
    # Guante táctico reforzado
    hx, hy = hand
    draw.ellipse([hx - 36, hy - 32, hx + 36, hy + 32], fill=(14, 16, 20, 255))
    draw.ellipse([hx - 32, hy - 28, hx + 32, hy + 28], fill=(68, 56, 44, 255))
    draw.ellipse([hx - 24, hy - 20, hx + 12, hy + 18], fill=(95, 80, 62, 255))
    # Nudillos blindados
    for kx in [-18, -6, 6, 18]:
        draw.rectangle([hx + kx - 4, hy - 24, hx + kx + 4, hy - 14], fill=(30, 32, 38, 255), outline=(10, 12, 16, 255))


def generate_pistol_hd(out_dir: str):
    # 1. PISTOLA IDLE
    img = create_canvas()
    d = ImageDraw.Draw(img)
    # Brazo
    draw_player_arm(d, (512, 512), (380, 420), (330, 370))
    # Mano izquierda estabilizadora
    d.ellipse([270, 370, 335, 425], fill=(55, 45, 36, 255), outline=(12, 14, 18, 255), width=3)
    
    # Empuñadura ergonómica
    draw_shaded_polygon(d, [(305, 305), (355, 320), (335, 415), (285, 395)], (48, 38, 30, 255))
    # Chasis (Frame) inferior
    draw_shaded_polygon(d, [(220, 275), (375, 295), (370, 335), (230, 330)], (34, 38, 46, 255))
    # Corredera (Slide) metálica dos tonos
    draw_shaded_polygon(d, [(185, 255), (375, 280), (372, 312), (188, 295)], (88, 98, 114, 255))
    d.line([(190, 260), (370, 285)], fill=(155, 170, 195, 220), width=3) # Reflejo de luz
    
    # Estrías traseras de corredera
    for sx in [335, 345, 355]:
        d.line([(sx, 275), (sx - 3, 305)], fill=(20, 24, 30, 255), width=2)
        
    # Miras nocturnas verdes de tritio
    d.rectangle([188, 248, 196, 256], fill=(50, 255, 90, 255), outline=(0, 0, 0, 255))
    d.rectangle([365, 272, 373, 280], fill=(50, 255, 90, 255), outline=(0, 0, 0, 255))
    # Guardamonte y gatillo
    d.arc([270, 325, 310, 365], start=0, end=180, fill=(40, 45, 55, 255), width=4)
    d.line([(288, 330), (288, 345)], fill=(120, 130, 145, 255), width=3)
    
    img.save(os.path.join(out_dir, "viewmodel_pistol_idle_hd.png"), 'PNG')

    # 2. PISTOLA FIRE
    img_f = create_canvas()
    df = ImageDraw.Draw(img_f)
    draw_player_arm(df, (512, 512), (380, 425), (330, 375))
    df.ellipse([270, 375, 335, 430], fill=(55, 45, 36, 255), outline=(12, 14, 18, 255), width=3)
    draw_shaded_polygon(df, [(305, 310), (355, 325), (335, 420), (285, 400)], (48, 38, 30, 255))
    draw_shaded_polygon(df, [(220, 280), (375, 300), (370, 340), (230, 335)], (34, 38, 46, 255))
    # Corredera retraída (+30px a la derecha)
    draw_shaded_polygon(df, [(215, 260), (405, 285), (402, 317), (218, 300)], (88, 98, 114, 255))
    # Cañón descubierto expuesto
    draw_shaded_polygon(df, [(180, 268), (220, 274), (218, 292), (182, 286)], (25, 28, 34, 255))
    
    # Destello de disparo masivo (Muzzle Flash)
    fx, fy = 145, 275
    flash_poly = [
        (fx, fy), (fx - 70, fy - 50), (fx - 35, fy - 18),
        (fx - 110, fy), (fx - 40, fy + 20), (fx - 80, fy + 55),
        (fx - 15, fy + 30), (fx, fy + 60), (fx + 25, fy)
    ]
    df.polygon(flash_poly, fill=(255, 220, 50, 255), outline=(255, 120, 20, 255))
    df.ellipse([fx - 45, fy - 30, fx + 20, fy + 30], fill=(255, 255, 230, 255))
    img_f.save(os.path.join(out_dir, "viewmodel_pistol_fire_hd.png"), 'PNG')

    # 3. PISTOLA RELOAD
    img_r = create_canvas()
    dr = ImageDraw.Draw(img_r)
    draw_player_arm(dr, (512, 530), (390, 450), (345, 410))
    # Cargador insertándose
    draw_shaded_polygon(dr, [(260, 420), (295, 435), (275, 510), (240, 495)], (60, 68, 80, 255))
    d_circ = [(260, 440), (275, 505)]
    dr.ellipse([275, 425, 290, 438], fill=(210, 180, 40, 255)) # Bala dorada visible arriba
    draw_shaded_polygon(dr, [(285, 335), (335, 350), (315, 440), (270, 420)], (48, 38, 30, 255))
    draw_shaded_polygon(dr, [(205, 305), (355, 325), (350, 365), (215, 360)], (34, 38, 46, 255))
    draw_shaded_polygon(dr, [(175, 285), (360, 310), (358, 342), (178, 325)], (88, 98, 114, 255))
    img_r.save(os.path.join(out_dir, "viewmodel_pistol_reload_hd.png"), 'PNG')


def generate_smg_hd(out_dir: str):
    # 1. SMG IDLE
    img = create_canvas()
    d = ImageDraw.Draw(img)
    draw_player_arm(d, (512, 512), (380, 405), (340, 365))
    # Mano izquierda frontal
    d.ellipse([180, 325, 250, 385], fill=(55, 45, 36, 255), outline=(12, 14, 18, 255), width=3)
    
    # Chasis principal SMG táctico
    draw_shaded_polygon(d, [(150, 255), (380, 285), (370, 350), (160, 335)], (30, 34, 42, 255))
    d.line([(155, 260), (375, 290)], fill=(80, 95, 118, 220), width=4)
    # Riel superior Picatinny
    for rx in range(180, 360, 14):
        d.line([(rx, 252), (rx + 4, 253)], fill=(15, 18, 22, 255), width=3)
        
    # Mira holográfica roja
    draw_shaded_polygon(d, [(240, 220), (295, 225), (290, 255), (242, 252)], (45, 52, 65, 255))
    d.rectangle([250, 224, 285, 248], fill=(20, 24, 30, 240), outline=(10, 12, 15, 255))
    d.ellipse([264, 232, 272, 240], fill=(255, 35, 35, 255)) # Punto rojo brillante
    d.ellipse([261, 229, 275, 243], outline=(255, 60, 60, 180), width=1)
    
    # Bocacha / Silenciador frontal
    draw_shaded_polygon(d, [(105, 275), (155, 280), (153, 312), (107, 307)], (55, 62, 75, 255))
    
    # Cargador curvo largo hacia abajo
    draw_shaded_polygon(d, [(230, 340), (275, 346), (295, 475), (250, 470)], (22, 25, 30, 255))
    for my in range(365, 460, 18):
        d.line([(240 + (my-365)*0.2, my), (270 + (my-365)*0.2, my + 3)], fill=(45, 52, 62, 255), width=2)
        
    img.save(os.path.join(out_dir, "viewmodel_smg_idle_hd.png"), 'PNG')

    # 2. SMG FIRE
    img_f = create_canvas()
    df = ImageDraw.Draw(img_f)
    draw_player_arm(df, (512, 512), (380, 412), (340, 372))
    df.ellipse([180, 332, 250, 392], fill=(55, 45, 36, 255), outline=(12, 14, 18, 255), width=3)
    draw_shaded_polygon(df, [(150, 262), (380, 292), (370, 357), (160, 342)], (30, 34, 42, 255))
    draw_shaded_polygon(df, [(240, 227), (295, 232), (290, 262), (242, 259)], (45, 52, 65, 255))
    df.ellipse([264, 239, 272, 247], fill=(255, 35, 35, 255))
    draw_shaded_polygon(df, [(105, 282), (155, 287), (153, 319), (107, 314)], (55, 62, 75, 255))
    draw_shaded_polygon(df, [(230, 347), (275, 353), (295, 482), (250, 477)], (22, 25, 30, 255))
    
    # Destello de ráfaga
    mx, my = 75, 295
    flash_poly = [
        (mx, my), (mx - 60, my - 35), (mx - 25, my - 12),
        (mx - 95, my), (mx - 30, my + 15), (mx - 70, my + 35),
        (mx, my + 40), (mx + 20, my)
    ]
    df.polygon(flash_poly, fill=(255, 230, 60, 255), outline=(255, 130, 20, 255))
    df.ellipse([mx - 35, my - 20, mx + 15, my + 20], fill=(255, 255, 240, 255))
    img_f.save(os.path.join(out_dir, "viewmodel_smg_fire_hd.png"), 'PNG')

    # 3. SMG RELOAD
    img_r = create_canvas()
    dr = ImageDraw.Draw(img_r)
    draw_player_arm(dr, (512, 530), (390, 440), (350, 400))
    draw_shaded_polygon(dr, [(160, 290), (380, 320), (370, 385), (170, 370)], (30, 34, 42, 255))
    # Cargador nuevo insertándose con mano izquierda
    draw_shaded_polygon(dr, [(220, 390), (265, 396), (285, 510), (240, 505)], (22, 25, 30, 255))
    dr.ellipse([210, 420, 280, 475], fill=(55, 45, 36, 255), outline=(12, 14, 18, 255), width=3)
    img_r.save(os.path.join(out_dir, "viewmodel_smg_reload_hd.png"), 'PNG')


def generate_shotgun_hd(out_dir: str):
    # 1. ESCOPETA IDLE
    img = create_canvas()
    d = ImageDraw.Draw(img)
    draw_player_arm(d, (512, 512), (390, 410), (350, 370))
    d.ellipse([150, 345, 225, 405], fill=(55, 45, 36, 255), outline=(12, 14, 18, 255), width=3)
    
    # Cañón doble masivo de combate
    draw_shaded_polygon(d, [(60, 265), (370, 295), (365, 345), (62, 315)], (45, 52, 64, 255))
    d.line([(65, 270), (365, 300)], fill=(125, 140, 165, 220), width=4)
    # Mira de fibra óptica verde frontal
    d.rectangle([65, 255, 78, 265], fill=(50, 255, 70, 255), outline=(0, 0, 0, 255))
    
    # Corredera delantera de bombeo de madera oscura/polímero
    draw_shaded_polygon(d, [(145, 305), (245, 312), (240, 355), (142, 345)], (65, 48, 36, 255))
    for px in range(160, 235, 14):
        d.line([(px, 310), (px - 2, 350)], fill=(20, 15, 10, 255), width=3)
        
    # Receptor y percutor
    draw_shaded_polygon(d, [(340, 295), (425, 300), (415, 385), (330, 370)], (30, 34, 42, 255))
    img.save(os.path.join(out_dir, "viewmodel_shotgun_idle_hd.png"), 'PNG')

    # 2. ESCOPETA FIRE
    img_f = create_canvas()
    df = ImageDraw.Draw(img_f)
    draw_player_arm(df, (512, 512), (390, 430), (350, 390))
    df.ellipse([150, 365, 225, 425], fill=(55, 45, 36, 255), outline=(12, 14, 18, 255), width=3)
    draw_shaded_polygon(df, [(60, 285), (370, 315), (365, 365), (62, 335)], (45, 52, 64, 255))
    draw_shaded_polygon(df, [(145, 325), (245, 332), (240, 375), (142, 365)], (65, 48, 36, 255))
    draw_shaded_polygon(df, [(340, 315), (425, 320), (415, 405), (330, 390)], (30, 34, 42, 255))
    
    # Muzzle flash brutal de postas
    mx, my = 25, 295
    flash_poly = [
        (mx, my), (mx - 90, my - 70), (mx - 35, my - 25),
        (mx - 150, my), (mx - 50, my + 30), (mx - 110, my + 75),
        (mx - 20, my + 40), (mx, my + 85), (mx + 30, my)
    ]
    df.polygon(flash_poly, fill=(255, 235, 80, 255), outline=(255, 110, 15, 255))
    df.ellipse([mx - 55, my - 40, mx + 25, my + 40], fill=(255, 255, 245, 255))
    img_f.save(os.path.join(out_dir, "viewmodel_shotgun_fire_hd.png"), 'PNG')

    # 3. ESCOPETA RELOAD
    img_r = create_canvas()
    dr = ImageDraw.Draw(img_r)
    draw_player_arm(dr, (512, 530), (400, 440), (360, 400))
    draw_shaded_polygon(dr, [(80, 310), (375, 335), (370, 385), (82, 360)], (45, 52, 64, 255))
    # Cartucho calibre 12 rojo vivo entrando
    draw_shaded_polygon(dr, [(250, 365), (295, 370), (290, 405), (245, 400)], (225, 30, 20, 255))
    dr.ellipse([275, 368, 295, 405], fill=(245, 210, 40, 255)) # Culote de latón dorado
    dr.ellipse([220, 370, 280, 430], fill=(55, 45, 36, 255), outline=(12, 14, 18, 255), width=3)
    img_r.save(os.path.join(out_dir, "viewmodel_shotgun_reload_hd.png"), 'PNG')


def generate_knife_hd(out_dir: str):
    img = create_canvas()
    d = ImageDraw.Draw(img)
    # Brazo y mano
    d.polygon([(460, 320), (512, 400), (450, 480), (380, 400)], fill=(32, 42, 58, 255), outline=(12, 16, 24, 255), width=4)
    d.ellipse([340, 340, 420, 410], fill=(55, 45, 36, 255), outline=(12, 14, 18, 255), width=3)
    
    # Hoja de navaja táctica militar afilada
    draw_shaded_polygon(d, [(140, 140), (350, 350), (330, 375), (115, 165)], (195, 205, 220, 255))
    d.line([(140, 140), (350, 350)], fill=(255, 255, 255, 255), width=4) # Filo brillante
    d.line([(130, 155), (220, 245)], fill=(185, 20, 25, 255), width=5) # Sangre en el filo
    
    # Líneas de estocada en arco
    d.arc([60, 80, 450, 450], start=125, end=235, fill=(255, 255, 255, 220), width=6)
    d.arc([40, 60, 470, 470], start=135, end=225, fill=(255, 50, 50, 180), width=4)
    img.save(os.path.join(out_dir, "viewmodel_knife_slash_hd.png"), 'PNG')


if __name__ == "__main__":
    assets_dir = r"c:\Users\ASUS\Downloads\10° CUATRIMESTRE\CREACION DE JUEGOS\JUEGO  BETA 2D\assets\generated"
    generate_pistol_hd(assets_dir)
    generate_smg_hd(assets_dir)
    generate_shotgun_hd(assets_dir)
    generate_knife_hd(assets_dir)
    print("[OK] Armas HD 2.5D regeneradas con arte detallado.")
