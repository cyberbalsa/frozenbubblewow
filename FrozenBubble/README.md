# Frozen Bubble Forever

Install this `FrozenBubble` folder in `World of Warcraft/_forever_/Interface/AddOns/`, restart WoW, and type `/fb`.

Mouse aims; left click fires. While hovering over the board, Left/Right or A/D aim, Space/Up fire, and P pauses solo play. Online matches keep running when hidden. Combat pauses solo and shared-keyboard games and cancels online matches without a result.

Choose **2P Game** to share one keyboard. The right player aims with Left/Right, fires with Up and centers with Down. The left player aims with X/V, fires with C and centers with D. P pauses both boards. **Next round** keeps each player’s win count.

Choose **Keys** on the main menu to rebind both players. F fits the game to the screen and restores its previous position when pressed again. In an online round, press Enter with the pointer over your board to type a message to your opponent. Enter sends it and Escape cancels it. Both players need alpha 10 or later to see match chat.

Use Multiplayer → Join community channel for discovery. The channel is called `FrozenBubbleForever`. If automatic addon messages are blocked, use **Announce queue**, **Share my best**, **Browse community**, or **Publish** to send a discovery message directly from a click. Matches and requested level downloads use addon whispers. All players must have the addon installed, and Blizzard's channel visibility and message restrictions apply.

Type **/fb scores** to see campaign board previews and the two training rankings. Campaign clears rank first, followed by the furthest level reached and then the quickest time. Use the Personal button to switch to community scores. Hover over a score to see the character’s realm.

## Addon settings

Open **Settings → AddOns → Frozen Bubble Forever**, right-click the minimap button, or type `/fb settings`. Left-click the button to toggle the game and drag to move it.

Flight invitations appear once per taxi ride. Idle invitations default to 90 seconds in one spot and can be adjusted from 60 to 120 seconds. Queued crafting counts as idle by default. Each invitation has Play and Later buttons. The page also controls the minimap icon, invitation duration, colorblind symbols, sound, music volume, window size, focus fade, reduced motion, community channel login, and debug logging.

Type `/fb debug` for recent diagnostics; `/fb debug on`, `off`, `clear`, or `errors` control logging and Lua error popups. The most recent 500 entries are stored in `FrozenBubbleDB.debugLog`. WoW writes them to `WTF/Account/<account>/SavedVariables/FrozenBubble.lua` on logout or `/reload`.

Source, issues, and releases: https://github.com/cyberbalsa/frozenbubblewow

Unofficial GPLv2 port. See COPYING and AUTHORS.upstream for the original game's license and credits.
