# 0.1.0-alpha.49

- Fixed the “Font not set” error when opening Multiplayer. Lobby and arena room rows now apply their font before displaying their labels.

# 0.1.0-alpha.48

- Added the original **Avoid instant-death penalties** option to training, shared-keyboard versus, duels and arenas. Incoming bubbles use a safe landing column when space allows. A volley can still end the round after the last safe space fills.
- Matchmaking and arena rooms agree on the rule before play. Other players can see a penalty rise in the eighth column when the staggered row has space for it. Recordings keep the rule used in the round.
- Corrected the last-frame training result from alpha 45. The desktop game checks the loss line before rising penalties land. A penalty that lands on the final frame still lets you finish. One that landed a frame earlier can end the run. Older recordings keep their original outcome.

# 0.1.0-alpha.47

- Settled bubbles and frozen overlays keep their positions between frames. The cannon changes sprites when its aim crosses one of the original rotation steps. This cuts repeated UI updates on solo boards and in five-player arenas.
- The sticking flash now holds its frame at Low graphics and resumes at Medium or Full. A second impact during the flash keeps the original two-frame rhythm.

# 0.1.0-alpha.46

- Restored the desktop training score card and its one-second input delay. Press a key or left-click to continue. Escape or a right-click leaves without saving the run.
- Saving a qualifying score shows the training table with the game music still playing. Continue from the table to start another round with the same chain-reaction rules. Discarding a name or finishing below the cutoff goes straight to the next round.

# 0.1.0-alpha.45

- Added the desktop multiplayer training difficulty setting. Choose an average wait of 0 to 120 seconds between penalty volleys. The default is 30 seconds. Personal recordings remember the setting.
- Training now resolves the last shot or rising penalty before judging the round. A clear on the final frame counts toward your score, and a penalty reaching the loss line on that frame ends the run.

# 0.1.0-alpha.44

- Campaign times now include opening reveals, long frames, and the wait before you retry or advance. The clock stops when the game pauses and picks up from the saved time when you resume a checkpoint.
- If you hide the addon during the loss animation, reopening it lets the remaining bubbles freeze and the retry button appear.

# 0.1.0-alpha.43

- Campaign and training highscores use the desktop menu lettering and shadow. Saving a qualifying score highlights the whole entry in bold. The original heading sits in the upper right, with the WoW window controls on the left.
- The community table now ranks campaign runs that finish within the same second by their millisecond times. Hover a campaign card to see the exact time when available. Older clients can still share whole-second scores.

# 0.1.0-alpha.42

- The multiplayer lobby now shows how long you played, who won or tied, and the round wins for everyone who took a seat. Players who left still appear in the final scores.
- Arena guests can recover the last round result if they miss the host’s update or the first room-close message. The host and guest both need alpha.42 for this.
- Leaving an active duel forfeits and exits in one click. If both boards lose together and the other result arrives after you leave, the lobby prints the corrected standings.

# 0.1.0-alpha.41

- Duels and arenas send incoming penalty bubbles as soon as they launch. You can watch a volley rise on an opponent’s board even when it lands between board updates. Both players need alpha.41 or later for the live volley.
- On miniature boards, penalty bubbles rise 30 desktop pixels per frame and hold at the destination before snapping into the staggered row. They draw in front of the penguin and chat panel.
- Duel and arena recordings save the incoming volleys, including their colors, lanes and timing.

# 0.1.0-alpha.40

- The online winner’s name uses the original game lettering. The sign can appear while opponents’ boards are still freezing, and loose bubbles keep falling in front of it. Draws use the full-size menu panel.
- Once the boards have settled, press a key or click **Next round** for a rematch. Escape leaves immediately, including while you’re waiting for other players.
- Arena opponents stay visible between rounds. Holding the rematch key through the start of the next round no longer fires a shot.

# 0.1.0-alpha.39

- The lower two arena cannons, next-bubble rims and low-graphics aiming dots line up with the original miniature boards. Aiming dots move on whole desktop pixels.
- In-game chat uses the desktop lettering colors, typewriter sound and five-second display time. The next bubble and penguin disappear behind the input while you type. The cannon still runs its normal shot clock.
- New duel and arena recordings replay incoming match messages under the sender’s board, with the chat sound on the frame the message arrived.

