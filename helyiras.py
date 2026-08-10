import json
import os
import shutil

def frissites_es_masolas():
    # 1. Elérési útvonalak meghatározása
    downloads_fajl = os.path.expanduser('~/Downloads/eromu_adatbazis.json')
    projekt_mappa = os.path.expanduser('~/developer/eromu_app/eromu_app/assets')
    projekt_fajl = os.path.join(projekt_mappa, 'eromu_adatbazis.json')
    
    if not os.path.exists(downloads_fajl):
        print(f"HIBA: Nem található a fájl a Downloads mappában: {downloads_fajl}")
        return

    with open(downloads_fajl, 'r', encoding='utf-8') as f:
        adatok = json.load(f)

    # Felhasználói bemenet bekérése
    cel_kod = input("Add meg a keresett berendezés/elosztó kódját (pl. 6DS): ").strip().upper()
    if not cel_kod:
        print("Üres kódot adtál meg, kilépés.")
        return

    # 2. Megkeressük a megadott kódú forráshelyszínt
    cel_helyszin = ""
    for elem in adatok:
        if str(elem.get('kod', '')).strip().upper() == cel_kod:
            cel_helyszin = elem.get('helyszin', '').strip()
            break
            
    if not cel_helyszin:
        print(f"HIBA: Nem találtam '{cel_kod}' kódot, vagy üres a helyszíne!")
        return

    print(f"Kinyert helyszín a(z) '{cel_kod}' kódhoz: '{cel_helyszin}'")

    # 3. Frissítjük a célmezőket a Downloads-ban lévő adaton
    modositott_db = 0
    for elem in adatok:
        eloszto = str(elem.get('elosztoNev', '')).strip().upper()
        leagazas = str(elem.get('leagazasJel', '')).strip().upper()
        
        if eloszto.startswith(cel_kod) or leagazas.startswith(cel_kod):
            elem['elosztoHelye'] = cel_helyszin
            modositott_db += 1

    # 4. Mentés a Downloads mappába
    with open(downloads_fajl, 'w', encoding='utf-8') as f:
        json.dump(adatok, f, ensure_ascii=False, indent=4)
        
    print(f"Siker! {modositott_db} darab rekord frissítve a Downloads-ban a(z) '{cel_kod}' kód alapján.")

    # 5. Automatikus átmásolás a projekt assets mappájába
    if not os.path.exists(projekt_mappa):
        os.makedirs(projekt_mappa, exist_ok=True)

    shutil.copy(downloads_fajl, projekt_fajl)
    print(f"Fájl sikeresen átmásolva ide: {projekt_fajl}")

if __name__ == '__main__':
    frissites_es_masolas()