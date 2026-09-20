import subprocess
import shutil
import os

def flutter_forditas():
    print("--- Flutter Web Build & Gyökérbe másolás ---")
    try:
        # 1. Fordítás a helyes base-href-fel (hogy az útvonalak stimmeljenek a GitHub Pages-en)
        subprocess.run([
            "flutter", "build", "web", "--release", "--base-href", "/eromu_app/"
        ], check=True)
        print("\nFlutter build kész.")
        
        source_dir = "build/web"
        
        # 2. Átmásolunk mindent a gyökérbe, KIVÉVE az assets mappát, 
        # mert a te eredeti assets mappád már eleve ott van és sértetlen!
        for item in os.listdir(source_dir):
            if item == "assets":
                continue # Ez védi meg az eredeti assets mappádat a felülírástól/duplikációtól!
                
            s = os.path.join(source_dir, item)
            d = os.path.join(".", item)
            
            # Ne bántsuk a saját szkripteket és forrásmappákat
            if item in [".git", "fordit.py", "githubsync.py", "lib", "web", "android", "ios", "docs"]:
                continue
                
            if os.path.isdir(s):
                if os.path.exists(d):
                    shutil.rmtree(d)
                shutil.copytree(s, d)
            else:
                shutil.copy2(s, d)
                
        # GitHub Pages miatt a .nojekyll fájl a gyökérbe kell
        open(".nojekyll", 'w').close()
        
        print("\nKész! A webes fájlok a gyökérbe kerültek, az eredeti assets mappa teljesen sértetlen maradt.")
        
    except subprocess.CalledProcessError as e:
        print(f"\nHiba történt a fordítás során: {e}")

if __name__ == '__main__':
    flutter_forditas()