# 0.1.0-alpha.38

- Room chat reaches the players seated in your arena before the round starts. Everyone in the room needs alpha.38 or later to use it. Public channel chat has a separate draft and history.
- Tab completes player names. Type `/me` followed by an action, `/list` to see who is in the room or public lobby, and `/help` to see the available commands.
- Hosts can remove guests with `/kick` and set a session-long exclusion with `/autokick`. Select the victory limit and press a number key for zero through nine, or cycle it with the arrow keys.

# 0.1.0-alpha.37

- Multiplayer and Arena rooms use the original world map and row highlight. Use Up, Down and Enter or click a listing. Selecting a queued duelist challenges them under their advertised rules.
- Choose Chat to talk on the FrozenBubbleForever channel. Page Up and Page Down scroll the lobby log. While typing, Up recalls a sent message and Down returns to your draft.
- Arena hosts can change chain reactions, the victory limit, targeting and departure rules while players gather. Guests receive the updated rules before the first shot.

# 0.1.0-alpha.36

- Save and reopen named level sets while they still have empty boards. The editor preserves empty boards in their original positions when importing and exporting desktop files and WoW codes. You can test individual boards as you build the set.
- The original Save Changes dialog appears over the board when you switch sets with unsaved edits. You can save, discard the changes, or keep editing.
- Two sets with the same layout can keep different names in your library. Publishing a copy offers it under the chosen name. A draft in My Library shows which board still needs bubbles.

# 0.1.0-alpha.35

- The level editor paints through the point where you release the mouse, even between frames. A held brush can leave the board and start painting again on the other side. Undo removes the whole stroke.
- Editor dialogs use the original wooden button areas and bitmap lettering. Delete opens the original empty-library message when there are no custom sets.

# 0.1.0-alpha.34

- Duels, arena matches and their recordings show each character’s name and round wins on the wooden score plaques. The main board and the four miniature boards use the original game’s two lettering sizes. Duels show realm names when two characters share a name.
- Window buttons and replay controls leave the score plaques clear. Player names appear during the opening wipe. Scripts outside the lettering atlas use WoW’s locale font and fade in with the board.

# 0.1.0-alpha.33

- In online duels and arenas you can watch the other player aim before they shoot. When they hold a turn key, their cannon rotates and their penguin leans. When they release it, the penguin straightens. Mouse aim and the center key also appear in recordings of those matches.
- Holding both turn keys keeps the cannon still and uses the original game's penguin animation.

# 0.1.0-alpha.32

- F11 toggles game music. F12 mutes or restores Frozen Bubble while remembering your music and sound-effect preferences. These keys work in a focused game, at the title screen and during recordings.
- Numpad + and − adjust both volumes. Options and WoW’s addon settings also let you change effects and music separately down to zero. Quieter effects use attenuated copies of the original cues and leave WoW’s effects volume alone.

# 0.1.0-alpha.31

- The campaign level, random-level sign, training score and clock, and both shared-keyboard round counters use the original game’s white lettering and black shadow. They appear on the wooden plaques as the board opens and during play and replays.
- Campaign and random-game points appear beside the ceiling countdown. In shared-keyboard replays the controls leave both round counters visible.

# 0.1.0-alpha.30

- In shared-keyboard play, either player can press a key for the next round once the losing board freezes. Escape starts the rematch immediately. The key that starts the round stays out of the new game until you release it.
- The two-player winner sign appears when the winner’s last bursting bubble leaves the screen. At low graphics it appears when the loser freezes. Recordings use the same timing as live play.
- On a solo loss, icicles overlap the row below and loose bubbles can fall in front of the result sign.

# 0.1.0-alpha.29

- **Pick a starting level** now shows the original wooden file list, blue lettering and a preview of the selected board. Single arrows move one board, double arrows move ten, and holding an arrow keeps scrolling. Switching sets keeps your board number when the new set contains it.
- Opening the set you’re already editing now lets you keep editing, discard changes, or save them before reopening. Returning from a test game still takes you back to your draft.

