# Dialogue Desk

A page for reading every line the adventure can say beside the book, editing lines, and sending the
edits back into the game.

- `export.lua` makes `dialogue.json`: every line, with its file, its place in the data, its room,
  who says it, and what kind of line it is. The book's text is never in it: the page opens the
  reader's own PDF in their browser and shows the room's pages there.
- `desk.html` is the page (published as a claude.ai artifact, with `dialogue.json` beside it). Edits
  are saved to the page's database, one document per line, under `edits/`.
- `collect.py` merges the saved edits (read into a folder) into one list; `apply.py` writes them
  into the data files, only where the old line appears exactly once, and reports what it skipped.

The loop, when Conner says "apply my dialogue edits":

1. Read the desk's `edits` collection into a folder.
2. `python3 tools/dialogue/collect.py <folder> edits.json`
3. `python3 tools/dialogue/apply.py edits.json --check`, then without `--check`.
4. Run the checks (truth, smoke), commit, and mark each applied edit `status: "applied"` on the desk.
5. Re-run `lua tools/dialogue/export.lua dialogue.json` and republish the desk, so it shows the lines
   as they now are.

For another adventure: change `ADV_FILES` and `BOOK_PAGES` in `export.lua`.
