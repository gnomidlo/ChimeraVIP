# ChimeraVIP

Pastelowa nakladka na **oficjalne skrypty Chimery 5.0** dla Mudleta.
Serwer: `chimera.co.pl:2300`. Wersja ChimeraVIP: **0.167**.
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