# 0.1.0-alpha.28

- When you clear a board, falling clusters and bursting bubbles pass in front of the wooden winner sign as they do in the desktop game. The buttons stay above the moving bubbles.
- Campaign losses now freeze the first and last bubbles on the same frames as the desktop game. The loss sound plays as the last shot lands, even when WoW draws several simulation frames at once.
- A level opened from the editor or your shared library now draws its opening ammunition from the same sequence as the campaign when given the same seed.

# 0.1.0-alpha.27

- Press **Print Screen** or type `/fb record` during a three-to-five-player arena round to save it. Leave multiplayer and open **Options → Recordings** to watch all the boards together. The replay includes incoming penalties, targeting arrows, departures and the round result.
- Arena replays use the multiplayer music and keep the final score on screen until you click or press a key. A round cut short by combat shows why it ended.

# 0.1.0-alpha.26

- Both names and scores have their own row during two-player replays. The timer sits under the opponent’s name and the Recordings button under yours.

# 0.1.0-alpha.25

- Press **Print Screen** during an online duel or type `/fb record` to save both boards from the start of the round. Leave multiplayer and open **Options → Recordings** to watch it.
- Duel replays include missed shots, incoming penalties, forfeits and ties. Watching a replay keeps your multiplayer record intact.

# 0.1.0-alpha.24

- Local games now draw ammunition, incoming rows and pop velocities from the same seeded sequence as the desktop game. Moving bubbles use whole sprite pixels on the original playfield and miniature boards.
- **Options → Recordings → Import** accepts plain-text Frozen Bubble solo and shared-keyboard recordings. Paste a recording, click Import, then select it to play. Recordings saved in alpha.23 still play with their original sequence.

# 0.1.0-alpha.23

- Press Print Screen or type `/fb record` to keep a random, training, endless or shared-keyboard round. The recording includes play from the start, even if you mark it later.
- Open **Options → Recordings** to watch either launcher aim, fire and react, with the original board sounds. Both players appear together in 2P recordings.
- Enable **Automatically save local recordings** to keep the ten most recent rounds. Watching a recording pauses the current local game and keeps its score intact.

# 0.1.0-alpha.22

- A lost campaign board can be retried in the same run. The clock includes every attempt. Choose **Finish run** on the pause or result screen to record how far you got.
- Qualifying campaign and training scores open the original wooden name-entry panel. Press Enter to accept your character name, type a nickname for your personal table, or discard the score. Open Highscores to finish an interrupted entry after a reload.
- A full campaign clear ranks ahead of reaching level 100. Tied campaign levels use elapsed time down to fractions of a second in the personal table. Community scores keep the character name supplied by WoW.

# 0.1.0-alpha.21

- Aim, fire and the penguin’s reaction now follow the original 20 ms game clock. An auto-fired bubble moves on its launch tick. Pressing fire while the cannon is busy queues one shot if you hold the key until it is ready.
- The local shot clock can be switched off in addon settings for solo and shared-keyboard games. Online games retain their timed rules.
- After a solo clear, a key advances when the popping bubbles leave the screen. A key retries a frozen board. Timed training shows the original full-size score panel and a key opens the highscore table.

# 0.1.0-alpha.20

- The level editor opens on a working copy of the original 100 boards. The wooden signs, bubble palette, eraser, help card and level browser use the desktop artwork. Press J to jump to a board or click Open to preview a saved set.
- The brush follows the original staggered rows. Drag to paint, right-drag to erase, and use Ctrl+Z to undo a stroke. You can save, test and share levels with floating clusters.
- Tools groups testing, undo, reordering, import, export and community level sharing beneath the board.

# 0.1.0-alpha.19

- Pausing fills the game window with the desktop pause artwork. The penguin plays all 35 frames at 50 Hz, then repeats frames 12–35. Click the picture or press P, Pause, Escape, Enter, or Space to resume.
- Launches, rebounds, pops, incoming bubbles, ceiling drops, and hurry warnings play in simulation order. Two chain reactions in the same screen update each get their own sound.
- The editor uses the title music. Solo and multiplayer demos switch to their own music as the board opens. Pausing or fading silences the existing track until you return.

