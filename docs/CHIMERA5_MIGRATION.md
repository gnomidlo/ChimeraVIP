# ChimeraVIP — migracja do rozszerzen oficjalnej Chimery 5

## Stan 0.178 (etap I: przygotowanie i zabezpieczenia)

Architektura docelowa: **Chimera 5 jest autorytatywnym silnikiem** dla
GMCP, druzyny, mapy, chodzika, akcji i danych statystycznych. VIP ma
prezentowac je czytelniej i dodawac tylko wlasne akcje i interpretacje.

Oficjalna paczka 5.0.1 z 2026-10-24 zostala przejrzana na poziomie
pliku `docs/API.md` i implementacji. To nie jest jeszcze wykonany
test gry w prawdziwej sesji Mudleta. `tested_upstream = 5.0.1`
oznacza zakres audytu zrodel, nie certyfikat integracyjny.

W wydaniu 0.178 nie przepisujemy ani nie kasujemy poprzedniego
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
