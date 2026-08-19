import os
import shutil
from PIL import Image, ImageOps

def kepek_elokeszitese():
    home = os.path.expanduser('~')
    temp_images_dir = os.path.join(home, 'Developer', 'ideiglenes képek')
    project_assets_dir = 'assets'
    
    print("--- Képek konvertálása, optimalizálása (.jpg-be) ---")
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

    print("\nKépfeldolgozás kész!")

if __name__ == '__main__':
    kepek_elokeszitese()