-- Welcome to the Ring's secrets: what the DM knows and the table doesn't, and the ways each can come out
-- (game/model/secrets.lua; the fields are documented at the top of game/data/museum/secrets.lua). Pages are the Death in
-- Space core rules' printed numbers (Christian Plogfors and Carl Niblaeus, Free League); every word here is ours.
-- `book = true` on a way out the book gives; the rest are the game's. A check is an ability, not a skill: bdy, dex,
-- svy, tec (game/rules/sets/dis.lua). People: game/data/ring/module.lua's M.people.

local M = {}

M.hub_broken = {
    name = "What the Brittle Star needs", page = 80, type = "place", room = "hub",
    covered_by = { { flag = "damage_known" } },
    what = "The hub's engine is burnt out and its tank is dry. A proper repair crew could fix it in three hours; the "
        .. "crew alone, without parts, can't. Then it needs fuel.",
    held_by = { "ri_comms" },
    hint = { "Every light on the engine panel is red, and the fuel gauge doesn't even twitch." },
    tell = { "Burnt couplings, a cracked fuel line, and an empty tank: it needs a repair crew and fuel, nothing less." },
    theory = { "That engine's not just off. Something in it's cooked.", "Is the tank meant to sound that hollow?" },
    paths = {
        { kind = "check", skill = { "tec" }, dc = 12, gives = "known", flag = "damage_known" },
        { kind = "ask", on = "ri_comms", gives = "known", flag = "damage_known" },
    },
}

M.comms_log = {
    name = "The ship's last voyage", type = "document", room = "hub", ours = true,
    what = "The comms keeps the Brittle Star's last log. It ends mid-sentence, on a course out past the Ring, and the "
        .. "comms has no memory of why. Whoever flew it last left in a hurry, or didn't leave at all.",
    held_by = { "ri_comms" },
    hint = { "The comms goes quiet, just for a moment, whenever anyone mentions where the ship's been." },
    tell = { "The last log stops mid-word, on a heading out past the Ring. The comms doesn't remember the rest, and "
                 .. "it doesn't like not remembering." },
    theory = { "The comms is hiding something. Or something's hidden from the comms." },
    paths = {
        { kind = "read", skill = { "tec" }, dc = 12, gives = "known" },
        { kind = "ask", on = "ri_comms", opinion = "warm", gives = "known" },
    },
}

M.ezra_owes = {
    name = "Ezra owes too", page = 81, type = "person", room = "dock",
    what = "Ezra Pascal bought the crew's debt because he owes the port authorities for fuel himself, and he needs "
        .. "holos fast. He'd take less than five hundred, today, rather than all of it later.",
    held_by = { "ri_ezra", "ri_salvagers" },
    hint = { "Ezra keeps glancing at the port authority's booth, and talking faster when anyone in uniform walks by." },
    tell = { "The salvagers are in debt to the port authorities for fuel. Ezra needs holos now, and he'd take less." },
    theory = { "He's in a bigger hurry than someone owed money should be." },
    paths = {
        { kind = "check", skill = { "svy" }, dc = 12, gives = "known", book = true, page = 81 },
        { kind = "ask", on = "ri_salvagers", gives = "hint" },
    },
}

M.rumour_fixers = {
    name = "Who can fix a hub", page = 79, type = "person", room = "bar_machine",
    what = "Either Roy Mirra of the Passel or Monotone Tynall of Parliament can have the hub repaired in three hours, for "
        .. "a favor. Hina Tsurutsuru sells fuel. Suro Ragosa lands with the next shuttle.",
    held_by = { "ri_friend", "ri_hina" },
    hint = { "Everyone in the docking bay talks about the Passel and Parliament the way you'd talk about the weather." },
    tell = { "Roy Mirra or Monotone Tynall could get the hub fixed in three hours, for a favor; Hina at the Tsurutsuru "
                 .. "sells fuel; and Ragosa is on the next shuttle." },
    theory = { "Somebody in this sector must fix ships. Who runs this place?" },
    paths = {
        { kind = "ask", on = "ri_friend", gives = "known", book = true, page = 80 },
        { kind = "check", skill = { "svy" }, dc = 12, gives = "known" },
    },
}

M.friend_informs = {
    name = "Dace informs on everyone", page = 80, type = "person", room = "bar_machine", call = 1,
    what = "The crew's old friend tells Monotone and Roy both whatever they hear, to keep in with them. Anything the crew "
        .. "says to Dace, both gangs will know by the next shift.",
    held_by = { "ri_friend" },
    hint = { "Dace keeps glancing at the elevators, and asks a lot of questions for someone just catching up." },
    tell = { "Dace is selling everything they hear, to both gangs, to stay alive." },
    theory = { "Dace wants to know an awful lot about our plans." },
    paths = {
        { kind = "check", skill = { "svy" }, dc = 12, gives = "known", book = true, page = 80 },
    },
}

