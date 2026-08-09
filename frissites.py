import os
import shutil
import subprocess

def frissit():
    home = os.path.expanduser('~')
    
    # Útvonalak
    downloads_json = os.path.join(home, 'Downloads', 'eromu_adatbazis.json')
    temp_images_dir = os.path.join(home, 'Developer', 'ideiglenes képek')
    project_assets_dir = 'assets'
    
    print("--- 1. JSON frissítése ---")
    if os.path.exists(downloads_json):
        os.makedirs(project_assets_dir, exist_ok=True)
        target_json = os.path.join(project_assets_dir, 'eromu_adatbazis.json')
        shutil.copy(downloads_json, target_json)
        print(f"JSON frissítve: {target_json}")
    else:
        print(f"Hiba: A JSON nem található: {downloads_json}")
        return

    print("\n--- 2. Képek hozzáadása ---")
    if os.path.exists(temp_images_dir):
        os.makedirs(project_assets_dir, exist_ok=True)
        for item in os.listdir(temp_images_dir):
            if item.lower().endswith(('.jpg', '.jpeg', '.png', '.webp', '.JPG', '.JPEG', '.PNG')):
                src_path = os.path.join(temp_images_dir, item)
                dst_path = os.path.join(project_assets_dir, item)
                shutil.copy(src_path, dst_path)
                print(f"Hozzáadva/Felülírva: {item}")
    else:
        print(f"Figyelem: A képek mappa nem létezik: {temp_images_dir}")

    print("\n--- 3. GitHub szinkronizálása (Törlésekkel együtt) ---")
    try:
        # A 'git add -A' a legfontosabb: ez regisztrálja a fájlok hozzáadását, módosítását ÉS a törlését is!
        subprocess.run(["git", "add", "-A"], check=True)
        
        # Ellenőrizzük, hogy van-e commit-olni való dolog
        status = subprocess.run(["git", "diff", "--cached", "--quiet"], capture_output=True)
        if status.returncode == 0:
            print("Nincs változás (sem hozzáadás, sem törlés), nincs mit feltölteni.")
        else:
            subprocess.run(["git", "commit", "-m", "Automata szinkronizalas: Adatbazis, kepek es torlesek"], check=True)
            subprocess.run(["git", "push", "origin", "main"], check=True)
            print("\nKész! A GitHubon most már pontosan az van, ami a gépeden.")
            
    except subprocess.CalledProcessError as e:
        print(f"Hiba a Git művelet során: {e}")

if __name__ == '__main__':
    frissit()