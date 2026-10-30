# Step by step, October 26

> Set aside on October 29: the current build is the October 20 version plus a prototype notice. This rework lives on the `step-by-step` branch.

The pre-session menus were full pages with everything at once. Now setting up a campaign and each week's prep ask one thing at a time, at the table with your friends in view. Duplicates are merged: the campaign planner, Session Zero and the backstories are one walk; the notebook's "This week" page is part of prep.

## The frame

- One question per step, its choices below it, Back and Next (or Enter). Next waits until the step is answered. There is no skip button: every step is walked.
- A top bar shows where you are: the sections (the current one in gold, finished ones ticked, any reachable one clickable), "Step n of m", and the Chill mode switch.
- The room stays in view above a panel along the bottom. Your friends react in bubbles over their heads: speech for what they say, thought bubbles (with a trail of dots) for what they're thinking. They also sit the way they feel: leaning in, cheering, arms folded, or on their phone.
- The route step needs the whole screen for the valley map, so it uses a full-screen layout.

## Setting up a campaign

1. **The campaign:** who's at the table, the style, three truths, the second front, the dice.
2. **Session Zero:** the tone, each player's ask (agree or push back), then the table rules one at a time (X-card, dice, rulings, session length, death).
3. **Backstories, per player:** your questions (their answers appear in their bubble), their idea for their past, and what turns up first.
4. **Ready:** whose stories come first (for a full table), then a summary of what everyone agreed.

A player who joins a small table later gets the same steps for their backstory, then a welcome.

## The week's prep

- **This week**
  - **The story so far:** where the story stands, each scene in a line (click one for its storyline's log), what they're out to do, what's new, and what only you know.
  - **Recap in their heads:** each hero thinks about the moment from last session they'd remember, and how their own story stands (warm, going cold, dropped, resolved).
  - **The group chat:** everyone's latest post over their heads; theories to answer or make true; private messages beside them.
  - **How's everyone doing?:** their notes, warnings, mood, Goodwill and long-term bars. Coffee (2 hours) is here.
  - **The world:** each faction's move, one step each: let it happen, bring it on screen, or hold it.
  - **Level up** (when it's earned), **who the session is for**, **who shows up**, and **an evening off for ideas**.
- **The route:** stop 1, 2 and 3 on the valley map, or an open scene. Every place in play is also listed under the map.
- **Each stop:** what kind of scene, then who's there, what they're after, what gets in the way, and what they can win. Each slot is picked from your hand or left to improvise. Combat stops get a fight step. A published adventure asks only whether to recast its person and swap its reward.
- **Before the night:** plant a seed (or not), then "Ready for Thursday?": each stop at a glance, what's worth knowing (the table clock, pacing, storylines, Session Zero flags, what's still open), and their thoughts about Thursday. The last button runs game night.

The first prep tips are gone. Each step says what it is for, and your friends say the rest.

## Chill mode

Off by default. With it off, you read your friends from what they say, what they think and how they sit:

- no green or red faces on choices;
- no dots on hand cards;
- no "would love it" lines in hovers;
- no coloured bubble edges.

Chill mode turns all of these back on: on scene types, hand cards, Session Zero's options and game night's calls. The switch is on the title screen and at the top right of every step. The game remembers the setting between launches.

## Game night's bubbles

Lines stay up about half again as long. When someone says something new, it appears over their head, and their previous line slides up above it and fades out.

## Code

- `game/ui/steps.lua`: the frame
- `game/ui/setup_view.lua`: setting up
- `game/ui/prep_steps.lua`: the week
- `game/ui/prefs.lua`: Chill mode
- `game/data/setup_talk.lua`: what they say
- Removed: the prep board's layout, the planner, Session Zero and backstory screens, the notebook's "This week" page, and the "Previously on" panel
