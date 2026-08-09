import os
import shutil
import json
import re
import subprocess

def frissit():
    home = os.path.expanduser('~')
    
    downloads_json = os.path.join(home, 'Downloads', 'eromu_adatbazis.json')
    temp_images_dir = os.path.join(home, 'Developer', 'ideiglenes képek')
    project_assets_dir = 'assets'
    
    print("--- 1. JSON tisztítása (eloszto alapú leagazasJel és kod mezők) ---")
    if os.path.exists(downloads_json):
        try:
            # Beolvassuk a Letöltésekben lévő JSON-t
            with open(downloads_json, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            valtozasok_szama = 0
            for item in data:
                # Elosztó név megkeresése a rekordban (többféle lehetséges mezőnév ellenőrzése)
                eloszto_mezok = ['eloszto', 'taplaloEloszto', 'elosztoNeve', 'elosztoJel']
                eloszto_neve = None
                for mezor in eloszto_mezok:
                    if mezor in item and item[mezor]:
                        eloszto_neve = str(item[mezor]).upper().strip()
                        eloszto_neve = re.sub(r'[^A-Z0-9]+', '_', eloszto_neve).strip('_')
                        break

                # 1. leagazasJel tisztítása és elosztó szerinti elválasztása
                if 'leagazasJel' in item and item['leagazasJel']:
                    eredeti = item['leagazasJel']
                    tiszta = re.sub(r'[^A-Z0-9]+', '_', eredeti.upper()).strip('_')
                    
                    # Ha megvan az elosztó neve, és a leágazás ezzel kezdődik
                    if eloszto_neve and tiszta.startswith(eloszto_neve):
                        maradek = tiszta[len(eloszto_neve):]
                        # Ha van karakter az elosztónév után, de nincs ott aláhúzás, beszúrjuk
                        if maradek and not maradek.startswith('_'):
                            tiszta = eloszto_neve + '_' + maradek.lstrip('_')

                    if eredeti != tiszta:
                        item['leagazasJel'] = tiszta
                        valtozasok_szama += 1

                # 2. kod mező tisztítása ugyanazon a szabállyal
                if 'kod' in item and item['kod']:
                    eredeti_kod = item['kod']
                    tiszta_kod = re.sub(r'[^A-Z0-9]+', '_', eredeti_kod.upper()).strip('_')
                    if eredeti_kod != tiszta_kod:
                        item['kod'] = tiszta_kod
                        valtozasok_szama += 1

            # Letöltések mappabeli fájl felülírása a tiszta adatokkal
            with open(downloads_json, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            print(f"Letöltések mappabeli JSON letisztítva és felülírva ({valtozasok_szama} módosítás összesen).")

            # Átmásolás a projekt assets mappájába is
            os.makedirs(project_assets_dir, exist_ok=True)
            target_json = os.path.join(project_assets_dir, 'eromu_adatbazis.json')
            shutil.copy(downloads_json, target_json)
            print(f"JSON átmásolva ide: {target_json}")
            
        except Exception as e:
            print(f"Hiba a JSON feldolgozása közben: {e}")
            return
    else:
        print(f"Hiba: A JSON nem található: {downloads_json}")
        return

    print("\n--- 2. Képek hozzáadása ---")
    if os.path.exists(temp_images_dir):
        os.makedirs(project_assets_dir, exist_ok=True)
        kep_szam = 0
        for item in os.listdir(temp_images_dir):
            if item.lower().endswith(('.jpg', '.jpeg', '.png', '.webp', '.JPG', '.JPEG', '.PNG')):
                src_path = os.path.join(temp_images_dir, item)
                dst_path = os.path.join(project_assets_dir, item)
                shutil.copy(src_path, dst_path)
                kep_szam += 1
        print(f"Átmásolva {kep_szam} darab kép.")
    else:
        print("Figyelem: A képek mappa nem létezik, képek nem lettek másolva.")

    print("\n--- 3. GitHub szinkronizálás (Kód, adatok, képek és törlések) ---")
    try:
        subprocess.run(["git", "add", "-A"], check=True)
        
        status = subprocess.run(["git", "diff", "--cached", "--quiet"], capture_output=True)
        if status.returncode == 0:
            print("Nincs változás a repóban, nincs mit feltölteni.")
        else:
            subprocess.run(["git", "commit", "-m", "Automata frissites: eloszto alapu leagazas es kod tisztitas, kepek, torlesek"], check=True)
            subprocess.run(["git", "push", "origin", "main"], check=True)
            print("\nMinden sikeresen felkerült a GitHubra!")
            
    except subprocess.CalledProcessError as e:
        print(f"Hiba a Git művelet során: {e}")

if __name__ == '__main__':
    frissit()