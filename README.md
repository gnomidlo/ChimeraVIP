# ChimeraVIP

Nakładka do oficjalnych skryptów **Chimera MUD** dla Mudleta. Projekt nie modyfikuje kodu upstreamu; korzysta z jego GMCP, eventów i publicznych struktur.

Serwer: `chimera.co.pl:2300`  
Aktualna wersja ChimeraVIP: **0.74**  
Wersja upstreamu używana przy rozwoju: **2.6**

## Instalacja

Najprostsza instalacja odbywa się bez ręcznego tworzenia skryptów. W linii poleceń Mudleta wpisz:

```lua
lua installPackage("https://raw.githubusercontent.com/gnomidlo/ChimeraVIP/main/packages/ChimeraVIP.xml")
```

Pakiet tworzy w profilu jedynie trwały loader `ChimeraVIP/loader`. Loader pobiera aktualną wersję do:

```text
getMudletHomeDir()/ChimeraVIP/
```

Dane użytkownika są przechowywane osobno w:

```text
getMudletHomeDir()/ChimeraVIP-data/
```

Po instalacji wpisz `/cvip`, aby zobaczyć pełną pomoc.

### Aktualizacja istniejącej instalacji

```text
/cvip sprawdz
/cvip aktualizuj
```

Updater pobiera całą nową wersję do katalogu stagingowego i dopiero po kompletnym pobraniu podmienia lokalne pliki. Aktualizacja nie nadpisuje danych użytkownika.

## Co robi ChimeraVIP

### Interfejs

- pastelowy motyw oficjalnego UI,
- responsywny Quiet Footer,
- kompas i wyjścia specjalne z GMCP,
- KOND / SIŁY / MANA,
- SYTOŚĆ / WODA,
- OBC / UPI,
- pasek EXP,
- panel auto-wsparcia,
- dynamiczne mini-przyciski: UKR, PRZ, ATK, ZBI, LAM, WAL i ZAS,
- `KOL ●/○` — trwały przełącznik modułu Combat Colors.

Mini-przyciski pokazują aktualny stan funkcji. Niedostępne akcje nie wykonują kliknięcia, a na węższym footerze etykiety przechodzą w krótszą postać.

### Ustawienia

Od 0.74 ustawienia są trwałe i zapisywane w:

```text
getMudletHomeDir()/ChimeraVIP-data/settings.lua
```

Podstawowe komendy:

```text
/cvip ustawienia
/cvip ustawienia czcionka <nazwa>
/cvip ustawienia czcionka domyslna
/cvip ustawienia rozmiar <8-11>
/cvip ustawienia moduly
/cvip ustawienia modul kolory on|off|toggle
/cvip moduly
```

`czcionka` ustawia rodzinę fontu tekstowej części okna kondycji. Nazwa może zawierać spacje, np.:

```text
/cvip ustawienia czcionka JetBrains Mono
```

`rozmiar` zmienia rozmiar głównego tekstu kondycji, a tekst pomocniczy jest skalowany razem z nim. Zmiana działa od razu i pozostaje po restarcie Mudleta.

### Integracja z oficjalną Chimerą

Stan oficjalnego folderu:

```text
chimera/skrypty/ui/gags
```

jest powiązany ze stanem Combat Colors:

- `KOL ON` — oficjalny `gags` jest wyłączony, aktywne są prefiksy ChimeraVIP,
- `KOL OFF` — prefiksy ChimeraVIP są usuwane, oficjalny `gags` jest ponownie włączany.

Kod oficjalnego pakietu nie jest edytowany.

### Kolory walki

`features/combat_colors` dodaje pastelowe prefiksy `0/3`–`3/3` i obsługuje:

- `zadane_*`,
- `otrzymane_*`,
- `innych_zadane_*`,
- `innych_otrzymane_*`.

Moduł uczy się aktualnych ustawień z wyniku komendy `kolory`. Wartość `-1` oznacza `bez koloru`. Prefiks jest dodawany wyłącznie do linii mających co najmniej 50 znaków i zawierających co najmniej jedną literę.

Ustawienia kolorów są zapisywane w:

```text
getMudletHomeDir()/ChimeraVIP-data/combat_colors.lua
```

Pomoc:

```text
/cvip pomoc walka
```

### Auto-wsparcie

Obserwuje GMCP drużyny i walki. Jeżeli członek drużyny walczy, a Twoja postać jeszcze nie uczestniczy w walce, wysyła `wesprzyj`. Przełącznik ON/OFF znajduje się w prawej części footera.

### Tracker XP

Łapie komunikaty zabicia z `[...xp]`, rozróżnia własne i drużynowe zabójstwa oraz liczy XP/h, aktywny czas, trend i statystyki mobów.

```text
/xp
/xp mobs
/xp mob <nazwa>
/xp last [N]
/xp rules
/xp add nazwa#forma
/xp del <nazwa>
/xp reset
/xp help
```

Reguły klasyfikacji są przechowywane w `ChimeraVIP-data/xp_mobs.lua`.

### Cechy i progres

`features/stats` przechwytuje standardowy wynik cech i wylicza Fiz / Ment / Odw / Łącznie.

`features/progression` łączy snapshoty cech z XP i zapisuje historię osobno dla każdej postaci rozpoznanej przez `gmcp.Char.Name.fullname`, z fallbackiem do `gmcp.Char.Name.name`.

```text
/progres
/progres historia [N]
/progres postacie
/progres help
/cechy info
/cechy historia [N]
```

Dane są zapisywane w `ChimeraVIP-data/progression.lua`.

## Pomoc

`/cvip` jest głównym centrum pomocy.

```text
/cvip
/cvip pomoc ustawienia
/cvip pomoc walka
/cvip pomoc xp
/cvip pomoc progres
/cvip pomoc ui
```

Komendy systemowe:

```text
/cvip status
/cvip sprawdz
/cvip aktualizuj
/cvip przeladuj
```

## Aktualizacje

Źródłem wersji jest `manifest.lua`. Przy publikacji nowej wersji aktualizowane są `VERSION`, manifest, changelog, release notes oraz zmienione moduły. Updater obejmuje również lokalny `loader.lua`.

## Struktura

```text
ChimeraVIP/
├── VERSION
├── CHANGELOG.md
├── README.md
├── loader.lua
├── manifest.lua
├── releases/
├── packages/
│   ├── ChimeraVIP.xml
│   └── CHIMERA_damage_prefixes.xml   # legacy
└── src/
    ├── init.lua
    ├── core/
    │   ├── bootstrap.lua
    │   ├── util.lua
    │   ├── settings.lua
    │   ├── help.lua
    │   └── updater.lua
    ├── integrations/
    │   └── chimera.lua
    ├── theme/
    │   └── pastel.lua
    ├── ui/
    │   ├── quiet_footer.lua
    │   ├── settings_apply.lua
    │   ├── footer_controls.lua
    │   └── module_controls.lua
    └── features/
        ├── combat_colors.lua
        ├── auto_support.lua
        ├── xp_tracker.lua
        ├── stats.lua
        └── progression.lua
```

## Zgodność

ChimeraVIP jest nakładką zależną od oficjalnych skryptów Chimery. Integracje z ich strukturami powinny być sprawdzane po zmianach upstreamu.
