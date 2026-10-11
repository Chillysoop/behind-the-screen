-- The slice's story (M7, written out in the real-session pass): the first four sessions of
-- a 20-session arc, The Silent Bells. Each session has a beat: a title, what it's for, an
-- opening the DM reads when the night starts, and a few story cards that turn up in that
-- week's hand. A story card on the board tells its part of the story when its scene plays
-- (reveal, in place of the card's usual line) and leaves a clue in the DM's notes. open_if:
-- a different opening when the party already has that clue. Using
-- them isn't required, but the story only moves when you do. Session 4 turns the first act:
-- end it high and the table can't wait for session 5.
--
-- pressure: the slice squeezes the start of an arc into four weeks, so each beat leans on
-- one table conflict (game/data/conflicts.lua) to make sure the social side shows up.
-- A DM who tends the table still heads most of it off.
-- Data only: tune freely. The model is game/model/campaign.lua (arc_beat) and
-- game/model/story.lua; the DM's notes are game/ui/notes_view.lua.

return {
    name = "The Silent Bells",
    pitch = "Kessrick's warband is gathering in the hills, and the bells that used to warn the valley have gone "
        .. "quiet. Twenty sessions to find out why. The slice is the first four.",
    SESSIONS = 4,              -- Session Zero, then this many game nights
    STORY_INVESTMENT = 2,      -- for storytellers and explorers when a story card hits the table

    -- The DM's own notes on the campaign: what the players don't know yet.
    premise = {
        "The Vale of Millbrook: a river valley ringed by hills, with the market town of Millbrook at its heart.",
        "Above the town stands the old bell tower. Its seven bells were blessed long ago to ring out whenever raiders "
            .. "cross the hills, and for a hundred years they always have.",
        "Nine days before the campaign starts, the bells fell silent. Somebody has laid a hush on them.",
        "Behind it: Kessrick the Wolf, the warlord who burned Brannoc's village. He silences a valley's bells, "
            .. "then he comes. His lieutenant Vask holds the tower.",
    },

    -- Who's who in the first act. Shown in the DM's notes once the party has met them
    -- (a card with this id has been played), or always (known = true). reveal_only: only
    -- counts as met when their story card tells who they are (any hooded stranger isn't Wren).
    people = {
        { id = "gus", name = "Gus", role = "Innkeeper of the Crooked Kettle", sprite = "npc_gus", known = true,
          about = "Knows everyone in Millbrook, and has polished the same mug for eleven years." },
        { id = "stranger", name = "Wren", role = "The bell-ringer's apprentice", sprite = "npc_stranger", reveal_only = true,
          about = "Watched her master come down from the tower white as milk, the night the bells went quiet." },
        { id = "tobin", name = "Old Tobin", role = "Bell-ringer of Millbrook, missing", sprite = nil, known = true,
          about = "Rang the bells for forty years. Took the north road nine days ago and never came back." },
        { id = "corin", name = "Corin", role = "Ilsa's assistant", sprite = "npc_corin",
          about = "Kept Ilsa's notes after she vanished. Flinches when anyone says her name." },
        { id = "madame_sable", name = "Madame Sable", role = "Collector for the Velvet Hand", sprite = "npc_sable",
          about = "Knows exactly what Pip owes, to the copper, and who else has been buying from the Hand." },
        { id = "abbot_ghost", name = "The abbot", role = "Ghost of Oswin's old abbot", sprite = "npc_ghost",
          about = "Died in the fire at Oswin's temple. Still watching over him." },
        { id = "hermit", name = "The hermit", role = "Talks to his kettle", sprite = "npc_hermit",
          about = "Has lived in the hills longer than anyone, and remembers the last time the bells failed." },
        { id = "wolf_lieutenant", name = "Vask", role = "Kessrick's lieutenant", sprite = "tough",
          about = "Scarred, patient, and holding the tower with a key bought in Lowmarket." },
        { id = "kessrick", name = "Kessrick the Wolf", role = "Warlord in the hills", sprite = nil, known = true,
          about = "Burned Hale's Crossing when Brannoc was a boy. Nobody has seen him in years." },
    },

    beats = {
        {
            title = "Strangers at the Kettle",
            about = "Bring the party together and give them something to chase.",
            hint = "Open warm, then drop the hook.",
            open = "Rain over the Vale of Millbrook. Four travellers, four reasons to be on the road, and one inn with "
                .. "its lamps still lit: the Crooked Kettle. Somewhere above the town, the bells that should be "
                .. "ringing the hour are silent.",
            cards = { "tavern", "gus", "stranger" },
            reveal = {
                tavern = "The Crooked Kettle, the only inn in Millbrook. Rain on the shutters, a fire that needs "
                    .. "feeding, and a whole room that goes quiet every hour, listening for bells that don't ring.",
                gus = "Gus sets down four mugs. 'Nine days those bells have been quiet. Nine. My gran said it never "
                    .. "happened in her lifetime, nor her gran's.'",
                stranger = "The stranger in the corner lowers her hood: Wren, the bell-ringer's apprentice. 'Old Tobin "
                    .. "came down from the tower white as milk, said they'd hushed the bells, and took the north road. "
                    .. "He never came back.'",
            },
            clues = {
                tavern = "Millbrook listens for its bells every hour. They haven't rung in nine days.",
                gus = "The bells have never gone quiet before, not in living memory.",
                stranger = "Old Tobin, the bell-ringer, said someone 'hushed' the bells, then took the north road "
                    .. "and vanished.",
            },
            -- What the DM is hoping the party walks away with (shown in the notes).
            goal = "The party agrees to look for Old Tobin up the north road.",
            -- Who's behind it this week, when a scene needs a name and nobody in it fits (the
            -- slice rework: outcomes always name someone).
            lead = "Old Tobin, the bell-ringer",
            culprit = { name = "a scarred stranger who took a room and never slept in it",
                        secret = "he was asking which key opens the bell tower" },
        },
        {
            title = "The road out",
            about = "Get them out of town. Somebody's past is waiting on the road.",
            hint = "Explore, and let a backstory show up.",
            open = "Morning, and the rain has finally stopped. The north road climbs out of Millbrook into the pines, "
                .. "toward the hills the bells used to watch.",
            -- When the party found this last week, the DM opens with what it means.
            open_if = { clue = "stranger", text = "Morning, and the rain has finally stopped. The north road climbs out "
                .. "of Millbrook into the pines: the way Old Tobin went nine days ago, and never came back." },
            cards = { "forest_road", "chapel", "hidden_map" },
            pressure = { spotlight = 18, rules = 8 },     -- Jess has found her groove; the first rules calls
            reveal = {
                forest_road = "The north road into the pines. Wolf tracks cross it, a lot of them, and a pewter "
                    .. "badge lies in the mud: a wolf's head.",
                chapel = "The roadside chapel, half fallen in. Its little bell has been cut from its rope, and Tobin's "
                    .. "lantern sits on the altar, burned out.",
                hidden_map = "Goal: Tobin hid something in the chapel. Find it before whoever cut the bell comes back "
                    .. "for it.",
            },
            clues = {
                forest_road = "Kessrick's wolves have been on the north road, and recently.",
                chapel = "Tobin made it as far as the roadside chapel. Its bell was cut down too.",
                hidden_map = "Tobin's map of the old bell paths: 'The hush was laid from inside the tower. They had "
                    .. "a key.'",
            },
            goal = "The party finds Tobin's map and learns the hush came from inside the tower.",
            lead = "a scarred man with a wolf badge",
            culprit = { name = "the scarred man with the wolf badge", secret = "he's been watching the north road for Kessrick" },
        },
        {
            title = "Old debts",
            about = "A backstory catches up with whoever has had the least of the spotlight.",
            hint = "Give the quietest player their scene.",
            open = "The trail runs three ways from here: the back alleys of Lowmarket, the room Ilsa rented above the "
                .. "scriptorium, and the ashes of Hale's Crossing. Every one of them is somebody's past.",
            open_if = { clue = "hidden_map", text = "Tobin's map points three ways: the back alleys of Lowmarket, the "
                .. "room Ilsa rented above the scriptorium, and the ashes of Hale's Crossing. Every one of them is "
                .. "somebody's past." },
            cards = { "velvet_den", "corin", "abbot_ghost", "hales_crossing" },
            pressure = { tone = 22 },                     -- backstory week: the serious stuff arrives
            reveal = {
                velvet_den = "The Velvet Hand's back room. Madame Sable doesn't look up from her ledger: 'A copy of "
                    .. "the tower key went through this room a month ago. Bought by a scarred man with a wolf badge. "
                    .. "Your old crew cut it, Pip.'",
                corin = "Corin unrolls a page in Ilsa's hand. The bells aren't just bells: they're a ward over the "
                    .. "whole valley, and somebody was learning how to hush it. Ilsa went up the tower to stop them. "
                    .. "That was two months ago.",
                abbot_ghost = "A cold light, and a voice Oswin knows. 'The relic you carried out of the fire is the "
                    .. "tongue of the first bell. A hush can be broken by a blessed voice. Carry it up.'",
                hales_crossing = "Brannoc's village, or what's left of it. Its little bell lies in the ash with its "
                    .. "tongue torn out. The night Kessrick came, it didn't ring either.",
            },
            clues = {
                velvet_den = "The Velvet Hand sold a copy of the tower key to a scarred man wearing Kessrick's badge.",
                corin = "Ilsa learned the bells are a ward over the valley, and went up the tower to stop whoever "
                    .. "was hushing it.",
                abbot_ghost = "Oswin's relic is the tongue of the first bell. A blessed voice can break the hush.",
                hales_crossing = "Hale's Crossing's bell was silenced before Kessrick burned it. He hushes the bells, "
                    .. "then he comes.",
            },
            goal = "The party learns who holds the tower, and what it will take to wake the bells.",
            lead = "Vask, Kessrick's lieutenant",
            culprit = { name = "Vask, Kessrick's lieutenant", secret = "Vask bought a copy of the tower key in Lowmarket" },
        },
        {
            title = "The silent bell",
            about = "The first act turns: the bell tower, and who silenced it.",
            hint = "End high: a big fight or a cliffhanger into session 5.",
            open = "A hundred and twelve steps up the bell tower above Millbrook. Tonight, somebody finally climbs "
                .. "them.",
            cards = { "bell_tower", "wolf_lieutenant", "riddle", "cliffhanger" },
            finale = true,
            reveal = {
                bell_tower = "The bell tower. Frost on the inside of the walls, and seven great bells hanging dead "
                    .. "still. Scratched into the stone by the stairs, in Ilsa's handwriting: 'Thessaly. Don't stop.'",
                wolf_lieutenant = "Under the bells waits a scarred man with Kessrick's wolf badge and a key from "
                    .. "Lowmarket on his belt: Vask. 'Kessrick sends his regards, farm boy.'",
                riddle = "Goal: the hush is a ward with three locks, written as a riddle around the great bell. "
                    .. "Ilsa's notes are in the margins.",
                cliffhanger = "The great bell swings, and rings out over the valley for the first time in weeks. "
                    .. "And from the hills, a hundred wolf-horns answer.",
            },
            clues = {
                bell_tower = "Ilsa made it to the tower and left a message for Thessaly.",
                wolf_lieutenant = "Vask, Kessrick's lieutenant, has been holding the tower.",
                riddle = "The hush has three locks, written as a riddle around the great bell.",
                cliffhanger = "The bells are awake, and Kessrick's warband knows it. It's coming.",
            },
            goal = "The bells ring again, and the first act ends on Kessrick's horns.",
            lead = "Kessrick the Wolf",
            culprit = { name = "Vask", secret = "Vask has been holding the tower for Kessrick all along" },
        },
    },

    -- How the first act lands, from how session 4 ends.
    finale = {
        landed = "The first act lands. Nobody wants to wait a week for session 5.",
        flat = "The first act ends with a shrug. Session 5 has some winning back to do.",
        HYPE = 3,              -- extra hype when it lands (on top of a cliffhanger's)
        INVESTMENT = 3,        -- for everyone at the table when it lands
    },
}
