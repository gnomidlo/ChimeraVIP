# ChimeraVIP — plan kompletnego uniezależnienia

Data analizy: 15 września 2026 r.

**Aktualizacja zakresu po decyzji użytkownika:** pierwsze wydanie to obecne
funkcje ChimeraVIP + mapper, przy zainstalowanej i wyłączonej oficjalnej Chimerze.
Pełne zastępowanie oficjalnej paczki nie jest już celem wydania. Pozostałe
mechanizmy dodajemy selektywnie później. Obowiązujący zakres i kryteria:
[migration/README.md](../migration/README.md), `migration/scope.json`.
Poniższa analiza wszystkich podsystemów pozostaje materiałem odniesienia;
etapy opcjonalne nie blokują pierwszego wydania.

Dokument rozdziela ustalenia wynikające z kodu od proponowanego sposobu migracji. Propozycje architektury, priorytety i kryteria odbioru są rekomendacją, a nie opisem już wdrożonych funkcji.

## 1. Cel i zakres

ChimeraVIP ma uruchamiać się i obsługiwać grę bez wykonywania kodu oficjalnej paczki Chimera. Oficjalna paczka pozostaje zainstalowana, z zachowanymi plikami i danymi, ale jest wyłączona. Powrót do poprzedniej konfiguracji ma być możliwy po odtworzeniu zapisanych ustawień i restarcie profilu.

Warunek niezależności: VIP nie potrzebuje oficjalnego loadera, UI, globalnych tabel, funkcji, subskrypcji GMCP, aliasów, triggerów, timerów ani zasobów odczytywanych z katalogu oficjalnej paczki. Korzystanie z GMCP wysyłanego przez serwer Chimera oraz wbudowanych możliwości Mudleta nie jest zależnością od oficjalnych skryptów.

Rozróżniamy dwa wyniki:

- **Samodzielność techniczna:** VIP działa przy całkowicie nieuruchomionej oficjalnej paczce.
- **Kompletność pierwszego wydania:** obecne funkcje VIP i mapper działają samodzielnie. Pełna inwentaryzacja oficjalnej paczki jest materiałem odniesienia, nie listą obowiązkowych portów. Użytkownik dopuścił wycinanie starych mechanizmów i sukcesywne dodawanie reszty; nie oznaczamy funkcji odłożonych jako już wdrożonych.

Ten dokument jest planem. Nie wprowadza zmian w kodzie repozytoriów, ustawieniach Mudleta ani konfiguracji użytkownika.

## 2. Podstawa analizy

Pobrano świeże kopie obu repozytoriów przez Git i przeanalizowano kod zależności, listy ładowania, definicje aliasów/triggerów/klawiszy oraz konfigurację testów.

| Repozytorium | Badany commit | Wersja w źródłach |
|---|---|---|
| ChimeraVIP | `a5e5951661ec53295663587769057cc25c5b867f` | 0.127 |
| Oficjalna Chimera | `2e6c3372220483b4e70b3f5cb24a4777437d5c6c` | 4.4 |

Commit VIP pochodzi z 15 września, oficjalny z 4 września 2026. Są to odczytane przy analizie końcówki odpowiednich repozytoriów. Pole `tested_upstream` w VIP nadal wynosi 4.3; nie jest to potwierdzenie testów na 4.4.

W porównaniu z wcześniejszą analizą VIP 0.113 nowe źródła obejmują m.in. prezentację karty zabicia, kompaktowe cechy, zmiany umiejętności i pachołków. Główne pliki zależne od oficjalnego UI i runtime nadal mają te same hashe w manifeście.

Ograniczenia: wykonano analizę statyczną, nie test w działającym Mudlecie. Nie odczytano prywatnego profilu gracza, jego dodatkowych pakietów, własnych aliasów, mapy ani aktualnych transmisji z serwera. Nie porównywano empirycznie stabilności obu paczek.

## 3. Potwierdzone zależności

