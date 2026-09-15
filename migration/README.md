# ChimeraVIP samodzielnie + mapper

Po zawężeniu zakresu przez użytkownika pierwsze wydanie obejmuje obecne funkcje
VIP 0.127 oraz mapper. Pozostałe mechanizmy oficjalnej paczki są opcjonalnym
zakresem na później; nie ma obowiązku skopiowania ich wszystkich. Oficjalna
paczka ma pozostać zainstalowana i wyłączona. Użytkownik nie
ma możliwości wykonywania testów etapowych; regresje i odtwarzanie komunikatów
sprawdzamy automatycznie. Obecny kod **nie jest jeszcze kompletnym zamiennikiem**.

## Zakres pierwszego wydania

| Teraz | Później, według potrzeb |
|---|---|
| Samodzielny start, GMCP, własne podstawy UI i stopka | Dodatkowe mechanizmy oficjalnego UI |
| Obecne funkcje VIP: ocena sprzętu, XP, cechy, postacie, kolory, defensywa, wsparcie i pozostałe moduły src | Pełna automatyzacja ekwipunku, lampa, zbieranie, naprawy |
| Wyświetlanie mapy, lokalizacja GMCP, poruszanie i chodzik `/idz`, `/opoz`, `/stop` | Transporty, zielarstwo, banki, poczta, wędkarstwo i inne dodatki |
| Zachowanie istniejącej mapy, jej identyfikatorów i metadanych oraz danych VIP | Rozszerzone narzędzia mapowania i edycji do osobnej oceny |

To zakres prac, nie deklaracja już działających funkcji. Własne usługi mogą
zastępować stare mechanizmy; zachowujemy potrzebne zachowania VIP. Nie tworzymy
pełnego odpowiednika całej oficjalnej paczki. Dla mappera przenosimy tylko
wymagane zależności. Definicje i metadane istniejących wyjść specjalnych także
podlegają zachowaniu i sprawdzeniu; nie oznacza to portu automatyki transportów.

## Inwentaryzacja

`official-inventory.json` i `vip-inventory.json` powstają z obiektów Git dokładnie
określonych rewizji. Obejmują wszystkie śledzone pliki, sumy SHA-256, rozmiary,
tryby plików oraz wszystkie definicje Mudleta, także foldery, wyłączone elementy,
triggery kolorujące i aliasy mające samo polecenie. Identyfikator JSON Pointer
rozróżnia definicje o identycznych nazwach. Nie zapisujemy kodu upstreamu.

Spis nie obejmuje prywatnego profilu gracza ani późniejszych zmian upstreamu.
Wskazanie skryptu w definicji to metadane do analizy: nie emuluje dziedziczenia
aktywności folderów ani zachowania Muddlera. Nie jest analizą osiągalności kodu.

Odtworzenie spisu, niezależne od lokalnych niezacommitowanych zmian:

```sh
python3 tools/migration_audit.py snapshot --official /katalog/chimera-mud-skrypty
python3 tools/migration_audit.py report > docs/standalone-v2-coverage.md
```

`inventory-lock.json` wykrywa przypadkowe zmiany spisu w CI. Regeneracja wymaga
dostępności przypiętych commitów w lokalnych kopiach Git. Samo sprawdzanie działa
offline, bez połączenia z grą, GitHubem ani GitLabem.

## Rozliczanie przeniesienia

Każdy plik `src/` obu paczek oraz każda definicja Mudleta ma osobną pozycję w
ewidencji. W pierwszym wydaniu wymagamy rozliczenia pozycji VIP i ośmiu kryteriów
w `scope.json`. Nierozliczone pozycje oficjalnej paczki nie blokują wydania.
Pliki testów, dokumentacji i narzędzi spoza `src/` pozostają w spisie
źródeł, ale nie są liczone jako funkcje gry. Kilka pozycji może być zastąpionych
przez jeden moduł VIP; każda musi wskazywać ten moduł w `decisions.json`:

```json
{
  "id": "official:file:src/przyklad.lua",
  "source_sha256": "suma-z-inwentaryzacji",
  "status": "replaced",
  "reason": "Opis zachowanego zachowania i jego odpowiednika",
  "targets": ["standalone/przyklad.lua"],
  "tests": ["tools/przyklad_test.lua"]
}
```

Dozwolone stany ukończone: `ported`, `replaced`. Brak decyzji, odłożenie lub
usunięcie funkcji nie oznacza ukończenia. Nie rozliczamy całych katalogów jednym
wpisem. Źródło musi mieć aktualną sumę, a pliki implementacji i testów istnieć.
To warunki ewidencyjne: przegląd implementacji nadal musi potwierdzić zachowanie,
a CI wykonać testy. Samo istnienie testu nie dowodzi poprawności.

```sh
python3 tools/migration_audit.py check
python3 tools/migration_audit.py release-gate
```

`check` sprawdza spójność ewidencji i zakresu. `release-gate` zwraca kod błędu,
jeśli istnieją nierozliczone pozycje VIP albo niepotwierdzone kryteria pierwszego
wydania z `scope.json`. Kryterium `verified` wymaga wskazania istniejącego pliku
z dowodami; ich treść podlega przeglądowi. Brak portu opcjonalnego mechanizmu
oficjalnego nie jest błędem. To narzędzie kontroli zakresu, nie instalator ani
mechanizm publikowania paczki.

## Automatyczna weryfikacja zamiast testowania etapów przez użytkownika

- Lua 5.1: istniejące regresje VIP, własny start i zasoby, GMCP oraz potwierdzane
  sekwencje poleceń. Testy nie łączą się z serwerem i nie wysyłają komend do gry.
- Python 3.10+: sprawdzenie inwentaryzacji, wykrywanie pominięć i błędnych decyzji,
  zgodność raportu ze źródłami, odczyt przypiętych commitów mimo brudnego checkoutu.
- Kolejne porty wymagają testów odtworzonych zdarzeń, ich kolejności, rozłączeń,
  anulowania, wielokrotnego reloadu oraz zachowania danych użytkownika.

## Odbiór pierwszego wydania

Odbieramy paczkę 2.0 obejmującą obecne funkcje VIP oraz mapper, działającą bez
uruchomionej oficjalnej Chimery. Transporty i inne opcjonalne dodatki nie są
warunkiem odbioru. Szczegóły architektury i etapów:
`docs/standalone-v2-plan.md`. Każdy wybrany port musi obejmować
potrzebne definicje Mudleta, zasoby i ustawienia, nie tylko funkcje Lua.

Przed uznaniem wersji za gotową wymagane są: rozliczony zakres VIP + mapper, przejście testów,
instalowalny artefakt, sprawdzony start w prawdziwym Mudlecie bez wykonania Chimery,
przeniesienie danych bez ich nadpisywania oraz sprawdzona procedura powrotu.
Testy na atrapach nie potwierdzają wyglądu Geysera, rzeczywistej instalacji,
mapy gracza ani zachowania serwera. Brak tego potwierdzenia musi być widoczny
w opisie wydania; nie oznaczamy go jako zaliczonego i nie wymagamy od użytkownika
testowania kolejnych PR-ów. Prywatne skrypty, których nie ma w repozytoriach,
pozostają poza potwierdzonym zakresem do czasu uzyskania ich źródeł.
