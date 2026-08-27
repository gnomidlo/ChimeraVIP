# Changelog

## 0.74 — 2026-08-27

Dodano trwały system ustawień oraz pierwszy przełączalny moduł ChimeraVIP.

### Dodano
- `src/core/settings.lua` — centralne ustawienia użytkownika zapisywane w `getMudletHomeDir()/ChimeraVIP-data/settings.lua`,
- trwałą konfigurację rodziny czcionki tekstowej części okna kondycji,
- trwałą konfigurację rozmiaru czcionki kondycji w zakresie 8–11,
- `src/ui/settings_apply.lua`, który nakłada ustawienia czcionki na KOND/SIŁY/MANA, potrzeby, OBC/UPI i EXP bez modyfikowania oficjalnego UI,
- rejestr stanów modułów przygotowany pod kolejne opcjonalne funkcje,
- `src/ui/module_controls.lua` z przyciskiem `KOL ●/○` w wolnym ósmym polu panelu footera,
- komendy `/cvip ustawienia`, `/cvip ustawienia moduly` i `/cvip moduly`,
- komendy `/cvip ustawienia czcionka <nazwa>`, `/cvip ustawienia czcionka domyslna` oraz `/cvip ustawienia rozmiar <8-11>`,
- komendę `/cvip ustawienia modul kolory on|off|toggle`.

### Zmieniono
- `Combat Colors` jest teraz modułem przełączalnym i domyślnie pozostaje włączony,
- `KOL ON` tworzy tymczasowe triggery prefiksów oraz wyłącza oficjalny folder `chimera/skrypty/ui/gags`,
- `KOL OFF` usuwa triggery prefiksów, wyłącza trigger uczenia kolorów i ponownie włącza oficjalny `gags`,
- stan `KOL` jest zapamiętywany pomiędzy restartami Mudleta,
- `src/integrations/chimera.lua` nie wyłącza już `gags` bezwarunkowo; synchronizuje go ze stanem modułu `combat_colors`,
- `/cvip` i `/cvip pomoc ustawienia` opisują nowe opcje konfiguracji i modułów.

### Dane użytkownika
- ustawienia ogólne: `ChimeraVIP-data/settings.lua`,
- ustawienia ANSI Combat Colors nadal pozostają w `ChimeraVIP-data/combat_colors.lua`,
- aktualizacje repozytorium nie nadpisują żadnego z tych plików.

## 0.73 — 2026-08-26

Przebudowano mini-przyciski Quiet Footera tak, aby ich etykiety i zachowanie odzwierciedlały rzeczywisty stan oficjalnych funkcji Chimery.

### Zmieniono
- `UKR` pokazuje stan ukrycia: brak znacznika dla postaci nieukrytej, `●` dla poprawnego ukrycia albo wartość liczbową, jeśli upstream ją udostępnia,
- `PRZ` pokazuje aktualny tryb przemykania: `OFF`, `JA` albo `DRU`; na węższym footerze przechodzi w kompaktowe `PRZ 1/2/3`,
- `ATK` pokazuje numer aktualnego `ateam.attack_mode`, a pełna oficjalna nazwa trybu pozostaje w tooltipie,
- `ZBI` pokazuje numer aktualnego `scripts.inv.collect.current_mode`, a pełna oficjalna nazwa trybu pozostaje w tooltipie,
- `LAM` używa `●` dla zapalonej i `○` dla zgaszonej lampy,
- `WAL` dynamicznie zmienia się na `WALKA ●` podczas walki oraz pokazuje stan/czas po walce, jeśli upstream go udostępnia,
- `ZAS` pokazuje `✓` gdy akcja zasłony jest gotowa, wartość odnowienia gdy nie jest gotowa oraz `—` gdy jest niedostępna,
- niedostępna `ZAS` nie wykonuje akcji po kliknięciu i nie dostaje aktywnego efektu hover,
- tooltipy opisują teraz typ kontrolki, aktualny stan oraz dokładny efekt kliknięcia,
- szerokość przycisków jest responsywna; przy małej ilości miejsca etykiety automatycznie przechodzą w krótszą postać,
- odświeżenie stanu po kliknięciu odbywa się dwukrotnie (krótkie i opóźnione), aby poprawnie łapać moduły upstreamu aktualizujące stan asynchronicznie.

### Architektura
- logika akcji nadal pozostaje po stronie oficjalnych skryptów Chimery; ChimeraVIP jedynie prezentuje stan i deleguje kliknięcia do istniejących funkcji upstreamu,
- nie wprowadzono własnych nazw trybów `ATK` i `ZBI`; numer jest pokazywany na przycisku, a oficjalny tekst Chimery w tooltipie, co ogranicza ryzyko rozjazdu po aktualizacji upstreamu.

## 0.72 — 2026-08-26

Dodano pełnoprawny moduł kolorowania walki, który przejmuje prezentację obrażeń po wyłączeniu oficjalnego folderu `chimera/skrypty/ui/gags`.

