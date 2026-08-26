# ChimeraVIP

Nakładka do oficjalnych skryptów Chimera MUD dla Mudleta. Projekt **nie modyfikuje kodu upstreamu**; korzysta z publicznych eventów, GMCP i struktur oficjalnych skryptów.

Aktualna wersja: **0.67**.

## Moduły 0.67

- `core/bootstrap` – namespace, kolejność startu i wspólne handlery.
- `theme/pastel` – pastelowy motyw i ponowne nakładanie po restarcie UI.
- `ui/quiet_footer` – responsywny footer: kompas, wyjścia specjalne, KOND/SIŁY/MANA, SYTOŚĆ/WODA, OBC, UPI i EXP.
- `features/auto_support` – auto-wsparcie drużyny z przełącznikiem ON/OFF.
- `ui/footer_controls` – mini-przyciski do wybranych funkcji oficjalnego footera.
- `packages/CHIMERA_damage_prefixes.xml` – obecny pakiet prefixów obrażeń zachowany jako osobny komponent.
- `core/updater` – sprawdzanie i pobieranie aktualizacji z tego repozytorium.

## Instalacja

### 1. Loader

W Mudlet → Scripts utwórz **jeden** trwały skrypt, np. `ChimeraVIP loader`, i wklej zawartość `loader.lua` z repozytorium.

Loader trzyma właściwe pliki w:

`getMudletHomeDir()/ChimeraVIP/`

Przy pierwszym uruchomieniu pobierze manifest i wszystkie moduły. Przy kolejnych startach uruchomi lokalną kopię.

### 2. Komendy

Po instalacji:

- `/cvip` – status i wersja,
- `/cvip sprawdz` – sprawdź, czy jest nowa wersja,
- `/cvip aktualizuj` – pobierz i uruchom najnowszą wersję,
- `/cvip przeladuj` – przeładuj lokalne moduły bez pobierania.

Updater wykonuje także ciche sprawdzenie wersji po starcie profilu. Nie instaluje aktualizacji automatycznie bez komendy użytkownika.

## Aktualizacje

Źródłem wersji jest `manifest.lua`. Każda wersja ma wpis w `CHANGELOG.md`.

Przy publikacji nowej wersji:

1. zmień `VERSION`,
2. zmień `version` w `manifest.lua`,
3. opisz zmiany w `CHANGELOG.md`,
4. zaktualizuj pliki źródłowe,
5. użytkownik wykonuje `/cvip aktualizuj`.

## Zgodność

Wersja 0.67 powstała na bazie oficjalnych skryptów Chimera **2.6**. Upstream może się zmieniać; integracje z jego strukturami powinny być sprawdzane przy kolejnych wydaniach.

## Struktura

```text
ChimeraVIP/
├── VERSION
├── CHANGELOG.md
├── README.md
├── loader.lua
├── manifest.lua
├── src/
│   ├── init.lua
│   ├── core/
│   │   ├── bootstrap.lua
│   │   ├── util.lua
│   │   └── updater.lua
│   ├── theme/
│   │   └── pastel.lua
│   ├── ui/
│   │   ├── quiet_footer.lua
│   │   └── footer_controls.lua
│   └── features/
│       └── auto_support.lua
└── packages/
    └── CHIMERA_damage_prefixes.xml
```
