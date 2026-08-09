import os
import shutil
import json
import re

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
                # leagazasJel és kod tisztítása
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
            print(f"Hiba: {e}")
            return
    else:
        print("Hiba: A JSON nem található a Letöltésekben.")
        return

    print("\n--- 2. Képek másolása ---")
    if os.path.exists(temp_images_dir):
        os.makedirs(project_assets_dir, exist_ok=True)
        kep_szam = 0
        for item in os.listdir(temp_images_dir):
            if item.lower().endswith(('.jpg', '.jpeg', '.png', '.webp', '.JPG', '.JPEG', '.PNG')):
                shutil.copy(os.path.join(temp_images_dir, item), os.path.join(project_assets_dir, item))
                kep_szam += 1
        print(f"Átmásolva {kep_szam} kép az assets mappába.")
    else:
        print("Figyelem: A képek mappa nem létezik.")

    print("\nKész az előkészítés! Ellenőrizd a fájlokat, majd ha mehet a GitHubra, futtasd a sync.py-t.")

if __name__ == '__main__':
    elokeszit()