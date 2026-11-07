-- The book's structure, as data (the fields are game/data/museum/fidelity.lua's), for Welcome to the Ring, the starting
-- adventure in the Death in Space core rules (Christian Plogfors and Carl Niblaeus, Free League). Printed page numbers
-- only; every word here is ours. One entry per place the party plays, by its id in M.places.

local M = {}

M.SOURCE = "Death in Space core rules by Christian Plogfors and Carl Niblaeus (Free League): printed page numbers"

M.rooms = {
    dock = {
        pages = { 80, 81 },
        sees = "a shantytown of junk and repair shops, work lights on chains, the timer on the wall, airlock 13C behind a heap of junk",
        secrets = { { key = "ezra_owes", words = { "port authorities" }, reveal = "check" } },
        people = { { cast = "ri_ezra", at = "airlock_13c" }, { cast = "ri_salvagers", at = "airlock_13c" } },
    },
    hub = {
        pages = { 26, 27, 30, 33 },
        ours = { what = "the crew's spacecraft, made by the book's hub steps", instead = "the book has the crew's hub broken and unfuelled at airlock 13C" },
        sees = "a cramped spacecraft on emergency lights: command center, crew quarters, mess, life support, a cold engine",
        secrets = { { key = "hub_broken", words = { "repair crew" }, reveal = "check" } },
        people = { { cast = "ri_comms", at = "command_center" }, { cast = "ri_cassius", at = "mess" } },
    },
    bar_machine = {
        pages = { 80 },
        sees = "a plaza round an old drilling machine made into a bar, a tarp against the drips",
        secrets = { { key = "rumour_fixers", words = { "three hours" }, reveal = "moment" },
                    { key = "friend_informs", words = { "both gangs" }, reveal = "check" } },
        people = { { cast = "ri_friend", at = "stools" } },
    },
    common = {
        pages = { 82, 83 },
        sees = "food stands, scaffolding full of bed capsules, rubbish, and the Tsurutsuru on its platform three floors up",
        secrets = { { key = "hina_hola", words = { "Hola!" }, reveal = "check" }, { key = "hina_out", words = { "somewhere warm" }, reveal = "moment" } },
        people = { { cast = "ri_hina", at = "hinas_office" } },
    },
    engine_room = {
        pages = { 84, 85, 86 },
        sees = "hot cooling corridors round the engine hall, coloured lights, fruit stalls, kids, steam through the floor",
        secrets = { { key = "roy_mother", words = { "mother" }, reveal = "check" }, { key = "roy_coup", words = { "overthrow" }, reveal = "check" } },
        people = { { cast = "ri_roy", at = "noodle_stand" } },
    },
    computer_center = {
        pages = { 88, 89, 90 },
        sees = "blue lights on padded walls, stacked old computers, dreamers in non-phys visors on the main hall's floor",
        secrets = { { key = "monotone_board", words = { "power" }, reveal = "check" },
                    { key = "monotone_lonely", words = { "best friend" }, reveal = "check" } },
        people = { { cast = "ri_monotone", at = "office_door" } },
        items = { { id = "circuit_board", at = "office_door" }, { id = "monotones_computer", at = "office_door" } },
    },
    relay = {
        pages = { 85, 90 },
        sees = "the station's hull in vacuum, the big dish, the relay unit beside it, a window onto the main hall",
    },
    engine_hall = {
        pages = { 86, 89 },
        sees = "wet heat, a deafening engine, dry plants climbing everything, racks of electronics by a control panel, a sleeper by the door",
    },
    shuttle = {
        pages = { 79 },
        sees = "the timer at zero, the shuttle in its airlock, Ragosa and her thugs",
        foes = { { cast = "ragosa", start = "awake", wakes = "talk fails", at = "shuttle_airlock" },
                 { cast = "uwa_thug", n = 2, start = "awake", wakes = "talk fails", at = "shuttle_airlock" } },
    },
}

return M
