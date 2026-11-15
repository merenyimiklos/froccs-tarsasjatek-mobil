# Fröccs mobiljáték – Flutter prototípus

Hajnóczy Soma **Fröccs** társasjátékának mobilos, közösségi prototípusa Androidra.
A cél az eredeti társasjáték digitális, 2–6 fős változata, közös Wi-Fi-n,
online szobakóddal, vagy botokkal.

## Jelenlegi állapot (0.2.0, fekvő nézetű technikai prototípus)

- Kizárólag fekvő (landscape) Flutter Android felület, teljes képernyős faasztalos játéknézettel, arany/zöld retró vizuális stílussal, saját kézzel, ellenfélkártyákkal és kocsmapulttal.
- Új, egységes kocsmai főmenü és lobby; kártyakiválasztás, célpontválasztás és vizuális poharak.
- Eredeti szabálykönyvből kinyert lapképek: 9 fröccslaptípus, 12 kocsmahős, 3 pohárlap és átlátszó logó; a főmenü és a játékasztal ezeket használja.
- 106 lapos fröccspakli a hivatalos összesített típusmennyiségekkel.
- Alap kétakciós kör, húzás, pohárvétel, kijátszás, eladás, körvége.
- 2 játékosnál három lapból kettő megtartása.
- Mások kezének elrejtése a küldött állapotból.
- 1–5 egyszerű automata ellenfél.
- LAN hostolás telefonon TCP 43992 porton, IP-címes belépés.
- Online WebSocket szobaszerver, hatjegyű kóddal és 6 fős limittel.
- GitHub Actions debug APK minden main push után.

**Fontos: még nem kész, nem teljesen szabályhű játék.**
Az alábbiak fejlesztést és fizikai kártyás ellenőrzést igényelnek:

- Az itallap pontos, kártyánkénti bor/szóda arány szerinti árlistája.
  A mostani eladás kalkuláció **ideiglenes**, tesztértékeket használ.
- A 19 szívatáskártya pontos altípusonkénti darabszáma még nincs
  ellenőrizve; a pakli jelenleg 5/5/5/4 elosztást használ.
- A 26 pohár pontos 2/3/5 dl-es eloszlását még ellenőrizni kell.
- A 12 kocsmahős képessége közül a Pohárnok árkedvezménye, Mélyivó Fred legkisebb pohár jutalma és Sommelier Pityu pénzbónusza kezelve van; Küv Évi pohárkorlátozás-feloldása részben kezelt.
  A többi kocsmahős még fejlesztésre szorul.
  A karakterválasztás, a többi egyedi képesség és a kezdő kiosztás
  még nincs véglegesítve.
- A teljes alku (kártyák kézből kézbe / pohárba helyezése, szabad
  ajánlatok és ígéretek) helyett jelenleg pénzes alkuteszt van.
- A botok alapstratégiát használnak; a szívatásokat még nem kezdeményezik.
- Végjátéki feltételek és többjátékos hibakezelés további teszteket igényelnek.
- Hálózati felhasználóazonosítás, visszacsatlakozás és a csalás elleni,
  valóban szerveroldali szabálymotor még szükséges.
- A nagy felbontású kiadói exportok még nem állnak rendelkezésre; jelenleg a szabálykönyv eredeti ábráit használjuk.

A hivatalos szabálykönyv:
https://saldokiado.hu/custom/saldowebshop/image/data/betekinto/tarsasjatekszabaly/_froccs-tarsasjatek.pdf

## Android APK letöltés

1. Nyisd meg a GitHub repo **Actions → Android APK** oldalát.
2. Válaszd ki a legújabb sikeres workflow futást (zöld pipa).
3. Az **Artifacts** részben töltsd le a `froccs-debug-apk` fájlt.
4. Csomagold ki a ZIP-et, telepítsd az `app-debug.apk` állományt.
5. Ez fejlesztői APK, a telefonon engedélyezni kell a külső APK telepítését.

A build folyamata Android scaffoldot generál, azt jelenleg nem
commitoljuk. Release aláírást és Store publikálást később állítunk be.