### Dodano
- `src/features/combat_colors.lua`,
- pastelowe prefiksy siły obrażeń `0/3`–`3/3`,
- obsługę nowych kategorii walki osób postronnych: `innych_zadane_*` oraz `innych_otrzymane_*`,
- automatyczne uczenie wszystkich 16 kategorii z wyniku komendy `kolory`,
- obsługę wartości `-1` jako `bez koloru` — bez tworzenia triggera ANSI,
- eventy `chimeraVipCombatColorsReady` i `chimeraVipCombatColorsUpdated`,
- sekcję `WALKA I KOLORY` w głównej pomocy `/cvip`, dostępną także przez `/cvip pomoc walka`.

### Zmieniono
- minimalna długość linii dla prefiksu wzrosła z 40 do 50 znaków,
- linia musi dodatkowo zawierać przynajmniej jedną literę, dzięki czemu separatory i techniczne linie UI nie są prefixowane,
- ustawienia kolorów są przechowywane w `getMudletHomeDir()/ChimeraVIP-data/combat_colors.lua`,
- starszy `chimera_damage_colors.lua` jest automatycznie migrowany do nowej lokalizacji,
- stare tymczasowe triggery standalone oraz znane triggery z legacy `CHIMERA_damage_prefixes.xml` są wyłączane przy starcie modułu, aby uniknąć podwójnych prefixów,
- synchronizacja po komendzie `kolory` jest batchowana i przebudowuje triggery dopiero po odczytaniu listy, zamiast po każdej pojedynczej linii.

### Domyślne kolory Chimery
- `zadane_brak = -1`, `zadane_niskie = 176`, `zadane_srednie = 169`, `zadane_wysokie = 160`,
- `otrzymane_brak = -1`, `otrzymane_niskie = 225`, `otrzymane_srednie = 203`, `otrzymane_wysokie = 196`,
- `innych_zadane_brak = -1`, `innych_zadane_niskie = 108`, `innych_zadane_srednie = 71`, `innych_zadane_wysokie = 34`,
- `innych_otrzymane_brak = -1`, `innych_otrzymane_niskie = 180`, `innych_otrzymane_srednie = 173`, `innych_otrzymane_wysokie = 166`.

## 0.71 — 2026-08-26

Nowy system instalacji i pomocy oraz dodatkowa integracja z oficjalnym pakietem Chimery.

### Dodano
- `packages/ChimeraVIP.xml` — instalator Mudleta uruchamiany jedną komendą `installPackage(...)`,
- trwały skrypt `ChimeraVIP/loader` instalowany jako pakiet; przy pierwszym uruchomieniu pobiera repozytoryjny `loader.lua`,
- `src/core/help.lua` — centralną, kategoryzowaną pomoc wszystkich modułów,
- `/cvip` jako pełne centrum pomocy,
- `/cvip pomoc [sekcja]`, np. `xp`, `progres` lub `ui`,
- `/cvip status` do szybkiego sprawdzania wersji nakładki i upstreamu,
- `src/integrations/chimera.lua` — warstwę integracji z oficjalnym pakietem,
- automatyczne wyłączanie folderu skryptów `chimera/skrypty/ui/gags` po starcie ChimeraVIP.

### Zmieniono
- `loader.lua` został dodany do manifestu i od wersji 0.71 jest aktualizowany razem z resztą runtime,
- `src/init.lua` ładuje centralną pomoc i integrację z oficjalną Chimerą przed modułami funkcjonalnymi,
- README opisuje instalację jedną komendą oraz nowe centrum pomocy,
- `/cvip` nie pokazuje już wyłącznie krótkiego statusu; bez argumentów wyświetla pełną, opisaną pomoc dla nowego użytkownika.

### Instalacja

```lua
lua installPackage("https://raw.githubusercontent.com/gnomidlo/ChimeraVIP/main/packages/ChimeraVIP.xml")
```

## 0.70 — 2026-08-26

Dodano trwałą historię progresji przypisaną do konkretnej postaci po GMCP `Char.Name`.

### Dodano
- `src/features/progression.lua`,
- rozpoznawanie aktualnej postaci przez `gmcp.Char.Name.fullname`, z fallbackiem do `gmcp.Char.Name.name`,
- osobne dane progresji dla każdej postaci używanej w tym samym profilu Mudleta,
- trwały zapis w `getMudletHomeDir()/ChimeraVIP-data/progression.lua`,
- licznik całego XP śledzonego dla postaci,
- licznik XP zdobytego od ostatniej rzeczywistej zmiany cech,
- historię maksymalnie 100 snapshotów bazowych/zmian,
- zapis różnic cech pomiędzy kolejnymi zmianami,
- powiązanie `chimeraVipXpGained` z `chimeraVipStatsUpdated`,
- event `chimeraVipProgressionUpdated` dla przyszłego UI,
- komendy `/progres`, `/progres historia [N]`, `/progres postacie`, `/progres help`,
- aliasy `/cechy info` i `/cechy historia [N]`.

