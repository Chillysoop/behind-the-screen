# Dialogue Desk

A page for reading every line the adventure can say beside the book, editing lines, and sending the
edits back into the game.

- `export.lua` makes `dialogue.json`: every line, with its file, its place in the data, its room,
  who says it, and what kind of line it is. The book's text is never in it: the page opens the
  reader's own PDF in their browser and shows the room's pages there. It reads the adventure's data,
  the shared data, the friends' table talk, and a few tables of lines kept in the code beside what
  uses them (`CODE_TABLES`: looking round, why a friend leans one way, the break, reacting before a
  fight; each module exposes its table as a field). Small moments are listed once, under their own
  file, though the module pulls them in.
- `when.lua` (used by `export.lua`) adds two fields to every line: `when`, one plain sentence on when
  it's said (the room, the card or moment by its title, the condition), and `odds`, how sure it is:
  "Always", "1 of N", "Your pick" (an option you choose from), "If chosen" (what follows a pick),
  "On a success" / "On a failure", "Sometimes", or "Never" (the data is there, but nothing in the
  museum shows it; the sentence says why). Its rules are keyed on the line's file and the shape of
  its path, each read off the code that uses that data; a line no rule matches gets a fallback with
  "Sometimes", and the export prints how many lines matched a rule. A new adventure's data needs its
  own rules here, beside the museum's.
- `desk.html` is the page (published as a claude.ai artifact, with `dialogue.json` beside it). Edits
  are saved to the page's database, one document per line, under `edits/`.
- `reach.lua` and `reach_match.py` check which lines can actually play: `reach.lua` runs whole prologues
  headless and records every line dealt and every piece of text shown; `reach_match.py` marks each
  exported line seen or not, grouped by where it lives. Re-run both when a new adventure arrives,
  before trusting the desk's list.
- `collect.py` merges the saved edits (read into a folder) into one list; `apply.py` writes them
  into the data files, only where the old line appears exactly once, and reports what it skipped.

The loop, when Conner says "apply my dialogue edits":

1. Read the desk's `edits` collection into a folder.
2. `python3 tools/dialogue/collect.py <folder> edits.json`
3. `python3 tools/dialogue/apply.py edits.json --check`, then without `--check`.
4. Run the checks (truth, smoke), commit, and mark each applied edit `status: "applied"` on the desk.
5. Re-run `lua tools/dialogue/export.lua dialogue.json` and republish the desk, so it shows the lines
   as they now are.

For another adventure: change `ADV_FILES`, `CODE_TABLES` and `BOOK_PAGES` in `export.lua`, and add its rules
to `when.lua`.
