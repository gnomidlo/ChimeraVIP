# Changelog

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
