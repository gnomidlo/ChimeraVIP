# ChimeraVIP — migracja do rozszerzen oficjalnej Chimery 5

## Stan 0.179 (etap II: jedna komenda aktualizacji)

Architektura docelowa: **Chimera 5 jest autorytatywnym silnikiem** dla
GMCP, druzyny, mapy, chodzika, akcji i danych statystycznych. VIP ma
prezentowac je czytelniej i dodawac tylko wlasne akcje i interpretacje.

Oficjalna paczka 5.0.1 z 2026-10-24 zostala przejrzana na poziomie
pliku `docs/API.md` i implementacji. To nie jest jeszcze wykonany
test gry w prawdziwej sesji Mudleta. `tested_upstream = 5.0.1`
oznacza zakres audytu zrodel, nie certyfikat integracyjny.

W wydaniach 0.178–0.179 nie przepisujemy ani nie kasujemy poprzedniego
kodu HUD, starszych integracji czy parserow. Te zadania beda osobnymi
PR-ami z testami regresyjnymi.

## Bezpieczna aktualizacja

- `/cvip kopia` — tworzy rezerwowa migawke danych gracza.
- Migracje od zainstalowanego 0.178 wykonaja migawke automatycznie
  przed podmiana kodu. Nieudana kopia PRZERYWA aktualizacje.
- Migawka przechowuje pliki `.lua/.json/.db/.txt` z glownego
  `<profil>/ChimeraVIP-data` w katalogu `backups/`.
- Pliki `Database_*.db` oficjalnej Chimery nie sa kopiowane;
  nie sa tez modyfikowane przez updater VIP.
- Nie ma automatycznego restore; w razie problemu przywracamy
  konkretny plik recznie z katalogu migawki.
- Pierwsze przejscie z 0.177 do 0.178 odbywa sie jeszcze przez
  wczesniejszy updater. Nie migrujemy w nim danych uzytkownika.

## Granice publicznego API

Stabilne wedlug oficjalnego `docs/API.md`: `ctx:use("gmcp")`
i `gmcp.room()`, `ctx:use("team")` i `team.view()`, `locations.room_actions()`,
`locations.run_action(n)`, `chimera.room.changed`,
`chimera.killed`, `chimera.progress`.

Potencjalnie niestabilne: `status_bar.model()`, `lamp.state()`,
`chimera.team.changed`, bezposrednie uzycie `scripts.ui`/ateam.
Pytanie o stabilizacje tych powierzchni poslano tworcy upstream.

## Plan PR

1. **0.178** — testy kompatybilnosci, audyt i zabezpieczenie danych.
2. **0.179** — `/cvip aktualizuj` instaluje tez wtyczki i przeladowuje
   wszystkie zaleznosci, z rollbackiem przy bledzie.
3. **0.180** — rozdzielenie monolitu `chimeravip_ui/init.lua` na
   male, niezalezne logicznie moduly (bez zmiany UI).
4. **0.181** — stabilny klucz pomieszczenia z `id` i `instance`;
   migracja bez utraty istniejacych wpisow `/cvakcja`.
5. **0.182** — XP: dane liczone oficjalnie, prezentowane przez VIP;
   zalezy od publicznego API odczytu historii.
6. **0.183** — usuniecie starych mechanik po przejsciu testow.
7. **1.0** — uproszczone ustawienia i opis instalacji.

## Tymczasowa instalacja w 0.178

```text
/cvip aktualizuj
/cvip v5 instaluj
/przeladuj
/cvip diagnostyka
```

Trzy pierwsze czynnosci nie sa jeszcze scalone w jeden przeplyw.
To jest zadanie 0.179, nie nalezy obiecywac go w 0.178.


## Wdrozone w 0.179: automatyczna instalacja wtyczek

Po scaleniu 0.179 do aktualizacji wystarcza `/cvip aktualizuj`.
Nowa wersja nadal jest pobierana z przypietego commita i poddawana
weryfikacji `file_meta`. Kopia danych gracza z 0.178 odbywa sie
zanim updater zmieni kod.

Po zapisaniu plikow wydania instalator `src/integrations/chimera5.lua`
sprawdza, czy zrodla sa oryginalnymi wtyczkami VIP i czy cele nie
naleza do innego pakietu. Przygotowuje oba pliki tymczasowe i
przechowuje rezerwowe pliki `.cvip-backup-...` na wypadek bledu
instalacji. Jesli druga wtyczka nie moze zostac zainstalowana,
odwraca pierwsza zmiane, a updater przywraca tez kod i manifest.
Wtyczki sa przechowywane tylko w `chimera_wtyczki`, bez
modyfikowania katalogu oficjalnej Chimery.

Dopiero po pomyslnym zapisie kodu i wtyczek nastepuje
`chimera.restart()`. Runtime oficjalnej 5.0.1 ponownie wykrywa
zainstalowane wtyczki, tak jak po `/przeladuj`. Wywolanie
nastepuje w timerze poza kontekstem aktualnie wykonywanej komendy.
Brak funkcji restartu jest komunikowany uzytkownikowi;
nie twierdzimy wtedy, ze wszystko przeladowano.

Przejscie 0.178 -> 0.179 wymaga wyjatku: stary updater nie
synchronizuje wtyczek po aktualizacji. Nowy bootstrap wykrywa
takie przejscie i konczy instalacje samodzielnie.
Jesli aktualizacja kodu nie jest potrzebna, ale pliki wtyczek sa
nieaktualne, `/cvip aktualizuj` naprawia je bez nowego wydania.

Uwaga: oficjalna wersja 5.0.1 jest zweryfikowana zrodlowo;
testy Mudleta na zywo wciaz sa osobnym krokiem.
