# Frozen Bubble Forever

Play the original 100 Frozen Bubble levels in WoW Forever, challenge a friend, or host an arena for up to five players. Share levels and highscores through the in-game community channel.

![Project artwork](art/curseforge-icon.png)

**Alpha software.** The Lua simulation, protocol, UI loading, and packaging have automated tests. Live Forever client testing is still required, particularly for addon-message restrictions and channel reach.

## Install and play

Download `FrozenBubbleForever-<version>.zip` from [GitHub Releases](https://github.com/cyberbalsa/frozenbubblewow/releases), extract it into `World of Warcraft/_forever_/Interface/AddOns/`, and restart WoW. The resulting file must be `Interface/AddOns/FrozenBubble/FrozenBubble.toc`.

Type `/fb`. Use the arrow keys and Enter or Space to navigate the main menu. Aim with the mouse and click to fire. While the pointer is over the board, Left/Right or A/D aim; Space/Up fire; P pauses solo games. Match three of the same color and drop clusters disconnected from the ceiling. The ceiling descends every nine solo shots and the launcher fires after 10.5 seconds in solo play.

With the keyboard, a fire press during a shot fires once when the cannon is ready if you keep holding it. After a solo win, press a key when the last popping bubble has left the screen to continue. After a loss, a key retries once the board has frozen. Escape retries a loss immediately. On a cleared board in a scored campaign, Escape finishes the run. The mouse buttons on the result screen also work.

Turn off **Use the local shot clock** in **Settings → AddOns → Frozen Bubble Forever** to take your time between shots. This applies to solo and shared-keyboard games. Training still lasts two minutes, and online matches always use their shot clock.

- **Campaign:** 100 original layouts with level unlocks and saved checkpoints. Start at level 1 for a scored run. Retry a lost board to keep going on the same clock, or choose **Finish run** from the pause or result screen. Finished campaigns rank first, followed by the furthest level reached. A shorter time wins a tie. Restarting a partially played board after logout becomes practice.
- **Multiplayer training:** survive the two-minute clock on a solo board. Earn one point for each bubble beyond three in a clear, including any that fall. Incoming penalties use the versus rules. Random levels and training both offer chain reactions. Turn them on and a falling bubble can fly back up to complete another match. Training records separate scores for each ruleset.
- **Endless:** clear the board for a new wave and a 500-point bonus.
- **2P Game** shares one keyboard. On the right board, Left and Right aim, Up fires and Down centers. On the left, X and V aim, C fires and D centers. P pauses both boards. Each win adds a round to that player’s total. Once the losing board freezes, press any key or choose **Next round**. Escape starts the rematch during the freeze.
- **Online duel:** both players start with the same board. Clearing more than three bubbles sends the excess to your opponent. Incoming bubbles rise from below in groups of up to seven. The last player above the danger line wins. Choose **Chain reactions on** in Multiplayer before you queue or challenge someone. The queue pairs players who selected the same rules. Both players need alpha 7 or newer for chain matches. You can watch the opponent aim, fire, and drop clusters on the left board. Hiding the window leaves the match running. Timeout or combat cancels the match without a result.
- **Level editor** opens a working copy of the 100 original levels the first time you enter. Pick a bubble from the wooden palette, then drag to paint. Right-drag or select the ring to erase. Press **J** to jump to a board and **F1** for keyboard shortcuts. **New** starts a blank set. **Open** shows your saved sets with a preview. **Tools** holds Undo, Test board, Import, Export and Publish set. Your draft survives logout.
- **Pick a starting level:** browse the 100 campaign boards and your saved sets. The preview shows the board you’ll play. Click the single or double arrows to move by one or ten boards, hold an arrow to scroll, or type a board number. Practice leaves your campaign checkpoint and scores alone. In the library, Play starts the set at board 1 and Next level advances after each clear.

Export copies either an original Frozen Bubble level file or a WoW code. Import accepts both, including existing 98-character single-board codes. Publish offers the whole saved set to the community. Both players need alpha 12 or later to exchange multi-board sets. Sets with floating clusters need alpha 20 or later on the receiving client.

## Graphics

Click **Graphics** on the title screen to cycle from Full to Low to Medium and back to Full. Full shows the animated penguins and rotating cannon. Medium keeps the cannon and bubble effects. Low uses the original aiming dot and limits the ceiling warning to the top row. The same setting is available under **Settings → AddOns → Frozen Bubble Forever**. **Options** on the title screen opens sound and display controls.

With Full graphics, press **Left Ctrl+N** over the main menu to cycle the nine desktop logo effects. Snow falls on December 25 and can also appear during the desktop game’s northern winter dates. Medium, Low, and Reduce motion show the still logo.

New boards and title demos open with a randomly chosen desktop transition. Click or press a key over the board to skip it. To skip every opening, turn off **Animate the start of a round** in the addon settings.

Press **P** or **Pause** during a solo or shared-keyboard round to see the original animated pause screen. Click it or press Pause, P, Escape, Enter, or Space to resume. Pausing or losing focus silences the current track. Playback continues underneath so returning to the game never sends the song back to its opening bars.

## Recordings

Press **Print Screen** with the pointer over the board, or type `/fb record`, to keep the round from its first shot. You can do this partway through a random, endless, training, shared-keyboard, online duel or arena round. To keep every round, enable **Automatically save recordings** in the addon settings. The ten most recent recordings stay in your account’s SavedVariables.

Choose **Options → Recordings** or type `/fb replays` to pick a round. `/fb replay` plays the latest one. For a shared-keyboard game or online duel, both launchers play back together. Duel recordings show the opponent as you saw them, including corrections that arrived after a shot. An arena replay puts your board in the center and every opponent in their original corner. It shows who targeted whom, who left, and who won. Leave multiplayer before starting playback. Click the board or press a key over the game to return to the list. Playback leaves your live game paused and awards no scores.

To watch a desktop recording, choose **Options → Recordings → Import**, paste the uncompressed text, then click **Import** and select the new entry. The importer reads Frozen Bubble’s protocol 0 random, training and shared-keyboard games. Desktop files omit the graphics level and command-line settings, so playback uses the desktop defaults for those. For a sample, copy the contents of the [original training recording](tests/demo1.record).

## Keys and match chat

With the game focused, **F11** toggles its music and **F12** mutes or restores all addon audio. **Numpad +** and **Numpad −** move music and effects together to the next 10% mark. Your WoW sound-effects slider stays where you set it. Use **Options** or **Settings → AddOns → Frozen Bubble Forever** to set the two volumes separately. If you’ve assigned an audio key to a cannon control, that binding takes priority on the board.

Choose **Keys** on the main menu to bind aim, fire and center for each player. The last two prompts set the full-window and chat keys. All ten bindings save together. Escape cancels a partial change. By default, F fits the addon to your screen and F again restores its size and position.

In **Multiplayer**, left-click **Victory limit** to raise the target or right-click to lower it. New profiles start at first to five. Upgrades keep Unlimited. Matchmaking pairs players who chose the same limit and chain rules. After both boards finish animating, either player can choose **Next round**. If the other player has the result screen in focus, both start a fresh board with the series score carried over. **Back to lobby** leaves a finished round without a forfeit. Both players need alpha 13 or later for series. Choose Unlimited to play a single round against an older client.

Choose **Multiplayer → Arena rooms** to host a room for three to five players. Choose the chain rules and victory limit in Multiplayer before hosting. Guests can click a listed room or enter the host’s Player-Realm name. **Announce room** sends a listing from a click when automatic channel discovery is unavailable. Everyone needs alpha 15 or later.

The host clicks **Start round** once at least three players have joined. Your board is in the center. With the pointer over it, F1–F4 target the top-left, top-right, bottom-left, and bottom-right opponents. F10 splits each penalty evenly among living opponents, rounding up. Press Enter to chat. A player whose board fills can watch the rest of the round. By default the remaining players may continue if a guest leaves. The host can turn this off before opening the room. The room closes when its host leaves or enters combat.

After 20 seconds on the focused title screen, one of the four original recordings plays. The three- and five-player recordings use the desktop arena with a small board for each opponent. Click or press a key to return. To turn demos off, open WoW Settings → AddOns → Frozen Bubble Forever and clear **Play demos on the title screen**. Demos also stay off during matchmaking and with Reduce motion enabled.

During an online round, press Enter over your board to chat. Type your message and press Enter to send or Escape to discard it. Your opponent sees it below their left board for ten seconds. Both players need alpha 10 or later for match chat.

## Addon settings

Open **Settings → AddOns → Frozen Bubble Forever**, right-click the minimap button, or type `/fb settings`. Left-click the button to toggle the game and drag to move it.

Flight invitations appear once per taxi ride. Idle invitations default to 90 seconds in one spot and can be adjusted from 60 to 120 seconds. Queued crafting counts as idle by default. Each invitation has Play and Later buttons. The page also controls the minimap icon, invitation duration, colorblind symbols, sound, music volume, window size, focus fade, reduced motion, community channel login, and debug logging.

## Community channel and P2P sharing

Open Multiplayer and join `FrozenBubbleForever`. This dedicated in-game channel carries queue advertisements, highscores, and level listings. Direct addon whispers carry match state and requested level data. No guild membership is required when using the community channel. Without it, discovery falls back to your guild/group.

The addon probes channel delivery instead of treating a successful API return as proof of delivery. If the probe fails, it shows manual mode. **Announce queue**, **Share my best**, **Browse community**, and **Publish** send normal channel discovery packets from your click. These are visible text messages in the dedicated channel; the addon does not post to General or Trade, or automate protected normal chat sends. Recipients with the addon parse them into the lobby/library. Normal chat announcements are rate-limited to one per two seconds. Automatic addon traffic is bounded and throttled.

**Channel scope is a client/server limitation.** Developers have reported blocked custom-channel addon messages and separate channel visibility across Forever's internal servers. Sharing a ruleset does not guarantee that two players can see each other. A direct Player-Realm challenge may work when public discovery does not. These limitations cannot be fixed by changing an addon.

The marketplace is a free exchange, with no currency or payment flow. A creator marks a level public; other players browse listings and request its layout directly. Creators must be online. Downloads are validated, stored locally, and may be explicitly republished by recipients. At most 100 saved levels, 200 live listings, and ten listings per catalog response are retained/returned. Listings expire after three minutes; requests time out after 12 seconds. Layouts are data, never executable code.

A top-ten campaign run or top-twenty score in either training ruleset opens the desktop name-entry panel. Ties at the cutoff qualify. Press Enter to use your character name, type a nickname for your personal table, or choose Discard. After a reload, open Highscores or type `/fb scores` on the same character to finish an interrupted entry. Shared scores use your WoW character name.

Highscores are personal or cached community reports, not a server-verified global ranking. Player names come from WoW's message sender, but another addon or a modified client can fabricate its own score. Match state is also peer-reported; this is friendly competition, not a cheat-proof ladder.

## Debugging

`/fb debug` prints the last twelve log entries. `on`, `off`, `clear`, and `errors` enable/disable logging, clear it, or enable WoW Lua error popups. Logging is enabled by default in this alpha and retains 500 entries. It records addon errors, delivery results, match transitions, and level transfers. It does not contain publishing credentials.

WoW saves `FrozenBubbleDB`, including `debugLog`, to `WTF/Account/<account>/SavedVariables/FrozenBubble.lua` on logout or `/reload`. A client crash before saving can lose recent entries. See [the live test checklist](docs/TESTING.md).

## Development and releases

Run `lua5.1 tests/run.lua` and `python3 tests/package_test.py`. `python3 tools/package.py v0.1.0-alpha.33` builds a deterministic ZIP and SHA-256 checksum in `dist/`. Runtime files live in `FrozenBubble/` and load in TOC order. Artwork regeneration uses Python, Pillow and a C99 compiler. The score and clock lettering also uses Frozen Bubble’s Perl SDLPango renderer. Release packaging requires only Python.

GitHub Actions tests Lua 5.1 and 5.4 and builds the addon ZIP. A `v*` tag publishes the tested ZIP and its checksum to GitHub Releases.

CurseForge receives push events from the repository webhook for project **1815958**. Its packager reads `.pkgmeta` and places the addon at `FrozenBubble/FrozenBubble.toc`. Tags containing `alpha` or `beta` select the corresponding release channel. CurseForge runs independently of GitHub Actions. [CurseForge automatic packaging](https://support.curseforge.com/support/solutions/articles/9000197281-automatic-packaging)

The local author token is stored outside the checkout in `~/.config/frozenbubblewow/curseforge-token` with mode 0600. The repository webhook uses the token in its HTTPS payload URL as required by CurseForge.

Original game source, license, attribution, and reproducible asset conversions are documented in [THIRD_PARTY.md](THIRD_PARTY.md). This port is GPL-2.0-only.