Helyben:

```bash
flutter create --project-name froccs_mobile --platforms android .
flutter pub get
flutter test
flutter run
```

## Botok

A kezdőképernyőn válassz 1–5 botot, majd indítsd a partit.
A botok a játékmotorban futnak, nincs külső szerverigény.

## Helyi hálózaton

1. Telefon A: **Helyi szoba létrehozása**.
2. Telefon B: ugyanarra a Wi-Fi-re kapcsolódik.
3. Telefon B: megadja az A képernyőjén megjelent IP:port címet.
4. A host botot is adhat hozzá, és elindítja a játékot.

Az Androidnak Internet jogosultság kell, a 43992/TCP portot a hálózat
nem blokkolhatja. Vendéghálózat/AP izoláció kizárhatja a kapcsolatot.

## Internetes szobák

A repóban található `server/` egy Node.js WebSocket relay. **A szerver
nem indul el automatikusan attól, hogy az APK elkészült.**
Telepíteni kell nyilvános szerverre HTTPS/WSS mögé.

```bash
cd server
npm install
npm start
```

A szerver alapértelmezés szerint a **8080-as porton** figyel.
Publikus üzemeltetéshez Reverse Proxy (Caddy/nginx) és TLS szükséges.
Példa: `wss://jatek.sajatdomain.hu`.

A játék beállításában add meg ezt a szervercímet, és hozz létre szobát.
A többiek azonos szerverre kapcsolódva, a hatjegyű kóddal lépnek be.

A workflow-ban beállítható repó **Actions variable**:
`FROCCS_SERVER=wss://...`, hogy az APK-ban ez legyen az alapértelmezés.

A szerver jelenleg csak továbbít: a hoszt állítja elő a saját és a
külön-külön titkosított kéz nélküli állapotokat. Ez prototípusnak megfelelő,
de versenyszerű éles játékhoz a szabálymotort autoritatív szerverre kell vinni.

## Eredeti grafika

A felhasználó Hajnóczy Somával egyeztetett, és az eredeti grafikák használatához
engedélyt jelzett. 2026-11-15-én az eredeti szabálykönyvből 25 grafika került
az `assets/original/` mappába: minden jelenlegi fröccslap, kocsmahős, pohárlap
és a logó. A kézben a teljes kártyafront látható, a főmenüben és az asztalon
eredeti karakterlapok jelennek meg, a pohárlapokon külön töltöttségjelzővel.

A forrás, oldalszámok és ellenőrzőösszeg az
[`assets/original/sources.json`](assets/original/sources.json) fájlban szerepelnek.
Az újragenerálás leírása: [`assets/original/README.md`](assets/original/README.md).
A képek a PDF eredeti ábrái, nem a kiadó nagy felbontású nyomdai exportjai.

A kiadó és az illusztrátor jogosultságait, illetve a nyilvános terjesztés
kereteit a bemutatás/publikálás előtt írásban ajánlott rögzíteni.

## Technikai felépítés

- `lib/game.dart`: lokális szabálymotor és botok.
- `lib/room.dart`: lobby, LAN WebSocket szerver/kliens és online kliens.
- `lib/main.dart`: landscape főmenü és lobby.
- `lib/landscape_board.dart`: 1200×660-as, telefonra adaptív asztalnézet, poharak, kártyák, akciók, alku UI és erős vizuális keretrendszer.
- `server/index.js`: online lobby relay.
- `test/game_test.dart`: alap unit tesztek.
- `.github/workflows/android-apk.yml`: debug APK CI.

A repó a bemutatóhoz használható eredeti kártyaképeket tartalmazza.

## Bemutatás Soma felé

A jelenlegi UI az eredeti szabálykönyv kártyaábráit használja. A kóddal rajzolt
helyettesítők hiányzó asset esetén tartalékként megmaradtak.
Az alkalmazás **még prototípus**, nem teljesen szabályhű: a hiteles itallap-árakat
és a 19 szívatáskártya részletes altípuseloszlását külön ellenőrizni kell,
illetve a kocsmahősök és az alku teljes szabályait is be kell fejezni.
