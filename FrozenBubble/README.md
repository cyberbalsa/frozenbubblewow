# Frozen Bubble Forever

Install this `FrozenBubble` folder in `World of Warcraft/_forever_/Interface/AddOns/`, restart WoW, and type `/fb`.

Mouse aims; left click fires. While hovering over the board, Left/Right or A/D aim, Space/Up fire, and P pauses solo play. Online matches keep running when hidden. Combat pauses solo and shared-keyboard games and cancels online matches without a result.

Choose **2P Game** to share one keyboard. The right player aims with Left/Right, fires with Up and centers with Down. The left player aims with X/V, fires with C and centers with D. P pauses both boards. **Next round** keeps each player’s win count.

Choose **Keys** on the main menu to rebind both players. F fits the game to the screen and restores its previous position when pressed again. In an online round, press Enter with the pointer over your board to type a message to your opponent. Enter sends it and Escape cancels it. Both players need alpha 10 or later to see match chat.

Use Multiplayer → Join community channel for discovery. The channel is called `FrozenBubbleForever`. If automatic addon messages are blocked, use **Announce queue**, **Share my best**, **Browse community**, or **Publish** to send a discovery message directly from a click. Matches and requested level downloads use addon whispers. All players must have the addon installed, and Blizzard's channel visibility and message restrictions apply.

In **Multiplayer**, left-click **Victory limit** to raise the target or right-click to lower it. New profiles start at first to five. Upgrades keep Unlimited. Matchmaking pairs players who chose the same limit and chain rules. After both boards finish animating, either player can choose **Next round**. If the other player has the result screen in focus, both start a fresh board with the series score carried over. **Back to lobby** leaves a finished round without a forfeit. Both players need alpha 13 or later for series. Choose Unlimited to play a single round against an older client.

Choose **Multiplayer → Arena rooms** to host a room for three to five players. Choose the chain rules and victory limit in Multiplayer before hosting. Guests can click a listed room or enter the host’s Player-Realm name. **Announce room** sends a listing from a click when automatic channel discovery is unavailable. Everyone needs alpha 15 or later.

The host clicks **Start round** once at least three players have joined. Your board is in the center. With the pointer over it, F1–F4 target the top-left, top-right, bottom-left, and bottom-right opponents. F10 splits each penalty evenly among living opponents, rounding up. Press Enter to chat. A player whose board fills can watch the rest of the round. By default the remaining players may continue if a guest leaves. The host can turn this off before opening the room. The room closes when its host leaves or enters combat.

Type **/fb scores** to see campaign board previews and the two training rankings. Campaign clears rank first, followed by the furthest level reached and then the quickest time. Use the Personal button to switch to community scores. Hover over a score to see the character’s realm.

After 20 seconds on the focused title screen, one of the four original recordings plays. The three- and five-player recordings use the desktop arena with a small board for each opponent. Click or press a key to return. To turn demos off, open WoW Settings → AddOns → Frozen Bubble Forever and clear **Play demos on the title screen**. Demos also stay off during matchmaking and with Reduce motion enabled.

Click **Graphics** on the title screen to cycle between Full, Low and Medium. Full shows the animated penguins, Medium keeps the cannon and bubble effects, and Low uses the original aiming dot. Use **Options** for sound and display controls.

In **Editor**, Insert and Append add boards on either side of the current board. Move changes their order, and Undo can restore a removed board. Copy a desktop Frozen Bubble level file through Export, or paste one through Import. Save keeps the whole set in your library. Publish shares it with other players. Both peers need alpha 12 or later for multi-board downloads. **Pick a starting level** opens a set at any board for unranked practice.

## Addon settings

Open **Settings → AddOns → Frozen Bubble Forever**, right-click the minimap button, or type `/fb settings`. Left-click the button to toggle the game and drag to move it.

Flight invitations appear once per taxi ride. Idle invitations default to 90 seconds in one spot and can be adjusted from 60 to 120 seconds. Queued crafting counts as idle by default. Each invitation has Play and Later buttons. The page also controls the minimap icon, invitation duration, colorblind symbols, sound, music volume, window size, focus fade, reduced motion, community channel login, and debug logging.

Type `/fb debug` for recent diagnostics; `/fb debug on`, `off`, `clear`, or `errors` control logging and Lua error popups. The most recent 500 entries are stored in `FrozenBubbleDB.debugLog`. WoW writes them to `WTF/Account/<account>/SavedVariables/FrozenBubble.lua` on logout or `/reload`.

Source, issues, and releases: https://github.com/cyberbalsa/frozenbubblewow

Unofficial GPLv2 port. See COPYING and AUTHORS.upstream for the original game's license and credits.
