# ChimeraVIP

Nakładka do oficjalnych skryptów **Chimera MUD** dla Mudleta. Projekt nie modyfikuje kodu upstreamu; korzysta z jego GMCP, eventów i publicznych struktur.

Serwer: `chimera.co.pl:2300`  
Aktualna wersja ChimeraVIP: **0.103**  
Wersja upstreamu potwierdzona w działającym runtime: **4.3**

## Instalacja

W linii poleceń Mudleta wpisz:

```lua
lua installPackage("https://raw.githubusercontent.com/gnomidlo/ChimeraVIP/main/packages/ChimeraVIP.xml")
```

Pakiet tworzy trwały loader `ChimeraVIP/loader`, który pobiera aktualny runtime do:

```text
getMudletHomeDir()/ChimeraVIP/
```

Dane użytkownika są przechowywane osobno w `getMudletHomeDir()/ChimeraVIP-data/`.

Aktualizacja istniejącej instalacji:

```text
/cvip sprawdz
/cvip aktualizuj
```

Updater 2.0 korzysta z manifestu v2 i po pierwszym przejściu pobiera tylko pliki, których Git blob SHA zmienił się względem lokalnego `installed_manifest.lua`. Aktualizacja jest przygotowywana w stagingu, sprawdza rozmiary plików i tworzy backup przed podmianą.

## Interfejs

ChimeraVIP dodaje pastelowy motyw oraz responsywny Quiet Footer z kompasem, wyjściami specjalnymi, KOND/SIŁY/MANA, potrzebami, OBC/UPI, EXP, auto-wsparciem i dynamicznymi kontrolkami oficjalnych funkcji Chimery.

Ustawienie rozmiaru w `/cvip ustawienia` dotyczy wyłącznie oficjalnych okien `states_window` i `enemy_states_window`. Quiet Footer zachowuje własne stałe fonty.

Od 0.103 footer nie przebudowuje ponownie elementów vitals, których wartość nie zmieniła się od poprzedniego eventu GMCP.

## Combat Colors

`features/combat_colors` dodaje pastelowe prefiksy `0/3–3/3` dla `zadane_*`, `otrzymane_*`, `innych_zadane_*` i `innych_otrzymane_*`. Moduł uczy się ustawień z wyniku `kolory`; `-1` oznacza brak koloru.

Rozpoznane trafienia `otrzymane_*` podnoszą `chimeraVipIncomingHit`, z którego korzysta Defense Tracker.

## Defense Tracker

`features/defense_tracker` po cichu prowadzi statystyki wyłącznie w pamięci bieżącej sesji. Niczego nie zapisuje na dysku.

Liczy pudła przeciwników, uniki, parowania, zasłony, ciosy zatrzymane pancerzem oraz znane trafienia `0/3–3/3`. Zasłony, parowania i pancerz mają dodatkowe zestawienie według użytego przedmiotu.

```text
/def
/def sprzet
/def last [N]
/def reset
/def pomoc
```

## Auto-wsparcie

Auto-wsparcie obserwuje dane drużyny i walki z GMCP Chimery. Gdy relacje pozwalają ustalić cel lidera, pilnuje aby postać biła ten sam cel.

Jedna próba wsparcia wysyła `wesprzyj` dwukrotnie z krótkim odstępem i podlega cooldownowi.

## Tracker XP

```text
/xp
/xp mobs
/xp mob <nazwa>
/xp last [N]
/xp reset
/xp pomoc
```

Tracker liczy XP/h, aktywny czas, trend, własne i drużynowe zabójstwa oraz statystyki mobów. Statystyki są agregowane inkrementalnie, a bufory ostatnich zdarzeń są ograniczone.

## Cechy i rozwój

`features/stats` formatuje odczyt `cechy`, tworzy snapshoty, liczy delty oraz zapisuje historię rozwoju osobno dla każdej postaci rozpoznanej przez `gmcp.Char.Name`.

```text
cechy
/cechy historia [N]
/cechy pomoc
```

Dane historyczne pozostają w `ChimeraVIP-data/progression.lua` dla zgodności z wcześniejszymi wersjami, ale osobny moduł `/progres` nie jest już używany.

## Postacie

`features/characters` zapisuje sześć odmian imienia, relację i kolory highlightu. Baza znajduje się w `ChimeraVIP-data/characters.lua`.

```text
odmien <imie>
/postacie
/postacie szukaj <tekst>
/postacie info <imie>
/postacie grupa <imie> p|n|w|?
/postacie kolor
```

## Pojemniki i ekwipunek

ChimeraVIP formatuje zawartość rozpoznanych pojemników, przenosi monety na górę raportu oraz lekko koloruje standardowe linie `RECE`, `EKWIPUNEK` i `PRZY SOBIE` bez przebudowywania tekstu MUD-a.

## Pomoc, ustawienia i system

```text
/cvip
/cvip ustawienia
/cvip moduly
/cvip diagnostyka
/cvip status
/cvip sprawdz
/cvip aktualizuj
/cvip przeladuj
```

`/cvip ustawienia` jest centralnym panelem trwałych ustawień ChimeraVIP i będzie rozszerzany o konfigurację kolejnych modułów.

## Struktura

```text
ChimeraVIP/
├── VERSION
├── manifest.lua
├── loader.lua
├── releases/
├── packages/
├── tools/
└── src/
    ├── init.lua
    ├── core/
    ├── integrations/
    ├── theme/
    ├── ui/
    └── features/
```

## Walidacja wydań

GitHub Actions uruchamia `tools/release_check.lua`. Checker pilnuje zgodności `VERSION`, manifestu i bootstrapu, składni Lua, istnienia plików oraz hashy i rozmiarów `file_meta`.

## Zgodność

ChimeraVIP jest nakładką zależną od oficjalnych skryptów Chimery. Aktualnie działanie zostało potwierdzone z upstreamem **4.3**. Integracje z publicznymi strukturami upstreamu powinny być ponownie sprawdzane po większych zmianach oficjalnych skryptów.
