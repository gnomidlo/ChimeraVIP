# ChimeraVIP 2.0 — pierwszy etap

Status: **szkielet deweloperski 2.0.0-dev.1, nie paczka do codziennej gry**.

Plan: [standalone-v2-plan.md](standalone-v2-plan.md).

Aktualny cel pierwszego wydania: **obecne funkcje VIP + mapper przy wyłączonej
oficjalnej Chimerze**. Pozostałe oficjalne mechanizmy są opcjonalne. Pełny spis
źródeł pozostaje materiałem odniesienia; nie wymaga już przeniesienia całości.
Kryteria gotowości określa `migration/scope.json`. To zmiana zakresu prac,
nie informacja o wdrożeniu mappera lub przepięciu wszystkich modułów VIP.

## Co działa w tym etapie

- Osobny punkt startu, bez oficjalnego loadera, UI i aktualizatora 1.x.
- Rejestr zasobów: handlery, aliasy, timery i funkcje sprzątające; unieważnianie starych callbacków.
- Własne subskrypcje GMCP oraz kopie odebranych pakietów postaci, lokacji, obiektów, grupy i walki.
- Reset przy rozłączeniu, obsługa ponownego ładowania i odrzucanie niepasujących pokojem danych w publicznym odczycie walki.
- Diagnostyka `/cvip2 status`, przeładowanie `/cvip2 reload`, zatrzymanie `/cvip2 stop`.
- Wspólna usługa sekwencji: oczekiwanie przed wysłaniem polecenia, potwierdzenie,
  anulowanie, timeout i reset sesji. Nie jest jeszcze podłączona do modułów gry.
- Pełna [inwentaryzacja migracji](standalone-v2-coverage.md) obu repozytoriów
  oraz [zasady automatycznej weryfikacji](../migration/README.md).
- Własna stopka na natywnych etykietach Mudleta: kondycja, siły, mana, sytość,
  woda, obciążenie, postęp i nazwa lokacji. Przyciski obejmują kierunki oraz
  maksymalnie dwa inne wyjścia (pozostałe nadal dostępne jako polecenia gry).
  Brak danych jest oznaczany kreską; wartości po rozłączeniu są czyszczone.
  Stopka korzysta wyłącznie ze stanu odebranego przez runtime VIP.
- Pierwsza obsługa [mappera i chodzika](standalone-v2-mapper.md): istniejąca mapa,
  lokalizacja przez hash/`chimera_id`, `/idz`, `/opoz`, `/stop` oraz natywne okno mapy.

Nie wdrożono jeszcze pełnego UI (okien drużyny, ustawień i kontrolek funkcji),
pełnych funkcji mappera, modułów VIP, ekwipunku, importu danych ani pełnej normalizacji i korelacji
GMCP. Stopka nie jest kopią całego dotychczasowego HUD: nie zawiera segmentowych
pasków, licznika obrotów EXP ani stanu upojenia. Odbiór `Combat.Kill` nie jest
jeszcze usługą korelacji nagród XP. Flaga gotowości oznacza gotowość rdzenia;
status stopki jest wyświetlany osobno. Przy brakującym API etykiet (np. w testach
bez interfejsu) rdzeń działa i podaje nazwę brakującej funkcji.

Stopka używa [natywnego API UI Mudleta](https://wiki.mudlet.org/w/Manual:UI_Functions).
Nie ładuje oficjalnych okien ani Geysera. Własne etykiety i callbacki należą do
rejestru zasobów VIP. Zatrzymanie zwalnia etykiety i odtwarza dolny margines,
jeśli w międzyczasie nie zmieniła go inna paczka. Testy sprawdzają zachowanie API
na atrapach; wyglądu w prawdziwym Mudlecie jeszcze nie zweryfikowano.

## Uruchomienie przez programistę

1. Pobierz checkout gałęzi z pierwszym PR-em 2.0 do osobnego katalogu.
2. Użyj osobnego testowego profilu Mudleta, z GMCP włączonym i bez uruchomionych oficjalnych skryptów oraz VIP 1.x. Profil używany do gry pozostaje bez zmian.
3. Uruchom lokalny punkt startu, podając rzeczywistą ścieżkę checkoutu (przykład Windows):

```lua
lua assert(loadfile([[C:/projekty/ChimeraVIP/standalone/init.lua]]))([[C:/projekty/ChimeraVIP]])
```

Uruchom przed połączeniem. Przy starcie w istniejącej sesji rdzeń czeka na następny obsługiwany pakiet GMCP, zamiast uznawać globalny cache za świeże dane. `/cvip2 stop` usuwa również alias diagnostyczny; ponowny start wymaga powyższej komendy. Stop nie zmienia subskrypcji serwera ani globalnego cache GMCP, żeby nie odłączać cudzych odbiorców.

Gałąź `standalone-v2` jest bazą prac 2.0. Pierwszy PR kieruje do niej gałąź `migration/v2-foundation`. Stabilne `loader.lua`, `manifest.lua`, `VERSION` i aktualizator nadal dotyczą 1.x. Nie używaj stabilnego instalatora do instalacji tego prototypu. Nie ma jeszcze automatycznego kanału aktualizacji 2.0.

## Następne kroki

- E0: inwentaryzacja prywatnego profilu i potwierdzona procedura wyłączania oficjalnego startu.
- E1/E2: rozszerzenie rejestru na moduły użytkowe, pełny model stanu i testy sesji/postaci/instancji na nagranych pakietach.
- E3: rozszerzenie własnej stopki, okna drużyny i przepięcie obecnych widoków VIP.

## Testy

```sh
lua5.1 tools/standalone_test.lua
lua5.1 tools/standalone_ui_test.lua
lua5.1 tools/mapper_test.lua
lua5.1 tools/sequences_test.lua
python3 tools/migration_audit.py check
python3 tools/migration_audit_test.py
```

Testy używają atrap Mudleta. Nie zastępują testu połączenia, instalacji i zachowania profilu z zainstalowaną, wyłączoną Chimerą. Cały kod pierwszego etapu jest własny; nie skopiowano kodu oficjalnej paczki.
