# Roadmap phase 1: the fixes Conner said yes to

Game: "Behind the Screen" (Defold/Lua), a cozy game where you are the DM for four simulated friends. The only game
in the code is now the museum prologue (*The Museum of Nightmares*, run in the adventure/module format). Read
`AGENTS.md` in your worktree first: ground rules (engine-free model code, no require cycles, no globals, plain warm
player text, "say only what's true", "therefore or but, never and then", never copy the book's text).

## Where you work
- Your own git worktree and branch (given in your prompt), made from `v2-museum` at e691363. Run everything from
  your worktree root. Don't touch `/home/claude/behind-the-screen` (the main checkout) or the other agent's worktree.
- Another agent is fixing a different set of items at the same time, in its own worktree. Stay inside your own items.
  If one of your fixes needs a change in an area the other agent owns, make the smallest change that works and say
  so in your report. Their items are listed in your prompt.
- Don't edit `AGENTS.md`, `README.md` or `docs/OVERVIEW.md` (both agents would conflict there). Put the doc lines you'd
  add in your report and I'll write them when I merge.

## What to fix
Conner reviewed the round-two playtest findings and said yes to each item. The full text of every item (what we saw,
the fix, and examples from the logs) is in the page source:
`/tmp/claude-0/-home-claude/6545778f-6f8d-5d88-b2f4-2abfe14c8e6f/scratchpad/roadmap_desk/index.html`, in `SECTIONS`
(search for `id: "F12"` and so on). The fix text is what he approved: do that, or better if the code shows a better way
to reach the same result, and say why.

Evidence:
- Round-two session logs (made just before the November 4 purge; the museum content is the same):
  `/tmp/claude-0/-home-claude/6545778f-6f8d-5d88-b2f4-2abfe14c8e6f/scratchpad/playlogs2/prologue_2*.txt`.
- Make your own: `lua tools/sim/museum.lua <seed> <careful|random|careless> log` prints every line the table hears.
  `DUMP_DIR=out lua tools/tests/museum_smoke.lua <seed>` writes every screen's nodes.
- The book's text, for checking where things are in it (private reference only; paraphrase, never copy a sentence):
  `/tmp/claude-0/-home-claude/6545778f-6f8d-5d88-b2f4-2abfe14c8e6f/scratchpad/book/museum.txt`.

Every fix gets a check that keeps it fixed: add cases to your own new test file (named in your prompt), in the style
of `tools/tests/playtest_nov3_check.lua` (whole prologues over several seeds, each fix seen in play, plus targeted
unit cases), and add to `tools/tests/museum_truth.lua` where a line asserting an outcome must read it from state.
A check must fail on the old code: confirm that for each one, for example by running the new check against the code at
e691363 (copy the test file into a throwaway `git worktree` at that commit), and say in your report how you confirmed it.

## Rules
- **2 CPUs, shared with the other agent.** Never run more than one heavy job at a time (one smoke seed, one sim, one
  test file). Never run `allchecks.sh` or loops in parallel. While working: one smoke seed, one sim, require_check,
  validate. Before you finish, run sequentially:
      for s in 1 2 3 4 5 6 7 8; do lua tools/tests/museum_smoke.lua $s || break; done
      for st in careful random careless; do for s in 1 2 3 4; do lua tools/sim/museum.lua $s $st || break; done; done
      lua tools/tests/museum_truth.lua; lua tools/tests/playtest_nov3_check.lua 4; lua tools/tests/table_life_check.lua 2
      lua tools/tests/save_check.lua; your own check file; and the tests for the areas you touched (README lists them)
      python3 tools/tests/require_check.py; python3 tools/validate.py
  Every check that passed before must still pass. `lua` is LuaTeX's texlua: always run script files (`lua -e` doesn't work).
- Museum saves must keep loading (FORMAT 2, `museum_save.txt` and the slots). New campaign state must be nil-safe for
  saves made before it existed; if you move data, migrate it in `game/model/save.lua` and cover it in save_check.
- Generated files (main/main.collection, main/props/, main/board/, main/scene_data.lua, game/ui/metrics.lua, meshes,
  textures) come from tools/*.py: change the generator and rerun it, never hand-edit.
- Don't change game/rules/ (the SRD rules engine) unless an item is about a rules bug there (F19 may be), and then
  add a case to tools/tests/rules_cases.lua.
- Player-facing text: short sentences, everyday words, warm, true to what happened. Our own words, never the book's.
- Commit in small coherent steps, each passing at least one smoke seed, one sim, require_check and validate. Message: a
  plain summary sentence (house style: see `git log`). End every commit message with exactly:
      Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
      Claude-Session: https://claude.ai/code/session_01NMxtsUUe88UPh7yTAc4fGU
  Push with `git push -q origin <your branch>`. Don't merge into v2-museum; I do that.
- Never `rm` with a glob after `cd`. Don't use `pkill -f` patterns that could match your own shell. Don't use bare
  `git stash` (the stash is shared between worktrees).

## Report back
For each item: what you changed (files), how you verified it (which check, and that it failed before), and anything
left or uncertain. Then: doc lines for README/AGENTS, the gate results, and anything you noticed that's broken but not
yours (don't fix it, list it).
