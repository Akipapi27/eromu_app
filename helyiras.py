import json
import os
import shutil

def frissites_es_masolas():
    downloads_fajl = os.path.expanduser('~/Downloads/eromu_adatbazis.json')
    projekt_mappa = os.path.expanduser('~/developer/eromu_app/eromu_app/assets')
    projekt_fajl = os.path.join(projekt_mappa, 'eromu_adatbazis.json')
    
    if not os.path.exists(downloads_fajl):
        print(f"HIBA: Nem található a fájl a Downloads mappában: {downloads_fajl}")
        return

    with open(downloads_fajl, 'r', encoding='utf-8') as f:
        adatok = json.load(f)

    cel_prefix = input("Add meg a keresett elosztó/berendezés prefixét (pl. 6DA): ").strip().upper()
    if not cel_prefix:
        print("Üres értéket adtál meg, kilépés.")
        return

    # 1. Megkeressük, van-e már olyan elem, aminek a KÓDJA ezzel kezdődik, és van benne helyszín
    cel_helyszin = ""
    for elem in adatok:
        kod = str(elem.get('kod', '')).strip().upper()
        if kod.startswith(cel_prefix):
            hely = elem.get('helyszin', '').strip()
            if hely:
                cel_helyszin = hely
                print(f"Találtam egyező kódot ('{kod}'), kinyert helyszín: '{cel_helyszin}'")
                break

    # Ha nincs automatikus helyszín, megszámoljuk, mennyi elem kapcsolódik ehhez a prefixhez
    if not cel_helyszin:
        kapcsolodo_db = sum(
            1 for elem in adatok 
            if str(elem.get('kod', '')).strip().upper().startswith(cel_prefix)
            or str(elem.get('elosztoNev', '')).strip().upper().startswith(cel_prefix) 
            or str(elem.get('leagazasJel', '')).strip().upper().startswith(cel_prefix)
        )
        
        if kapcsolodo_db > 0:
            print(f"Figyelem: A(z) '{cel_prefix}*' prefix-szel kezdődő elemekhez még nincs helyszín rendelve ({kapcsolodo_db} db találat).")
            cel_helyszin = input(f"Kérlek, add meg a(z) '{cel_prefix}*' csoport helyszínét: ").strip()
        else:
            print(f"HIBA: Az adatbázisban semmi sem kezdődik ezzel: '{cel_prefix}'!")
            return

    if not cel_helyszin:
        print("Nem adtál meg helyszínt, a folyamat megszakítva.")
        return

    print(f"Alkalmazott helyszín: '{cel_helyszin}'")

    # 2. Frissítjük mindazokat, amelyek ezzel a prefix-szel kezdődnek (kod, elosztoNev vagy leagazasJel)
    modositott_db = 0
    for elem in adatok:
        kod = str(elem.get('kod', '')).strip().upper()
        eloszto = str(elem.get('elosztoNev', '')).strip().upper()
        leagazas = str(elem.get('leagazasJel', '')).strip().upper()
        
        if kod.startswith(cel_prefix) or eloszto.startswith(cel_prefix) or leagazas.startswith(cel_prefix):
            # Ha a saját kódja is ezzel kezdődik és üres a helyszíne, oda is beírjuk
            if kod.startswith(cel_prefix) and not elem.get('helyszin', '').strip():
                elem['helyszin'] = cel_helyszin
            elem['elosztoHelye'] = cel_helyszin
            modositott_db += 1

    # 3. Mentés a Downloads mappába
    with open(downloads_fajl, 'w', encoding='utf-8') as f:
        json.dump(adatok, f, ensure_ascii=False, indent=4)
        
    print(f"Siker! {modositott_db} darab rekord frissítve a Downloads-ban a(z) '{cel_prefix}*' prefix alapján.")

    # 4. Automatikus átmásolás a projekt assets mappájába
    if not os.path.exists(projekt_mappa):
        os.makedirs(projekt_mappa, exist_ok=True)

    shutil.copy(downloads_fajl, projekt_fajl)
    print(f"Fájl sikeresen átmásolva ide: {projekt_fajl}")

if __name__ == '__main__':
    frissites_es_masolas()