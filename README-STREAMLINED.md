# Behind the Screen - Streamlined

A separate, guided edition of the existing Defold game. You are the DM for Mara,
Dev, Jess, and Sam through the four opening episodes of **The Silent Bells**.
The original campaign remains available in an ordinary build; this edition is
selected by `tools/build/streamlined.ini` and uses its own save directory.

## Play

For Windows, extract the entire `Behind-the-Screen-Streamlined-windows.zip`
package and open the executable inside. Keep the bundled files together.

The game introduces the friends and the adventure as you play. Each session has:

1. A choice of whose personal story to feature.
2. One signature twist to add to the prepared adventure.
3. Four contextual DM calls, with outcomes and reactions from the table.
4. An automatic recap and a hook for the next session. The fourth ends in a
   campaign scrapbook instead of another planning step.

The four episodes are **Strangers at the Kettle**, **The Road Out**, **Old Debts**,
and **Up the Bell Tower**. Choices establish facts, relationships, allies,
complications, and callbacks. Checks state their stakes and show the actual die,
modifier, and target. Combat uses the existing rules engine and plays a short
tabletop replay; the player can move on when ready.

### Controls

| Control | Action |
| --- | --- |
| Mouse | Select an on-screen choice or button. |
| 1, 2, 3 | Choose the corresponding option. |
| Up / Down, then Enter | Select and confirm an option. |
| Enter | Continue after a result; during a fight, finish the replay. |
| Space | Continue a result or step through combat playback. |
| F / G | Speed up or slow down combat playback. |
| Esc | Open or close the pause menu. |
| S | Open the record of your campaign. |
| M | Toggle music. |

Progress saves after decisions and transitions, so quitting mid-session returns
to the current moment without rerolling the outcome. Beginning another campaign
asks for confirmation.

## What changed

This edition replaces manual route, scene, card-slot, and encounter construction
with prepared episodes. There is no prep-hour budget, card-fit puzzle, recurring
faction approval, expiring seed queue, background story decay, social-meter
dashboard, or Empathy information gate. Dormant personal stories wait safely.

The player keeps authorship through the personal focus, substantial twist,
contextual improvisation, NPC intent, player theories, fair stakes, and lasting
consequences. The cast, room, boards, minis, portraits, music, and combat rules
come from the original game. Milestones and keepsakes arrive through play.

The new campaign does not call the old prep, social-maintenance, or storyline
decay models. Reducing the interface therefore also removes their hidden costs.

## Independent saves and builds

- Classic saves remain under `behind_the_screen`.
- Streamlined saves use `behind_the_screen_streamlined/campaign.json` in the
  platform's normal application-data directory.
- The current verified save, its previous backup, and an interrupted temporary
  save are considered during recovery.
- The two formats are deliberately separate. Starting the streamlined campaign
  does not convert or overwrite a classic campaign.
- Native test automation uses a separate `autotest_campaign.json`.

`game/game.gui_script` selects the new controller only when
`streamlined.enabled = 1`. The build settings also give the application a distinct
title and version. Build outputs and ZIP packages live under `dist/streamlined/`.

## Build from source

Use official Defold **1.13.2** Bob and **Java 25**:

```sh
python3 tools/build/build_streamlined.py \
  --bob /path/to/bob.jar \
  --java /path/to/java \
  --target windows
```

Use `--target linux` or `--target html5` for other targets. The HTML5 package
includes a local server because a WebAssembly game must be served over HTTP.
See [the build guide](tools/build/README.md) for details.

## Implementation and checks

| File | Responsibility |
| --- | --- |
| `game/data/guided_episodes.lua` | The authored four-episode campaign and options. |
| `game/model/guided.lua` | Deterministic, engine-free campaign state and outcomes. |
| `game/ui/guided_app.lua` | Native controller, table playback, and independent saving. |
| `game/ui/guided_view.lua` | The concise interface, reactions, and scrapbook. |
| `tools/tests/guided_check.lua` | Branches, decision budget, persistence, dice, battles, and malformed saves. |
| `tools/tests/guided_gui_smoke.lua` | The real GUI entry point with strict engine mocks, full campaign, and resume. |

```sh
lua tools/tests/guided_check.lua
lua tools/tests/guided_gui_smoke.lua 1
python3 tools/tests/require_check.py
python3 tools/validate.py
```

The six existing GUI smoke seeds continue to cover the classic route. A native
autoplay can be enabled for development with `streamlined.autotest = 1`; release
packaging rejects a compiled game with that setting enabled.

The content and timing remain a first playable redesign. Automated correctness
checks are not a substitute for watching beginner and experienced DMs play it.

## Credits

The original project's SRD 5.2.1 attribution and font licenses still apply.
Playable packages include `CREDITS.txt` and the font licenses. See the main
[README](README.md) for the original game and its rules implementation.
