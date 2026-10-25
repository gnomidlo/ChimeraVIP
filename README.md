# ChimeraVIP

Pastelowa nakladka na **oficjalne skrypty Chimery 5.0** dla Mudleta.
Serwer: `chimera.co.pl:2300`. Wersja ChimeraVIP: **0.180**.
Audyt źródeł oficjalnej Chimery: **5.0.1** (testy integracyjne w Mudlecie nadal potrzebne).

W 0.180 poprawiono zachowanie układu przy restarcie i podzielono HUD na
moduły. [Audyt cyklu życia i scenariusz testów](docs/ui-lifecycle-0.180.md)
opisuje zachowanie dockingu, Kondycji i okna pachołków.

## Instalacja i aktualizacja

Oficjalna Chimera 5 musi byc zainstalowana i uruchomiona.
W Mudlecie:

```lua
lua installPackage("https://raw.githubusercontent.com/gnomidlo/ChimeraVIP/main/packages/ChimeraVIP.xml")
```

Od 0.179 **wystarczy jedna komenda**:

```text
/cvip aktualizuj
```

Aktualizator zabezpiecza dane, pobiera i weryfikuje kod, synchronizuje
most API i HUD w `chimera_wtyczki/` oraz automatycznie uruchamia
`chimera.restart()` z oficjalnej 5.0.1. Nie zmienia plików Chimery.
Przy błędzie instalacji wtyczek przywraca poprzednie pliki; przy braku
oficjalnego restartu informuje wprost, że potrzeba ręcznego `/przeladuj`.
Gdy kod jest aktualny, ale wtyczki nie — ta sama komenda naprawia je
bez ponownego pobierania całej paczki.

**Przejście z 0.178:** pierwszy raz stary updater dostarcza nowy kod,
a 0.179 automatycznie synchronizuje wtyczki i kończy restart.
Możesz nadal sprawdzić ich stan przez `/cvip v5`; ręczne
`/cvip v5 instaluj` pozostaje wyłącznie opcją awaryjną.

## Interfejs i powrot do oryginalu

- `/cvhud vip` — pastelowy pasek i dokowalne okno Kondycje.
- `/cvhud oficjalny` — przywraca oficjalny pasek i Kondycje.
- `/cvhud ustawienia` — ustawienia widocznosci i trybu wtyczki.
- `/cvhud status` — ktory HUD jest aktywny.
- `/cvip v5` — stan instalacji wtyczek.

VIP stara sie utworzyc oba widoki przed ukryciem oficjalnych.
Gdy Geyser lub okna Mudleta nie dzialaja, nie wylacza oficjalnego
interfejsu. Widoki tworzy osobna wtyczka `chimeravip_ui`; kod 4.x
nie jest uruchamiany na Chimera 5. Wlasne Kondycje stosuja
litery `A,B,C...` bez luk, wyswietlaja druzyne, pachołkow, ogluszenie,
cel ataku, przeciwnikow, osoby na lokacji i nieaktywnych walczacych `[X]`.

Przyciski wywoluja oficjalne komendy:
`/tryb_ataku`, `/autowsparcie`, `/autopogon`, `/zbieranie`,
`/lampa`, `/mbind`, a akcje lokacji wykonuja API `locations.run_action()`.
Skroty VIP `/vz NUMER`, `/vza LITERA`, `/vrza LITERA LITERA`
korzystaja z oznaczen z aktualnych Kondycji; oficjalne `/z` i `/za`
zachowuja swoja semantyke.

## Pozostale moduly

Wlasny `/xp` (zabicia, XP/h, typy mobow), Combat Colors,
Kamienie Milowe, cechy, ekwipunek, skracanie opisow i raporty pozostaja
czescia VIP. Nie instalujemy Defense Trackera ani osobnej bazy
odmian graczy. Dawne dane w `ChimeraVIP-data/` pozostaja nietkniete.

## Testowanie i repozytorium

`lua tools/release_check.lua` sprawdza manifest v2, SHA Git blob i skladnie.
`texlua tools/chimera5_ui_test.lua` uruchamia mock UI bez Mudleta.
Wymagane jest jeszcze sprawdzenie w prawdziwej sesji Chimera 5.


## Quiet HUD i Kondycje — 0.168

HUD zachowuje kompaktowa wysokosc **76 px**. Zamiast duzych przyciskow
pokazuje kolorowe paski procentowe. Dane pobiera z cache GMCP Chimery
oraz z `gmcp.Char.Vitals` Mudleta (rowniez po przeladowaniu pluginu).
Okno Kondycje uzywa fizycznych kolorow i czcionki 8 pt.

