# Kompletność migracji ChimeraVIP 2.0

Raport generowany przez `python3 tools/migration_audit.py report`.

Pierwsze wydanie: **obecne funkcje VIP + samodzielny mapper**.
Oficjalna Chimera pozostaje zainstalowana i wyłączona.

Pełny spis obu repozytoriów służy jako materiał odniesienia. Nie wymaga
przeniesienia całej oficjalnej paczki. Foldery, definicje nieaktywne
i zasoby pozostają w spisie, także jeśli nie należą do pierwszego wydania.

| Źródło | Pliki repozytorium | Pliki src | Definicje Mudleta (z folderami) |
|---|---:|---:|---:|
| official | 1774 | 1756 | 1799 |
| vip | 108 | 33 | 0 |

Ukończone pozycje: **0**. Nierozliczone: **3588**.

Powyższe liczby dotyczą pełnej ewidencji źródeł, a nie zakresu wydania 2.0.

## Gotowość pierwszego wydania

Nierozliczone pozycje VIP: **33**. Niepotwierdzone kryteria: **8**.

**VIP + mapper: NIEGOTOWE.**

Brak odpowiedników opcjonalnych funkcji oficjalnej Chimery nie blokuje tego zakresu.
Kryteria i dowody: `migration/scope.json`.

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
Decyzje: `migration/decisions.json`. Brak decyzji dla VIP oznacza pracę do wykonania.
Nierozliczone źródła oficjalne pozostają materiałem do selektywnego wykorzystania później.
Ten raport nie uruchamia ani nie kopiuje kodu upstreamu.
