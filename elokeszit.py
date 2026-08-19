import os
import shutil
import json
import re
from PIL import Image, ImageOps

def elokeszit():
    home = os.path.expanduser('~')
    
    downloads_json = os.path.join(home, 'Downloads', 'eromu_adatbazis.json')
    temp_images_dir = os.path.join(home, 'Developer', 'ideiglenes képek')
    project_assets_dir = 'assets'
    
    print("--- 1. JSON tisztítása ---")
    if os.path.exists(downloads_json):
        try:
            with open(downloads_json, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            valtozasok_szama = 0
            for item in data:
                for mező in ['leagazasJel', 'kod']:
                    if mező in item and item[mező]:
                        eredeti = item[mező]
                        tiszta = re.sub(r'[^A-Z0-9]+', '_', eredeti.upper()).strip('_')
                        if eredeti != tiszta:
                            item[mező] = tiszta
                            valtozasok_szama += 1

            with open(downloads_json, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            
            os.makedirs(project_assets_dir, exist_ok=True)
            target_json = os.path.join(project_assets_dir, 'eromu_adatbazis.json')
            shutil.copy(downloads_json, target_json)
            print(f"JSON letisztítva és átmásolva ({valtozasok_szama} módosítás).")
        except Exception as e:
            print(f"Hiba a JSON feldolgozásnál: {e}")
            return
    else:
        print("Hiba: A JSON nem található a Letöltésekben.")
        return

    print("\n--- 2. Képek konvertálása, optimalizálása (.jpg-be) ---")
    if os.path.exists(temp_images_dir):
        os.makedirs(project_assets_dir, exist_ok=True)
        kep_szam = 0
        for item in os.listdir(temp_images_dir):
            if item.lower().endswith(('.jpg', '.jpeg', '.png', '.webp')):
                source_path = os.path.join(temp_images_dir, item)
                
                # Eredeti fájlnév kiterjesztés nélkül, az új pedig fixen .jpg lesz
                base_name, _ = os.path.splitext(item)
                dest_filename = f"{base_name}.jpg"
                dest_path = os.path.join(project_assets_dir, dest_filename)
                
                # Kép megnyitása és feldolgozása Pillow-val
                with Image.open(source_path) as img:
                    # EXIF orientáció korrekció (megakadályozza a képek elforgatását)
                    img = ImageOps.exif_transpose(img) or img

                    # Ha a kép átlátszó (pl. PNG), teszünk alá egy fehér hátteret, 
                    # mert a JPEG formátum nem támogatja az átlátszóságot (különben fekete lenne).
                    if img.mode in ('RGBA', 'LA') or (img.mode == 'P' and 'transparency' in img.info):
                        background = Image.new('RGB', img.size, (255, 255, 255))
                        if img.mode == 'P':
                            img = img.convert('RGBA')
                        background.paste(img, mask=img.split()[3])
                        img = background
                    else:
                        img = img.convert('RGB')
                    
                    # Mentés szabványos .jpg-ként, optimalizált tömörítéssel (85-ös minőség)
                    img.save(dest_path, 'JPEG', quality=85, optimize=True)
                
                kep_szam += 1
        print(f"Konvertálva, optimalizálva és átmásolva {kep_szam} kép (.jpg-ként) az assets mappába.")
    else:
        print("Figyelem: A képek mappa nem létezik.")

    print("\nKész az előkészítés! Ellenőrizd a fájlokat, majd ha mehet a GitHubra, futtasd a sync.py-t.")

if __name__ == '__main__':
    elokeszit()