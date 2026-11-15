# Eredeti Fröccs grafikák

A 25 PNG az eredeti, nyilvánosan elérhető Fröccs-szabálykönyv ábráiból származik.
Forrás: https://saldokiado.hu/custom/saldowebshop/image/data/betekinto/tarsasjatekszabaly/_froccs-tarsasjatek.pdf
Letöltés: 2026-11-15. A sources.json tárolja a forrás SHA-256 lenyomatát, az oldalszámokat, a kivágási koordinátákat és a képméreteket.

- card_*.png: mind a 9 fröccslaptípus, kb. 408 × 568 px.
- hero_*.png: mind a 12 kocsmahős teljes lapja, kb. 449 × 624 px.
- cup_2.png, cup_3.png, cup_5.png: eredeti fekvő pohárlapok.
- logo.png: eredeti logó átlátszó háttérrel.

A lapokat a nyomdai keret mentén egyenesítettük ki és vágtuk körül.
A PDF vektoros részei nagy felbontásban renderelve, a raszterelemek eredeti részletességükkel kerülnek a képekbe. Nincs AI-val újrarajzolt illusztráció.
Ezek bemutatóhoz használható eredeti ábrák, nem a kiadó nyomdai exportjai.
A hivatalos exportok ugyanezekkel a fájlnevekkel cserélhetők be.

Újragenerálás a letöltött PDF-ből:

    python -m pip install pymupdf pillow
    python tools/import_original_art.py /path/to/rules.pdf

A repó korábbi dokumentációja szerint a felhasználó Hajnóczy Somával egyeztetett, és engedélyt jelzett az eredeti grafikák használatához.
A grafika jogai az eredeti jogosultaké; a nyilvános PDF önmagában nem ad újrafelhasználási engedélyt. A kód esetleges licence nem terjed ki automatikusan ezekre a képekre.