| Obszar VIP | Dowód w kodzie | Konsekwencja dla migracji |
|---|---|---|
| `src/theme/pastel.lua` | Dziedziczenie po `scripts.ui.themes.plain`, wywołanie `scripts.ui:setup()` i stylowanie istniejących okien | Motyw wymaga własnego właściciela UI. |
| `src/ui/quiet_footer.lua` | Rodzic `scripts.ui.bottom`; ustawienia szerokości i wysokości oficjalnej stopki | Własne utworzenie kontenera, marginesów, rozmiarów i cyklu odbudowy. |
| `src/ui/settings_apply.lua` | Zapis `scripts.ui.states_font_size` | Przekierowanie ustawień do okien VIP. |
| `src/ui/footer_controls.lua` | Odczyty `ateam`, `amap`, `scripts.inv`, `scripts.character`, `scripts.ui` | Każda kontrolka potrzebuje własnego modelu stanu i akcji. |
| `src/integrations/runtime.lua` | Delegowanie kliknięć do `scripts_ui_info_*`; lokacja ma fallback `gmcp.room.info` | Adapter musi udostępniać własne usługi, nie obudowywać oficjalne funkcje. |
| `src/integrations/chimera.lua` | Włączanie/wyłączanie oficjalnego `gags` | W trybie samodzielnym wyłączyć tę integrację; KOL OFF nie może uruchamiać oficjalnych gagów. |
| `src/core/bootstrap.lua` | Odczyty wersji upstreamu i nasłuch `scriptsLoaded` | Rdzeń już może zgłosić gotowość z `src/init.lua`, ale gotowość usług trzeba oddzielić od samego załadowania plików. |
| Auto-wsparcie i defensywa | Nasłuch natywnego GMCP Chimery | Własna subskrypcja, reset sesji i spójny stan danych. |
| `src/features/xp_tracker.lua` | Grupa z `Chimera.Group.State` lub `Chimera.Room.Entities`, fallback `gmcp.objects.data`, kontekst z `Chimera.Combat.Kill` | XP także wymaga objęcia własnym modelem GMCP; samo zachowanie triggerów tekstowych nie wystarczy dla wszystkich funkcji. |

W kodzie VIP nie znaleziono własnego wysyłania subskrypcji przez `sendGMCP`. Oficjalne `skrypty/team/core.lua` zgłasza m.in. `Chimera.Group 1`, `Chimera.Room.Entities 1` i `Chimera.Combat 1`. Czytanie już obecnych tabel GMCP w aktywnej sesji nie sprawdza samodzielnej negocjacji po nowym połączeniu.

Oficjalne okna kondycji, mapper, chodzik, operacje na torbach, zbieranie i lampa nie mają pełnych odpowiedników w obecnym manifeście VIP. Własne formatowanie ekwipunku i pojemników jest warstwą prezentacji, nie kompletną obsługą operacji na przedmiotach.

## 4. Architektura docelowa — propozycja

Właścicielem działania jest `chimera_vip`. Moduły gry nie powinny czytać ani modyfikować `scripts`, `ateam` lub `amap`.

Proponowane usługi:

- `lifecycle`: rejestr zasobów modułów i kontrolowany start/stop/reload;
- `protocol`: negocjacja GMCP i odbiór pakietów;
- `state`: ujednolicony stan postaci, pokoju, obiektów, drużyny i walki;
- `actions`: wykonywanie poleceń, wybór celu i sprawdzanie aktualności celu;
- `sequences`: oczekiwanie na odpowiedź, timeouty i anulowanie operacji;
- `ui`: własne kontenery, okna kondycji, stopka, mapa i ustawienia;
- `mapper`, `team`, `inventory`, `transport`: niezależne podsystemy użytkowe;
- opcjonalna, jawna warstwa zgodności dla rozpoznanych prywatnych skryptów.

Nazwy są projektowe, nie istniejącym API. Nie proponuje się tworzenia pustych atrap całego `scripts`, `ateam` i `amap`. Kod przenoszony z oficjalnych źródeł ma być dostosowany do usług VIP wraz ze wszystkimi wymaganymi definicjami i testami.

Wspólny rejestr ma przechowywać ID wszystkich timerów, handlerów, triggerów, aliasów, klawiszy i okien każdego modułu. `stop()` zwalnia zasoby i unieważnia oczekujące callbacki; ponowny `start()` nie tworzy dodatkowej kopii tego samego działania. Samo stosowanie `pcall` nie jest kryterium poprawności — błąd ma trafić do diagnostyki z nazwą modułu.

## 5. Decyzje: zachować, adaptować, napisać

Tabela przedstawia możliwości adaptacji. Do pierwszego wydania należą VIP,
własny GMCP/UI, mapper oraz ich konieczne zależności. Pełny ekwipunek użytkowy,
transport, zioła i pozostałe dodatki są opcjonalne i nie wymagają teraz portu.

