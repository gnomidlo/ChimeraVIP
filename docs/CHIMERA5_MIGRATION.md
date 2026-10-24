# ChimeraVIP — PR 1, kompatybilnosc z Chimera 5.0.0-beta.13

Wymagana jest oficjalna paczka. Obecna wersja ChimeraVIP jest nakladka,
ktora nie modyfikuje kodu upstreamu ani automatycznie nie ukrywa HUD-u.

## Instalacja mostu
1. Zaktualizuj ChimeraVIP i oficjalna Chimere.
2. Wpisz `/cvip v5 instaluj` (kopiuje wtyczke do
   `<profil>/chimera_wtyczki/chimera_vip_bridge/init.lua`).
3. Wpisz oficjalne `/przeladuj`. Stan: `/cvip v5`, `/wtyczki`.
4. Cofniecie: usun katalog `chimera_vip_bridge` i znowu `/przeladuj`.

## Granice kompatybilnosci
Most udostepnia jedynie udokumentowane `ctx:use("gmcp")`,
`ctx:use("team")` i zdarzenia `chimera.room.changed`,
`chimera.killed`, `chimera.progress`. Refresh druzyny sygnalizuje
na natywnych zdarzeniach Mudleta GMCP. Interna `scripts.ui` i
`ateam` nie sa API Chimery 5.

W Chimera 5 oficjalne `/z` i `/za` zostaja nietkniete.
Alias VIP z dawna semantyka: `/vz NUMER`, `/vza LITERA`,
`/vrza LITERA LITERA`. Nasze stare Kondycje i Quiet Footer
sa jeszcze nieaktywne; odtworzymy je w PR 2 i wtedy ukryjemy
ich odpowiedniki oficjalne, z opcja powrotu.

Defense Tracker i wlasna baza postaci nie sa juz ladowane. Plik
`ChimeraVIP-data/characters.lua` nie jest kasowany.
Oficjalna baza NPC nie zawiera pelnych relacji graczy (p/n/w).

Uwaga: nie testowano w dzialajacej sesji Mudleta z Chimera 5.
Testy jednostkowe: `tools/chimera5_test.lua`,
`tools/runtime_test.lua`; test wersji i manifestu:
`tools/release_check.lua`.
