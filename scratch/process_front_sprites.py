from PIL import Image, ImageChops
import os

images = {
    "walker": {
        "src": r"C:\Users\ASUS\.gemini\antigravity-ide\brain\fa341b5d-256a-41e8-bfc2-05a25cb02984\zombie_walker_front_1792129046418.jpg",
        "out": r"assets/generated/zombie_walker_front_walk.png",
        "frame_size": (64, 64)
    },
    "runner": {
        "src": r"C:\Users\ASUS\.gemini\antigravity-ide\brain\fa341b5d-256a-41e8-bfc2-05a25cb02984\zombie_runner_front_1792129064251.jpg",
        "out": r"assets/generated/zombie_runner_front_walk.png",
        "frame_size": (64, 64)
    },
    "brute": {
        "src": r"C:\Users\ASUS\.gemini\antigravity-ide\brain\fa341b5d-256a-41e8-bfc2-05a25cb02984\zombie_brute_front_1792129082313.jpg",
        "out": r"assets/generated/zombie_brute_front_walk.png",
        "frame_size": (96, 96)
    },
    "miniboss": {
        "src": r"C:\Users\ASUS\.gemini\antigravity-ide\brain\fa341b5d-256a-41e8-bfc2-05a25cb02984\zombie_miniboss_front_1792129102353.jpg",
        "out": r"assets/generated/zombie_miniboss_front_walk.png",
        "frame_size": (96, 96)
    }
}

def remove_background(im):
    im = im.convert("RGBA")
    datas = im.getdata()
    newData = []
    # Corners are solid white/near-white
    for item in datas:
        # Check if near white (background)
        if item[0] > 238 and item[1] > 238 and item[2] > 238:
            newData.append((255, 255, 255, 0))
        else:
            newData.append(item)
    im.putdata(newData)
    
    # Crop to content bbox
    bbox = im.getbbox()
    if bbox:
        im = im.crop(bbox)
    return im

def build_walk_sheet(sprite, frame_w, frame_h):
    # Fit sprite proportionally inside (frame_w - 6, frame_h - 4)
    max_w = frame_w - 6
    max_h = frame_h - 4
    
    ratio = min(max_w / sprite.width, max_h / sprite.height)
    new_w = max(1, int(sprite.width * ratio))
    new_h = max(1, int(sprite.height * ratio))
    
    # Nearest neighbor to preserve pixel art
    base_frame = sprite.resize((new_w, new_h), Image.Resampling.NEAREST)
    
    # 4 frames:
    # 0: center step (slight left shift)
    # 1: step up (stride bob)
    # 2: center step (slight right shift)
    # 3: step up (stride bob alternate)
    sheet = Image.new("RGBA", (frame_w * 4, frame_h), (0, 0, 0, 0))
    
    offsets = [
        (-1, 0, 0),    # (dx, dy, rot)
        (0, -2, 1),
        (1, 0, 0),
        (0, -2, -1)
    ]
    
    for i, (dx, dy, rot) in enumerate(offsets):
        f = Image.new("RGBA", (frame_w, frame_h), (0, 0, 0, 0))
        x_pos = (frame_w - new_w) // 2 + dx
        y_pos = (frame_h - new_h) + dy - 1
        
        frame_img = base_frame
        if rot != 0:
            frame_img = base_frame.rotate(rot * 2, resample=Image.Resampling.NEAREST, expand=False)
            
        f.paste(frame_img, (x_pos, y_pos), frame_img)
        sheet.paste(f, (i * frame_w, 0), f)
        
    return sheet

for key, cfg in images.items():
    print(f"Processing {key}...")
    src_im = Image.open(cfg["src"])
    sprite = remove_background(src_im)
    fw, fh = cfg["frame_size"]
    sheet = build_walk_sheet(sprite, fw, fh)
    sheet.save(cfg["out"])
    print(f"Saved {cfg['out']} ({sheet.size})")

print("All front walk sheets generated successfully!")