# 0.1.0-alpha.18

- The title logo now ripples, folds, catches the light, and gathers falling snow. Full graphics picks an effect when the addon loads. Press **Left Ctrl+N** over the main menu to cycle through all nine.
- The logo holds its pose while the window is faded. Medium graphics, Low graphics, and Reduce motion use the still artwork.

# 0.1.0-alpha.17

- New boards open with the original 50 Hz blinds, alternating bars, diagonal squares, circles, plasma, scattered pixels, and brightness effects. They play over the preceding menu or result screen in solo play, shared keyboard games, network rounds, and the four title demos.
- Click or press a key over the game to finish a board reveal. An input during a demo opening takes you back to the title. Local clocks start once the board is visible. Online opponents keep playing through the reveal.
- Turn off **Animate the start of a round** under Settings → AddOns → Frozen Bubble Forever to enter immediately. Low graphics and Reduce motion also skip the effect.

# 0.1.0-alpha.16

- Popped bubbles, falling clusters, and attachment flashes follow the desktop game's 50 Hz clock. Falling bubbles pass in front of the cannon. A shot caught in midair at the end of a versus round bursts where it was flying.
- The shooter penguin follows a mouse sweep through its turning animation. Holding an aim key keeps the original leaning pose at the end of the cannon's travel. Firing, releasing a turn, and waiting use the original frame sequences.
- Miniature arena boards use their own screen positions for falling bubbles and returning chains. A bubble shed by a top board can fall past the lower board.

# 0.1.0-alpha.15

- Host or join a live three-to-five-player arena in Multiplayer. Everyone starts with the same board. The host sets the chain rules and victory limit and can allow targeting and continuing after a guest leaves.
- F1 through F4 send your next penalty to a particular opponent. F10 splits it among the surviving opponents. Watch shots, rising penalties, chat, and eliminations on the original four small boards. The last player standing wins.
- Stay to spectate after losing your board. Next round carries the score forward. Combat takes you out of play. Leaving as host closes the room. Everyone in a room needs alpha 15 or later.

# 0.1.0-alpha.14

- Leave the title screen open for 20 seconds to watch one of the four recordings shipped with Frozen Bubble. Watch a training run, a duel, or a three- or five-player match. The recordings use the original shots, sound cues, and closing wipe.
- Click or press a key to return to the menu. Demos leave your paused board, scores, and matchmaking alone. Turn them off under Settings → AddOns → Frozen Bubble Forever → Play demos on the title screen. Reduce motion also turns them off.

# 0.1.0-alpha.13

- Select a victory limit in Multiplayer before queuing or challenging a friend. Left-click to raise it or right-click to lower it. New players start at first to five. Existing profiles keep Unlimited so they can still play older opponents.
- Either player can choose Next round once both boards finish animating. A focused opponent at the result screen joins automatically. The boards reset together, the score carries over, and a draw awards neither player a win. Back to lobby ends the series.
- Both players need alpha 13 or later for rematches and victory limits. For a single round with an older client, choose Unlimited.

# 0.1.0-alpha.12

- Build an ordered set of up to 100 boards in the editor. Insert, append, move and remove boards. Undo restores a deleted board or a paint stroke. Your open draft survives logout.
- Import and export the desktop game’s level-file format. Existing WoW single-board codes still work. Publish shares a whole set, and downloads appear in the library after all boards arrive and pass validation. Both peers need alpha 12 or later for sets.
- Pick a starting level opens any campaign board or saved set for practice. Next level advances through a set in order. Retry restarts the current board. Practice leaves campaign checkpoints and highscores intact.

# 0.1.0-alpha.11

- Click Graphics on the title screen to cycle the original three graphics levels. Full shows the shooter penguins. Medium keeps the cannon and bubble effects. Low replaces the cannon with the two-pixel aim marker and still shows returning chain bubbles.
- The launcher now uses all 201 angles rendered from the original shooter artwork by Frozen Bubble’s own rotation code. The ceiling warning starts its sweep when the shot attaches.
- Use Options on the title screen for sound and display controls, or choose the graphics level in WoW’s addon settings.

