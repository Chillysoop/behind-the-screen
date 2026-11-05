-- The book's structure, as data (docs/design/2026-11-05-root-causes.md, class 4: book fidelity).
--
-- The museum was imported room by room as our own paraphrase, and nothing kept the book's structure:
-- what the players can see on walking in, what the DM keeps secret, what wakes what, where everyone
-- starts, which doors are locked, what each thing does. This file is that structure, one room at a
-- time, each fact with the page it's on in the reader's own PDF of *The Museum of Nightmares* (Luke
-- Russell, DMs Guild): page numbers only, and every word here is ours, never the book's.
-- tools/tests/book_check.lua checks the module, its cards, the maps and whole prologues against it.
--
-- Per room:
--   pages     the pages the room is on
--   map       its board in game/data/map_library.lua
--   sees      what the players can see on walking in (nothing more is said as the room opens)
--   secrets   what the DM knows and the table doesn't yet: `words` that give it away, `reveal` what lets
--             it be said ("fight": the foes have shown themselves, as the fight opens; "moment": the moment
--             that shows it), `shows` the words of a line that is that moment (a knight climbing out)
--   foes      who fights here: their cast card, how they `start` ("prop": looks like part of the room;
--             "painting": a picture until it climbs out; "hidden": out of sight; "still": plainly a machine,
--             standing still; "awake"), what `wakes`
--             them ("attack": they strike when nobody expects it; "steal": someone robs what they
--             guard; "inspect": someone looks closely; "enter": walking in; "approach": getting close;
--             "code": the right words), and where they are (`at`: a place on the board, or a place per
--             creature, `anchor` the map spec's anchor that stands them there)
--   people    who's here and not fighting: cast card, place, anchor
--   doors     a door's place on the board and whether it starts locked
--   traps     what bites, and where: `dc` the book's, `game` the moment that plays it; `ours = true` for the
--             game's own (the small finds and traps of looking round a room), with what the book has instead
--   items     what's here to take, by its place: `paint` (it counts as paint), what the book gives it,
--             and the game's own item it became; `ours = true` where the game added something the book
--             doesn't have (said, so a fix doesn't take it for the book's)

local M = {}

M.SOURCE = "The Museum of Nightmares by Luke Russell (DMs Guild): page numbers in the reader's own PDF"

M.rooms = {
    garden = {
        pages = { 8, 10 }, map = "museum_garden",
        sees = "a whole garden inside the caravan, a pond, a little iron plaque, hedges clipped into beasts, the museum's great doors",
        secrets = {
            { what = "three of the clipped beasts are living guardians of thorn, and they attack", page = 10, reveal = "fight",
              words = { "Briar", "aren't hedges", "not hedges", "shake themselves awake", "come alive", "guardians" },
              shows = { "shake themselves", "tear free", "uproot" } },
            { what = "something in the pond lashes out at anyone who comes within five feet", page = 10, reveal = "moment",
              words = { "tentacle" } },
        },
        foes = {
            { cast = "mus_briar", starts = "prop", wakes = "attack", page = 10,
              at = { briar_triceratops = "1B", briar_boar = "1C", briar_beast = "1D" } },
        },
        props = { { place = "1E", what = "a fourth hedge-cat that's only ever a hedge", page = 10 } },
        doors = { { place = "doors", locked = false, page = 11 } },
        traps = { { place = "pond", what = "the pond's tentacles: a Dexterity save (DC 10) or a little slashing damage", page = 10,
                    dc = 10, game = "mus_pond" } },
    },
    entrance = {
        pages = { 11, 12 }, map = "museum_entrance",
        sees = "marble, a chandelier's blue light, a glass donation case, two doors at the far end and a metal statue between them",
        secrets = {
            { what = "the statue is a guardian that wakes only if someone tries to break into the case", page = 11, reveal = "fight",
              words = { "Sentinel", "hasn't moved", "Yet.", "wakes if", "comes to life" },
              shows = { "steps down" } },
        },
        foes = { { cast = "mus_sentinel", starts = "prop", wakes = "steal", page = 11, at = "2A", anchor = "foes" } },
        doors = { { place = "front", locked = false, page = 11 } },
    },
    chamber = {
        pages = { 12, 14 }, map = "museum_chamber",
        sees = "sandstone, hot wind, a guardian of gold and bone in the middle, jars, a cracked tablet",
        foes = { { cast = "mus_bone_construct", starts = "awake", wakes = "enter", page = 12, at = "3B", anchor = "foes" } },
        traps = { { place = "3H", what = "the crocodile's jaw snaps shut on a hand", page = 13, ours = true,
                    book = "the jaw is a lever that opens a tap; nothing bites" } },
        items = {
            { place = "3D", what = "two curved daggers whose rings are locked together", page = 13,
              book = "an artefact of the room; the book gives them no powers", game = "twin_daggers", ours = true,
              note = "The game made them an uncommon magic weapon (+1 to hit and damage). The book's only reward for the artefacts is a Franc for putting them back." },
            { place = "3F", what = "a notebook of notes on the old glyphs", page = 13, book = "helps read the tablet" },
        },
    },
    paintings = {
        pages = { 14, 16 }, map = "museum_paintings",
        sees = "a long hall hung with paintings, a smell of damp paint, one painting dominating the far end",
        secrets = {
            { what = "the knight in the far painting is a living painting that climbs out and fights if inspected", page = 15, reveal = "fight",
              words = { "Knight of Shades", "climbs out", "so lifelike it almost breathes", "comes to life" },
              shows = { "climbs out" } },
        },
        foes = { { cast = "mus_knight", starts = "painting", wakes = "inspect", page = 15, at = "4K", anchor = "foes" } },
        items = {
            { place = "4A", what = "the white-haired elf in a snowfield: a scimitar", paint = true, page = 14,
              trap = "the cold: a Constitution save (DC 12) or a little cold damage" },
            { place = "4B", what = "the red-bearded king: a whetstone that paints one weapon", paint = true, page = 14 },
            { place = "4C", what = "the dice game: a set of odd dice", paint = false, page = 14 },
            { place = "4F", what = "the unknown lady: nothing to take", paint = false, empty = true, page = 15 },
            { place = "4G", what = "the warrior on the bridge: his blade, a dagger", paint = true, page = 15,
              trap = "his blade: a Dexterity save (DC 12) or slashing damage" },
            { place = "4H", what = "the empty throne: a glass of blood", paint = false, page = 15 },
            { place = "4I", what = "the ship and the squid: a keg of powder", paint = true, page = 15 },
            { place = "4J", what = "the duellist: a pistol", paint = true, page = 15 },
        },
        -- (The game hangs one painting per hero: game/data/museum/module.lua's portraits, by friend.)
        portraits = { mara = "4F", dev = "4G", jess = "4J", sam = "4H", default = "4A" },
    },
    gift_shop = {
        pages = { 16, 17 }, map = "museum_gift_shop",
        sees = "a little shop, shelves, a boot on the counter",
        people = { { cast = "mus_telpur", place = "5A", anchor = "npc", page = 16, what = "a boot with a demon in it, on his counter" } },
        items = {
            { what = "the vorpal sword the DM promised in the group chat", page = 17, game = "vorpal_sword", ours = true,
              book = "nothing like it: the book's shop sells keepsakes and small wonders for Francs",
              note = "The game's own: the friends ask about it in the chat before the night, and the player (as DM) can promise it. It's a payoff for that promise, not the book's." },
        },
    },
    hunting = {
        pages = { 18, 20 }, map = "museum_hunting",
        sees = "a big floor of dioramas, stuffed beasts and exhibits under a high roof",
        secrets = {
            { what = "five pack hunters hide among the exhibits: two in the jungle, two in the cave model, one posing as a statue by the big bird",
              page = 20, reveal = "fight", words = { "huntling", "Huntling", "kruthik", "Kruthik", "hiding in the dioramas" },
              shows = { "spring the trap", "spring their trap" } },
        },
        foes = { { cast = "mus_huntlings", starts = "hidden", wakes = "approach", page = 20, at = { "6F", "6I", "6C" }, anchor = "foes" } },
        traps = { { place = "6F", what = "a vine snare in the jungle", page = 20, ours = true,
                    book = "the jungle hides two of the pack; no snare" } },
    },
    offices = {
        pages = { 20, 22 }, map = "museum_offices",
        sees = "two studies off the hunting floor: one open, with a bird under a glass dome; one with its door shut",
        secrets = {
            { what = "the archivist is dead at his desk behind the locked door, his notebook beside him", page = 21, reveal = "moment",
              words = { "corpse", "dead archivist", "carved eyes" } },
        },
        people = { { cast = nil, place = "7B", anchor = "npc", page = 21, what = "the archivist, long dead at his desk" } },
        doors = { { place = "door", locked = true, page = 21 } },
    },
    tomorrow = {
        pages = { 22, 23 }, map = "museum_tomorrow",
        sees = "neon, static, a cheerful voice from the ceiling that names the Steam Mech, and the brass war machine itself, standing still",
        foes = { { cast = "mus_mech", starts = "still", wakes = "code", page = 23, at = "8A", anchor = "npc" } },
    },
    lecture = {
        pages = { 23, 24 }, map = "museum_lecture",
        sees = "old benches, dust, and a ghost lecturing from behind a lectern with a blackboard behind him",
        foes = { { cast = "mus_lecturer", starts = "awake", wakes = "enter", page = 24, at = "9A", anchor = "npc" } },
    },
    lair = {
        pages = { 25, 27 }, map = "museum_lair",
        sees = "a temple of mosaics and broken pottery, and Euryale waiting as their host",
        foes = { { cast = "mus_euryale", starts = "awake", wakes = "talk", page = 25, at = "10A", anchor = "foes" } },
        rules = { { what = "she fights hooded with her bow, and drops the hood at half her hit points; only then can she turn them to stone", page = 26 } },
    },
}

-- What the friends can't know until the table's heard it (the knowledge playtest of November 5): a friend line
-- with one of a fact's `words` needs a line said to the table before it with one of its `told_by`
-- (tools/tests/knowledge_check.lua, FACTS). Book pages where the book keeps it for the DM, or says what shows it.
M.facts = {
    { id = "the ritual", page = 13, words = { "ritual" }, told_by = { "ritual" } },
    { id = "her sisters, trapped", page = 27, words = { "her sisters" }, told_by = { "her sisters" } },
    { id = "who's upstairs", page = 16, words = { "whatever's upstairs", "about upstairs", "for upstairs", "what's upstairs is" },
      told_by = { "upstairs is", "what is upstairs", "what's upstairs" } },
    { id = "her drink", page = 25, words = { "drink anything", "don't drink", "nobody drink" },
      told_by = { "have a drink", "have a glass", "a drink", "pours" } },
    { id = "the drone makes you sit", page = 37, words = { "sit down" }, told_by = { "on the benches", "sit." } },
    { id = "the bird's name", page = 21, words = { "mythril" }, told_by = { "mythril" } },
    { id = "the bird's six wings", page = 21, words = { "six wings" }, told_by = { "six wings", "six wing" } },
    { id = "the sunken city", page = 22, words = { "map of the sea", "under the sea", "sunken" },
      told_by = { "under the sea", "sunken city", "beneath the sea" } },
    { id = "Telpur's claim", page = 17, words = { "demon" }, told_by = { "demon", "underworld", "duke" } },
    { id = "the pack", page = 20, words = { "in packs", "hunts in packs" }, told_by = { "pack hunters", "a pack of", "hunt together" } },
    -- (Once they know she's a Gorgon, that gorgons come in threes is old stories, for a History roll to recall.)
    { id = "her sisters, three", page = 27, words = { "in threes" }, told_by = { "three sisters", "gorgon" } },
    { id = "the pond's tentacles", page = 10, words = { "tentacle" }, told_by = { "tentacle" } },
    { id = "the pedestal", page = 13, words = { "pedestal" }, told_by = { "pedestal" } },
    { id = "the jackal jug", page = 13, words = { "jackal" }, told_by = { "jackal" } },
    { id = "the falcon jug", page = 13, words = { "falcon" }, told_by = { "falcon" } },
    { id = "the killings", page = 6, words = { "killing people", "killed people" },
      told_by = { "killed", "never came out", "didn't come out", "never came back" } },
    { id = "her stare", page = 35, words = { "look at her eyes", "her stare", "her gaze", "meet her eyes" },
      told_by = { "gorgon", "turned to stone", "to stone", "her eyes" } },
    { id = "the blackboard", page = 24, words = { "blackboard" }, told_by = { "blackboard", "chalk" } },
    { id = "the window blankets", page = 24, words = { "blanket" }, told_by = { "blanket" } },
    { id = "the cleaning cupboard", page = 16, words = { "cleaning cupboard" }, told_by = { "cupboard" } },
    { id = "the red-bearded king", page = 14, words = { "dwarf king", "red-bearded", "his beard" }, told_by = { "king" } },
    { id = "the ship painting", page = 15, words = { "stormy sea" }, told_by = { "sea", "ship" } },
    { id = "the notes put readers to sleep", page = 24, words = { "to sleep with the", "put her to sleep", "send her to sleep" },
      told_by = { "asleep", "yawns", "sleep" } },
    { id = "the archivist's desk", page = 21, words = { "his desk" }, told_by = { "desk" } },
    { id = "the archivist's body", page = 21, words = { "that body", "the body" }, told_by = { "body", "slumped", "corpse", "dead" } },
    { id = "the painting of five", page = 14, words = { "painting of us" }, told_by = { "five people", "rolling dice" } },
}

-- Names the book keeps (tools/tests/book_check.lua, NAMES): `labels`, what the DM calls things that the table
-- never hears (the book's read-alouds say a black knight, strange armoured creatures, a guardian, a statue,
-- bushes); `secret`, a name the table hears first in the line that tells it, with what that line says.
M.names = {
    labels = { { word = "Knight of Shades", page = 15 }, { word = "kruthik", page = 20 }, { word = "huntling", page = 20 },
               { word = "briar", page = 10 }, { word = "Bone Construct", page = 12 }, { word = "Sentinel", page = 11 } },
    secret = {
        { word = "Euryale", page = 6, told_by = { "called Euryale", "her name is euryale", "euryale, a gorgon", "a gorgon. euryale" } },
        { word = "Gorgon", page = 6, told_by = { "a gorgon called", "euryale, a gorgon", "a gorgon in a jar", "she's a gorgon", "a gorgon.",
                                                 "snakes" } },
    },
}

return M
