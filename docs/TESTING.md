# Live WoW Forever test checklist

Automated tests cannot prove that Blizzard will deliver messages or that every texture/UI API behaves the same as the simulated frame harness. Test the alpha on the actual client.

1. Restart the client after installing. Enable Frozen Bubble Forever. Run `/fb debug errors` and `/fb`.
2. Play level 1 with mouse and keyboard. Check wall bounces, match-three groups, detached clusters, next-bubble preview, nine-shot ceiling drops, and 10.5-second auto-fire. Resize UI scale and verify mouse aim matches the pointer.
3. Pause solo, hide/show, start combat, then resume after combat. Ensure movement keys pass through outside the board and no keys remain held when the pointer leaves it.
4. Clear a level and continue. Log out and back in; confirm unlocks, scores, custom levels, and debug history persist. A mid-level checkpoint restart is practice.
5. Enable sound/music and verify that effects play once and music stops when hidden or disabled.
6. On two accounts, join FrozenBubbleForever. Check whether delivery becomes verified or manual. In manual mode, click Announce queue on both clients. Also test a direct Player-Realm challenge.
7. Confirm the challenge must be accepted unless both players queued. Check identical starting boards, live opponent previews, falling-cluster attacks, single result recording, forfeit, timeout, and combat cancellation. Repeat with packet loss simulated in unit tests and real latency in-client.
8. Share a best score and refresh on the other client. Verify sender attribution and separation from personal records. Try different Forever internal servers to measure actual channel reach; record the server names and builds.
9. Create a level with a floating cluster, save, test, publish, browse from the other client, download, and play. Confirm offline requests expire, corrupt codes fail, and republishing requires a click.
10. Use `/fb debug`, then log out or `/reload` to flush `FrozenBubbleDB.debugLog`. Report errors with the client build, UI scale, relevant log entries, and which of the above steps failed.

11. In Settings → AddOns → Frozen Bubble Forever, toggle the minimap button and colorblind symbols. Check the board, current and next bubbles, and editor palette. Drag the icon, reload, and check that its position and settings persist.
12. Set the idle delay to 60 seconds. Walk before it expires, then queue several crafts while standing still. Check that a single invitation appears after the new interval and Later dismisses it for that idle period. Try the same batch with crafting invitations disabled. Check a taxi ride, landing, and combat with a prompt showing.
13. Open the editor on a fresh profile and jump to board 33. Check the name and board counter, then open F1 help. Create a new set, drag across alternating row edges, undo the stroke, and repeat with the eraser and with right-drag. Open the level browser and check the selected thumbnail. Test an unsaved draft and return with Edit level. Check the title, colors and grid at two UI scales.
14. During a solo game, let the window fade and return to it. Listen for the same place in the track. After several ceiling drops, inspect the piston shafts from the screen edge down to the compressor. Sweep the mouse across the board and hold an aim key at the edge. The penguin should finish its turn, hold the lean and return when the key is released. During a clear, watch detached bubbles fall in front of the cannon.

14. Queue with chain reactions selected on one client and standard rules on the other. Then select chains on both and play a round. Follow a shot from launch on the left board, watch a return flight hit another group, and check penalties after each clear. At the end, compare the freeze order, winning penguin, and winner’s name on both clients.

15. Open Highscores with the main menu arrow keys and Enter. Check the thumbnail and time of a campaign entry, toggle colorblind symbols, view both training columns, and use Share best from each column. On a second account, refresh the shared table and compare the level and clear marker.


For an arena test, host a room and join it from two to four other characters. Check that each character sees their own board in the center, that F1–F4 target the opponent in the corresponding corner, and that F10 resumes split penalties. Leave one board full and verify that its player can watch the survivors. Check room chat, guest departure, combat, and a rematch to the chosen victory limit.

Start a campaign, advance from a result panel, and retry a multiplayer round with board transitions enabled. Check that the previous screen shows through each reveal, the first click skips without firing, colorblind symbols stay visible, and combat restores WoW input. Check immediate starts with Low graphics, Reduce motion, and the transition setting switched off individually.

Hold an aim key as the shot clock expires. Check that the bubble leaves along the rotating barrel and the penguin fires at the same time. Turn off **Use the local shot clock** and wait at least 11 seconds on a solo board, then try both local launchers. An online duel should still fire automatically. At the end of training, check the wooden score panel, wait a second, then press a key over the window to view the score.

Start a scored campaign at level 1, lose on level 2, retry, then choose **Finish run** from pause. Check that the total time includes the failed board. Reload at the name prompt and use `/fb scores` on the same character. Enter a nickname, check it on the personal card, and share the score with another client. The other client should see the sender’s character name. Repeat with Discard and verify the score is absent from both tables.

Take several mouse and keyboard shots on a random board, press Print Screen, play a little longer and start a different game. Reload and choose **Options → Recordings**. Look for the shots you took before pressing Print Screen as well as the later ones. Check that the current campaign checkpoint survives playback. Repeat with a shared-keyboard round in which both players fire on the same tick. Watch the cannons, listen for rebounds, and compare incoming bubbles and the final score with live play.

In **Options → Recordings → Import**, paste `tests/demo1.record` and play the training entry. Watch the opening shot fire at frame 27 and listen for the first wall rebound on frame 128. Check that an alpha.23 personal recording still plays. Return to the level editor and import a board to verify each paste dialog returns to the right screen.
