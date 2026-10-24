# ChimeraVIP

Pastelowa nakladka na **oficjalne skrypty Chimery 5.0** dla Mudleta.
Serwer: `chimera.co.pl:2300`. Wersja ChimeraVIP: **0.171**.
Testowana baza: **5.0.0-beta.13**.

## Instalacja i aktualizacja

Oficjalna Chimera 5 musi byc zainstalowana i uruchomiona.
W Mudlecie:

```lua
lua installPackage("https://raw.githubusercontent.com/gnomidlo/ChimeraVIP/main/packages/ChimeraVIP.xml")
```

Po aktualizacji `/cvip aktualizuj` wykonaj `/cvip v5 instaluj`
i oficjalne `/przeladuj`. Instaluje to most API i wtyczke HUD do
`chimera_wtyczki/`; nie modyfikuje plikow oficjalnej paczki.

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

Po scaleniu aktualizacji: `/cvip aktualizuj`, `/cvip v5 instaluj`,
oficjalne `/przeladuj`. W razie problemow: `/cvhud oficjalny`.
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

Po scaleniu: `/cvip aktualizuj`, `/cvip v5 instaluj`,
oficjalne `/przeladuj`.


## Kolorystyczny Quiet HUD 0.171

Nowy wyglad inspirowany wariantem 1: stonowane panele Geyser, kolor
HP/MP/ZM zalezy od procentu, GORA/DOL w kompasie, a przyciski wspieraja
wskazania ON/OFF pobierane z oficjalnego `status_bar.model()`.
Pasek EXP zajmuje dolna krawedz footera. Dodatkowe warstwy w zloto-
bursztynowych odcieniach widac tylko gdy oficjalne GMCP albo zdarzenie
postepu dostarczy wartosc wyzsza niz 100; w przeciwnym razie nie ma
wiarygodnych danych o nadwyzce. /cvhud oficjalny cofa zmiany.
