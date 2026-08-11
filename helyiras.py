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
    if not cel_prefix or len(cel_prefix) < 2:
        print("HIBA: Túl rövid vagy üres prefixet adtál meg (legalább 2 karakter kell).")
        return

    # 1. Megkeressük, van-e már valamilyen helyszín a prefixhez
    aktualis_helyszin = ""
    for elem in adatok:
        kod = str(elem.get('kod', '')).strip().upper()
        if kod.startswith(cel_prefix):
            hely = elem.get('helyszin', '').strip()
            if hely:
                aktualis_helyszin = hely
                break

    # 2. Mindenképpen kiírjuk, mit találtunk, és felajánljuk a módosítást
    print("\n" + "-"*50)
    if aktualis_helyszin:
        print(f"A(z) '{cel_prefix}' prefixhez jelenleg rögzített helyszín: '{aktualis_helyszin}'")
    else:
        print(f"A(z) '{cel_prefix}' prefixhez még NINCS kitöltve helyszín.")
    print("-"*50)

    uj_helyszin = input("Add meg a helyszínt (ha jó a fenti és nem változtatod, csak nyomj Entert): ").strip()
    
    if uj_helyszin:
        cel_helyszin = uj_helyszin
        print(f"-> Új helyszín érvényesítve: '{cel_helyszin}'")
    else:
        cel_helyszin = aktualis_helyszin

    if not cel_helyszin:
        print("HIBA: Nincs érvényes helyszín megadva, a folyamat megszakítva.")
        return

    # 3. Előzetes szűrés, hogy lássuk, miket érint
    erintett_elemek = []
    for elem in adatok:
        kod = str(elem.get('kod', '')).strip().upper()
        eloszto = str(elem.get('elosztoNev', '')).strip().upper()
        leagazas = str(elem.get('leagazasJel', '')).strip().upper()
        
        if kod.startswith(cel_prefix) or eloszto.startswith(cel_prefix) or leagazas.startswith(cel_prefix):
            erintett_elemek.append(elem)

    if not erintett_elemek:
        print(f"HIBA: Az adatbázisban semmi sem kezdődik ezzel: '{cel_prefix}'!")
        return

    print("\n" + "="*50)
    print(f"BIZTONSÁGI ELLENŐRZÉS:")
    print(f"-> Keresett prefix: '{cel_prefix}'")
    print(f"-> Alkalmazott helyszín: '{cel_helyszin}'")
    print(f"-> Érintett rekordok száma: {len(erintett_elemek)} db")
    print("="*50)

    joovahagyas = input("Biztosan végrehajtod a módosítást? (i / n): ").strip().lower()
    if joovahagyas not in ['i', 'igen', 'y', 'yes']:
        print("A folyamat a felhasználó által megszakítva. Nem történt változtatás.")
        return

    # 4. Végrehajtás
    modositott_db = 0
    for elem in erintett_elemek:
        kod = str(elem.get('kod', '')).strip().upper()
        if kod.startswith(cel_prefix):
            elem['helyszin'] = cel_helyszin
        elem['elosztoHelye'] = cel_helyszin
        modositott_db += 1

    # 5. Mentés a Downloads mappába
    with open(downloads_fajl, 'w', encoding='utf-8') as f:
        json.dump(adatok, f, ensure_ascii=False, indent=4)
        
    print(f"Siker! {modositott_db} darab rekord frissítve a Downloads-ban.")

    # 6. Automatikus átmásolás a projekt assets mappájába
    if not os.path.exists(projekt_mappa):
        os.makedirs(projekt_mappa, exist_ok=True)

    shutil.copy(downloads_fajl, projekt_fajl)
    print(f"Fájl sikeresen átmásolva ide: {projekt_fajl}")

if __name__ == '__main__':
    frissites_es_masolas()