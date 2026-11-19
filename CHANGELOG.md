# 0.1.0-alpha.2

- The launcher loads the next bubble when you fire. In 63 reference shots across seven campaign boards, the Lua engine lands on the same cell and simulation tick as the upstream collision routines.
- The shooter penguin returns from the pose it reached when you release an aim key. Aiming wakes it from its idle animation.
- Versus adds alternating seven- and eight-bubble rows every twelve shots. The opponent preview follows the same stagger.
- Restored the original hurry sign, next-bubble rim, shot indicators, and bubble freeze order.

# 0.1.0-alpha.1

First playable WoW Forever port. This is an alpha release for in-client testing.

- Original 100-level campaign, endless mode, mouse and keyboard aiming, wall bounces, falling clusters, ceiling pressure, and automatic fire.
- Two-player versus with garbage attacks, queue matchmaking, direct challenges, opponent previews, retrying handshakes, and disconnect handling.
- Dedicated FrozenBubbleForever discovery channel with delivery detection and click-to-announce fallback on restricted clients.
- Personal and community highscores; shared scores are player-reported.
- Ten-row level editor, import/export codes, and a free P2P level marketplace.
- Original Frozen Bubble textures, sound effects, and optional music, with GPLv2 notices.
- Persistent debug log, `/fb debug`, and automated Lua/packaging tests.

Known limits: two-player matches only; custom-channel reach is controlled by Blizzard and is not guaranteed across all Forever servers in a ruleset. Modern chat restrictions can prevent discovery or direct messages. No authoritative global leaderboard or anti-cheat service. Graphics, audio timing, network pacing, and combat handling still need live client verification.
