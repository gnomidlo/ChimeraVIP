# AutoExp 5 — nowy silnik dla Chimery 5.x

Wtyczka `chimera_autoexp` zastępuje stary AutoExp 0.4x napisany dla `amap` i zdarzeń `amapWalker*`. Nie modyfikuje oficjalnych skryptów ani ChimeraVIP. Bazuje na publicznych modułach `gmcp`, `mapper`, `walker` Chimery 5 i zdarzeniach `chimera.*`.

## Instalacja testowa (ręczna i odwracalna)

1. Zrób kopię profilu Mudleta oraz swojej starej bazy `ChimeraVIP-data/autoexp.lua` (lub `autoexp_areas.lua`).
2. **Wyłącz starą grupę EXP z XML w Mudlecie** — oba systemy używają komend `/exp`. Nie usuwaj danych.
3. Skopiuj cały folder `chimera_autoexp` do `<katalog profilu Mudleta>/chimera_wtyczki/`, aby istniał plik `chimera_wtyczki/chimera_autoexp/init.lua`.
4. W działającej Chimerze 5 wykonaj `/przeladuj` (lub uruchom profil ponownie). Sprawdź `/wtyczki` i `/exp`.
5. Jednorazowo wykonaj `/exp import`, aby **skopiować** profile ze starej bazy. Import nie zmienia źródłowego pliku. Dopiero po inspekcji profilu przetestuj `/exp test`.

To wersja **beta**. Nie należy zostawiać postaci bez nadzoru, zwłaszcza gdy grozi walka lub utrata połączenia. Konfiguracja nie włącza automatu — trzeba ręcznie wpisać `/exp start`.

## Podstawowe komendy

`/exp`, `/exp status`, `/exp pomoc` — stan i komendy. `/exp obszary` — lista.

`/exp mapuj Bagna` — start mapowania, ponowienie tej samej komendy kończy i scala trasę. `/exp mapuj! Bagna` — tworzy trasę od nowa przy zapisie. `/exp mapuj-` — anulowanie.

`/exp wybierz Bagna` — aktywny teren, `/exp cel snotling` — dopisz fragment nazwy celu, `/exp cel- snotling` — usuń cel, `/exp unikaj boss` oraz `/exp unikaj- boss` — dodaj lub usuń wyjątek, `/exp bezpieczna` — zapamiętaj bieżącą bezpieczną lokację, `/exp hp 35 85` — odwrót/powrót, `/exp limit 3` — maksymalna liczba obcych NPC w pokoju, `/exp odnowa 60` — czas, po którym ponownie odwiedzamy oczyszczoną lokację.

`/exp test` — **tylko jedna decyzja, bez ruchu i bez ataku**; `/exp start` — uruchomienie patrolu, `/exp pauza`, `/exp wznow`, `/exp stop` — sterowanie.

## Import

Czyta, wyłącznie na żądanie, stare dane `ChimeraVIP-data/autoexp.lua`, a jeśli pliku nie ma — `autoexp_areas.lua`. Wymaga pustej nowej bazy. Przenosi nazwy profili, trasę GMCP ID, cele, wyjątki, lokację bezpieczną i podstawowe progi (`retreatHP`, `returnHP`, `maxEnemies`, `minRoomRevisit`). Własna baza wtyczki trzymana jest przez `ctx:saved()` w `Database_settings.db` oficjalnej Chimery.

Nie importuje danych starego panelu handlowego, rejestrowanych opisów lokacji, parametrów sprzedaży, ani dopelniaczy (komendy `zabij <GMCP ID>` nie wymagają odmiany). Dane oryginalne pozostają na dysku, aby można było wrócić do starego modułu.

## Co działa w wersji beta

- Mapowanie odwiedzonej trasy po `Room.Info.id`, bez zależności od `amap`.
- Patrol kolejnych dostępnych punktów na mapie, z minimalnym odstępem ponownych odwiedzin i bez nieograniczonej liczby wywołań `getPath()` na każdy pakiet.
- Weryfikacja, że `Chimera.Room.Entities.room == Room.Info.id`, przed wyborem celu; zakaz ataku na graczy i sojuszników/pachołków.
- Wysyłanie `zabij <entity.id>`; jeden atak na ID w tej samej lokacji, oczekiwanie na `Combat.State`.
- Detekcja członków drużyny, kondycji postaci i towarzyszy, walki, zbyt wielu NPC oraz cudzych walk PvE.
- Pochodzenie mapowania, chodzika i zdarzeń z nowej oficjalnej Chimery. Nie nadpisuje globalnych `doSpeedWalk` ani `amap`.
- Stany OFF, READY, MOVING, ENGAGING, COMBAT, POST_COMBAT, WAIT_ENTITIES, RECOVERY, COOLDOWN, PAUSED, RETREAT. Wstrzymanie po niezapowiedzianym przerwaniu chodzika, utracie członka drużyny, ręcznym ruchu, braku synchronizacji GMCP i rozłączeniu.

## Ograniczenia świadome

- **Nie ma jeszcze handlu, bankowania, sprzedaży ani zbierania łupów** — stary moduł handlowy zależał od nieistniejących już API. Wznowienie tych operacji wymaga osobnego, potwierdzanego potwierdzeniami serwera modułu.
- **Nie ma jeszcze panelu Geyser**; komendy są dostępne, ale nowe UI Chimery 5 powinno być rozbudowywane przez publiczne API wtyczek, nie przez `scripts.ui` starego upstream.
- **Podczas trwającej walki przy niskim HP wtyczka pauzuje i wymaga interwencji.** Oficjalny chodzik sam przerywa ruch podczas walki; nie zakładamy, że próba `walker.go(safeRoom)` oznacza skuteczny odwrót z aktywnej walki. Po walce, przy niskim HP poza bezpieczną lokacją, idzie do bezpiecznej lokacji za pomocą oficjalnego chodzika.
- **Zmiana instancji z identycznym Room.Info.id:** obecny profil opiera się na identyfikatorze lokacji, tak jak oficjalny mapper. Instancje o tym samym ID mogą wymagać osobnej polityki.
- Nie ma ponawiania ataku na tę samą encję w jednym pokoju. Przy błędzie komendy lub uciekającym przeciwniku pomija ją do następnej wizyty.
- Zewnętrzny chodzik uruchomiony przed załadowaniem wtyczki może nie być wykryty; odpalaj automat dopiero po zakończeniu ręcznej trasy.

## Weryfikacja

Test lokalny bez Mudleta: `lua tests/autoexp5_mock.lua`. Przechodzi składnię oraz symulowane scenariusze importu, mapowania, potwierdzenia ataku, priorytetu walki, ochrony niskiego HP, zatrzymania ruchu i rozłączenia. **Testy symulacyjne nie oznaczają walidacji w prawdziwej sesji gry.**