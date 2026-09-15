# Kompletność migracji ChimeraVIP 2.0

Raport generowany przez `python3 tools/migration_audit.py report`.

To ewidencja zakresu, nie wynik testu gry. Każdy plik w `src/` i każda
definicja Mudleta wymagają osobnego wskazania odpowiednika i testów.
Foldery, definicje nieaktywne i zasoby także pozostają w spisie.

| Źródło | Pliki repozytorium | Pliki src | Definicje Mudleta (z folderami) |
|---|---:|---:|---:|
| official | 1774 | 1756 | 1799 |
| vip | 108 | 33 | 0 |

Ukończone pozycje: **0**. Nierozliczone: **3588**.

**Wydanie kompletnej migracji: ZABLOKOWANE.**

Nawet kompletna ewidencja nie potwierdza działania w Mudlecie ani zgodności z serwerem.
Istnienie pliku testu nie oznacza jego wykonania; za uruchomienie odpowiada CI.

## Definicje oficjalnej paczki

| Typ | Wszystkie | Foldery | Jawnie nieaktywne |
|---|---:|---:|---:|
| aliases.json | 408 | 41 | 0 |
| keys.json | 13 | 0 | 0 |
| scripts.json | 1 | 0 | 0 |
| timers.json | 2 | 1 | 1 |
| triggers.json | 1375 | 209 | 67 |

## Nierozliczone pliki oficjalnej paczki

| Katalog src | Pliki |
|---|---:|
| aliases | 345 |
| keys | 1 |
| resources | 477 |
| scripts | 1 |
| timers | 3 |
| triggers | 929 |

Szczegóły: `migration/official-inventory.json`, `migration/vip-inventory.json`.
Decyzje: `migration/decisions.json`. Brak decyzji oznacza pracę do wykonania,
a nie zgodę na usunięcie funkcji. Nie uruchomiono ani nie skopiowano kodu upstreamu.
