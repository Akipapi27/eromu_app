import subprocess

def flutter_forditas():
    print("--- Gyors Flutter Web Build ---")
    try:
        # Csak a tiszta build fut le, felesleges várakozás nélkül
        subprocess.run(["flutter", "build", "web", "--release"], check=True)
        print("\nKész! A webes build sikeresen elkészült.")
    except subprocess.CalledProcessError as e:
        print(f"\nHiba történt a fordítás során: {e}")

if __name__ == '__main__':
    flutter_forditas()