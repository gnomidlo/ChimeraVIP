# ChimeraVIP

Nakładka do oficjalnych skryptów **Chimera MUD** dla Mudleta. Projekt nie modyfikuje kodu upstreamu; korzysta z jego GMCP, eventów i publicznych struktur.

Serwer: `chimera.co.pl:2300`  
Aktualna wersja ChimeraVIP: **0.77**  
Wersja upstreamu używana przy rozwoju: **2.6**

## Instalacja

W linii poleceń Mudleta wpisz:

```lua
lua installPackage("https://raw.githubusercontent.com/gnomidlo/ChimeraVIP/main/packages/ChimeraVIP.xml")
```

Pakiet tworzy trwały loader `ChimeraVIP/loader`, który pobiera aktualny runtime do:

```text
getMudletHomeDir()/ChimeraVIP/
```

Dane użytkownika są przechowywane osobno w:

```text
getMudletHomeDir()/ChimeraVIP-data/
```

Po instalacji wpisz `/cvip`, aby zobaczyć pełną pomoc.

Aktualizacja istniejącej instalacji:

```text
/cvip sprawdz
/cvip aktualizuj
```

## Interfejs

ChimeraVIP dodaje pastelowy motyw oraz responsywny Quiet Footer z kompasem, wyjściami specjalnymi, KOND/SIŁY/MANA, potrzebami, OBC/UPI, EXP, auto-wsparciem i dynamicznymi kontrolkami oficjalnych funkcji Chimery.

Footer zachowuje własne stałe rozmiary tekstu. Ustawienie rozmiaru w `/cvip ustawienia` dotyczy wyłącznie oficjalnych okien stanów:

```text
states_window
enemy_states_window
```

czyli widoku kondycji drużyny, przeciwników i innych postaci.

## Ustawienia

Ustawienia są trwałe i zapisywane w:

```text
getMudletHomeDir()/ChimeraVIP-data/settings.lua
```

```text
/cvip ustawienia
/cvip ustawienia rozmiar <7-14>
/cvip ustawienia moduly
/cvip ustawienia modul kolory on|off|toggle
/cvip moduly
```

`/cvip ustawienia` otwiera panel z klikalnymi próbkami rozmiarów `7–14`. Zmiana jest od razu stosowana do `states_window` i `enemy_states_window` oraz pozostaje po restarcie Mudleta.

## Combat Colors

`features/combat_colors` dodaje pastelowe prefiksy `0/3–3/3` dla:

- `zadane_*`,
- `otrzymane_*`,
- `innych_zadane_*`,
- `innych_otrzymane_*`.

Moduł uczy się ustawień z wyniku `kolory`. `-1` oznacza brak koloru. Prefiks jest dodawany tylko do linii mających minimum 50 znaków i zawierających co najmniej jedną literę.

Stan modułu jest powiązany z oficjalnym folderem:

```text
chimera/skrypty/ui/gags
```

`KOL ON` wyłącza `gags` i uruchamia prefiksy ChimeraVIP. `KOL OFF` usuwa własne triggery i ponownie włącza `gags`.

## Auto-wsparcie

Auto-wsparcie obserwuje `gmcp.Chimera.Group` i `gmcp.Chimera.Combat`.

Od 0.77, gdy relacje walki pozwalają ustalić cel lidera drużyny, moduł porównuje go z celem bieżącej postaci. Jeśli postać nie walczy z tym samym przeciwnikiem, ponawia wsparcie.

Jedna próba wsparcia wysyła:

```text
wesprzyj
[0.18 s]
wesprzyj
```

Druga komenda obsługuje NPC wymagających potwierdzenia. Cała para podlega cooldownowi 1500 ms. Jeśli cel lidera nie jest jeszcze dostępny w GMCP, moduł używa wcześniejszego fallbacku i dołącza do trwającej walki drużyny.

## Tracker XP

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

Tracker liczy XP/h, aktywny czas, trend, własne i drużynowe zabójstwa oraz statystyki mobów. Ręczne klasyfikacje są przechowywane w `ChimeraVIP-data/xp_mobs.lua`.

## Cechy i progres

`features/stats` formatuje odczyt cech i tworzy snapshoty. `features/progression` łączy je z XP i zapisuje historię osobno dla każdej postaci rozpoznanej po `gmcp.Char.Name.fullname`, z fallbackiem do `gmcp.Char.Name.name`.

```text
/progres
/progres historia [N]
/progres postacie
/progres help
/cechy info
/cechy historia [N]
```

Dane progresji są zapisywane w `ChimeraVIP-data/progression.lua`.

## Pomoc i system

```text
/cvip
/cvip pomoc ustawienia
/cvip pomoc walka
/cvip pomoc xp
/cvip pomoc progres
/cvip pomoc ui

/cvip status
/cvip sprawdz
/cvip aktualizuj
/cvip przeladuj
```

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
    │   ├── settings_panel.lua
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