| Podsystem | Proponowane działanie | Zakres źródeł oficjalnych / zależności |
|---|---|---|
| Pomoc, konfiguracja, aktualizator VIP | Zachować i rozszerzyć | Manifest, kontrola integralności, osobne dane użytkownika; dodać migracje schematów i status samodzielności. |
| Ocena sprzętu, widoki, cechy, postacie, kolory, defensywa | Zachować | Sprawdzić start bez upstreamu, wyłączanie, reload i brak podwójnego formatowania. |
| XP i prezentacja pachołków | Zachować | XP podłączyć do własnego stanu grupy i zdarzeń zabicia; nie traktować prezentacji pachołków jako pełnej automatyzacji dowodzenia. |
| GMCP | Napisać własną usługę; adaptować reguły walidacji | `skrypty/team/chimera_gmcp.lua`, `team/core.lua`, `character/chimera_vitals.lua`, `mapper/gmcp_compat.lua`. |
| UI | Zachować wygląd VIP, napisać własne podstawy i kondycje | Oficjalne `ui/themes/plain.lua`, `skrypty/ui/states_window/*` są referencją funkcji; nie kopiować całego UI. |
| Mapper i chodzik | Adaptować wybrany spójny zestaw wraz z testami | `mapper/chimera_map.lua`, `chimera_reconcile.lua`, `walker.lua`, `walk_cmd.lua`, core/map/room/dirs/path/shortcuts, gates/pausers i wymagane usługi. |
| Drużyna i cele | Własny model, adaptacja potrzebnych akcji | `skrypty/team/*`, `people/bind_attack_gmcp.lua`; zachować jedno auto-wsparcie VIP. |
| Ekwipunek użytkowy | Adaptować logikę, usunąć zależność od UI upstreamu | `skrypty/inventory/*`, torby, broń, zbieranie, lampa, wyposażenie, naprawy i trwałość. |
| Bindy i sekwencje | Własna wspólna usługa | `keybind/*`, `multibinds.lua`, `utils/temp_binds.lua`, `command_sequence.lua`; zachować potrzebne skróty użytkowe. |
| Transport | Adaptować silnik, definicje i testy | `skrypty/transport/*`, definicje JSON, wejście/wyjście, oczekiwanie i podążanie drużyny. |
| Zioła | Osobny moduł VIP | `skrypty/herbs/*`, baza i jej format, pojemniki, efekty, używanie, UI. |
| Pozostałe funkcje | Portować w wydzielonych modułach | Handel i pieniądze, banki, NPC, rozmowy i poczta, książki/biblioteki/wiedza, żywność, wędkarstwo, alarmy, skrypty lokacyjne. |

To lista podsystemów do adaptacji, nie gotowa lista plików do skopiowania. Dla każdego portu trzeba domknąć zależności: funkcje pomocnicze, dane, assety, definicje JSON, zdarzenia i timery. Przykład: oficjalna lampa używa nazwanego timera `lamp_info_timer` i triggerów spoza swojego pliku Lua.

## 6. Etapy realizacji i odbiór

Pierwsze wydanie obejmuje E0–E4, niezbędną dla obecnego VIP część E5 oraz E9.
E6–E8 to zakres późniejszy. Te etapy nie blokują samodzielnego VIP z mapperem.

### E0 — inwentaryzacja migracyjna i punkt powrotu

Przygotować rejestr funkcji na podstawie `scriptsList.lua` oraz drzew `aliases`, `triggers`, `keys`, `timers`. Każda funkcja otrzymuje: starą komendę/bind, zależności, dane użytkownika, odpowiednik VIP, etap oraz test odbioru. Uwzględnić komendy pośrednio wywoływane przez inne aliasy i callbacki mapy.

Z profilu użytkownika odczytać listę pakietów i modułów, ich sposób startu, własne pluginy i bindy. Zapisać stan włączenia oficjalnych elementów, kopię profilu, mapy i konfiguracji. Nie przenosić haseł do raportów. Testy migracji wykonywać w kopii profilu.

Zweryfikować pochodzenie i warunki licencji plików przeznaczonych do kopiowania. README oficjalnego repo deklaruje zachowanie licencji Arkadii; osobnego pliku LICENSE nie znaleziono w badanych drzewach. Sam publiczny dostęp do repo nie rozstrzyga warunków redystrybucji.

**Odbiór:** istnieje rejestr zakresu i kopia przywracania; żadna funkcja nie jest pomijana przez brak wpisu.

### E1 — samodzielny start i zarządzanie zasobami

Dodać jawny tryb samodzielny oraz rejestr zasobów. W tym trybie VIP nie wywołuje `scripts.ui:setup()`, nie przełącza oficjalnego `gags`, nie uruchamia oficjalnych aliasów i nie ładuje ich plików. Gotowość raportować osobno: kod, protokół, dane, UI, mapper.

Wyłączyć zależność startu od `scriptsLoaded` i `uiReady` tam, gdzie warunkuje działanie własnych usług. Zachować własny instalator i aktualizator; nie włączać automatycznego przechodzenia na oficjalny pakiet w razie błędu VIP.

**Odbiór:** start i kolejne przeładowania VIP w testowym środowisku bez globali oficjalnych; stała liczba aktywnych zasobów; zgłoszone błędy modułów nie są ukryte.

