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

    -- The big questions (M8, B10): the arc's few conclusions, each with at least three clue cards
    -- in the deck (the three clue rule: a party misses some clues, so every conclusion needs
    -- several roads to it). clues: the story cards whose reveal answers part of it; answered
    -- once this many are found.
    questions = {
        { id = "hushed", q = "Who hushed the bells, and why?",
          answer = "Kessrick, to bring down the valley's ward before his warband comes.",
          clues = { "stranger", "hales_crossing", "corin", "riddle" }, answered_at = 3 },
        { id = "tower", q = "Who holds the bell tower?",
          answer = "Vask, Kessrick's lieutenant, let in with a copied key.",
          clues = { "hidden_map", "velvet_den", "wolf_lieutenant", "bell_tower" }, answered_at = 3 },
        { id = "tobin", q = "Where did Old Tobin go?",
          answer = "Up the north road along the old bell paths, carrying the map that shows the hush came from inside.",
          clues = { "stranger", "forest_road", "chapel", "hidden_map" }, answered_at = 3 },
    },
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
          about = "Rang the bells for forty years. Took the north road the night they went quiet, and never came back." },
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
            open = "Rain over the Vale of Millbrook. Travellers, each with a reason to be on the road, and one inn with "
                .. "its lamps still lit: the Crooked Kettle. Somewhere above the town, the bells that should be "
                .. "ringing the hour are silent.",
            -- The opening names a place: it's only used when scene 1 is there (A11); else open_else.
            open_place = "tavern",
            open_else = "Rain over the Vale of Millbrook. Travellers, each with a reason to be on the road. Somewhere "
                .. "above the town, the bells that should be ringing the hour are silent.",
            cards = { "tavern", "gus", "stranger" },
            reveal = {
                tavern = "The Crooked Kettle, the only inn in Millbrook. Rain on the shutters, and a whole room that goes "
                    .. "quiet every hour, listening for bells that don't ring. A carter swears he saw wolves at the edge of "
                    .. "town last night, and there was no bell to warn anyone.",
                gus = "Gus sets down a round of mugs. 'Nine days. And the tower's locked up tight: Tobin had the only key, "
                    .. "and he never let it out of his sight.'",
                stranger = "The stranger in the corner lowers her hood: Wren, the bell-ringer's apprentice. 'Old Tobin "
                    .. "came down from the tower white as milk, said they'd hushed the bells, and took the north road. "
                    .. "He never came back.'",
            },
            clues = {
                -- (October 15: the opening already says the bells stopped; each card here adds something.)
                tavern = "Wolves were seen at the edge of town last night, and there was no bell to warn anyone.",
                gus = "The bell tower is locked, and Old Tobin had the only key.",
                stranger = "Old Tobin, the bell-ringer, said someone 'hushed' the bells, then took the north road "
                    .. "and vanished.",
            },
            -- What the DM is hoping the party walks away with (shown in the notes).
            goal = "The party agrees to look for Old Tobin up the north road.",
            -- What the party is out to do tonight, as the DM tells the table after the recap ("And
            -- here we are today: you're at ..., out to ..."); objective_if when they found the clue.
            objective = "find out why Millbrook's bells went silent",
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
                .. "of Millbrook into the pines: the way Old Tobin went the night the bells stopped, and never came back." },
            open_place = "forest_road",
            open_else = "Morning, and the rain has finally stopped. Above Millbrook, the bells are still silent.",
            open_else_if = "Morning, and the rain has finally stopped. The night the bells stopped, Old Tobin took the north road "
                .. "into the pines, and never came back.",
            -- They've walked it before: no "the north road climbs" as if it were new (A11).
            open_again = "Morning, and the rain has finally stopped. Back up the north road, then, into the pines.",
            open_again_if = "Morning, and the rain has finally stopped. Back up the north road, then: the way Old Tobin "
                .. "went the night the bells stopped, and never came back.",
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
                forest_road = "Kessrick's wolves have been on the north road, not long ago.",
                chapel = "Tobin made it as far as the roadside chapel. Its bell was cut down too.",
                hidden_map = "Tobin's map of the old bell paths: 'The hush was laid from inside the tower. They had "
                    .. "a key.'",
            },
            goal = "The party finds Tobin's map and learns the hush came from inside the tower.",
            objective = "find out who silenced Millbrook's bells, and why",
            objective_if = { clue = "stranger", text = "follow Old Tobin up the north road and find out what happened to him" },
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
            -- It names three places: only when scene 1 is one of them (A11); else the trail stays unnamed.
            open_place = { "velvet_den", "ilsa_room", "hales_crossing" },
            open_else = "The trail runs three ways from here, and every one of them is somebody's past.",
            open_else_if = "Tobin's map points three ways, and every one of them is somebody's past.",
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
            objective = "find out who's behind the silent bells, and what it'll take to wake them",
            objective_if = { clue = "hidden_map", text = "follow Tobin's map and find out who had a key to the tower" },
            lead = "Vask, Kessrick's lieutenant",
            culprit = { name = "Vask, Kessrick's lieutenant", secret = "Vask bought a copy of the tower key in Lowmarket" },
        },
        {
            title = "The silent bell",
            about = "The first act turns: the bell tower, and who silenced it.",
            hint = "End high: a big fight, or a cliffhanger they'll talk about all week.",
            open = "A hundred and twelve steps up the bell tower above Millbrook. Tonight, somebody finally climbs "
                .. "them.",
            open_place = "bell_tower",
            open_else = "The bell tower stands over Millbrook, silent, a hundred and twelve steps high. Tonight, "
                .. "somebody climbs them.",
            open_again = "The bell tower again, silent over Millbrook. Tonight, somebody climbs all the way to the top.",
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
            objective = "climb the bell tower and wake the bells",
            objective_if = { clue = "velvet_den", text = "climb the bell tower, deal with whoever has that key, and wake the bells" },
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