Po scaleniu aktualizacji: `/cvip aktualizuj`. W razie problemow: `/cvhud oficjalny`.
Gdy serwer nie przeslal jeszcze `Char.Vitals`, brak wartosci
pozostanie jako `--`; nie zmyslamy procentow.


## Quiet HUD 2.0 — 0.170

- Footer pozostaje wysoki na **76 px**. Kompas jest tekstowa sciagawka,
  wyjscia nietypowe sa wypisane obok.
- HP/MP/ZM wyswietlaja procent, a gdy oficjalne GMCP udostepnia
  rzeczywiste wartosci takze `x/y`. Nie wyliczamy `x/y` z procentow.
- PR, GL, OBC i PAN nadal maja cztery oddzielne, dyskretne pola.
- Akcje kontekstowe lokacji pojawiaja sie jako polprzezroczysta lista
  nad blokiem ATK/WSP/POG. Klawisze pobierane sa z `locations.room_actions()`,
  klikniecie wywoluje `locations.run_action(index)`. Po opuszczeniu
  lokacji lub braku akcji lista znika. Wylaczenie: `/cvhud ustawienia`
  → `akcje`.
- Kondycje: styl Hybrid z osmioma segmentami, mniejsza czcionka
  (domyslnie 7 pt, regulacja 6-12), neutralne nazwy w POZOSTALI.
- Powrot do oryginalu: `/cvhud oficjalny`.

Po scaleniu: `/cvip aktualizuj`.


## Kolorystyczny Quiet HUD 0.171

Nowy wyglad inspirowany wariantem 1: stonowane panele Geyser, kolor
HP/MP/ZM zalezy od procentu, GORA/DOL w kompasie, a przyciski wspieraja
wskazania ON/OFF pobierane z oficjalnego `status_bar.model()`.
Pasek EXP zajmuje dolna krawedz footera. Dodatkowe warstwy w zloto-
bursztynowych odcieniach widac tylko gdy oficjalne GMCP albo zdarzenie
postepu dostarczy wartosc wyzsza niz 100; w przeciwnym razie nie ma
wiarygodnych danych o nadwyzce. /cvhud oficjalny cofa zmiany.


## Quiet HUD 0.173 — ostateczny uklad

Footer w Geyser ma stale 76 px. W gornej czesci: roza wiatrow z
gora/dolem na prawo, skrocone wyjscia nietypowe, duze paski **zycie**,
**mana** i **sily** (sily = 100% - zmeczenie z Char.Vitals), cztery
niewielkie, rowne wiersze **pragnienie**, **glod**, **obciazenie** i
**panika**, oraz rowna siatka 3x3 opcji jako klikalne ikony.
Aktywne kierunki maja inny kolor niz nieaktywne. Gdy mapa GMCP
nie zawiera dostepnych wyjsc, nie pokazujemy falszywych oznaczen.
Na samym dole jest pasek EXP z warstwa nadmiarowa tylko przy
rzeczywistych danych >100%. Ikony maja podpowiedzi po najechaniu
oraz kolory ON/OFF na podstawie stanu oficjalnej Chimery.

Aby zobaczyc poprawiony HUD po scaleniu i aktualizacji:
`/cvip aktualizuj`.
W razie problemow: `/cvhud oficjalny`.


## Wlasne bindy: wyjscia i akcje lokacji (0.175)

W edytorze Mudleta otworz **Keys / Klawisze**. W nowym bindzie
ustaw kombinacje, a jako kod Lua wpisz wybrana funkcje:

| Skrot w Mudlecie | Kod Lua | Przeznaczenie |
| --- | --- | --- |
| np. Alt+4 | `chimera_vip.ui.special_exit(1)` | pierwsze niestandardowe przejscie |
| np. Alt+5 | `chimera_vip.ui.special_exit(2)` | drugie niestandardowe przejscie |
| np. Alt+6 | `chimera_vip.ui.special_exit(3)` | trzecie niestandardowe przejscie |
| Alt+1 | `chimera_vip.ui.room_action(1)` | pierwsza akcja kontekstowa |
| Alt+2 | `chimera_vip.ui.room_action(2)` | druga akcja kontekstowa |
| Alt+3 | `chimera_vip.ui.room_action(3)` | trzecia akcja kontekstowa |

Indeksy oznaczaja biezaca pozycje na liscie, nie stala komende.
Wyjscia nietypowe sa alfabetycznie sortowane wedlug aktualnych
kluczy `Room.Info.exits` — tak samo jak klikane etykiety.
Po zmianie lokacji bind wykonuje odpowiednia nowa akcje.
Gdy brak przejscia albo akcji, nie wysyla niczego i zwraca `false`.

Funkcje staja sie dostepne po `/cvip aktualizuj`. Od 0.179
instalacja wtyczek i odswiezenie oficjalnej Chimery nastepuja
automatycznie. Nie trzeba osobno uzywac `/przeladuj`.