### E2 — własny protokół GMCP i spójny stan

Obsłużyć co najmniej `Char.Name`, `Char.Vitals`, `Room.Info`, `Chimera.Room.Entities`, `Chimera.Group.State`, `Chimera.Combat.State` oraz dane zabicia używane przez XP. Wysłać wymagane subskrypcje po włączeniu protokołu i obsłużyć reload w aktywnej sesji. Dokładną dostępność pakietów potwierdzić nagraniami z serwera; nazwę modułu subskrypcji odróżniać od nazwy zdarzenia.

Stan musi uwzględniać:

- rozpoczęcie nowej sesji, reconnect, zmianę postaci i wyjście z pokoju;
- kolejność Room/Entities/Group/Combat oraz odrzucanie danych niepasujących do bieżącego pokoju;
- różnicę między pełnym snapshotem i aktualizacją częściową;
- usunięcie obiektów niewystępujących w pełnym snapshotcie;
- normalizację flag `true`/`1` i identyfikatorów tekstowych;
- rozróżnienie braku danych od wartości zero — bez przenoszenia reguły „brak = zero” na wszystkie pakiety;
- zachowanie potrzebnych pól Room.Info: m.in. nazwy, obszaru, instancji, wyjść oraz pól środowiska, gdy są dostępne;
- aktualność kontekstu `Combat.Kill` i oczekujących nagród XP, aby nie przypisać starego zdarzenia nowemu zabiciu.

Istotna korekta względem uproszczonego „wszystko po ID”: źródła oficjalne rozróżniają `entity.id` i `command_ref`. ID jest kluczem modelu; do komendy stosować potwierdzony uchwyt `command_ref` albo osobno zweryfikowany wariant ID dla konkretnej akcji. Nie zakładać, że każdy identyfikator nadaje się do każdej komendy.

**Odbiór:** odtwarzanie pakietów w różnych kolejnościach nie łączy starej walki z nowym pokojem; brak danych wyłącza zależną akcję, a nie udaje pustej/bezpiecznej sytuacji; reconnect nie przywraca starych celów.

### E3 — własny interfejs i stan przycisków

Utworzyć własne kontenery Geyser, układ mapy i konsoli, stopkę, okna drużyny/przeciwników. Zachować kolory i prezentację VIP. Przepiąć ustawienia fontów, skalowania i położenia na własne obiekty. Usuwanie i odbudowa okien należą do rejestru zasobów.

Przyciski rozdzielić na stan oraz akcję:

| Kontrolka | Właściciel stanu i działania |
|---|---|
| UKR | Stan ukrycia z potwierdzonych danych/komunikatów i własna akcja |
| PRZ | Własny tryb przemieszczania oraz stan drużyny |
| ATK | Własne tryby ataku i wybór celu |
| ZBI | Własny moduł zbierania |
| LAM | Własny stan lampy i obsługa oleju |
| WAL | Własny stan walki i obsługa blokady po walce |
| ZAS | Własny wybór celu zasłony i gotowość manewru |
| KOL | Wyłącznie moduł kolorów VIP |

Nie przenosić jako prawdy serwera stałych czasów z oficjalnych skryptów bez potwierdzenia. Przykładowo oficjalne `combat_state.lua` ma `cooloff_time = 32`; jest to wartość w kliencie, nie zweryfikowany przy tym audycie kontrakt serwera.

**Odbiór:** UI pojawia się po czystym starcie bez upstreamu, poprawnie skaluje się i nie mnoży okien po reloadzie. Każdy przycisk ma działanie własne albo jawny stan niedostępności do ukończenia jego modułu.

### E4 — mapa, chodzik i klawiatura

Adaptować mapowanie Chimery, dopasowanie map importowanych oraz chodzik z potwierdzeniami GMCP. Zachować numerację mapy Mudleta, hashe i `chimera_id`, obszary, koordynaty, opisy, notatki, bindy, skróty, specjalne wyjścia i dane powiązań drużynowych. Własny mapper korzysta z mapy Mudleta; nie wymaga jej rysowania od zera.

Uwzględnić `/idz`, `/opoz`, `/stop`, wznowienie, przejścia specjalne, bramy, pauzy, odpoczynek, rysowanie/dopasowanie, import/eksport i numpad. Polecenia ruchu z klawiatury, kliknięcia kompasu i chodzika powinny przechodzić przez ten sam mechanizm rejestracji ruchu.

Zachować rozróżnienie stabilnego ID pokoju, instancji i lokalnego numeru pokoju na mapie. Wyjścia z nieustalonym celem nie mogą być traktowane jak potwierdzona krawędź do dowolnego pokoju.

