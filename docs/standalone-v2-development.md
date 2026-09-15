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
- Integracja 18 plików istniejącego VIP: ustawienia, kolory walki, obrona,
  automatyczne wsparcie, XP i karty zabicia, statystyki i raporty, postacie,
  pojemniki, umiejętności, pachołki oraz ocena sprzętu. Lista źródeł znajduje się
  w `standalone/features.lua`; oryginalne pliki `src/` pozostają wspólne z 1.x.
- Własne przyciski `KOL` i `AS` w stopce oraz `/kolory on|off` i `/wsparcie on|off`.
  `/cvip` pokazuje pomoc samodzielnego zestawu.

Nie wdrożono jeszcze pełnego UI (okien drużyny i ustawień),
pełnych funkcji mappera, kompletnej migracji danych ani pełnej normalizacji i korelacji
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

## Integracja funkcji VIP

Moduły działają we wspólnym środowisku Lua 5.1, które rejestruje ich aliasy,
triggery, handlery i timery w cyklu życia wersji 2.0. Odczyty GMCP otrzymują
kopie stanu rdzenia, a powiadomienia trafiają do modułów po przetworzeniu pakietu.
Nie tworzymy globalnych zamienników `scripts`, `ateam` ani `amap`.
Wyłączanie nazwanych triggerów oficjalnej paczki nie jest wykonywane.
Stare callbacki i linki konsoli tracą możliwość wykonania po zatrzymaniu lub reloadzie.

Zapis odbywa się w katalogu profilu `ChimeraVIP-v2/`, z zachowaniem wewnętrznych
nazw plików modułów (np. `ChimeraVIP-v2/ChimeraVIP-data/settings.lua`). Jeśli
nowego pliku jeszcze nie ma, odczyt może skorzystać z danych VIP 1.x. Oryginały
nie są nadpisywane. Błąd odczytu zatrzymuje start i dalsze zapisy. Podmiana pliku
korzysta z pliku tymczasowego; na systemach odmawiających nadpisania przez rename
poprzednia wersja zostaje w `.bak`. Nie jest to importer danych oficjalnej Chimery.

XP korzysta z istniejących komunikatów tekstowych. Wzbogacanie karty zabicia
przez niepowiązane zdarzenie `Combat.Kill` i stary cache obiektów jest pominięte
do wdrożenia korelacji z sesją i nagrodą. Lampa, automatyczne zbieranie i inne
akcje oficjalnej stopki nadal nie są udostępnione.

## Uruchomienie przez programistę

1. Pobierz checkout aktualnej gałęzi integracyjnej 2.0 do osobnego katalogu.
2. Użyj osobnego testowego profilu Mudleta, z GMCP włączonym i bez uruchomionych oficjalnych skryptów oraz VIP 1.x. Profil używany do gry pozostaje bez zmian.
3. Uruchom lokalny punkt startu, podając rzeczywistą ścieżkę checkoutu (przykład Windows):

```lua
lua assert(loadfile([[C:/projekty/ChimeraVIP/standalone/init.lua]]))([[C:/projekty/ChimeraVIP]])
```

Uruchom przed połączeniem. Przy starcie w istniejącej sesji rdzeń czeka na następny obsługiwany pakiet GMCP, zamiast uznawać globalny cache za świeże dane. `/cvip2 stop` usuwa również alias diagnostyczny; ponowny start wymaga powyższej komendy. Stop nie zmienia subskrypcji serwera ani globalnego cache GMCP, żeby nie odłączać cudzych odbiorców.

Gałąź `standalone-v2` jest bazą prac 2.0. Pierwszy PR kieruje do niej gałąź `migration/v2-foundation`. Stabilne `loader.lua`, `manifest.lua`, `VERSION` i aktualizator nadal dotyczą 1.x. Nie używaj stabilnego instalatora do instalacji tego prototypu. Nie ma jeszcze automatycznego kanału aktualizacji 2.0.

## Następne kroki

- E0: inwentaryzacja prywatnego profilu i potwierdzona procedura wyłączania oficjalnego startu.
- E1/E2: pełny model stanu i testy sesji/postaci/instancji na nagranych pakietach.
- E3: okno drużyny i ustawień, dopracowanie mappera oraz osobna paczka instalacyjna 2.0.

## Testy

```sh
lua5.1 tools/standalone_test.lua
lua5.1 tools/standalone_ui_test.lua
lua5.1 tools/mapper_test.lua
lua5.1 tools/features_test.lua
lua5.1 tools/sequences_test.lua
python3 tools/migration_audit.py check
python3 tools/migration_audit_test.py
```

Testy używają atrap Mudleta. Nie zastępują testu połączenia, instalacji i zachowania profilu z zainstalowaną, wyłączoną Chimerą. Cały kod pierwszego etapu jest własny; nie skopiowano kodu oficjalnej paczki.
Test integracji ładuje rzeczywiste moduły i wywołuje ich zarejestrowane callbacki,
ale podstawia `matches`; nie uruchamia silnika PCRE Mudleta.