M.hina_hola = {
    major = true,
    name = "Where Hina's fuel goes", page = 83, type = "person", room = "common",
    what = "Hina makes Hola!, a non-phys drug, from fuel and flowers off Roy's farm, and sells it all to Monotone. Roy, who "
        .. "hates non-phys, has no idea his flowers go into it.",
    held_by = { "ri_hina", { on = "ri_monotone", gives = "hint",
                             hint_says = { "\"Hina's the only one who still makes anything worth dreaming on,\" Monotone says, flatly." } } },
    hint_words = { "Hola!" },
    hint = { "The Tsurutsuru smells faintly of fuel and flowers, which is a strange thing for a bar to smell of.",
             "Half the dreamers in the computer center have little glass vials with a Tsurutsuru label." },
    tell = { "Hina's Hola! is made from her fuel and Roy's flowers, and Monotone buys every drop. Roy doesn't know." },
    theory = { "What's a bar owner doing with that much fuel?", "Those vials came from somewhere close." },
    paths = {
        { kind = "check", skill = { "svy" }, dc = 12, gives = "known", book = true, page = 83 },
        { kind = "check", skill = { "tec" }, dc = 12, gives = "hint" },
    },
}

M.hina_out = {
    name = "Hina wants out", page = 83, type = "person", room = "common",
    what = "Hina wants to leave Aurum 80 quietly, without anyone knowing, and live somewhere warm. She'll pay for a ride "
        .. "in fuel, up front.",
    held_by = { "ri_hina" },
    hint = { "Hina asks a lot about the Brittle Star's range for someone just selling fuel." },
    tell = { "Hina wants off the Ring, quietly, and she'll pay in fuel for a ride somewhere warm." },
    theory = { "She's not selling. She's shopping." },
    paths = {
        { kind = "check", skill = { "svy" }, dc = 12, gives = "known" },
        { kind = "ask", on = "ri_hina", opinion = "warm", gives = "known", book = true, page = 83 },
    },
}

M.roy_mother = {
    major = true,
    covered_by = { { flag = "peace" } },
    name = "Why Roy left", page = 85, type = "person", room = "engine_room",
    what = "Roy's mother died of non-phys, and Monotone kept selling it to her. That's why he left Parliament and started "
        .. "the Passel, and why he can't forgive them.",
    held_by = { "ri_roy", { on = "ri_hina", gives = "hint",
                            hint_says = { "\"Ask Roy about his mother,\" Hina says. \"Then don't, ever again.\"" } } },
    hint = { "Roy spits at the very word non-phys.", "There's a little shrine by Roy's noodle stand: a photo and a burnt-out visor." },
    tell = { "His mother died in a non-phys visor, and it was Monotone's people who sold it to her." },
    theory = { "Something happened between those two. Something personal." },
    paths = {
        { kind = "check", skill = { "svy" }, dc = 12, gives = "known", book = true, page = 85 },
        { kind = "ask", on = "ri_roy", opinion = "warm", gives = "known" },
    },
}

M.roy_coup = {
    name = "Roy's plans", page = 86, type = "document", room = "engine_room",
    what = "Roy's office holds drives with his plans to overthrow Suro Ragosa as Aurum's leader. Ragosa would pay well "
        .. "for them, and she'd do anything to the Passel once she had them.",
    held_by = { "ri_roy" },
    hint = { "Roy's office is the only door in the engine room with two guards on it." },
    tell = { "Roy means to overthrow Ragosa, and the plans are in his office." },
    theory = { "What's Roy keeping behind that door?" },
    paths = {
        { kind = "check", skill = { "dex" }, dc = 12, gives = "known", book = true, page = 86 },
        { kind = "read", skill = { "tec" }, dc = 12, gives = "known" },
    },
}

M.monotone_board = {
    major = true,
    covered_by = { { flag = "monotone_deal_done" }, { flag = "roy_deal_done" } },
    name = "What the board does", page = 89, type = "item", room = "computer_center",
    what = "Monotone's circuit board doesn't fix anything. Put in the engine hall's control panel, it hands Parliament "
        .. "control of Aurum's power, and the Passel lose everything they have.",
    held_by = { "ri_monotone" },
    hint = { "The board has Parliament's mark scratched into it, and far too many connectors for a simple fix." },
    tell = { "The board hands Monotone the station's power. Fit it, and the Passel are finished." },
    theory = { "Half an hour's work, they said. For what, exactly?" },
    paths = {
        { kind = "check", skill = { "tec" }, dc = 12, gives = "known", book = true, page = 89 },
        { kind = "ask", on = "ri_hina", opinion = "warm", gives = "hint",
          hint_says = { "\"A board from Monotone?\" Hina laughs. \"Nothing Monotone gives away is a favor, darling.\"" } },
    },
}

M.monotone_lonely = {
    major = true,
    covered_by = { { flag = "peace" } },
    name = "What Monotone wants", page = 89, type = "person", room = "computer_center",
    what = "Under the flat voice, Monotone is lonely, stuck on a memory cartridge playing the old days over and over: "
        .. "Roy, Hina and them, before the war. What they want most is Roy back.",
    held_by = { "ri_monotone", { on = "ri_hina", gives = "hint",
                                 hint_says = { "\"Monotone and Roy,\" Hina says. \"You've never seen two people miss each other more.\"" } } },
    hint = { "Every photo on Monotone's wall has Roy in it.", "The cartridge behind Monotone's ear clicks, and they go still, listening." },
    tell = { "Monotone wants Roy's friendship back more than they want the station." },
    theory = { "Monotone doesn't hate Roy. Look at those photos." },
    paths = {
        { kind = "check", skill = { "svy" }, dc = 12, gives = "known", book = true, page = 89 },
        { kind = "ask", on = "ri_monotone", opinion = "warm", gives = "known" },
    },
}

return M
