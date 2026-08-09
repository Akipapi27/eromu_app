import subprocess

def flutter_forditas():
    print("--- 1. Flutter Clean & Pub Get (Tiszta környezet) ---")
    try:
        subprocess.run(["flutter", "clean"], check=True)
        subprocess.run(["flutter", "pub", "get"], check=True)
        
        print("\n--- 2. Flutter Web Release Építés ---")
        subprocess.run(["flutter", "build", "web", "--release"], check=True)
        
        print("\nKész! A webes build sikeresen elkészült a build/web mappában.")
    except subprocess.CalledProcessError as e:
        print(f"\nHiba történt a fordítás során: {e}")

if __name__ == '__main__':
    flutter_forditas()