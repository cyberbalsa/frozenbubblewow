# Frozen Bubble Forever

Frozen Bubble in WoW Forever: the original 100 levels, two-player versus, community highscores, and player-created levels. Native Lua; no external service or runtime dependencies.

![Project artwork](art/curseforge-icon.png)

**Alpha software.** The Lua simulation, protocol, UI loading, and packaging have automated tests. Live Forever client testing is still required, particularly for addon-message restrictions and channel reach. This is an adaptation of the game, not a bit-for-bit port of its Perl/SDL runtime or its five-player internet server.

## Install and play

Download `FrozenBubbleForever-<version>.zip` from [GitHub Releases](https://github.com/cyberbalsa/frozenbubblewow/releases), extract it into `World of Warcraft/_forever_/Interface/AddOns/`, and restart WoW. The resulting file must be `Interface/AddOns/FrozenBubble/FrozenBubble.toc`.

Type `/fb`. Use the arrow keys and Enter or Space to navigate the main menu. Aim with the mouse and click to fire. While the pointer is over the board, Left/Right or A/D aim; Space/Up fire; P pauses solo games. Match three of the same color and drop clusters disconnected from the ceiling. The ceiling descends every nine solo shots and the launcher fires after 10.5 seconds in solo play.

- **Campaign:** 100 original layouts with level unlocks and saved checkpoints. Runs started at level 1 qualify for campaign highscores. Finished campaigns rank first, followed by the furthest level reached. A shorter time wins a tie. Restarting a partially played board after logout becomes practice.
- **Multiplayer training:** survive the two-minute clock on a solo board. Earn one point for each bubble beyond three in a clear, including any that fall. Incoming penalties use the versus rules. Random levels and training both offer chain reactions. Turn them on and a falling bubble can fly back up to complete another match. Training records separate scores for each ruleset.
- **Endless:** clear the board for a new wave and a 500-point bonus.
- **2P Game** shares one keyboard. On the right board, Left and Right aim, Up fires and Down centers. On the left, X and V aim, C fires and D centers. P pauses both boards. Each win adds a round to that player’s total. Choose **Next round** to keep the score.
- **Online versus:** both players start with the same board. Clearing more than three bubbles sends the excess to your opponent. Incoming bubbles rise from below in groups of up to seven. The last player above the danger line wins. Choose **Chain reactions on** in Multiplayer before you queue or challenge someone. The queue pairs players who selected the same rules. Both players need alpha 7 or newer for chain matches. You can watch the opponent aim, fire, and drop clusters on the left board. Hiding the window leaves the match running. Timeout or combat cancels the match without a result.
- **Editor:** paint up to ten rows, test, save, import/export a 98-character layout code, and publish to the community. Saved/imported levels are unranked.

## Addon settings

Open **Settings → AddOns → Frozen Bubble Forever**, right-click the minimap button, or type `/fb settings`. Left-click the button to toggle the game and drag to move it.

Flight invitations appear once per taxi ride. Idle invitations default to 90 seconds in one spot and can be adjusted from 60 to 120 seconds. Queued crafting counts as idle by default. Each invitation has Play and Later buttons. The page also controls the minimap icon, invitation duration, colorblind symbols, sound, music volume, window size, focus fade, reduced motion, community channel login, and debug logging.

## Community channel and P2P sharing

Open Multiplayer and join `FrozenBubbleForever`. This dedicated in-game channel carries queue advertisements, highscores, and level listings. Direct addon whispers carry match state and requested level data. No guild membership is required when using the community channel. Without it, discovery falls back to your guild/group.

The addon probes channel delivery instead of treating a successful API return as proof of delivery. If the probe fails, it shows manual mode. **Announce queue**, **Share my best**, **Browse community**, and **Publish** send normal channel discovery packets from your click. These are visible text messages in the dedicated channel; the addon does not post to General or Trade, or automate protected normal chat sends. Recipients with the addon parse them into the lobby/library. Normal chat announcements are rate-limited to one per two seconds. Automatic addon traffic is bounded and throttled.

**Channel scope is a client/server limitation.** Developers have reported blocked custom-channel addon messages and separate channel visibility across Forever's internal servers. Sharing a ruleset does not guarantee that two players can see each other. A direct Player-Realm challenge may work when public discovery does not. These limitations cannot be fixed by changing an addon.

The marketplace is a free exchange, with no currency or payment flow. A creator marks a level public; other players browse listings and request its layout directly. Creators must be online. Downloads are validated, stored locally, and may be explicitly republished by recipients. At most 100 saved levels, 200 live listings, and ten listings per catalog response are retained/returned. Listings expire after three minutes; requests time out after 12 seconds. Layouts are data, never executable code.

Highscores are personal or cached community reports, not a server-verified global ranking. Player names come from WoW's message sender, but another addon or a modified client can fabricate its own score. Match state is also peer-reported; this is friendly competition, not a cheat-proof ladder.

## Debugging

`/fb debug` prints the last twelve log entries. `on`, `off`, `clear`, and `errors` enable/disable logging, clear it, or enable WoW Lua error popups. Logging is enabled by default in this alpha and retains 500 entries. It records addon errors, delivery results, match transitions, and level transfers. It does not contain publishing credentials.

WoW saves `FrozenBubbleDB`, including `debugLog`, to `WTF/Account/<account>/SavedVariables/FrozenBubble.lua` on logout or `/reload`. A client crash before saving can lose recent entries. See [the live test checklist](docs/TESTING.md).

## Development and releases

Run `lua5.1 tests/run.lua` and `python3 tests/package_test.py`. `python3 tools/package.py v0.1.0-alpha.9` builds a deterministic ZIP and SHA-256 checksum in `dist/`. Runtime files live in `FrozenBubble/` and load in TOC order. Python and Pillow are needed only to regenerate artwork; Python packaging itself has no third-party dependencies.

GitHub Actions tests Lua 5.1 and 5.4 and builds the addon ZIP. A `v*` tag publishes the tested ZIP and its checksum to GitHub Releases.

CurseForge receives push events from the repository webhook for project **1815958**. Its packager reads `.pkgmeta` and places the addon at `FrozenBubble/FrozenBubble.toc`. Tags containing `alpha` or `beta` select the corresponding release channel. CurseForge runs independently of GitHub Actions. [CurseForge automatic packaging](https://support.curseforge.com/support/solutions/articles/9000197281-automatic-packaging)

The local author token is stored outside the checkout in `~/.config/frozenbubblewow/curseforge-token` with mode 0600. The repository webhook uses the token in its HTTPS payload URL as required by CurseForge.

Original game source, license, attribution, and reproducible asset conversions are documented in [THIRD_PARTY.md](THIRD_PARTY.md). This port is GPL-2.0-only.
