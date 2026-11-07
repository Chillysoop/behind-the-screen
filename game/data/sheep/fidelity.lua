-- The book's structure, as data (root-causes class 4; the fields are game/data/museum/fidelity.lua's), for *The Wild
-- Sheep Chase* (Richard Jansen-Parkes, DMs Guild) and the Bogden Road Country Inn sheet. Page numbers only ("inn" for
-- the inn sheet); every word here is ours. One entry per place the party plays, by its id in M.places.

local M = {}

M.SOURCE = "The Wild Sheep Chase by Richard Jansen-Parkes (DMs Guild): page numbers in the reader's own PDF"

M.rooms = {
    inn_common = {
        pages = { 2 },
        sees = "a busy common room, the hearth, the bar, Teddy, travellers; then a sheep with a scroll in its mouth",
        secrets = {
            { key = "sheep_wizard", words = { "Shinebright", "wizard" }, reveal = "moment", shows = { "read the scroll" } },
            { key = "guards_are_people", words = { "polymorphed", "people" }, reveal = "moment" },
            { key = "bear", words = { "bear" }, reveal = "fight" },
        },
        foes = {
            { cast = "guz", start = "awake", wakes = "talk fails", at = "door" },
            { cast = "wolf_guard", n = 3, start = "awake", wakes = "guz attacks", at = "door", goal = "grab the sheep" },
            { cast = "bear_guard", start = "hidden", wakes = "guz attacks", at = "door", note = "cloaked, hood up" },
        },
        people = { { cast = "sh_teddy", at = "bar" }, { cast = "sh_shinebright", at = "tables" } },
        items = { { id = "speak_scroll", at = "tables", note = "in the sheep's mouth" } },
    },
    -- (The inn sheet has the rooms and Sir Luenn as colour; the side quest in them, Wenna and Hobb, is ours.)
    inn_upstairs = {
        source = "inn",
        sees = "five bedrooms, two of them shared, and a sitting room round a great hearth",
        ours = { what = "Sir Luenn's missing ring and the accused maid", instead = "the sheet has the rooms, and Sir Luenn staying in one" },
        people = { { cast = "sh_luenn", at = "luenn_room" }, { cast = "sh_wenna", at = "luenn_room" } },
    },
    inn_cellar = {
        source = "inn",
        sees = "barrels, spirits, sacks of dry goods, cobwebs, a clay floor, the trapdoor and the storm doors",
        ours = { what = "a pack rat's nest of the inn's lost things, with the ring in it", instead = "the sheet has the cellar's stores and its spiders" },
        foes = { { cast = "pack_rat", start = "hidden", wakes = "the nest disturbed", at = "nest" },
                 { cast = "cellar_rats", n = 2, start = "hidden", wakes = "the nest disturbed", at = "nest" } },
        items = { { id = "signet_ring", at = "nest" } },
    },
    woods_path = {
        pages = { 4 },
        sees = "a well-used path into the oaks, the ground churned by feet and paws",
        secrets = { { key = "tracks", words = { "Guz" }, reveal = "check", note = "the freshest tracks are Guz's group's" } },
    },
    compound = {
        pages = { 4, 5 },
        sees = "the platforms in the oaks, two huts, an outhouse, three apes dicing on the lawn with greatswords stuck in the ground",
        secrets = { { key = "bear_outhouse", words = { "bear" }, reveal = "moment" } },
        foes = {
            { cast = "ape_guard", n = 3, start = "awake", wakes = "approach", at = "lawn", note = "asleep or dicing" },
            { cast = "bear_guard", start = "hidden", wakes = "fight", at = "outhouse" },
        },
    },
    garden = {
        pages = { 4 },
        sees = "the lowest platform, ringed with branches, flowers and small trees; the hall's door above",
        doors = { { to = "hall", locked = true, athletics = 14, thieves_tools = 12 } },
    },
    hall = {
        pages = { 4, 5, 6 },
        sees = "a library and lab, a sitting room, a dining room and kitchen; shelves, notes, beast diagrams",
        secrets = {
            { key = "second_scroll", words = { "scroll" }, reveal = "check" },
            { key = "cant_pay", words = { "sold" }, reveal = "check" },
        },
        people = { { cast = "sh_noke", at = "lab", note = "working on new spells" } },
        items = { { id = "lab_gear", at = "lab" }, { id = "speak_scroll_2", at = "library" } },
    },
    bedroom = {
        pages = { 5, 6 },
        sees = "a wardrobe, a big wooden bed, a cluttered dressing table",
        secrets = { { key = "bed_escape", words = { "dragon" }, reveal = "moment" } },
        items = { { id = "robe", at = "wardrobe" } },
    },
}

return M
