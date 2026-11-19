# Frozen Bubble Forever

Install this `FrozenBubble` folder in `World of Warcraft/_forever_/Interface/AddOns/`, restart WoW, and type `/fb`.

Mouse aims; left click fires. While hovering over the board, Left/Right or A/D aim, Space/Up fire, and P pauses solo play. Multiplayer keeps running when hidden. Combat pauses solo games and cancels versus matches without a result.

Use Multiplayer → Join community channel for discovery. The channel is called `FrozenBubbleForever`. If automatic addon messages are blocked, use **Announce queue**, **Share my best**, **Browse community**, or **Publish** to send a discovery message directly from a click. Matches and requested level downloads use addon whispers. All players must have the addon installed, and Blizzard's channel visibility and message restrictions apply.

Type `/fb debug` for recent diagnostics; `/fb debug on`, `off`, `clear`, or `errors` control logging and Lua error popups. The most recent 500 entries are stored in `FrozenBubbleDB.debugLog`. WoW writes them to `WTF/Account/<account>/SavedVariables/FrozenBubble.lua` on logout or `/reload`.

Source, issues, and releases: https://github.com/cyberbalsa/frozenbubblewow

Unofficial GPLv2 port. See COPYING and AUTHORS.upstream for the original game's license and credits.