Nie zmieniamy domyslnych klawiszy oficjalnej Chimery:
`Ctrl+Shift+1/2/3` moga dzialac rownolegle z wlasnymi `Alt+1/2/3`.
`Ctrl+1/2/3` lepiej zostawic dla przelaczania profili Mudleta 5.


## Wlasne akcje lokacji: /cvakcja (0.176)

Wpisz `/cvakcja`, aby zobaczyc pomoc oraz akcje zapisane dla aktualnego
pokoju, kazda z klikalnym `[usun]`. Dane sa przypisywane do
`gmcp.Room.Info.id` i zapisywane w `ChimeraVIP-data/room_actions.lua`
poza plikami aktualizatora, wiec nie znikaja przy aktualizacji.

Przyklady:

```text
/cvakcja dodaj Pociagnij dzwignie - pociagnij stara dzwignie
/cvakcja alias Przygotuj sie - naps
/cvakcja alias Wlacz magie - /wlm
/cvakcja sekwencja Otworz krypte - wyjmij klucz, otworz wrota, wejdz
/cvakcja usun Pociagnij dzwignie
```

Ponowne podanie istniejacej nazwy w danej lokacji zmienia tresc akcji.
Oficjalne akcje wyswietlane sa najpierw, a wlasne pod nimi. W panelu
`AKCJE LOKACJI` kazdy wiersz jest klikalny i ma lawendowy numer 1-12.
Wlasne i oficjalne akcje sa dostepne w bindach:

```lua
chimera_vip.ui.room_action(1)
chimera_vip.ui.room_action(2)
chimera_vip.ui.room_action(3)
```

Nie przypisujemy automatycznie klawiszy. Gracz moze wybrac np.
`Alt+1/2/3` w edytorze Keys Mudleta. Numer odnosi sie do aktualnie
wyswietlanej pozycji. Przy braku akcji funkcja nic nie wysyla.
Sekwencje wysylaja osobne komendy z odstepem 0.15 s.
Wymagane jest istnienie ID aktualnej lokacji w GMCP.

Po scaleniu: `/cvip aktualizuj`.


## Dwa ulubione bindy (0.177)

Dostepne sa niezalezne funkcje Lua:

```lua
chimera_vip.context_action:run() -- np. klawisz backslash
chimera_vip.map_action:run()     -- np. Alt+backslash
```

**Wazne:** ustaw je samodzielnie w edytorze **Mudlet → Keys**;
pakiet nie przejmuje klawiszy uzytkownika i nie zmienia skrotow
oficjalnej Chimery. Jezeli masz w profilu stary, recznie wklejony
skrypt `context_action.lua`, **wylacz go po aktualizacji**, aby jego
funkcje i timery nie kolidowaly z nowym modulem ChimeraVIP.

Akcja `\\` reaguje na triggery: poprzednie skrypty pozostaja poprawne.

```lua
chimera_vip.context_action:set_send("uderz we wrota", false, 30)
chimera_vip.context_action:set_alias("naps", false, 30)
chimera_vip.context_action:set_alias("/wlm", false, 0)
chimera_vip.context_action:set(function() send("pociagnij dzwignie") end, "Dzwignia", 30)
```

TTl=0 oznacza brak limitu czasu. Akcja z przypisanym pokojem jest
czyszczona po zmianie lokacji (i ponownie weryfikowana przy wykonaniu).
Informacje mają styl [⚡ Kontekst] w brzoskwiniowym odcieniu.

Akcja `Alt+\\` korzysta z wlasnych akcji przypisanych do pokoju
komenda `/cvakcja` (zwykla komenda, alias lub sekwencja).
Przy jednej akcji jest domyslna od razu; jesli jest ich kilka:

```text
/cvakcja
/cvakcja domyslna Otworz wrota
/cvakcja domyslna
/cvakcja domyslna brak
```

Akcja mapowa zawsze sprawdza aktualny `gmcp.Room.Info.id` i nie
wykonuje automatycznie wszystkich akcji. Komunikaty mapowe korzystaja
z [⌖ Mapa] w kolorze lawendowym. Wybrana nazwa jest zapamietana
miedzy sesjami w `ChimeraVIP-data/room_actions.lua`.

Panel Quiet HUD w wersji VIP juz pokazuje same numerki
1-12 w lawendowych obramowaniach. Jezeli widzisz nadal
`Ctrl+Shift+1–3`, sprawdz `/cvhud status` i `/cvhud vip`,
bo moze to byc **oficjalny panel akcji** lub stara kopia wtyczki
w `chimera_wtyczki/chimeravip_ui/`.

