# The November 4 playtests and fixes

What the third playtest found, how the fixes were split and what each batch reported, and what the confirming playtest
found after them. Kept so the work can be picked up again, and for the review of every bug class before the longer
campaign (what to prevent at the source).

- `plans/`: the briefs the fix batches worked from (BRIEF, ROUND3, FINAL), the playtesters' brief (PLAYTEST) and the
  wave 2 design notes.
- `round3-reviews/`: the third playtest's five reviews (careful DM, random DM, alive, the screens, the engine).
- `round3-fix-reports/`: the four round-three batches' reports, the merge's, and the leftovers pass.
- `confirming-reviews/`: the confirming playtest's four reviews of r3-int (truth, alive, screens, engine).

The final pass (FINAL.md: f-facts, f-words, f-screens) was stopped by the usage limit; each branch holds a pushed
work-in-progress commit on top of r3-int at bfa5157, not yet checked. The paths inside these files point at the session's
scratch folder, which may be gone; the logs they quote can be remade with `lua tools/sim/museum.lua <seed> <style> log`.
