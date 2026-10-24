# ChimeraVIP

Pastelowa nakladka na **oficjalne skrypty Chimery 5.0** dla Mudleta.
Serwer: `chimera.co.pl:2300`. Wersja ChimeraVIP: **0.176**.
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
`/cvip aktualizuj`, `/cvip v5 instaluj`, `/przeladuj`.
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

Funkcje dostepne sa po zainstalowaniu wtyczki ChimeraVIP 5 oraz
przeladowaniu `/przeladuj`. Jesli instalujesz poprawke po aktualizacji,
wykonaj: `/cvip aktualizuj`, `/cvip v5 instaluj`, `/przeladuj`.

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

Po scaleniu: `/cvip aktualizuj`, `/cvip v5 instaluj`, `/przeladuj`.