Instalacja po scaleniu: `/cvip aktualizuj`. Jezeli wczesniej pracowal osobny Script, wylacz go,
a nastepnie uruchom ponownie profil Mudleta, by zaladowac nowy
modul `src/features/context_action.lua`.


### Kondycje — czytelniejszy znacznik pachołka (0.177)

W oknie Kondycje mała złota ikonka szachowego piona **♟** oznacza
pachołka i stoi **przed** literą znacznika postaci, w miejscu
zwykłego wcięcia (jak gwiazdka ★ przy liderze).
Dawne `[P]` za nazwą oraz `Z:xx%` zostały usunięte.
Nie zmienia to działania oznaczeń `[A]`, `[X]`,
ogłuszenia ani kierunków walki.


### Kondycje w walce — mniej oznaczen (0.177)

Wszystkie wiersze pozostaja klikalne. Relacje napastnikow
pokazujemy jednokrotnie, np. `JA - [1]` i `goblin - [@, A]`,
bez podwojnych strzalek `->` / `<-`. Znaczniki `[A]`,
`[1]`, `[X]` i paski zdrowia pozostaja bez zmian.
Ogluszenie nie dodaje `[OGL]` i nie zmienia barw calego wiersza:
podswietla jedynie nazwe postaci subtelnym grafitem `#303645`.


### Kondycje w walce — relacje i szerokosc (korekta PR 0.177)

Wyswietlamy relacje **raz**, po stronie osoby atakowanej:
`JA - [1]` oznacza, ze przeciwnik [1] atakuje JA;
`goblin - [@, A]` oznacza, ze goblina atakuja JA i czlonek
zespolu A. Nie wyswietlamy rownolegle powtornych strzalek
`->` i `<-`. Oznaczenia [X], HP i wyroznienie
ogluszonego przeciwnika pozostaja bez zmian.

Dlugie nazwy sa skracane od lewej strony, zachowujac ostatnie slowa
(np. `… nerwowy goblin`). Liczba dostepnych kolumn pochodzi
z aktualnej szerokosci okna Kondycje (`getColumnCount`),
a na koncu rezerwowane jest miejsce na oznaczenia napastnikow.
Zmiana rozmiaru okna automatycznie odswieza nazwy.


## ChimeraVIP 0.178 — bezpieczna migracja na Chimere 5

ChimeraVIP staje sie **warstwa prezentacji i lekkich rozszerzen**.
Oficjalna Chimera pozostaje zrodlem GMCP, druzyny, mapy, akcji i
statystyk gry. Stary silnik VIP pozostaje tymczasowo w repozytorium;
nie usuwamy go przed wydzieleniem i przetestowaniem zamiennikow.

**Kopia danych:**

```text
/cvip kopia
/cvip diagnostyka
```

Zabezpieczane sa wszystkie pliki `.lua`, `.json`, `.db` i `.txt`
bezposrednio w katalogu profilu `ChimeraVIP-data`, m.in. ustawienia,
`room_actions.lua`, historia cech i kolory walki. Nie kopiujemy
podkatalogow, kopii archiwalnych, oficjalnej bazy `Database_*.db`
ani ustawien Mudleta. Kazda migawka trafia do osobnego katalogu
`ChimeraVIP-data/backups/cvip-YYYYMMDD-HHMMSS[-N]`. Nie ma
automatycznego przywracania ani usuwania starych kopii.

Po instalacji 0.178 aktualizator wykona taka kopie automatycznie
PRZED kazda kolejna aktualizacja VIP, przed pierwsza zmiana pliku.
Gdy kopia nie powiedzie sie, aktualizacja zostanie przerwana.
Pierwsza aktualizacja z 0.177 do 0.178 uzywa jeszcze starego
aktualizatora; w 0.178 nie wykonujemy zadnej migracji danych.

Oficjalne wydanie 5.0.1 porownano na poziomie zrodel i publicznego
API wtyczek. Zgodnosc w prawdziwej sesji Mudleta pozostaje do
potwierdzenia. `/cvip diagnostyka` pokazuje osobno wersje z
`chimera.app.version` i zakres audytu zrodel. Wydanie 0.179
wprowadzilo juz automatyczna instalacje wtyczek i przeladowanie klienta.


## ChimeraVIP 0.179 — jedna aktualizacja

`/cvip aktualizuj` zarządza już instalacją i odświeżeniem wtyczek.
Nie trzeba dopisywać `/cvip v5 instaluj` ani `/przeladuj`.
Jeśli nic się nie zmieniło, nie wymusza niepotrzebnego restartu.
W razie błędu lub braku `chimera.restart()` pokaże instrukcję.
Szczegółowy opis przejścia oraz zabezpieczeń: `docs/CHIMERA5_MIGRATION.md`.