Nie kopiować wszystkich historycznych lokalizatorów automatycznie; sprawdzić, które zachowania pozostają potrzebne przy natywnym Room.Info, a które są wymagane dla transportów i wyjątkowych przejść.

**Odbiór:** kroki są potwierdzane po odebraniu danych, nie po samym wysłaniu kierunku; brak odpowiedzi, nieznana lokacja, błędny cel trasy, teleport i rozłączenie zatrzymują sekwencję zgodnie z testami. Mapa po migracji zachowuje dane przed jakimkolwiek nowym mapowaniem.

### E5 — drużyna, cele, akcje i bindy kontekstowe

Wdrożyć własną listę obiektów i drużyny, rozpoznanie siebie/lidera, kondycje, cele, numerację, akcje ataku/wsparcia/zasłony oraz potrzebne rozkazy. Auto-wsparcie VIP pozostaje jedynym właścicielem automatycznego wspierania.

Wspólny mechanizm celu weryfikuje jego obecność i aktualność tuż przed wysłaniem komendy. Bind ma właściciela, priorytet, opis oraz warunek wygaśnięcia. Wyjście z lokacji, koniec zdarzenia lub rozłączenie usuwa nieaktualną akcję. Informacja o przypisanym bindzie pozostaje widoczna.

Sekwencje obsługują jawnie `send` i `expandAlias`. Oczekiwanie na odpowiedź rejestrujemy przed wysłaniem komendy. Operacja ma timeout, token unieważniający stare callbacki i regułę zakończenia; nie ponawiamy bezwarunkowo działań o nieznanym wyniku.

**Odbiór:** dwie podobnie nazwane postaci, zmiana lidera, odejście celu, szybka odpowiedź i zmiana pokoju nie powodują wykonania akcji na starym celu; jeden bodziec wywołuje tylko zamierzoną liczbę komend.

### E6 — pełna obsługa ekwipunku i czynności codziennych

Wdrożyć konfigurację toreb i ich przeznaczenia, otwieranie/zamykanie, wyjmowanie/odkładanie, zestawy uzbrojenia, dobywanie/chowanie, zbieranie monet/kamieni/innych łupów, używane operacje na walutach, jedzenie/picie, naprawy i lampę. Zachować obecne formatowanie i ocenę sprzętu VIP.

Portować razem definicje zdarzeń, timerów i aliasów. Stan lampy czy broni nie powinien być wywnioskowany wyłącznie z kliknięcia: odróżnić wysłaną komendę od potwierdzonego skutku. Operacje wielokomendowe używają usługi sekwencji z E5.

**Odbiór:** brak torby, zamknięta torba, brak przedmiotu, odmowa komendy, pełny pojemnik i utrata połączenia kończą operację czytelnie; ustawienia zachowują się po restarcie; zbieranie drużynowe respektuje aktualny skład grupy.

### E7 — transporty i podążanie

Przenieść silnik transportu, oczekiwanie na przybycie, wybór właściwego środka, wejście/wyjście, przystanki, wznawianie chodzika i podążanie drużyny. Przenieść wymagane JSON-y definicji oraz powiązania z mapą; nie ograniczać portu do `transport_waiter.lua`.

**Odbiór:** poprawny wybór przy kilku transportach, timeout wejścia/wyjścia, pominięty przystanek, opuszczenie lokacji i reconnect. Działanie żadnego etapu nie wymaga starego `/statek` lub starego binda ukrytego w oficjalnej paczce.

### E8 — domknięcie pełnego zakresu

Osobnymi modułami przenieść zakres pozostały w rejestrze E0: zioła, bazy NPC i gildii, wiedzę/książki/biblioteki, banki, rozmowy i historię, pocztę, wędkarstwo, alarmy i skrypty lokacyjne. Lista w E0 ma rozstrzygać każde stare polecenie; sama obecność tego etapu nie oznacza ukończenia tych funkcji.

Moduły zachowują własne ustawienia w przestrzeni VIP. Nie przenosić oficjalnego autoaktualizatora, globalnego loadera wszystkich modułów, systemu automatycznego odtwarzania oficjalnej paczki ani drugiej implementacji funkcji już obsługiwanych przez VIP. Wymagane przez portowane funkcje dane i assety muszą należeć do wydania VIP.

**Odbiór opcjonalnego rozszerzenia:** rozliczone pozycje wybrane do danego rozszerzenia; moduły opcjonalne mogą być wyłączone bez zatrzymania rdzenia. Ten etap nie jest warunkiem wydania VIP + mapper.

### E9 — przełączenie profilu i wydanie

