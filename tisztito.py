import json
import re
import os

def json_tisztitas_letoltesbol():
    # Megkeressük a Letöltések mappát Macen / Windowson
    letoltesek_mappa = os.path.expanduser('~/Downloads')
    forras_fajl = os.path.join(letoltesek_mappa, 'eromu_adatbazis.json')
    
    # Ahová menteni kell a projektben
    cel_fajl = 'assets/eromu_adatbazis.json'

    print(f"Forrásfájl beolvasása: {forras_fajl}...")
    try:
        with open(forras_fajl, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except FileNotFoundError:
        print(f"Hiba: Az eromu_adatbazis.json nem található a Letöltések mappában!")
        return

    valtozasok_szama = 0

    for item in data:
        if 'leagazasJel' in item and item['leagazasJel']:
            eredeti = item['leagazasJel']
            
            # Nagybetűsítés + nem alfanumerikus karakterek cseréje aláhúzásra
            tiszta = re.sub(r'[^A-Z0-9]+', '_', eredeti.upper())
            tiszta = tiszta.strip('_')

            if eredeti != tiszta:
                item['leagazasJel'] = tiszta
                valtozasok_szama += 1

    # Mentés a projekt assets mappájába
    os.makedirs('assets', exist_ok=True)
    with open(cel_fajl, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(f"\nKész! Összesen {valtozasok_szama} leágazás jel lett tisztítva.")
    print(f"A végleges, tiszta fájl mentve ide: {cel_fajl}")

if __name__ == '__main__':
    json_tisztitas_letoltesbol()