# 0.1.0-alpha.10

- The original Keys menu now walks through both players’ aim, fire and center controls. Finish the ten prompts to save your bindings. Escape keeps the previous set.
- F fits the addon to the screen. Press it again to return to the same window size and position.
- Press Enter over your board during an online round to write to your opponent. Enter sends the message, Escape discards it, and incoming messages appear for ten seconds with the original artwork and sound. Both players need alpha 10 or later for chat.

# 0.1.0-alpha.9

- **2P Game** opens a shared-keyboard match. Player 1 uses the arrows on the right board. Player 2 uses X and V to aim, C to fire and D to center on the left. Both players start with the same layout and opening bubbles.
- Large clears send bubbles across the table. Each player has their original winner panel, and Next round carries the score into the rematch. Local rounds pause together on combat or when the game fades.

# 0.1.0-alpha.8

- Campaign highscores rank a full clear first, then the furthest level reached, then the fastest time. The gallery shows each run’s level, time and board. Older scores keep their recorded level and time.
- Regular and chain-reaction training scores appear side by side on the original wooden highscore screen. View highscores at the end of a run jumps to your entry. Community sharing uses the signed-in character’s best.
- Use the arrow keys and Enter or Space on the main menu. The selection icons run at the original speed, the penguins blink independently, and the original credits scroll below the logo.

# 0.1.0-alpha.7

- Choose chain reactions in the multiplayer lobby before joining the queue or challenging a friend. Direct invitations show the rules. Standard and chain games have separate queues.
- The left board now shows the opponent’s shot traveling, bouncing, and breaking groups. Return flights, rising penalties, the hurry sign, and the shooter penguin animate during the round.
- When a round ends, the winner’s bubbles fly off and the loser’s bubbles freeze from the bottom right. The winner’s name appears on the original network victory panel. Back to lobby returns to matchmaking.
- Closing the result panel keeps the round result retrying if the first message was lost.

# 0.1.0-alpha.6

- Random levels and multiplayer training now ask whether to enable chain reactions. A falling bubble can fly back up to complete a match and set off another drop. The launcher waits until the last returning bubble lands.
- Training keeps separate personal and community highscores for games played with chain reactions. Try again keeps your choice.
- GitHub Actions publishes the tested ZIP and checksum to GitHub Releases. CurseForge packages the repository through its push webhook.

# 0.1.0-alpha.5

- Find Frozen Bubble Forever under WoW Settings → AddOns, or type `/fb settings`. The minimap button opens the game on left-click and settings on right-click. Drag it to move it.
- A small invitation can appear once per flight path or after 60–120 seconds standing idle. The default is 90 seconds, including time spent batch crafting. Flight, idle, and crafting prompts can be switched off separately. A prompt opens the game only when you click Play.
- Turn on Colorblind bubble symbols to use the eight original Frozen Bubble patterns throughout play and editing.
- The editor uses its original background and shows the playable cells. Drag to draw, right-drag to erase, and undo a whole stroke. Test a draft without saving, then click Edit level to return to it.
- Music stays on the same playback during a focus or combat fade. The solo compressor now extends its piston shafts all the way to the top of the window.

# 0.1.0-alpha.4

- All eight bubble colors have smooth, color-matched rims. The old GIFs had a jagged black outline at large UI scales. Ceiling warnings and freeze effects now draw over the bubble artwork.
- The solo menu uses the original wooden panel, lettering, and animated selection glow. Pick a campaign start, play a random board, or practice in multiplayer training.
- Training uses the original two-minute clock, incoming penalties, and attack-based scoring. Completed sessions have their own personal and community rankings. This release includes the standard training rules. Chain reactions are still in development.

# 0.1.0-alpha.3

- Upscaled the menu and both game backgrounds, the menu logo, and the wooden buttons with Upscayl. All five use the original artwork at twice the resolution.
- Versus penalties now rise from the bottom after a shot hits another bubble. Bananas count single penalties and tomatoes count groups of seven. Clearing your own board keeps the round going.
- Both players’ penguins appear on the versus screen, and the opponent’s cannon and ammunition update with their board.

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
