# Mapper samodzielnego VIP — pierwszy zakres

Implementacja: `standalone/mapper.lua`. Nadal jest to element deweloperskiej
gałęzi 2.0, nie gotowa instalacja całego VIP. Testy używają atrap API Mudleta;
nie potwierdzono działania na mapie i profilu gracza ani na żywym serwerze.

## Dostępne operacje

| Polecenie | Działanie |
|---|---|
| `/cvip2 mapa` | Otwiera natywne okno mapy i wypisuje stan lokalizacji. |
| `/cvip2 mapa odswiez` | Ponownie odczytuje przypisania z aktualnie załadowanej mapy; zatrzymuje trwający chodzik. |
| `/idz 123` | Wyznacza trasę do liczbowego ID pokoju Mudleta i rozpoczyna chodzik. |
| `/opoz 0.2` | Ustawia odstęp po potwierdzonym dojściu, przed kolejnym krokiem; zakres 0–60 sekund. |
| `/stop` | Anuluje ruch oczekujący na odpowiedź oraz zaplanowany następny krok. |

Domyślne opóźnienie wynosi 2 sekundy. Pierwsza komenda jest wysyłana od razu,
następne po potwierdzeniu i opóźnieniu. `/opoz` dotyczy kolejnych planowanych
odstępów; nie przestawia już utworzonego timera. Timeout pojedynczego ruchu wynosi
10 sekund. Odmowa bez zmiany lokacji kończy się timeoutem; nie ma ponawiania.

Ręczne polecenia ruchu oraz przyciski stopki aktualizują pozycję po odebraniu
`Room.Info`. Natywne wybranie celu na mapie korzysta z hooka `doSpeedWalk`, jeżeli
nie był już zajęty przez inny skrypt. W przeciwnym razie VIP pozostawia go bez
zmian, a jego własny chodzik jest dostępny przez `/idz`. Zatrzymanie VIP usuwa
własny hook i odtwarza poprzednią flagę `mudlet.mapper_script`.

## Istniejąca mapa i lokalizacja

Odczyt obejmuje natywne hashe Mudleta oraz `chimera_id` w danych pokoju mapy
importowanej. Klucz to 16 znaków szesnastkowych i opcjonalne `#numer` dla dodatniej
instancji. Instancja nie jest dopasowywana do pokoju bazowego. Hashe współrzędnych
nie są interpretowane jako ID Chimery. Wielkość liter w ID nie wpływa na wynik.

Powielone przypisania lub rozbieżne natywne ID i `chimera_id` wykluczają takie
przypisanie z lokalizacji. Mapper nie zgaduje po nazwie ani współrzędnych.
Indeks powstaje przy starcie. Po wczytaniu innej mapy lub zmianach przypisań
należy wykonać `/cvip2 mapa odswiez`.

Kod odczytuje mapę i przesuwa marker, ale nie zapisuje ani nie zmienia jej
pokoi, obszarów, wyjść, kolorów, współrzędnych, hashy i danych użytkownika.
Mapa musi być wcześniej załadowana w Mudlecie. Nie ma automatycznego importu
plików oficjalnej paczki. Przy braku przypisania wewnętrzna pozycja VIP jest
nieznana i chodzik odmawia startu; natywne okno może nadal pokazywać ostatni
znany marker. Aktualny stan jest dostępny przez `/cvip2 mapa` i `/cvip2 status`.

## Trasa i potwierdzenia

Trasa jest pobierana przez [API mappera Mudleta](https://wiki.mudlet.org/w/Manual:Mapper_Functions#getPath).
Wszystkie jej pokoje muszą mieć jednoznaczne przypisania, zanim zostanie wysłana
pierwsza komenda. Przed każdym krokiem sprawdzane jest bieżące wyjście z GMCP.
Handler i timeout istnieją przed wysłaniem, także gdy odpowiedź przychodzi
synchronicznie. Następny krok następuje dopiero po potwierdzeniu dokładnego
klucza pokoju i instancji; inna lokacja, utrata pozycji, timeout lub rozłączenie
zatrzymują chodzik. Tablice trasy Mudleta są kopiowane do własnego planu.

Wyjścia specjalne mogą być pojedynczą komendą obecną w bieżącym GMCP. Komendy
wieloczęściowe z separatorami, aliasy i skrypty zapisane jako specjalne wyjścia
nie są wykonywane. Definicje na mapie pozostają zachowane. To nie jest jeszcze
obsługa bram, transportów, odpoczynku, skradania ani automatycznego wznowienia.
Nie dodano numpada, skrótów nazwanych, rysowania nowych pokoi ani dopasowywania
nieprzypisanej mapy. Te ograniczenia nie oznaczają pełnej gotowości mappera 2.0.

## Weryfikacja automatyczna

`lua5.1 tools/mapper_test.lua` uruchamia pełny punkt startu z atrapami mapy.
Obejmuje stare hashe, `chimera_id`, konflikty, instancje, szybką odpowiedź GMCP,
kopię trasy, opóźnienie, brak potwierdzenia, nieoczekiwany ruch, stop, rozłączenie,
reload, błąd wysłania i cykl życia hooka mapy. Test nie łączy się z grą.
