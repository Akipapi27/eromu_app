import subprocess

def sync():
    print("--- GitHub szinkronizálás indítása ---")
    try:
        # A törlések, módosítások és új fájlok hozzáadása
        subprocess.run(["git", "add", "-A"], check=True)
        
        # Ellenőrizzük, van-e commit-olni való
        status = subprocess.run(["git", "diff", "--cached", "--quiet"], capture_output=True)
        if status.returncode == 0:
            print("Nincs változás a repóban, nincs mit feltölteni.")
        else:
            commit_msg = input("Add meg a commit üzenetet (pl: Frissites): ") or "Automata frissites"
            subprocess.run(["git", "commit", "-m", commit_msg], check=True)
            subprocess.run(["git", "push", "origin", "main"], check=True)
            print("\nSiker! Minden fent van a GitHubon.")
            
    except subprocess.CalledProcessError as e:
        print(f"Hiba a Git művelet során: {e}")

if __name__ == '__main__':
    sync()