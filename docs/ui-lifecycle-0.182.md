# 0.182: cold profile startup

Mudlet 4.19.1 `Host::openWindow` creates a new dock on the right, loads the
saved layout, then applies the optional explicit area. Passing `"right"`
therefore overrides the restored floating/left placement even with
`loadLayout=true`. Source:
https://github.com/Mudlet/Mudlet/blob/Mudlet-4.19.1/src/Host.cpp#L3088

VIP now omits the optional area. First-time placement remains Mudlet's
right-hand default; saved layout chooses placement on subsequent starts.
Existing windows are still reused. No new global layout restore is added.

The previous test double applied docking BEFORE restore, hiding the bug.
It now models the native ordering. The cold-start regression drops all
windows, plugin globals and contexts after sysExitEvent, retaining only
copied settings and saved layout. It covers floating, left and right docks,
geometry, mapper, hidden henchmen, XL footer and a manual 19 pt font.
The old call fails this test with `cold start lost dock for floating`.

Limitations: these are Lua contract tests, not a live Qt desktop test or
SQLite persistence test. Confirm on Smoti's profile: move/resize Kondycje,
select XL, optionally set a custom font in /cvhud ustawienia, close Mudlet
normally and reopen twice. Check placement, dimensions and text size.
If only font size resets, this docking correction does not establish the
cause of that separate symptom.
