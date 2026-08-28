# ChimeraVIP

Nakładka do oficjalnych skryptów **Chimera MUD** dla Mudleta. Projekt nie modyfikuje kodu upstreamu; korzysta z jego GMCP, eventów i publicznych struktur.

Serwer: `chimera.co.pl:2300`  
Aktualna wersja ChimeraVIP: **0.78**  
Wersja upstreamu używana przy rozwoju: **2.6**

## Instalacja

W linii poleceń Mudleta wpisz:

```lua
lua installPackage("https://raw.githubusercontent.com/gnomidlo/ChimeraVIP/main/packages/ChimeraVIP.xml")
```

Pakiet tworzy trwały loader `ChimeraVIP/loader`, który pobiera aktualny runtime do:

```text
getMudletHomeDir()/ChimeraVIP/
```

Dane użytkownika są przechowywane osobno w `getMudletHomeDir()/ChimeraVIP-data/`.

Aktualizacja istniejącej instalacji:

```text
/cvip sprawdz
/cvip aktualizuj
```

## Interfejs

ChimeraVIP dodaje pastelowy motyw oraz responsywny Quiet Footer z kompasem, wyjściami specjalnymi, KOND/SIŁY/MANA, potrzebami, OBC/UPI, EXP, auto-wsparciem i dynamicznymi kontrolkami oficjalnych funkcji Chimery.

Ustawienie rozmiaru w `/cvip ustawienia` dotyczy wyłącznie oficjalnych okien `states_window` i `enemy_states_window`. Dostępne są klikalne rozmiary `7–14`; Quiet Footer zachowuje własne stałe fonty.

## Combat Colors

`features/combat_colors` dodaje pastelowe prefiksy `0/3–3/3` dla `zadane_*`, `otrzymane_*`, `innych_zadane_*` i `innych_otrzymane_*`. Moduł uczy się ustawień z wyniku `kolory`; `-1` oznacza brak koloru.

`KOL ON` wyłącza oficjalny `chimera/skrypty/ui/gags` i uruchamia prefiksy ChimeraVIP. `KOL OFF` usuwa własne triggery i ponownie włącza `gags`.

Od 0.78 rozpoznane trafienia `otrzymane_*` podnoszą `chimeraVipIncomingHit`, z którego korzysta Defense Tracker.

## Defense Tracker

`features/defense_tracker` po cichu prowadzi statystyki wyłącznie w pamięci bieżącej sesji. Niczego nie zapisuje na dysku.

Liczy:

- pudła przeciwników,
- uniki,
- parowania,
- zasłony,
- ciosy zatrzymane pancerzem,
- znane trafienia `0/3–3/3` przekazane przez Combat Colors.

`OBRONIONE` to suma pudło + unik + parowanie + zasłona. Zatrzymania pancerzem są raportowane osobno. Zasłony, parowania i pancerz mają dodatkowe zestawienie według nazwy użytego przedmiotu.

```text
/def
/def sprzet
/def last [N]
/def reset
/def help
```

Jeżeli `otrzymane_brak = -1`, trafienia 0/3 bez koloru nie mają jeszcze pewnego sygnału do rozpoznania. `/def` zaznacza wtedy, że procenty obejmują tylko znane próby ataku.

## Auto-wsparcie

Auto-wsparcie obserwuje `gmcp.Chimera.Group` i `gmcp.Chimera.Combat`. Gdy relacje pozwalają ustalić cel lidera, pilnuje aby postać biła ten sam cel.

Jedna próba wsparcia wysyła:

```text
wesprzyj
[0.18 s]
wesprzyj
```

Cała para podlega cooldownowi 1500 ms.

## Tracker XP

```text
/xp
/xp mobs
/xp mob <nazwa>
/xp last [N]
/xp rules
/xp add nazwa#forma
/xp del <nazwa>
/xp reset
/xp help
```

Tracker liczy XP/h, aktywny czas, trend, własne i drużynowe zabójstwa oraz statystyki mobów.

## Cechy i progres

`features/stats` formatuje odczyt cech i tworzy snapshoty. `features/progression` łączy je z XP i zapisuje historię osobno dla każdej postaci rozpoznanej po `gmcp.Char.Name.fullname`, z fallbackiem do `gmcp.Char.Name.name`.

```text
/progres
/progres historia [N]
/progres postacie
/progres help
/cechy info
/cechy historia [N]
```

## Pomoc i system

```text
/cvip
/cvip pomoc obrona
/cvip pomoc ustawienia
/cvip pomoc walka
/cvip pomoc xp
/cvip pomoc progres
/cvip status
/cvip sprawdz
/cvip aktualizuj
/cvip przeladuj
```

## Struktura

```text
ChimeraVIP/
├── VERSION
├── CHANGELOG.md
├── README.md
├── loader.lua
├── manifest.lua
├── releases/
├── packages/
│   ├── ChimeraVIP.xml
│   └── CHIMERA_damage_prefixes.xml   # legacy
└── src/
    ├── init.lua
    ├── core/
    ├── integrations/
    ├── theme/
    ├── ui/
    └── features/
        ├── combat_colors.lua
        ├── defense_tracker.lua
        ├── auto_support.lua
        ├── xp_tracker.lua
        ├── stats.lua
        └── progression.lua
```

## Zgodność

ChimeraVIP jest nakładką zależną od oficjalnych skryptów Chimery. Integracje z ich strukturami powinny być sprawdzane po zmianach upstreamu.
