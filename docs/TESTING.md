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
9. Create a connected level, save, test, publish, browse from the other client, download, and play. Confirm offline requests expire, corrupt codes fail, and republishing requires a click.
10. Use `/fb debug`, then log out or `/reload` to flush `FrozenBubbleDB.debugLog`. Report errors with the client build, UI scale, relevant log entries, and which of the above steps failed.

11. In Settings → AddOns → Frozen Bubble Forever, toggle the minimap button and colorblind symbols. Check the board, current and next bubbles, and editor palette. Drag the icon, reload, and check that its position and settings persist.
12. Set the idle delay to 60 seconds. Walk before it expires, then queue several crafts while standing still. Check that a single invitation appears after the new interval and Later dismisses it for that idle period. Try the same batch with crafting invitations disabled. Check a taxi ride, landing, and combat with a prompt showing.
13. Drag a line across the editor, undo it, and repeat with right-drag. Test an unsaved draft and return with Edit level. Check the title, colors and grid at two UI scales.
14. During a solo game, let the window fade and return to it. Listen for the same place in the track. After several ceiling drops, inspect the piston shafts from the screen edge down to the compressor.

14. Queue with chain reactions selected on one client and standard rules on the other. Then select chains on both and play a round. Follow a shot from launch on the left board, watch a return flight hit another group, and check penalties after each clear. At the end, compare the freeze order, winning penguin, and winner’s name on both clients.

15. Open Highscores with the main menu arrow keys and Enter. Check the thumbnail and time of a campaign entry, toggle colorblind symbols, view both training columns, and use Share best from each column. On a second account, refresh the shared table and compare the level and clear marker.


For an arena test, host a room and join it from two to four other characters. Check that each character sees their own board in the center, that F1–F4 target the opponent in the corresponding corner, and that F10 resumes split penalties. Leave one board full and verify that its player can watch the survivors. Check room chat, guest departure, combat, and a rematch to the chosen victory limit.