Przeprowadzić procedurę z sekcji 7, testy z sekcji 9 i przegląd danych z sekcji 8. Przygotować instrukcję powrotu oraz aktualizację manifestu, instalatora, pomocy i diagnostyki.

Prace prowadzić na osobnej gałęzi i w kopii profilu. Wydanie obejmuje uzgodniony zakres VIP + mapper; nie czeka na E6–E8. Nie publikować prototypu z brakującymi funkcjami tego zakresu jako domyślnej aktualizacji działającej paczki. Wydania testowe muszą jawnie wskazywać ograniczenia.

**Odbiór:** użytkownik może pozostawić oficjalną paczkę zainstalowaną i wyłączoną, zrestartować profil i korzystać z całego uzgodnionego zakresu wyłącznie w VIP.

## 7. Jak wyłączyć Chimerę, zachowując instalację

To część wdrożenia wymagająca potwierdzenia w używanej wersji Mudleta, nie gotowa instrukcja jednego polecenia.

1. Odczytać faktyczną strukturę zainstalowanej paczki/modułu i zapisać stan aktywności jej elementów. Nie dobierać celu wyłącznie po ogólnej nazwie `skrypty`, `mapper`, `init` lub `gags`, bo podobne nazwy mogą mieć własne elementy użytkownika.
2. Zatrzymać aktywne czynności przed migracją. Przygotować kopię profilu i eksport mapy.
3. Zablokować start oficjalnego loadera. `src/scripts/scripts.json` zawiera skrypt `init` wywołujący `require` paczki, a `src/resources/init.lua` ładuje całe `scriptsList.lua`. Mechanizm wyłączenia musi zatrzymać tę ścieżkę przed jej wykonaniem przy starcie. Nie zakładać, że odznaczenie dowolnego folderu wystarczy — sprawdzić to na zainstalowanej paczce.
4. Wyłączyć należące do oficjalnej paczki aliasy, triggery, klawisze i timery. Dotyczy to także punktów aktualizacji i ponownego załadowania. Nie usuwać pakietu ani katalogu zasobów.
5. Zapisać profil i wykonać jego pełny restart. Nie zastępować restartu samym `/cvip przeladuj`: już utworzone anonimowe handlery, timery i obiekty Lua wymagają osobnego uwzględnienia, a pełny restart z zablokowanym loaderem daje właściwy scenariusz odbioru.
6. Potwierdzić w diagnostyce, że VIP wystartował bez `scriptsLoaded`, oficjalne akcje nie wysyłają komend, oficjalne UI nie powstało i nie wystartował aktualizator upstreamu. Sama obecność paczki na liście zainstalowanych jest oczekiwana; sama obecność tabeli globalnej nie dowodzi aktywności.
7. W trybie samodzielnym wykrycie aktywnego drugiego wykonawcy tych samych automatów ma skutkować czytelną diagnostyką i wstrzymaniem kolidującej automatyki VIP. Nie odinstalowywać drugiej paczki i nie usuwać nieznanych handlerów.

Nie planować płynnego przełączania dwóch całych runtime'ów podczas walki. Podstawowa procedura przejścia i powrotu wykorzystuje restart profilu.

**Powrót:** zatrzymać VIP, przywrócić zapisany stan aktywności oficjalnych elementów oraz zgodną wcześniejszą konfigurację VIP, jeśli użytkownik wraca do trybu nakładki; następnie zrestartować profil. Mapę i dane odtwarzać z kopii tylko wtedy, gdy jest to potrzebne, po zachowaniu zmian powstałych od migracji. Samo ponowne włączenie obu paczek jednocześnie nie jest procedurą powrotu.

## 8. Migracja danych i prywatnych skryptów

Import powinien być jednorazowy, wersjonowany i idempotentny: ponowne uruchomienie nie tworzy duplikatów i nie nadpisuje nowszych ustawień VIP. Oryginały pozostają na miejscu.

| Dane | Zasada migracji |
|---|---|
| Mapa Mudleta | Zachować numery pokoi, hashe, `chimera_id`, koordynaty, obszary, wyjścia i specjalne przejścia. |
| Room user data | Zachować także nieznane VIP klucze; w źródłach występują m.in. `description` i `team_follow_link`. |
| Kolory/środowiska mapy | Zachować identyfikatory środowisk, kolory oraz niestandardowe dane; nie nadpisywać całej mapy domyślną paletą. |
| Skróty mappera | Zaimportować dane z `amap_shortcuts_db.lua`, zachowując cele o tych samych numerach. |
| Konfiguracja oficjalna | Importować rozpoznane ustawienia toreb, broni, klawiszy i UI do schematu VIP; nie wykonywać automatycznie dowolnego starego kodu konfiguracyjnego. |
| Dane VIP | Zachować `ChimeraVIP-data`, dane postaci, historię cech i ustawienia istniejących modułów. |
| Zioła, NPC, transporty i inne bazy | Dla każdego modułu rozpoznać format i lokalizację jego danych przed portem; nie wymyślać wspólnej ścieżki. |
| Prywatne pluginy i aliasy | Zmapować odwołania do `amap`, `ateam`, `scripts`, eventów i starych aliasów; przepiąć na API VIP albo objąć wąskim adapterem zgodności. |

