# Maps: from an adventure's pages to boards on the table

An adventure's battle maps become boards the game can put on the table, and every one lands in
the map library the DM browses. Three steps:

1. **`import_map.py`** reads a map image: finds the square grid and makes a first guess at what
   each square is. It writes a draft (JSON) and an overlay picture to check by eye.
2. **`draft_to_spec.py`** turns a draft (or the part of it that's one room) into a **map spec**:
   a plain-text `.map` file with the room as a 20 x 13 grid of characters. You (or Claude) finish
   it by hand: real pieces from the kit, the starts, and the spots worth going to.
3. **`build_maps.py`** checks every spec in `game/data/maps/` and compiles them into
   `game/data/map_library.lua`. `game/data/boards.lua` adds the library's boards to its own, so a
   location in `game/data/terrain.lua` can name one like any other board.

The importer is a first pass, not the finished map. The finishing is the part that matters:
the book's arrangement, in our own pieces and our own words. Never copy a book's text or art:
paraphrase it, and draw the map in our pieces.

## Commands

    python3 tools/maps/import_map.py PAGE.jpg --out DRAFT.json [--grid auto|PX|PX,OX,OY] [--crop x,y,w,h]
    python3 tools/maps/draft_to_spec.py DRAFT.json --out game/data/maps/ROOM.map \
            [--crop col,row,w,h] [--rotate auto|0|90|180|270] [--scale auto|1|2|3] [--id ID] [--title T] [--adventure ID]
    python3 tools/maps/build_maps.py              # check every spec and write the library
    python3 tools/maps/build_maps.py --check      # check only
    python3 tools/maps/build_maps.py --print ID   # one board as text: blocked squares, starts, spots
    python3 tools/maps/build_maps.py --maps DIR --out FILE.lua   # check specs kept somewhere else
    python3 tools/preview_boards.py --top OUT_DIR ID ...         # straight down, with the grid, starts and places
    python3 tools/preview_boards.py OUT_DIR ID ...               # from the table camera

Getting map images out of a PDF: `pdfimages -list BOOK.pdf` shows the full-page images; `pdfimages
-j -f PAGE -l PAGE BOOK.pdf out` pulls one out. `pdftotext -f PAGE -l PAGE BOOK.pdf -` gives the
page's words, for what each keyed spot is.

## import_map.py: the first pass

- **The grid.** For each column (and row) it counts how many rows have a sharp step there; a
  grid's lines run the whole map, so they stand out from the drawings. The spacing comes from the
  repeat in that count (autocorrelation), then a comb fit settles the square size to a twentieth
  of a pixel and where the lines fall. `--grid 142` gives the size and finds the lines;
  `--grid 142,12,30` gives all three.
- **The squares.** Each square's middle (its edges left out, so grid lines don't count) is
  measured: colour, brightness, texture, how much of it matches the background colour (the
  commonest colour in the outer ring of squares) and the floor colour (the commonest plain colour
  that isn't background). Then: outside, floor, wall, door, water, stairs (parallel treads),
  plants, object (anything drawn on the floor) or dark.
- **Second looks** with the neighbours in view: a line of dark squares along a floor is a wall,
  a dark blob a pit; a square in a wall line with wall on both sides is a door; a patch of grey
  "wall" out in the background is a clump of trees (grey-scale maps draw them that way).
- **Walls on the grid lines.** Most battle maps draw walls along the lines, not filling squares:
  each edge is checked for a band darker than the squares either side of it (`edges` in the
  draft, thick red in the overlay; doors orange).
- **The draft:** `grid` (size, ox, oy, cols, rows), `cells` (rows of class names), `confidence`,
  `edges` (`h`: rows+1 by cols, `v`: rows by cols+1, "wall"/"door"/""), `refs` (the colours it
  matched against), `text` (the classes as characters), and the overlay PNG beside it.

How good it is (October 30): on the three maps in *The Museum of Nightmares* the grid was found
exactly every time (141.4 to 142.4 px squares, every line on the tiles' seams). Floor and
background came out right nearly everywhere; walls drawn on the lines were mostly found, the thick
slanting octagon walls about half the time; every exhibit is just "object" (it can't tell a statue
from a jar); doors and stairs only some of the time (benches and the model city's rows read as
stairs). On a made-up colour dungeon map it got 398 of 408 squares right. Either way, finish it
by hand.

## draft_to_spec.py: a skeleton to finish

It crops the room out of the draft (`--crop` in the draft's squares; without it, everything that
isn't background), folds walls drawn on grid lines into the squares on the room's side, turns the
room so it fits the 20 x 13 mat (`--rotate auto` also prefers its doors on the west edge: the
party usually comes in from the west), blows a small room up (`--scale auto`: 2 x 2 or 3 x 3 per
square), and centres it. A room bigger than the mat is cut round its middle with a note: condense
it by hand, keeping its shape and its exhibits.

Walls become `wall_room`, doors `wall_door`, plants `bush`. Stairs, water, dark squares and
objects become `TODO_...` kinds, which the builder refuses until they're real pieces.

## The map spec (`.map`)

Plain text. Lines starting with `--` are comments. The header, then five sections.

    id: museum_chamber                 lower_case; the file is named after it (museum_chamber.map)
    title: The Chamber of Ancients     what the table calls the place
    light: candle                      day, candle, hearth, fire or dark
    adventure: museum                  which adventure it belongs to (the module's id)
    room: chamber                      the adventure's own id for the room (optional)
    source: adventure                  adventure: drawn by hand after its map; imported: the importer's draft
    credit: The Museum of Nightmares by Luke Russell (DMs Guild): the Area 1 map (3A-3H)
    about: The water puzzle: the jars, the tablet, the pedestal and its guardian.
    tags: indoor, museum, ground floor, puzzle
    order: 3                           where it comes in the adventure (the library's order)
    tight: yes                         optional: a cramped room (35% free squares instead of 60%)
    party: 7,4                         where everyone starts (x, y)
    foes: 9,9
    npc: 14,6
    npc_at: telpur 12,7                optional, repeatable: a named NPC's spot

**`grid:`** 13 rows of exactly 20 squares between bars, x 1-20 west to east, y 1-13 north to
south (the DM sits south). `.` is open floor, a space is outside the room (nobody may get there).
Every other character is in the legend.

    grid:
    |    #########//     |
    |    #.rl.o.Tl.//    |
    |    Db.........//   |
    ...

A block of one character is tiled into pieces from its north-west corner in reading order, so a
3 x 3 block of `~` is one 3 x 3 pond, and four `b` in a row are two 2 x 1 benches. A block that
doesn't tile exactly is an error.

**`legend:`** `char | kind | feature | turn`. The kind comes from the prop kit
(`game/data/props.lua`, made by `tools/gen_props.py`). Several characters can share a feature
(its parts). Turn is 0-3 (0 faces south; 1 west, 2 north, 3 east, as in `game/model/board.lua`)
or `auto` for one-square pieces: a wall turns its back to the mat's edge, the outside or the next
wall and faces the open floor; a `wall_diag` closes whichever corner its closed sides make (0
north-west, 1 north-east, 2 south-east, 3 south-west); a straight run of auto walls lines up on
one edge.

    legend:
    -- char | kind         | feature   | turn
    #       | wall_room    | walls     | auto
    /       | wall_diag    | walls     | auto
    D       | wall_door    | doors     | auto
    j       | canopic_jars | jackal    |

**`pieces:`** pieces placed by their north-west square instead of drawn: `feature | kind | x,y |
turn`. For whole-mat floors and anything lying under other pieces (a rug).

    pieces:
    floor | floor_marble | 1,1 |

**`features:`** `id | flags | words | say`, in the order the DM sets them down (features not
listed follow, in the order they're first used). Flags: `base` (goes down with the place itself:
the floor, the walls, the doors) and `own_words` (only these words, not the kit's). Words: what
the DM might call it in a line, comma separated. Say: how the DM names it when setting out the
rest (plain, short, ours).

    features:
    floor  | base      | floor, sand, dust      | a marble floor dusted with sand
    jackal | own_words | jackal, jug, small jug | a small clay jug with a jackal on it

**`spots:`** the places in the room worth going to: `key | x,y | name | one line`. Give every
room a handful. Use the book's keys where it has them (3A, 3B...), each on a free square beside
the thing it's about, with one plain line in our own words. The game walks heroes to them and
lets the table choose among them.

    spots:
    3A | 10,6 | the pedestal | A raised stand with a button carved like a woman.

## What the builder checks

Every kind is in the kit (`--lenient` accepts the kinds listed in `mapspec.EXPECTED` while new
pieces are on their way into the kit); every piece is on the mat; nothing stands in anything else
(floors, paths and rugs may lie under things); the starts and every spot are on free squares;
the party can walk to the foes (eight ways, as the battle rules move; a shut door is a wall here,
as in `tools/tests/board_check.lua`) and to every spot (doors open for that); nobody can walk
outside the room (a slanting wall needs two layers of `wall_diag`, or a step through the corner
gets out); enough free squares to fight in; a base feature; words for every feature; and, for the
museum, none of the old story's words (`adventure.FOREIGN`) in anything the table hears.

## What it writes

`game/data/map_library.lua` returns `{ boards = { [id] = board }, order = { ids } }`. A board is
the `boards.lua` shape (title, light, party, npc, foes, features) plus:

    adventure = "museum", room = "chamber", order = 3,
    source = "adventure", credit = "...", about = "...", tags = { ... },
    places = {
        { id = "3A", x = 10, y = 6, name = "the pedestal", near = { "pedestal" },
          line = "A raised stand with a button carved like a woman..." },
    },

`places` are the spec's spots (named `places` so they aren't confused with `board.compile`'s
`spots`, the squares a hero walks to when a feature drops in); `near` lists the features beside
each one (not the floor, walls or paths).

## House style for the boards

- The DM sits south: tall things (walls, shelves, paintings) along the north edge. The south wall
  is left off so the room shows from the DM's seat; walls run along the north, west and east
  edges, slanting corners at all four. Something set against the south side stays low.
- The party comes in from the west where the room allows it: turn the room, and say so in the
  spec's comment.
- Keep the book's arrangement (where the doors are, what stands where), stretched or condensed to
  the mat. Paintings and tapestries are wall segments: on a slanting wall they sit in a short
  straight stretch.
- The museum's boards (`game/data/maps/museum_*.map`) are worked examples of all of this.
