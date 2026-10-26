# Layout audit and regression checks — 0.180

## Sources and boundaries

Audited `chimera-mud-skrypty-main (3).zip` supplied locally, whose changelog
starts at **5.0.1**, especially `src/chimera/init.lua`, `boot.lua`,
`core/{loader,context,plugins,config}.lua`, `ui/{room_window,henchman_window,windows,status_bar}.lua`.
The older `official/` checkout is not the 5.0.1 source of truth.
ZIP SHA-256: `a8b88d797c74940710364e814be384bbc720cf239cc654ba73aa35058627350e`.
The legacy `mfile` still says 4.4; the package builder supplies the actual
runtime version. No upstream source files are modified or shipped by VIP.

Mudlet references:
- [Native windows and layout](https://wiki.mudlet.org/w/Manual:UI_Functions#openUserWindow)
- [Geyser user windows](https://www.mudlet.org/geyser/files/geyser/Geyser.UserWindow.html)
- [Geyser container lifecycle](https://github.com/Mudlet/Mudlet/blob/development/src/mudlet-lua/lua/geyser/GeyserContainer.lua)

## Lifecycle and cause

`/cvip aktualizuj` deploys code and plugin copies, then schedules a full
`chimera.restart()`. Restart shuts down the old app, clears `chimera.*`
require entries, discovers plugins, starts modules in dependency order and
emits `chimera.ready`. The loader stops modules in reverse dependency order;
Context disposes registered resources in reverse registration order.
`chimera.shutdown` is emitted **after** `stop_all`, too late for a plugin's
already-unregistered event handler to snapshot its layout.

Both official native windows render during setup. `henchman_window.okno`
defaults to true, even with no henchman. Hiding the dock alone does not
disable that setting. Official windows survive Lua module teardown.

VIP 0.179 cleanup calls `restore()`, which enables official Kondycje and
the official footer, persists those settings and hides VIP Kondycje.
The next VIP instance waits 0.5 seconds and disables them again. Thus the
dock population changes during restart. VIP never disables the henchman
module. Layout is only explicitly saved on profile exit, not immediately
before this restart, so a just-resized window may have stale saved geometry.
These are source-confirmed causes of layout churn; exact Qt splitter sizes
still require a real Mudlet session to verify.

`openUserWindow` can re-dock an existing window; use `windowType` (or the
older size lookup) and `showWindow` instead. `moveWindow` / `resizeWindow`
are not a safe way to repair docked geometry: they can float the window.
Geyser footer containers and labels are separate from native Qt docks;
repositioning the footer does not restore native dock splitter dimensions.

## New ordering

1. Complete the multi-file plugin transaction. At the restart boundary,
   run the current installer again: the 0.179 caller only copied init.lua.
2. Save the complete current native layout **before old cleanup**, retaining
   a pending snapshot flag across VIP bootstrap and official restart.
3. Teardown removes VIP callbacks/Geyser objects without enabling official
   windows. Direct `/przeladuj` also snapshots before hiding VIP.
4. On the next event-loop turn, after synchronous loader startup, apply VIP
   settings and reuse the existing Kondycje dock. Henchman is an explicit
   dependency. Its previous setting is stored persistently for switchback.
5. On another event-loop turn restore the snapshot once, then reapply
   visibility, since Qt layout restoration includes visibility. No mapper
   move, resize, reopen or `/okna przywroc` call is issued.

Kondycje has a native QDockWidget minimum of 260×160 pixels. It repairs
collapsed layouts without forcing a fixed size or floating the dock; larger
user sizes and docking area are retained. The palette, font defaults, footer
geometry, commands and public action APIs remain unchanged. A minimum can
necessarily redistribute space in an already-collapsed Qt splitter.

Explicit `/cvhud oficjalny` and rendering failure restore official controls.
Restart cleanup does not. The previous henchman setting survives restarts;
switchback restores it and clears the temporary preference. Changing VIP
Kondycje settings while in official mode cannot open the VIP dock.

Helper files are loaded relative to the installed init.lua with `dofile`:
official restart only clears `chimera.*`, so ordinary cached helper `require`
calls would otherwise leave old code after an update. Installer preflights
ownership and syntax of every file, stages all files, then replaces helpers
before init.lua, rolling back the whole transaction on failure.

## Tests

CI runs `lua5.1 tools/ui_lifecycle_test.lua` with native-window contract
doubles, plus existing HUD/action tests and deployment/updater tests.
The layout double models re-docking, saved visibility, native minima,
dimensions, disposal and queued callbacks. It rejects native move/resize.
The same test can run the original official window modules:

```sh
CHIMERA501_SOURCE=/path/to/chimera-mud-skrypty-main lua5.1 tools/ui_lifecycle_test.lua
```

Covered: three consecutive full stop/start cycles; resize without manual
save; left/floating docking; mapper preservation; 0.179 cleanup migration;
collapsed layout; hidden Kondycje; henchman preference true and false;
switchback; stale startup callbacks; stable Geyser object count; missing,
invalid or foreign helper; late transaction failure and rollback; helper
deployment before restart; restart failure snapshot restoration.

## Manual acceptance in Mudlet

Use a copy of the profile with official Chimera 5.0.1. Install the PR's
complete code and plugin files; `/cvip aktualizuj` follows **main**, so it
does not fetch an unmerged PR by itself.

1. Place the mapper and enlarge VIP Kondycje below it. Restart twice with
   `/przeladuj`; compare placement and dimensions after each restart.
2. Repeat with Kondycje docked left and floating. Resize without dragging
   before restarting, then close/reopen the profile.
3. Start with tiny saved Kondycje. Confirm readable minimum size and that
   it stays docked; verify the mapper has not been moved to another area.
4. Confirm no henchman dock in VIP, including after layout restore and team
   GMCP updates. Switch official/VIP and check restoration of both a
   previously enabled and a previously disabled henchman preference.
5. Toggle Kondycje off, restart, then on. Test `/cvakcja`, map default,
   Alt actions and footer resizing. Check `/chimera bledy`.

Automated Lua tests do not render Qt and do not certify actual pixels.