### Zachowanie
- pierwszy pełny odczyt cech tworzy punkt bazowy,
- zwykłe ponowne sprawdzenie cech bez zmiany nie zeruje licznika XP,
- dopiero faktyczna zmiana którejkolwiek cechy zapisuje wpis historii i zeruje licznik `XP od zmiany`,
- gdy kilka cech zmieni się jednocześnie, XP jest raportowane dla całego przedziału między snapshotami; moduł nie próbuje sztucznie przypisywać części XP do jednej cechy,
- XP otrzymane zanim GMCP poda nazwę postaci jest chwilowo buforowane i przypisywane po pojawieniu się `gmcp.Char.Name`.

## 0.69 — 2026-08-26

Dodano moduł formatowania i podsumowania cech postaci.

### Dodano
- `src/features/stats.lua`,
- formatowanie nagłówka postępów i wszystkich linii cech,
- automatyczne podsumowanie: Fiz, Ment, Odw i Łącznie,
- zapamiętywanie ostatniego pełnego odczytu cech w `chimera_vip.stats.last`,
- event `chimeraVipStatsUpdated` po zebraniu pełnego zestawu cech, przygotowany pod przyszłe integracje UI i historię.

### Zmieniono
- parser cech został przeniesiony do namespace ChimeraVIP i obsługuje hot reload bez dublowania triggerów,
- kolorystyka została dopasowana do pastelowego motywu ChimeraVIP,
- moduł jest ładowany przez `src/init.lua` i aktualizowany przez standardowy updater ChimeraVIP.

## 0.68 — 2026-08-26

Dodano tracker doświadczenia i wydajności expienia jako pełnoprawny moduł ChimeraVIP.

### Dodano
- `src/features/xp_tracker.lua`,
- łapanie własnych i drużynowych komunikatów zabicia z wartością XP,
- podsumowanie sesji, aktywnego czasu i wydajności XP/h,
- 10-minutowe tempo bieżące oraz trend względem poprzedniego okna,
- statystyki mobów, średnie XP/kill i ręczne reguły klasyfikacji,
- rozdzielenie XP zdobytego przez własne i drużynowe zabicia,
- wskazanie najbardziej dochodowego moba w podsumowaniu,
- `/xp mob <nazwa>` ze szczegółami wybranego typu przeciwnika,
- `/xp last [N]` z wyborem liczby ostatnich zabójstw,
- event `chimeraVipXpGained` dla przyszłych modułów UI i integracji.

### Zmieniono
- ręczne reguły mobów są przechowywane poza katalogiem aktualizowanym przez repozytorium w `getMudletHomeDir()/ChimeraVIP-data/xp_mobs.lua`,
- przy pierwszym uruchomieniu tracker automatycznie odczyta starszy plik `chimera_xp_mobs.lua` i przeniesie reguły do nowej lokalizacji,
- moduł jest ładowany przez `src/init.lua` i aktualizowany przez standardowy updater ChimeraVIP.

### Komendy XP
- `/xp` — podsumowanie sesji,
- `/xp mobs` — statystyki mobów,
- `/xp mob <nazwa>` — szczegóły moba,
- `/xp last [N]` — ostatnie N zabójstw,
- `/xp rules` — lista reguł,
- `/xp add nazwa#forma` — dodanie reguły,
- `/xp del nazwa` — usunięcie reguł,
- `/xp reset` — reset sesji.

## 0.67 — 2026-08-26

Pierwsza wersja repozytoryjna ChimeraVIP. Traktujemy ją jako punkt startowy dalszego wersjonowania.

### Dodano
- centralny namespace `chimera_vip` / `chimera_overlay`,
- bootstrap i kontrolowaną kolejność uruchamiania modułów,
- pastelowy motyw kompatybilny z oficjalnym UI Chimery,
- responsywny Quiet Footer,
- panel Vitals i EXP,
- kompas GMCP i wyjścia specjalne,
- auto-wsparcie z przełącznikiem,
- mini-przyciski do funkcji oficjalnego footera,
- mechanizm aktualizacji z GitHuba,
- loader lokalnych modułów,
- manifest wersji i listę plików aktualizatora,
- archiwalny pakiet prefixów obrażeń.

### Zmieniono
- kod został rozdzielony na moduły zamiast jednego dużego configu,
- wspólne funkcje pomocnicze przeniesiono do `src/core/util.lua`,
- moduły UI komunikują się przez eventy `chimeraVipReady`, `chimeraThemeReady` i `chimeraFooterReady`,
- updater pobiera pliki do stagingu i dopiero po kompletnym pobraniu podmienia lokalną instalację.

### Uwagi
- wersja rozwijana względem oficjalnych skryptów Chimera 2.6,
- `CHIMERA_damage_prefixes.xml` pozostaje na razie osobnym pakietem Mudleta i nie jest automatycznie instalowany przez loader,
- pierwsze uruchomienie wymaga jednorazowego dodania `loader.lua` jako trwałego skryptu w Mudlecie.
