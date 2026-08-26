# Changelog

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