Oficjalny loader ładuje też katalog pluginów. Jeśli prywatny plugin korzystał z tego mechanizmu, pozostawienie jego plików na dysku nie oznacza, że uruchomi się bez loadera. Trzeba nadać mu własny jawny sposób startu.

Wąski adapter może zachować wybrane stare nazwy komend lub zdarzeń, jeżeli wymagają tego sprawdzone prywatne skrypty. Nie może ładować oficjalnego runtime'u ani wymagać jego tabel. Baza terenu i dodatkowe skrypty mapy użytkownika wymagają osobnej inwentaryzacji — nie są objęte samym przeglądem tych dwóch repozytoriów.

## 9. Testy, które rozstrzygają o gotowości

| Scenariusz | Kryterium odbioru |
|---|---|
| Tylko VIP w pustym profilu testowym | Uruchomienie rdzenia i UI oraz samodzielna negocjacja danych po połączeniu. To dodatkowy test niezależności; nie wymaga usuwania oficjalnych skryptów z profilu użytkownika. |
| Oficjalna paczka zainstalowana, wyłączona | Po restarcie działa tylko VIP; stare aliasy/klawisze nie wykonują się i loader nie odtwarza runtime'u. |
| Reload VIP | Nie rośnie liczba timerów/handlerów/okien; nie ma podwójnych komend i callbacków poprzedniej generacji. |
| Reconnect / zmiana postaci | Prawidłowe subskrypcje, nowy stan sesji i właściwe dane użytkownika; brak starych celów. |
| GMCP nieobecne / częściowe / w różnej kolejności | Jasny status braku danych; brak automatycznych akcji opartych na starych snapshotach. |
| Chodzik | Trasa, opóźnienie, stop, wznowienie, blokada, portal, zmęczenie i niespodziewany ruch zgodne z testami. |
| Drużyna i walka | Aktualny lider, cele i kondycje; poprawna obsługa dwóch podobnych nazw; jedno auto-wsparcie. |
| XP | Własne i drużynowe zabicia, obcy zabójca, szybkie kolejne zabicia, brak/stary `Combat.Kill`, reset oczekujących nagród. |
| Ekwipunek i transport (rozszerzenia późniejsze) | Pozytywne scenariusze oraz odmowa/timeout/przerwanie dla każdej dodanej operacji wieloetapowej; nie blokują pierwszego wydania. |
| Mapa po imporcie | Zgodne liczby pokoi i obszarów, powiązania, wyjścia i metadane; brak niezamierzonych zmian układu. |
| Aktualizacja i rollback VIP | Integralność plików, zachowanie danych i możliwość powrotu do zgodnej wersji. |
| Dłuższa sesja | Obserwacja liczby zasobów, błędów i czasu obsługi zdarzeń bez narastającego dublowania działań. |
| Kompletność | Rozliczone obecne funkcje VIP oraz kryteria mappera i samodzielności z `migration/scope.json`. Oficjalne dodatki pozostają opcjonalne. |

Rozszerzyć istniejące testy VIP i przenieść adekwatne testy oficjalne: `mapper_chimera_walker`, `mapper_gmcp_only`, `mapper_chimera_reconcile`, `mapper_change_area_selection`, `chimera_condition_window_gmcp`, testy transportów, bazy NPC i wędkarstwa.

Istniejące testy używają atrap funkcji Mudleta. Zaliczenie ich oraz kontroli składni nie zastępuje testu rzeczywistego profilu, subskrypcji sieciowych, paczki instalacyjnej i UI.

## 10. Kontrola postępu i ryzyka

Proponowane punkty kontrolne:

1. **Rdzeń samodzielny:** E1–E3; niezależny start, dane i UI. To jeszcze nie kompletna paczka do codziennej gry.
2. **Pierwsze wydanie VIP + mapper:** E4, wymagane przez obecny VIP elementy E5 i odbiór E9. Działają obecne funkcje VIP i mapper; oficjalna paczka pozostaje wyłączona.
3. **Opcjonalne rozszerzenia:** wybrane elementy E6–E8 według potrzeb, dodawane sukcesywnie. Pełne odtworzenie oficjalnej paczki nie jest wymagane.

