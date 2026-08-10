import json
import os

def frissites():
    # A fájl útvonala a Downloads mappában
    fajl_utvonal = os.path.expanduser('~/Downloads/eromu_adatbazis.json')
    
    if not os.path.exists(fajl_utvonal):
        print(f"HIBA: Nem található a fájl itt: {fajl_utvonal}")
        return

    with open(fajl_utvonal, 'r', encoding='utf-8') as f:
        adatok = json.load(f)

    # 1. Megkeressük a "6DS" kódú forráshelyszínt
    cel_helyszin = ""
    for elem in adatok:
        if elem.get('kod') == '6DS':
            cel_helyszin = elem.get('helyszin', '').strip()
            break
            
    if not cel_helyszin:
        print("HIBA: Nem találtam '6DS' kódot, vagy üres a helyszíne!")
        return

    print(f"Kinyert helyszín: '{cel_helyszin}'")

    # 2. Frissítjük a célmezőket
    modositott_db = 0
    for elem in adatok:
        eloszto = str(elem.get('elosztoNev', '')).upper()
        leagazas = str(elem.get('leagazasJel', '')).upper()
        
        # Ha 6DS-sel kezdődik az elosztó vagy a leágazás
        if eloszto.startswith('6DS') or leagazas.startswith('6DS'):
            elem['elosztoHelye'] = cel_helyszin
            modositott_db += 1

    # 3. Mentés
    with open(fajl_utvonal, 'w', encoding='utf-8') as f:
        json.dump(adatok, f, ensure_ascii=False, indent=4)
        
    print(f"Siker! {modositott_db} darab 6DS-hez tartozó rekord frissítve a Downloads-ban.")

if __name__ == '__main__':
    frissites()