# Instalacja ChimeraVIP 2.0

Wersja **2.0.0-dev.2** jest paczką deweloperską. Testy automatyczne obejmują
rozpakowany instalator i moduły, ale nie wykonano testu w prawdziwym Mudlecie
ani połączenia z serwerem. Nadal brakuje pełnych okien drużyny i ustawień oraz
części funkcji mappera.

## Pierwsza instalacja

1. Zachowaj kopię profilu i mapy przed zmianą używanego zestawu.
2. Użyj profilu z włączonym GMCP, w którym oficjalna Chimera i VIP 1.x nie
   uruchamiają się. Możesz pozostawić oficjalną paczkę zainstalowaną. Wyłącz
   również jej skrypty startowe, aliasy, timery i klawisze, nie tylko triggery.
   Zapisz profil, zamknij go i otwórz ponownie, aby usunąć stan poprzedniej sesji Lua.
3. Pobierz plik [ChimeraVIP2.mpackage](../packages/ChimeraVIP2.mpackage)
   przyciskiem pobrania pliku na GitHub. Nie rozpakowuj go.
4. W Mudlecie otwórz **Menedżer pakietów / Package Manager (Alt+O)**,
   wybierz **Install** i wskaż pobrany plik. Użyj menedżera pakietów, nie modułów.
   Możesz też przeciągnąć plik do otwartego profilu.
5. Paczka uruchamia się po instalacji oraz przy otwarciu profilu. Połącz się
   z grą i wpisz `/cvip2`. Oczekiwany status: rdzeń ON, stopka ON, moduły 18.
   Dane lokacji i postaci pojawiają się dopiero po odebraniu nowych pakietów GMCP.

Format paczki i sposób instalacji opisuje
[instrukcja Mudleta](https://wiki.mudlet.org/w/Manual:Mudlet_Packages).

Instalator zawiera kod i nie pobiera dodatkowych skryptów. Nie przełącza
oficjalnej paczki za użytkownika. Jeśli wykryje jej obiekty w pamięci lub
uruchomione VIP 1.x, pokaże komunikat i zatrzyma start.

## Pierwsze polecenia

| Polecenie | Działanie |
|---|---|
| `/cvip` | Skrócona pomoc |
| `/cvip2` | Stan rdzenia, stopki, mappera i modułów |
| `/cvip2 mapa` | Okno mapy |
| `/idz ID` | Chodzik do numeru pokoju istniejącej mapy |
| `/opoz SEKUNDY` | Opóźnienie chodzika |
| `/stop` | Zatrzymanie chodzika |
| `/kolory on` / `/kolory off` | Kolory walki; także przycisk KOL |
| `/wsparcie on` / `/wsparcie off` | Automatyczne wsparcie; także przycisk AS |
| `/cvip2 reload` | Przeładowanie zainstalowanego kodu, bez pobierania aktualizacji |
| `/cvip2 stop` | Zatrzymanie VIP do kolejnego otwarcia profilu |

Paczka nie zawiera mapy. Korzysta z mapy obecnej w profilu i rozpoznaje lokacje
przez hash pokoju lub dane `chimera_id`. Przy braku przypisania nie uruchamia
chodzika. Szczegóły: [mapper](standalone-v2-mapper.md).

## Dane, aktualizacja i powrót

Kod jest instalowany pod `ChimeraVIP2/` w katalogu profilu. Dane VIP 2.0 są
zapisywane osobno pod `ChimeraVIP-v2/`, np.
`ChimeraVIP-v2/ChimeraVIP-data/settings.lua`. Przy braku nowych plików moduły
mogą odczytać dotychczasowe dane VIP 1.x, bez zapisywania zmian do oryginałów.
To nie import ustawień oficjalnej Chimery.

Aktualizacja jest ręczna: rozłącz się z grą, odinstaluj **ChimeraVIP2** w
menedżerze pakietów, zainstaluj nowy plik i ponownie otwórz profil. Obsługa
odinstalowania zatrzymuje rdzeń; dane poza katalogiem paczki pozostają na dysku.
Nie usuwaj `ChimeraVIP-v2/`, jeśli chcesz zachować swoje dane.

Aby wrócić do wcześniejszego zestawu, odinstaluj **ChimeraVIP2**, przywróć
poprzednie ustawienia aktywności oficjalnej paczki i VIP 1.x, zapisz i ponownie
otwórz profil. Nie uruchamiaj obu zestawów w tej samej sesji.

## Budowanie z repozytorium

```sh
python3 tools/build_standalone.py
python3 tools/build_standalone.py --check
python3 tools/package_test.py
```

Test wymaga Lua 5.1 w PATH jako `lua5.1`; inną ścieżkę można wskazać zmienną
`LUA`. Budowanie wymaga wyłącznie standardowej biblioteki Python 3. Archiwum
ma stałą kolejność i daty wpisów oraz spis sum SHA-256 `CONTENTS.json`.
CI sprawdza zgodność paczki ze źródłami i udostępnia ją jako artefakt
`ChimeraVIP2-installer`. Zmiany kodu dołączonego do paczki wymagają jej przebudowania.