Największe ryzyka to: niepełne wyłączenie loadera, ukryte wywołania starych aliasów, kopiowanie Lua bez definicji JSON, mieszanie snapshotów różnych lokacji, używanie niewłaściwego identyfikatora celu, utrata danych mapy oraz założenie, że udany reload dowodzi poprawnego zimnego startu.

Nie podano terminu w dniach: dokładny nakład zależy od liczby funkcji i prywatnych integracji ujawnionych w E0. Szacowanie wdrożenia przed tą inwentaryzacją byłoby pozorną precyzją.

## 11. Źródła kodowe

Wszystkie poniższe odsyłacze wskazują badane commity, a nie ruchomą gałąź `main`.

- [VIP: manifest 0.127](https://github.com/gnomidlo/ChimeraVIP/blob/a5e5951661ec53295663587769057cc25c5b867f/manifest.lua)
- [VIP: runtime i delegowanie akcji](https://github.com/gnomidlo/ChimeraVIP/blob/a5e5951661ec53295663587769057cc25c5b867f/src/integrations/runtime.lua)
- [VIP: motyw zależny od oficjalnego UI](https://github.com/gnomidlo/ChimeraVIP/blob/a5e5951661ec53295663587769057cc25c5b867f/src/theme/pastel.lua)
- [VIP: stopka](https://github.com/gnomidlo/ChimeraVIP/blob/a5e5951661ec53295663587769057cc25c5b867f/src/ui/quiet_footer.lua)
- [VIP: kontrolki](https://github.com/gnomidlo/ChimeraVIP/blob/a5e5951661ec53295663587769057cc25c5b867f/src/ui/footer_controls.lua)
- [VIP: integracja przełączania gagów](https://github.com/gnomidlo/ChimeraVIP/blob/a5e5951661ec53295663587769057cc25c5b867f/src/integrations/chimera.lua)
- [VIP: XP, grupa i kontekst zabicia](https://github.com/gnomidlo/ChimeraVIP/blob/a5e5951661ec53295663587769057cc25c5b867f/src/features/xp_tracker.lua)
- [VIP: testy runtime](https://github.com/gnomidlo/ChimeraVIP/blob/a5e5951661ec53295663587769057cc25c5b867f/tools/runtime_test.lua)
- [Chimera: metadane wersji](https://gitlab.com/bfbps-group/chimera-mud-skrypty/-/blob/2e6c3372220483b4e70b3f5cb24a4777437d5c6c/mfile)
- [Chimera: deklaracja skryptu startowego](https://gitlab.com/bfbps-group/chimera-mud-skrypty/-/blob/2e6c3372220483b4e70b3f5cb24a4777437d5c6c/src/scripts/scripts.json)
- [Chimera: loader i pluginy](https://gitlab.com/bfbps-group/chimera-mud-skrypty/-/blob/2e6c3372220483b4e70b3f5cb24a4777437d5c6c/src/resources/init.lua)
- [Chimera: lista modułów](https://gitlab.com/bfbps-group/chimera-mud-skrypty/-/blob/2e6c3372220483b4e70b3f5cb24a4777437d5c6c/src/resources/scriptsList.lua)
- [Chimera: subskrypcje GMCP](https://gitlab.com/bfbps-group/chimera-mud-skrypty/-/blob/2e6c3372220483b4e70b3f5cb24a4777437d5c6c/src/resources/skrypty/team/core.lua)
- [Chimera: snapshoty i command_ref](https://gitlab.com/bfbps-group/chimera-mud-skrypty/-/blob/2e6c3372220483b4e70b3f5cb24a4777437d5c6c/src/resources/skrypty/team/chimera_gmcp.lua)
- [Chimera: chodzik](https://gitlab.com/bfbps-group/chimera-mud-skrypty/-/blob/2e6c3372220483b4e70b3f5cb24a4777437d5c6c/src/resources/mapper/walker.lua)
- [Chimera: dopasowanie mapy](https://gitlab.com/bfbps-group/chimera-mud-skrypty/-/blob/2e6c3372220483b4e70b3f5cb24a4777437d5c6c/src/resources/mapper/chimera_reconcile.lua)
- [Chimera: lampa i zewnętrzne triggery/timery](https://gitlab.com/bfbps-group/chimera-mud-skrypty/-/blob/2e6c3372220483b4e70b3f5cb24a4777437d5c6c/src/resources/skrypty/inventory/lampa.lua)
- [Chimera: opis pochodzenia i licencji](https://gitlab.com/bfbps-group/chimera-mud-skrypty/-/blob/2e6c3372220483b4e70b3f5cb24a4777437d5c6c/README.md)
