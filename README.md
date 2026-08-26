# ChimeraVIP

Nakładka do oficjalnych skryptów **Chimera MUD** dla Mudleta. Projekt nie modyfikuje kodu upstreamu; korzysta z jego GMCP, eventów i publicznych struktur.

Serwer: `chimera.co.pl:2300`  
Aktualna wersja ChimeraVIP: **0.73**  
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

Po instalacji wpisz:

```text
/cvip
```

aby zobaczyć pełną pomoc.

### Aktualizacja istniejącej instalacji

```text
/cvip sprawdz
/cvip aktualizuj
```

Updater pobiera całą nową wersję do katalogu stagingowego i dopiero po kompletnym pobraniu podmienia lokalne pliki. Aktualizacja nie nadpisuje danych użytkownika.

### Instalacja ręczna

Jeżeli instalacja pakietu URL nie jest dostępna w używanej wersji Mudleta, można utworzyć ręcznie jeden trwały Script i wkleić do niego zawartość `loader.lua`.

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
- dynamiczne mini-przyciski oficjalnych funkcji Chimery: UKR, PRZ, ATK, ZBI, LAM, WAL i ZAS.

Mini-przyciski pokazują stan funkcji zamiast być wyłącznie skrótami:

- `UKR` — stan ukrycia (`●` albo wartość, jeśli upstream ją udostępnia),
- `PRZ` — aktualny tryb przemykania (`OFF`, `JA`, `DRU`),
- `ATK N` — numer oficjalnego trybu ataku; pełna nazwa jest w tooltipie,
- `ZBI N` — numer oficjalnego trybu zbierania; pełna nazwa jest w tooltipie,
- `LAM ●/○` — lampa zapalona/zgaszona,
- `WALKA ●` / `WAL Ns` — stan walki lub okres po walce,
- `ZAS ✓` / `ZAS N` / `ZAS —` — zasłona gotowa, w odnowieniu albo niedostępna.

Niedostępne akcje nie wykonują kliknięcia. Na węższym footerze etykiety automatycznie przechodzą w krótszą postać.

### Integracja z oficjalną Chimerą

Po uruchomieniu ChimeraVIP wyłącza oficjalny folder skryptów:

```text
chimera/skrypty/ui/gags
```

Kod oficjalnego pakietu nie jest edytowany. ChimeraVIP używa `disableScript()` do dezaktywacji folderu w profilu.

### Kolory walki

`features/combat_colors` przejmuje prezentację siły obrażeń po wyłączeniu oficjalnego `gags` i dodaje pastelowe prefiksy `0/3`–`3/3`.

Obsługiwane są cztery grupy kolorów:

- `zadane_*` — obrażenia zadawane przez Twoją postać,
- `otrzymane_*` — obrażenia otrzymywane przez Twoją postać,
- `innych_zadane_*` — obrażenia zadawane w walce osób postronnych,
- `innych_otrzymane_*` — obrażenia otrzymywane w walce osób postronnych.

Moduł automatycznie uczy się aktualnych ustawień z wyniku komendy gry:

```text
kolory
```

Wartość `-1` oznacza `bez koloru` i dla takiej kategorii nie jest tworzony trigger ANSI. Prefiks jest dodawany wyłącznie do linii mających co najmniej 50 znaków i zawierających co najmniej jedną literę.

Ustawienia są zapisywane w:

```text
getMudletHomeDir()/ChimeraVIP-data/combat_colors.lua
```

Starszy plik `chimera_damage_colors.lua` jest automatycznie wykrywany i migrowany. Stare triggery z pakietu `CHIMERA_damage_prefixes.xml` są wyłączane, aby nie tworzyć podwójnych prefiksów.

Pomoc:

```text
/cvip pomoc walka
```

### Auto-wsparcie

Obserwuje GMCP drużyny i walki. Jeżeli członek drużyny walczy, a Twoja postać jeszcze nie uczestniczy w walce, wysyła `wesprzyj`. Przełącznik ON/OFF znajduje się w prawej części footera.

### Tracker XP

Łapie komunikaty zabicia z `[...xp]`, rozróżnia własne i drużynowe zabójstwa oraz liczy XP/h, aktywny czas, trend i statystyki mobów.

Najważniejsze komendy:

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

### Cechy

`features/stats` przechwytuje standardowy wynik cech, poprawia czytelność i wylicza:

- `Fiz` = Siła + Zręczność + Wytrzymałość,
- `Ment` = Intelekt + Mądrość,
- `Odw` = Odwaga,
- `Łącznie` = suma wszystkich cech.

### Progres postaci

Historia progresji łączy snapshoty cech z XP i zapisuje dane osobno dla każdej postaci. Postać jest identyfikowana przez:

1. `gmcp.Char.Name.fullname`,
2. fallback: `gmcp.Char.Name.name`.

Dane są zapisywane w `ChimeraVIP-data/progression.lua`.

```text
/progres
/progres historia [N]
/progres postacie
/progres help
/cechy info
/cechy historia [N]
```

## Pomoc

`/cvip` jest głównym centrum pomocy i wyświetla opis wszystkich modułów w kategoriach.

```text
/cvip
/cvip pomoc
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

Moduły zachowują również własne krótsze pomoce, np. `/xp help` i `/progres help`.

## Aktualizacje

Źródłem wersji jest `manifest.lua`. Przy publikacji nowej wersji aktualizowane są:

1. `VERSION`,
2. `manifest.lua`,
3. `CHANGELOG.md`,
4. `releases/<wersja>.md`,
5. zmienione moduły.

Updater obejmuje również lokalny `loader.lua`, dzięki czemu infrastruktura startowa może być rozwijana razem z resztą projektu.

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
    │   ├── help.lua
    │   └── updater.lua
    ├── integrations/
    │   └── chimera.lua
    ├── theme/
    │   └── pastel.lua
    ├── ui/
    │   ├── quiet_footer.lua
    │   └── footer_controls.lua
    └── features/
        ├── combat_colors.lua
        ├── auto_support.lua
        ├── xp_tracker.lua
        ├── stats.lua
        └── progression.lua
```

## Zgodność

ChimeraVIP jest nakładką zależną od oficjalnych skryptów Chimery. Integracje z ich strukturami powinny być sprawdzane po zmianach upstreamu.
