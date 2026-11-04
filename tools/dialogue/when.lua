-- When a line is said, for the Dialogue Desk (the author, November 4: "add context of when the
-- character might or will say the line"). For each exported line, one short plain sentence (when)
-- and how sure it is to be said (odds):
--   "Always"        said whenever that moment happens
--   "1 of N"        one of N alternatives picked for that moment
--   "Your pick"     an option on a card (or a button) the DM chooses from
--   "If chosen"     what follows from picking an option
--   "On a success" / "On a failure"   a roll's outcome
--   "Sometimes"     a chance, when nothing more precise can be said
--   "Never"         the data is there, but nothing in the museum shows it (said so in `when`)
-- The rules are keyed on the line's file and the shape of its path in the data, and each one was
-- read off the code that uses that data (named beside it). Anything unmatched gets a fallback
-- that says what it can, with "Sometimes". Used by tools/dialogue/export.lua.

local adventure = require "game.model.adventure"
local util = require "game.model.util"
local json = require "game.model.jsonlite"

local MODULE = adventure.data
local W = {}

local NAME = { mara = "Mara", dev = "Dev", jess = "Jess", sam = "Sam" }
local HERO = { mara = "Thessaly", dev = "Brannoc", jess = "Pip", sam = "Oswin" }
local SUBJ = { mara = "she", dev = "he", jess = "she", sam = "he" }
local CLASS_KEY = { wizard = "mara", fighter = "dev", rogue = "jess", cleric = "sam" }
-- Who plays to each type (game/data/players.lua: primary and secondary).
local ARCH_WHO = { storyteller = { "mara" }, explorer = { "mara" }, butt_kicker = { "dev" }, power_gamer = { "dev" },
                   method_actor = { "jess" }, instigator = { "jess" }, casual = { "sam" }, tactician = { "sam" } }

-- Words -------------------------------------------------------------------------------------------

local FILL = { actor_char = "the hero", char = "the hero", Char = "The hero", actor = "the player", holder = "the hero",
               boss = "the boss", Boss = "The boss", round = "N", target = "the target", other_char = "a friend",
               other = "a friend", name = "the player", them = "them", their = "their", ["they"] = "they" }

local function plain(s)
    s = tostring(s or "")
    s = string.gsub(s, "%%f%[%%[%a]%]", "")
    s = string.gsub(s, "%%(%p)", "%1")
    s = string.gsub(s, "{([%w_]+)|[%w_]+}", "%1")
    s = string.gsub(s, "{([%w_]+)}", function(k)
        return FILL[k] or "…"
    end)
    s = string.gsub(s, "^[\"']+", "")
    s = string.gsub(s, "[\"']+$", "")
    return s
end

-- A short quote of a title, label or line: “Its first few words…”.
local function Q(s, n)
    s = plain(s)
    s = string.gsub(s, "[%.!]+$", "")
    local words = {}
    for w in string.gmatch(s, "%S+") do
        table.insert(words, w)
    end
    n = n or 6
    local out = table.concat(words, " ", 1, math.min(#words, n))
    if #words > n then
        out = string.gsub(out, "[,;:%.]+$", "") .. "…"
    end
    return "“" .. out .. "”"
end

local function lowfirst(s)
    return util.lower_first(s or "")
end
-- (Always lowercase: "On the street" mid-sentence.)
local function lc1(s)
    s = s or ""
    return string.lower(string.sub(s, 1, 1)) .. string.sub(s, 2)
end

local function names(keys)
    local out = {}
    for _, k in ipairs(keys) do
        table.insert(out, NAME[k] or k)
    end
    return util.join_names(out)
end

-- Rooms: "the garden", and "In the garden".
local function rname(id)
    if id == "thanks" then
        return "Flitwidget's thanks"
    end
    local r = MODULE.rooms[id]
    return r and lowfirst(r.name) or tostring(id)
end
local IN = { street = "On the street", stairs = "On the stairs up", thanks = "At Flitwidget's thanks" }
local function in_room(id)
    return IN[id] or ("In " .. rname(id))
end
-- "The Knight of Shades" mid-sentence, but never "euryale".
local function lthe(s)
    return (string.gsub(s or "", "^The ", "the "))
end
-- "Mara's", "the huntlings'".
local function poss(name)
    return string.find(name, "s$") and (name .. "'") or (name .. "'s")
end
-- "after a night in the garden", "on the street", "on the stairs up".
local function at_room(id)
    return lc1(in_room(id))
end
local POS = { mara = "her", dev = "his", jess = "her", sam = "his" }

local function count(t)
    local n = 0
    for _ in pairs(t or {}) do
        n = n + 1
    end
    return n
end
local function one_of(n)
    if not n or n <= 1 then
        return "Always"
    end
    return "1 of " .. util.int(n)
end

local function sentence(s)
    s = string.gsub(s, "%s+", " ")
    s = string.gsub(s, " ([,%.])", "%1")
    s = string.gsub(s, "%.%.$", ".")
    if not string.find(s, "[%.!?]$") then
        s = s .. "."
    end
    return util.capitalize(s)
end

-- The places on each room's board (game/data/map_library.lua), for "poking at the shears".
local PLACES = {}
do
    local ok, L = pcall(require, "game.data.map_library")
    for _, b in pairs(ok and L.boards or {}) do
        if type(b) == "table" and b.room then
            PLACES[b.room] = PLACES[b.room] or {}
            for _, pl in ipairs(b.places or {}) do
                PLACES[b.room][pl.id] = pl.name
            end
        end
    end
end

-- Conditions (adventure.test), in words -----------------------------------------------------------

local FLAG = {
    arrows = "they bought fire arrows", boon = "someone dropped a coin in the donation box",
    brass_key = "they fished the brass key out of the pond", charmed = "her wine charmed a hero",
    daggers = "they kept the twin daggers", door_open = "they got the locked study open",
    fussed = "Flitwidget keeps checking on them", guards = "Flitwidget signed them up as guards",
    hyper_saved = "they saved Hyper Destroyer Mode for her", hyper_spent = "they tried Hyper Destroyer Mode early",
    manual = "they bought the Mech manual", mech_burnt = "the Mech burnt out", no_surprise = "they made the huntlings come to them",
    notebook = "they have the archivist's notebook", paint = "they pulled a weapon out of a painting",
    paint_dagger = "Telpur sold them a paint-touched dagger", rested = "you promised a long rest in the chat",
    ritual_failed = "they got the water ritual wrong", seen = "Pip crept upstairs alone", she_read = "Euryale has the notebook",
    shoelace = "Telpur gave Pip a talking shoelace", spork = "you joked about a vorpal spork",
    studied = "Thessaly studied the notebook", telpur_along = "Telpur is coming along", told = "Telpur told Flitwidget everything",
    truth = "they heard the truth about the Gorgon", vorpal_lair = "you said a vorpal sword is behind her couch",
    vorpal_price = "Telpur offered a vorpal sword for 40 Francs", vorpal_sword = "they bought the vorpal sword",
    whispered = "something whispered a hero's name", portrait_mara = "the hall's painting was Thessaly's",
    pip_alone = "Pip goes off alone", rematch = "she sent them back down once already",
    tapestry = "someone noticed the tapestry", deaf = "they blocked their ears with wax",
}
local MARK = {
    topiary = "a hedge-beast got away", garden_burned = "they burned the garden", robbed = "they tried to rob the donation box",
    scarabs = "they smashed the Bone Construct", calmed = "they calmed the Bone Construct", knight = "the Knight of Shades is still about",
    pack = "huntlings ran from the fight", mirror = "they took the polished door", know = "they read up on gorgons",
    bracelet = "Flitwidget gave them a bracelet", mech = "the Steam Mech is on their side", drone = "the Lecturer still drones on",
    pages = "they have the Lecturer's notes", careful = "they've been careful with the museum",
}

local function moment_by_id(id)
    for _, m in ipairs(MODULE.moments) do
        if m.id == id then
            return m
        end
    end
    for _, k in ipairs({ "drink", "talk", "yield" }) do
        local m = MODULE.showdown[k]
        if m and m.id == id then
            return m
        end
    end
end

local function cond(c)
    if type(c) ~= "table" or not next(c) then
        return nil
    end
    local bits, nots = {}, {}
    local function add(s)
        if s then
            if string.sub(s, 1, 7) == "not if " then
                table.insert(nots, string.sub(s, 8))
            else
                table.insert(bits, s)
            end
        end
    end
    if c.knob then
        local k = MODULE.knobs[c.knob]
        add("you chose " .. Q(k and k.name or c.knob, 5) .. " in prep")
    end
    if c.not_knob then
        local k = MODULE.knobs[c.not_knob]
        add("not if you chose " .. Q(k and k.name or c.not_knob, 5) .. " in prep")
    end
    if c.flag then
        add(FLAG[c.flag] or "an earlier choice set it up")
    end
    if c.not_flag then
        add("not if " .. (FLAG[c.not_flag] or "an earlier choice changed it"))
    end
    if c.mark then
        add(MARK[c.mark] or "a mark is on Euryale's card")
    end
    if c.not_mark then
        add(MARK[c.not_mark] and ("not if " .. MARK[c.not_mark]) or nil)
    end
    if c.done then
        add(c.done == "lair" and "Euryale is dealt with" or (rname(c.done) .. " is done"))
    end
    if c.skipped then
        add("they skipped " .. rname(c.skipped))
    end
    if c.seen then
        local m = moment_by_id(c.seen)
        add("the card " .. Q(m and m.title or c.seen, 5) .. " came up")
    end
    if c.chose then
        local m = moment_by_id(c.chose[1])
        local o = m and m.options[c.chose[2]]
        add("the pick was " .. Q(o and (o.want or o.label) or "an option", 5))
    end
    if c.ending then
        local e = MODULE.endings[c.ending]
        add("the ending is " .. Q(e and e.name or c.ending, 5))
    end
    if c.not_ending then
        local e = MODULE.endings[c.not_ending]
        add("not if the ending is " .. Q(e and e.name or c.not_ending, 5))
    end
    if c.soft then
        add("Session Zero keeps " .. ((MODULE.content_names or {})[c.soft] or c.soft) .. " off screen")
    end
    if c.not_soft then
        add("not if Session Zero keeps " .. ((MODULE.content_names or {})[c.not_soft] or c.not_soft) .. " off screen")
    end
    if c.line then
        add("Session Zero ruled out " .. ((MODULE.content_names or {})[c.line] or c.line))
    end
    if c.talk then
        add("Euryale is easy enough to talk round")
    end
    if c.met then
        add("they've met " .. c.met)
    end
    if c.companion then
        local d = MODULE.companions and MODULE.companions[c.companion]
        add((d and d.name or c.companion) .. " is along")
    end
    if c.favor then
        local who = c.favor.who == "telpur" and "Telpur" or "Flitwidget"
        add((c.favor.at or 1) >= 2 and (who .. " is delighted with them") or (who .. " is pleased with them"))
    end
    if #bits == 0 and #nots == 0 then
        return nil
    end
    local out = table.concat(bits, " and ")
    if #nots > 0 then
        out = out .. (#bits > 0 and ", " or "") .. "unless " .. table.concat(nots, " or ")
    end
    return out
end

local function if_(c)
    local w = cond(c)
    if not w then
        return ""
    end
    if string.sub(w, 1, 7) == "unless " then
        return ", " .. w
    end
    return ", if " .. w
end

-- What a result says ------------------------------------------------------------------------------

local function R(when, odds)
    odds = odds or "Sometimes"
    if odds == "Sometimes" then
        when = string.gsub(when, "^Sometimes, ", "")
    end
    return { when = sentence(when), odds = odds }
end

local function walk_to(root, path, n)
    local t = root
    for i = 1, n do
        if type(t) ~= "table" then
            return nil
        end
        t = t[path[i]]
    end
    return t
end

-- Moment cards (museum_night.play_moment, table_pick, warn_step) ----------------------------------

local PARENT = {}
for _, m in ipairs(MODULE.moments) do
    for _, o in ipairs(m.options or {}) do
        if o.then_moment then
            PARENT[o.then_moment] = { card = m, opt = o }
        end
    end
end

local MOMENT_IN = {
    mus_drink = "In the Gorgon's lair, before her ultimatum",
    mus_ultimatum = "In the Gorgon's lair, after the drink",
    mus_yield = "In the Gorgon's lair, after she yields in the fight",
}

-- card: the moment; rest: the path after the card; room: where it plays.
local function moment_line(card, rest, room)
    local title = Q(card.title or "a card", 5)
    local where = MOMENT_IN[card.id] or in_room(room)
    local f1, f2 = rest[1], rest[#rest]
    local party = card.party
    if f1 == "title" then
        return R(where .. ": the title of a card that comes up" .. if_(card.when), "Always")
    elseif f1 == "text" then
        if PARENT[card.id] then
            local pp = PARENT[card.id]
            return R(where .. ", right after the table picks " .. Q(pp.opt.want or pp.opt.label, 5) .. " at " .. Q(pp.card.title, 4),
                "Always")
        end
        if card.id == "mus_drink" then
            return R(where .. ": her offer of wine, unless they burned her garden", "Always")
        end
        return R(where .. (party and ", as the table talks over " or ", the card ") .. title .. if_(card.when), "Always")
    elseif f1 == "text_if" then
        local alt = card.text_if[rest[2]]
        return R(where .. ", the card " .. title .. if_(alt and alt.when), "Always")
    elseif f1 == "danger" then
        return R(where .. ", at " .. title .. ": the risk you can warn them of, if they go for it", "Sometimes")
    elseif f1 == "options" then
        local o = card.options[rest[2]] or {}
        local lab = Q(o.want or o.label, 5)
        local f = rest[3]
        -- (When the option is on offer at all: its own when, or what it needs, or what else will do.)
        local oc = o.when or o.needs
        local only = ""
        if oc then
            local a, b = cond(oc), o.alt_needs and cond(o.alt_needs)
            local w = a and b and (a .. " or " .. b) or a
            only = w and ((string.sub(w, 1, 7) == "unless ") and (", " .. w) or (", if " .. w)) or ""
        end
        if f == "label" then
            if party then
                if o.want then
                    return R(where .. ", at " .. title .. ": not shown, the table says this choice in its own words", "Never")
                end
                return R(where .. ", an option the table can settle on at " .. title .. only, "If chosen")
            end
            return R(where .. ", an option on the card " .. title .. only, "Your pick")
        elseif f == "want" then
            return R(where .. ", at " .. title .. ": how the table says this choice (" .. Q("Let's …") .. ")" .. only, "Sometimes")
        elseif f == "sub" then
            return R(where .. ", the note under " .. Q(o.label, 5) .. " on the card " .. title, "Your pick")
        elseif f == "log" then
            return R(where .. ", if " .. (party and "the table picks " or "you pick ") .. lab .. " at " .. title, "If chosen")
        elseif f == "roll" then
            local how = rest[4]
            if rest[5] == "empty" then
                local who = {}
                for k, pt in pairs(MODULE.portraits or {}) do
                    if pt.empty then
                        table.insert(who, HERO[k])
                    end
                end
                table.sort(who)
                return R(where .. ", " .. title .. ": a success on " .. util.join_names(who) .. "'s painting, which has nothing to take",
                    "On a success")
            end
            return R(where .. ", " .. title .. ": " .. lab .. " is picked and the roll " .. (how == "success" and "succeeds" or "fails"),
                how == "success" and "On a success" or "On a failure")
        end
    end
    return nil
end

-- The adventure (game/data/museum/module.lua) ------------------------------------------------------

local A = {}

A.ANSWER_NAMES = function(p)
    return R("Between sessions: a button for answering a friend's private request", "Your pick")
end

A.after_talk = function(p)
    local e = MODULE.endings[p[2]]
    return R("In the Gorgon's lair, if the talk ends it with " .. Q(e and e.name or p[2], 5) .. " and others came with her", "Always")
end

A.all_in = function(p)
    return R("At the first session's introductions, if " .. NAME[p[2]] .. " is all in", one_of(#MODULE.all_in[p[2]]))
end

A.reinforcements = function(p)
    local room, f = p[2], p[3]
    local card = Q("An early knockout")
    if f == "label" then
        return R("In a fight " .. lowfirst(in_room(room)) .. ", on " .. card .. ": the option to send more", "Always")
    elseif f == "soft" then
        return R("In a fight " .. lowfirst(in_room(room)) .. ", if you send more on " .. card .. " and the table veiled creepy-crawlies",
            "If chosen")
    end
    return R("In a fight " .. lowfirst(in_room(room)) .. ", if you send more on " .. card, "If chosen")
end

A.asides = function(p)
    local a = MODULE.asides[p[2]]
    if p[3] == "in_room" then
        return R("As the night's first fight starts, if it's " .. lowfirst(in_room(p[4])) .. if_(a and a.when), "Always")
    end
    local rooms = {}
    for r in pairs(a and a.in_room or {}) do
        table.insert(rooms, lowfirst(in_room(r)))
    end
    table.sort(rooms)
    local rest = (a and not a.no_sneak) and " (never two weeks running)" or ""
    return R("As the night's first fight starts" .. (#rooms > 0 and (", unless it's " .. table.concat(rooms, " or ")) or "")
        .. if_(a and a.when) .. rest, (a and a.lines) and one_of(#a.lines) or "Always")
end

A.author = function()
    return R("On the hooks page at Session Zero: the book's author", "Always")
end
A.title = function()
    return R("On the hooks page and the first night's opening slides: the adventure's title", "Always")
end
A.pitch = function()
    return R("On the hooks page at Session Zero: the adventure in a sentence", "Always")
end
A.credit = function()
    return R("At the foot of your notes and the journey recap: the book's credit", "Always")
end

A.base = function(p)
    if p[2] == "name" then
        return R("On Euryale's card: her name", "Always")
    end
    return R("On Euryale's card, under her name: how she fights before any marks", "Always")
end

A.chat = function(p)
    local line = MODULE.chat[p[2]][p[3]]
    local c = type(line) == "table" and line.when or nil
    return R("Group chat after a night " .. at_room(p[2]) .. ": " .. NAME[p[3]] .. "'s post" .. if_(c), "Sometimes")
end

A.chat_ask = function(p)
    local q = MODULE.chat_ask[p[2]]
    local who = NAME[q.who]
    if p[3] == "text" then
        local from = (q.from or 1) > 1 and (", from week " .. util.int(q.from)) or ""
        return R("In the group chat, " .. who .. " asks you this (one question a week" .. from .. ")" .. if_(q.when), "Sometimes")
    end
    local r = q.replies[p[4]]
    if p[5] == "label" then
        return R("In the group chat, a reply you can pick when " .. who .. " asks " .. Q(q.text:gsub("^@DM ", ""), 5), "Your pick")
    elseif p[5] == "say" then
        return R("In the group chat, what you post if you pick " .. Q(r.label, 5), "If chosen")
    elseif p[5] == "back" then
        return R("In the group chat, " .. who .. "'s answer after your reply " .. Q(r.label, 5), "If chosen")
    end
end

A.chat_banter = function(p)
    local b = MODULE.chat_banter[p[2]]
    local n = one_of(#MODULE.chat_banter)
    if p[3] == 2 then
        return R("In the group chat between sessions, from week 2: " .. NAME[b[1]] .. "'s small talk for the week", n)
    end
    return R("In the group chat: " .. NAME[b[3]] .. "'s reply to " .. NAME[b[1]] .. "'s " .. Q(b[2], 5), n)
end

A.companions = function(p)
    local c = MODULE.companions[p[2]]
    local name = c.name
    local owner = NAME[c.owner]
    local f = p[3]
    if f == "name" or f == "what" then
        return R("On " .. HERO[c.owner] .. "'s player tile, the hover for " .. name .. ", while " .. name .. " is along", "Always")
    elseif f == "helps" then
        return R("When " .. name .. " helps someone look around a room and turns up a Franc (once a night)", "Sometimes")
    elseif f == "lines" then
        local kind = p[4]
        local voice = c.kind == "person" and (name .. " pipes up") or (owner .. " says this")
        local list = c.lines[kind]
        if kind == "join" then
            return R("At the start of the first night " .. name .. " comes along", "Always")
        elseif kind == "start" then
            return R("At the start of each later night with " .. name .. " along: " .. voice, one_of(#list))
        elseif kind == "look" then
            return R("When " .. HERO[c.owner] .. " looks around with " .. name .. " along, and there's nothing much there: " .. voice,
                one_of(#list))
        elseif kind == "hint" then
            return R("When " .. HERO[c.owner] .. " looks around with " .. name .. " along, and there's something there (a find, or an "
                .. "answer worth the sniffing): " .. voice, one_of(#list))
        elseif kind == "fight" then
            return R("As a fight starts with " .. name .. " along, more often than not: " .. voice, one_of(#list))
        elseif kind == "win" then
            return R("Not said yet: nothing in the game plays " .. name .. "'s lines for a won fight", "Never")
        end
    end
end

A.endings = function(p)
    local id, f = p[2], p[3]
    local e = MODULE.endings[id]
    if id == "timeout" then
        if f == "name" then
            return R("In the report and journey recap, if the weeks run out with Euryale still upstairs", "Always")
        end
        return R("In the last session's report, if the weeks run out with Euryale still upstairs", "Always")
    end
    if f == "name" then
        return R("In the report and journey recap, when the prologue ends this way", "Always")
    elseif f == "line" then
        return R("On boss night, when the prologue ends with " .. Q(e.name, 5) .. "; also in the journey recap", "Always")
    elseif f == "flit" then
        return R("On boss night, Flitwidget's word right after the ending " .. Q(e.name, 5), "Always")
    elseif f == "stone_line" then
        return R("On boss night, when Euryale falls turned to stone by the mirror, in place of the usual line", "Always")
    end
end

A.epilogue = function()
    return R("On boss night, at the very end, after Flitwidget's thanks", "Always")
end

A.explore = function(p)
    local room, kind, pid, f = p[2], p[3], p[4], p[5]
    local place = (PLACES[room] or {})[pid] or "a spot on the board"
    local where = in_room(room)
    if kind == "finds" then
        if f == "what" then
            return R(where .. ", on the card " .. Q("Something to find") .. " when a friend looks around " .. place, "Always")
        end
        return R(where .. ", looking around " .. place .. ": if you pick " .. Q("They find it") .. " or more Francs", "If chosen")
    elseif kind == "traps" then
        if f == "what" then
            return R(where .. ", on the card " .. Q("A trap") .. " when a friend heads for " .. place, "Always")
        elseif f == "hit" then
            return R(where .. ": the trap at " .. place .. " goes off and their roll fails", "On a failure")
        elseif f == "dodge" then
            return R(where .. ": you let the trap at " .. place .. " go off and they roll clear", "On a success")
        elseif f == "spotted" then
            return R(where .. ": you give them a chance to spot the trap at " .. place .. ", and they do", "On a success")
        end
    end
end

A.extras_lost = function()
    return R("In the Gorgon's lair, if she's gone but her collection wins the fight that follows", "Always")
end

A.favors = function(p)
    local d = MODULE.favors[p[2]]
    local who = d.name
    if p[3] == "text" then
        return R("Between sessions, once the party has sided with " .. who .. " twice", "Always")
    elseif p[3] == "helps" then
        return R("Between sessions, after siding with " .. who .. " twice: one way it helps them", "Your pick")
    elseif p[3] == "hurts" then
        return R("Between sessions, after siding with " .. who .. " twice: one way it costs them", "Your pick")
    end
end

local FOE_LEADS = { knight_of_shades = true, briar_beast = true, giant_scarab_swarm = true, kruthik_huntling = true }
A.foe_names = function(p)
    if FOE_LEADS[p[2]] then
        return R("In the Gorgon's lair, naming the one who leads her collection once she's out of the fight", "Sometimes")
    end
    return R("Not said: the lair only names the foes that can fight at her side", "Never")
end

A.fork_at = function(p)
    if p[3] == "after" then
        return R("At a fork in the entrance hall, once both wings are done", "Always")
    end
    return R("At a fork in " .. rname(p[2]) .. ", as the table talks over where to go", "Always")
end

local FORK_WHEN = { wings = "while both wings are still ahead", second_wing = "once one wing is done",
                    hub = "upstairs, among the doors off the hunting floor", roam = "when the choice is going on or going back" }
A.forks = function(p)
    if p[3] == "title" then
        return R("At a fork " .. (FORK_WHEN[p[2]] or "") .. ": the card's title, if the table asks you", "Sometimes")
    end
    return R("At a fork " .. (FORK_WHEN[p[2]] or "") .. ", only where the room has no view of its own (rare)", "Sometimes")
end

A.glossary = function(p)
    local g = MODULE.glossary[p[2]]
    if p[3] == "match" then
        return R("Words that show the " .. Q(g.plain, 4) .. " hover, wherever they appear on screen", "Always")
    end
    return R("On hover over " .. Q(g.plain, 4) .. ", anywhere on screen", "Always")
end

A.heroes = function(p)
    if p[3] == "gist" then
        return R("At Session Zero, under the party: who " .. HERO[p[2]] .. " is", "Always")
    end
    return R("Not shown in the museum: only the older game's prep board shows it", "Never")
end

A.hooks = function(p)
    local who, h, f = p[2], MODULE.hooks[p[2]][p[3]], p[4]
    if f == "name" then
        return R("At Session Zero, on the hooks page: a reason " .. HERO[who] .. " might have come", "Your pick")
    elseif f == "text" then
        return R("On the hooks page at Session Zero, under " .. HERO[who] .. "'s reason " .. Q(h.name, 4), "Always")
    elseif f == "says" then
        return R("On the hooks page at Session Zero, " .. NAME[who] .. "'s quote under " .. Q(h.name, 4), "Always")
    elseif f == "intro" then
        return R("At the first session's introductions, if you picked " .. Q(h.name, 4) .. " for " .. HERO[who], "If chosen")
    elseif f == "payoff" then
        return R(in_room(h.room) .. ", when " .. HERO[who] .. "'s reason " .. Q(h.name, 4) .. " pays off", "If chosen")
    end
end

A.items = function(p)
    local it = MODULE.items[p[2]]
    if p[3] == "name" then
        return R("In the session report under " .. Q("Picked up") .. ", and its hover there, once they have it", "Always")
    end
    local where = (it.rooms and it.rooms[1] == "lair") and "As the fight in the Gorgon's lair starts" or "As a fight starts"
    local extra = it.ally == "steam_mech" and " with the Mech fighting beside them" or ""
    return R(where .. extra .. if_(it.when) .. (it.once and " (just the first time)" or ""), "Always")
end

A.keepsakes = function(p)
    local g = MODULE.keepsakes[p[2]]
    local f = p[3]
    if f == "name" then
        return R("After a session, when a friend's Goodwill fills up and they bring you this gift", "Sometimes")
    elseif f == "line" then
        return R("After a session, what a friend says as they hand you the " .. g.short, "Sometimes")
    elseif f == "use" then
        return R("After a session, if you put the " .. g.short .. " a friend gave you to use", "If chosen")
    elseif f == "short" then
        return R("How the " .. g.short .. " is named on the table, once a friend has given it", "Sometimes")
    end
end

A.knobs = function(p)
    local k = MODULE.knobs[p[2]]
    local f = p[3]
    if f == "name" then
        return R("On the prep board, under " .. rname(k.room) .. ": a way to run it you can switch on", "Your pick")
    elseif f == "say" then
        return R("As they enter " .. rname(k.room) .. ", if you switched on " .. Q(k.name, 5) .. " in prep", "If chosen")
    elseif f == "off" then
        return R("Not shown yet: the prep board only shows " .. Q(k.name, 5) .. " and a box to tick", "Never")
    elseif f == "blurb" then
        return R("Not shown yet: the prep board has no note for " .. Q(k.name, 5), "Never")
    end
end

A.loose_ends = function(p)
    local le = MODULE.loose_ends[p[2]]
    local room = le.when and le.when.skipped
    if p[3] == "text" then
        return R("Between sessions, if the party went on without " .. rname(room), "Always")
    end
    return R("Between sessions, if they went on without " .. rname(room) .. ": one way to settle it", "Your pick")
end

A.magic_items = function(p)
    local d = MODULE.magic_items[p[2]]
    if p[3] == "name" then
        return R("On the hero's sheet and in the report, once someone carries the " .. lowfirst(d.name), "Always")
    end
    return R("The hover for the " .. lowfirst(d.name) .. " on the hero's sheet and in the report", "Always")
end

A.marks = function(p)
    local id, f = p[2], p[3]
    local m = MODULE.marks[id]
    local why = MARK[id] or "this mark lands"
    if f == "name" then
        return R("On Euryale's card, once " .. why, "Always")
    elseif f == "why" then
        return R("On Euryale's card, the reason under " .. Q(m.name, 5), "Always")
    elseif f == "showdown" then
        return R("On Euryale's card: what " .. Q(m.name, 5) .. " changes on boss night", "Always")
    elseif f == "thought" then
        return R("Upstairs, Euryale's thought when " .. Q(m.name, 5) .. " lands on her card", "Always")
    elseif f == "thought_if" or f == "why_if" then
        local alt = m[f][p[4]]
        local what = f == "thought_if" and ("Upstairs, Euryale's thought when " .. Q(m.name, 5) .. " lands")
            or ("On Euryale's card, the reason under " .. Q(m.name, 5))
        return R(what .. if_(alt and alt.when), "Always")
    end
end

A.mech_names = function()
    return R("The Steam Mech's name, picked when the party reaches the World of Tomorrow", one_of(#MODULE.mech_names))
end

A.memory = function(p)
    local id = p[2]
    local m = MODULE.memory[id][p[3]]
    local who = id == "mus_telpur" and "Telpur" or "Flitwidget"
    if id == "mus_telpur" then
        -- (No talk card for Telpur: the gift shop is a short room. The notes' People tab shows it.)
        return R("What Telpur remembers, in your notes on the museum's people" .. if_(m and m.when), "Always")
    end
    return R("What Flitwidget remembers (his talk card at his thanks, and your notes)" .. if_(m and m.when), "Always")
end

A.moments = function(p)
    local card = MODULE.moments[p[2]]
    local rest = {}
    for i = 3, #p do
        table.insert(rest, p[i])
    end
    return moment_line(card, rest, card.room)
end

local NPC_NAME = { mus_flitwidget = "Flitwidget", mus_telpur = "Telpur", mus_euryale = "Euryale", mus_lecturer = "the Lecturer" }
-- Where each person's lines can come up (night:npc_line): a greeting is for a room without a fight,
-- or a short room (museum_night.quick_room); a good or bad word follows a hero's check, the chat or a
-- talk card, all of which only a full room without a fight has (night.lua quick_checks, conversation,
-- takeover.talk). Flitwidget's full room is his thanks; the gift shop is a short room; Euryale and the
-- Lecturer are fights (an improvised room plays short, so the Lecturer greets them then).
A.npc_lines = function(p)
    local sp, tr = p[2], p[3]
    local who = NPC_NAME[sp] or sp
    local n = one_of(#MODULE.npc_lines[sp][tr])
    if tr == "npc_greet" then
        if sp == "mus_euryale" then
            return R("Not said: greetings are for rooms without a fight, and her lair is one", "Never")
        elseif sp == "mus_lecturer" then
            return R("Only if you improvise the lecture theatre: the Lecturer's greeting, before the fight", n)
        elseif sp == "mus_telpur" then
            return R("When the party walks into the gift shop and Telpur greets them", n)
        end
        return R("On the street, when Flitwidget first greets the party", n)
    elseif tr == "npc_again" then
        if sp == "mus_flitwidget" then
            return R("At Flitwidget's thanks, when he greets the party again", n)
        end
        return R("When Telpur greets the party again, in a later session", n)
    elseif tr == "npc_good" or tr == "npc_bad" then
        if sp ~= "mus_flitwidget" then
            return R("Not said: " .. who .. " is only met in a short room or a fight, with no checks or talk", "Never")
        end
        return R("At Flitwidget's thanks, sometimes, right after a hero's roll " .. (tr == "npc_good" and "goes well, or a warm talk with him"
            or "goes badly, or after a lie caught in a talk"), n)
    elseif tr == "npc_taunt" then
        return R("In the fight with " .. who .. ": every second round from round 2, while still standing", n)
    elseif tr == "npc_down" then
        return R("When " .. who .. " falls in the fight", n)
    end
end

A.npc_sheet = function(p)
    local id, f = p[2], p[3]
    local who = NPC_NAME[id] or (id == "mus_bone_construct" and "the Bone Construct") or (id == "mus_knight" and "the Knight of Shades")
        or (id == "mus_sentinel" and "the Sentinel") or (id == "mus_mech" and "the Steam Mech") or id
    if f == "about" then
        return R("On " .. poss(who) .. " sheet, and the hover on their name", "Always")
    elseif f == "match" then
        return R("Words that open " .. poss(who) .. " sheet, wherever they appear in a line", "Always")
    elseif f == "not_before" then
        return R("Not said: stops " .. Q("Flitwidget Franc") .. " from opening Flitwidget's sheet", "Never")
    end
end

A.openings = function(p)
    local i = p[2]
    if i == 1 then
        return R("At the start of the very first night, on the opening slides and read out", "Always")
    elseif i == 2 then
        return R("At the start of the first night upstairs, past the gift shop", "Always")
    end
    return R("At the start of the night they climb to Euryale", "Always")
end

A.openings_from = function()
    return R("At the start of the first night upstairs, if the last one stopped in the gift shop", "Always")
end

A.outs = function()
    return R("In the Ties and locks editor: something that happened, for a lock to wait on", "Always")
end

A.people = function(p)
    local pp = MODULE.people[p[2]]
    return R("In your notes on the museum's people, and the hover on " .. pp.name .. "'s name", "Always")
end

local function portrait_line(whose, f)
    local card = Q("The paint is wet")
    if f == "painting" then
        return R("In the Hall of Paintings, on " .. card .. ", when the painting is " .. whose, "Always")
    elseif f == "hint" then
        return R("In the Hall of Paintings, on " .. card .. ": the danger you can see, when the painting is " .. whose, "Always")
    elseif f == "danger" then
        return R("In the Hall of Paintings, if you warn them about " .. whose .. " painting, and in your notes on fair warning", "Sometimes")
    elseif f == "bite" or f == "aspect" then
        return R("In the Hall of Paintings, on " .. card .. ": a missed roll reaching into " .. whose .. " painting", "On a failure")
    end
    return R("In the Hall of Paintings: what comes out of " .. whose .. " painting on " .. card, "On a success")
end

A.portraits = function(p)
    return portrait_line(HERO[p[2]] .. "'s", p[3])
end

A.portrait_default = function(p)
    return portrait_line("anyone else's (the elf in the snow)", p[2])
end

A.premise = function()
    return R("In your notes: the adventure's secrets, for your eyes only", "Always")
end

A.prep_notes = function(p)
    local what = p[3] == "voices" and "a voice to practise" or "a handout to have ready"
    return R("On the prep board, under " .. rname(p[2]) .. ": " .. what, "Always")
end

A.pull = function(p)
    if p[3] == "label" then
        return R("At a fork with " .. rname(p[2]) .. " on offer: that way, as the table names it", "Sometimes")
    end
    return R("At a fork, how a friend says they want " .. rname(p[2]) .. ": " .. Q("Mara wants …"), "Sometimes")
end

A.recap = function(p)
    if p[2] == "lair" and p[3] == "win" then
        return R("Not said: the museum is over once they win in her lair, so no next night recaps it", "Never")
    end
    local well = p[3] == "win" and "went well" or "went badly"
    return R("At the start of the next night, " .. Q("Last time, they …") .. ", if " .. rname(p[2]) .. " " .. well, "Always")
end

A.recap_beats = function(p)
    if p[2] == "escape" then
        return R("In the session recap, when a foe got away", one_of(#MODULE.recap_beats.escape))
    end
    return R("In the session recap, when someone falls", one_of(#MODULE.recap_beats[p[2]]))
end

local STATE = { down = "went down last session", last_hit = "landed a killing blow last session", spells = "is out of spells",
                hurt = "is still hurt", party = "the whole party is worn down" }
A.requests = function(p)
    local rq = MODULE.requests[p[2]]
    local who = NAME[rq.who]
    local after = rname(rq.after) .. " is done" .. (rq.needs_flag and (" and " .. (FLAG[rq.needs_flag] or "")) or "")
    local f = p[3]
    if f == "ask" then
        if rq.only_if then
            return R("Not said: " .. who .. " only asks this in one of the variants below", "Never")
        end
        return R("Between sessions, " .. who .. "'s private message to you, once " .. after
            .. (rq.ask_if and ", unless a variant below fits" or ""), "Always")
    elseif f == "ask_if" then
        local alt = rq.ask_if[p[4]]
        local why = alt.state and ((alt.state == "party" and STATE.party) or (HERO[rq.who] .. " " .. (STATE[alt.state] or "is worn")))
            or cond(alt.when)
        return R("Between sessions, " .. who .. "'s private message once " .. after .. ", if " .. (why or "it fits"), "Always")
    elseif f == "about" then
        return R("On the prep board, above " .. who .. "'s request", "Always")
    elseif f == "answers" then
        return R("Between sessions, your reply to " .. who .. "'s request if you answer " .. Q(MODULE.ANSWER_NAMES[p[4]], 5), "If chosen")
    end
end

local REVISIT = { missed = "someone wants another look at a cleared room with something still in it",
                  hint = "you've hinted a cleared room still has something in it",
                  passed = "someone wants to see a room they walked past",
                  shop = "someone has Francs to spend in the gift shop",
                  rest = "everyone's hurt and wants to fall back to the gift shop" }
A.revisit_why = function(p)
    return R("At a fork, when " .. (REVISIT[p[2]] or "someone wants to go back"), "Sometimes")
end

A.rooms = function(p)
    local id, f = p[2], p[3]
    local r = MODULE.rooms[id]
    if f == "name" then
        return R("The room's name, on the map, the prep board and the mat", "Always")
    elseif f == "read" then
        return R("As the party walks into " .. rname(id) .. ": its read-aloud" .. (r.read_if and ", unless a variant below fits" or ""),
            "Always")
    elseif f == "read_if" then
        return R("As the party walks into " .. rname(id) .. if_(r.read_if[p[4]].when), "Always")
    elseif f == "sum" then
        return R("On the prep board and in your notes, under " .. rname(id), "Always")
    elseif f == "callbacks" then
        return R("As they enter " .. rname(id) .. if_(r.callbacks[p[4]].when), "Always")
    elseif f == "boss_name" then
        return R(in_room(id) .. ": what the fight's leader is called", "Always")
    end
end

A.ruling_costs = function(p)
    local n = one_of(#MODULE.ruling_costs[p[2]])
    if p[2] == "near" then
        return R("When a big roll just misses and you rule " .. Q("Yes, at a cost. Close enough", 6) .. ": the hero takes 1d4", n)
    end
    return R("When a big roll succeeds and you rule " .. Q("Yes, but... it costs them something", 6) .. ": the hero takes 1d4", n)
end

A.showdown = function(p)
    local f = p[2]
    if f == "openers" or f == "styles" then
        local what = f == "openers" and "how Euryale opens" or "how Euryale fights"
        if p[4] == "name" then
            return R("On the boss night prep board: " .. what .. ", for you to pick", "Your pick")
        end
        return R("On the boss night prep board, under " .. Q(MODULE.showdown[f][p[3]].name, 5), "Always")
    elseif f == "drink" or f == "talk" or f == "yield" then
        local rest = {}
        for i = 3, #p do
            table.insert(rest, p[i])
        end
        return moment_line(MODULE.showdown[f], rest, "lair")
    elseif f == "dead_but_lost" then
        return R("In the Gorgon's lair, if she dies but her collection still wins the fight", "Always")
    elseif f == "yield_line" then
        return R("In the fight in her lair, the moment Euryale yields (if you prepped her to)", "Always")
    end
end

A.sides = function(p)
    local s = MODULE.sides[p[2]]
    if p[3] == "name" or p[3] == "about" then
        return R("On the Story sidebar on game night: " .. Q(s.name, 5), "Always")
    elseif p[3] == "with" then
        return R("On the Story sidebar, under Euryale, once " .. (MARK[p[4]] or "a mark lands"), "Always")
    elseif p[3] == "members" then
        local m = s.members[p[4]]
        if p[5] == "states" then
            return R("On the Story sidebar, " .. poss(lthe(m.name)) .. " line" .. if_(m.states[p[6]].when), "Always")
        end
        return R("On the Story sidebar, under " .. Q(s.name, 5), "Always")
    end
end

A.thoughts = function(p)
    if p[2] == "arrive" then
        return R("When the party climbs the stairs up: Euryale, upstairs", "Always")
    end
    return R("At the start of each night: Euryale, upstairs", one_of(#MODULE.thoughts.open))
end

A.want_more = function(p)
    local who = p[2]
    local l = MODULE.want_more[who][p[3]]
    local c = type(l) == "table" and l.when or nil
    return R("When the prologue ends, " .. NAME[who] .. "'s parting word" .. if_(c), one_of(#MODULE.want_more[who]))
end

local STANCE = { warm = "Warm", guarded = "Guarded", lie = "A lie" }
local TALK_SET = { open = "meeting the party for the first time", again = "seeing them again in a later session",
                   ask = "when the hero asks what they know", done = "at his thanks, his first words",
                   done_ask = "at his thanks, when the hero asks about the reward" }
A.talk = function(p)
    local who = NPC_NAME[p[2]] or p[2]
    -- (takeover.talk runs only in a full room: never the gift shop or the street. At Flitwidget's
    -- thanks the museum is done: his "done" lines first, then "done_ask" when they ask about the reward.)
    if p[2] == "mus_telpur" then
        return R("Not said: the gift shop is a short room, and short rooms have no " .. Q("Talk as …") .. " card", "Never")
    elseif p[3] ~= "done" and p[3] ~= "done_ask" then
        return R("Not said: you only talk as Flitwidget at his thanks, once it's over, and then his " .. Q("done") .. " lines are used",
            "Never")
    end
    return R("On the " .. Q("Talk as " .. who) .. " card, " .. TALK_SET[p[3]] .. ": the " .. Q(STANCE[p[4]] or p[4]) .. " line",
        "Your pick")
end

-- Small moments (game/data/museum/table_life.lua, game/model/table_life.lua) ----------------------

local TL_KIND = { banter = "some banter", snack = "a snack", plan = "planning at the door", cantrip = "a cantrip trick",
                  pocket = "a souvenir pocketed", drink = "a drink", name = "a naming", haggle = "haggling with Telpur" }

local function fond_of(who)
    local keys, seen = {}, {}
    for _, a in ipairs(who or {}) do
        for _, k in ipairs(ARCH_WHO[a] or {}) do
            if not seen[k] then
                seen[k] = true
                table.insert(keys, k)
            end
        end
    end
    return #keys > 0 and names(keys) or nil
end

local ANSWER_WORDS = { dull = "the plain answer (a roll under 10)", detail = "the detail (a roll of 10 to 16)",
                       lore = "the bit of lore (17 or more)" }

local function small_moment(p)
    -- p: rooms/<room>/<part>/<i>/<field>..., or people/<who>/<slip|misheard>/<i>
    if p[1] == "people" then
        local who = p[2] == "telpur" and "Telpur" or (p[2] == "flitwidget" and "Flitwidget") or tostring(p[2])
        if p[3] == "slip" then
            return R("A natural 20 asking " .. who .. " a question in a quiet moment, if you pick " .. Q(who .. " lets something slip"),
                "If chosen")
        end
        return R("A natural 1 asking " .. who .. " a question in a quiet moment, if you pick " .. Q(who .. " hears a different question"),
            "If chosen")
    end
    local room, part, i = p[2], p[3], p[4]
    local TLD = MODULE.table_life
    if part == "scare" then
        if room == "lair" or room == "street" then
            return R("Not said: no little scares " .. at_room(room), "Never")
        end
        return R("A natural 1 poking at something " .. at_room(room) .. ", if you pick the little scare", "If chosen")
    end
    local rd = TLD.rooms[room] or {}
    local b = rd[part] and rd[part][i] or {}
    local f = p[5]
    if room == "lair" then
        return R("Not said: small moments never play in the Gorgon's lair", "Never")
    end
    if b.when and b.when.done == "lair" then
        return R("Not said: the museum is over once Euryale is dealt with, and the thanks scene has no small moments", "Never")
    end
    local where = "Quiet moment " .. at_room(room)
    if part == "curios" then
        local what = plain(b.what or "something")
        local fans = fond_of(b.who)
        if f == "ask" then
            return R(where .. ": a friend" .. (fans and (" (often " .. fans .. ")") or "") .. " pokes at " .. what, "Sometimes")
        elseif f == "dull" then
            return R(where .. ": someone pokes at " .. what .. " and rolls under 10", "On a failure")
        elseif f == "detail" then
            return R(where .. ": someone pokes at " .. what .. " and rolls 10 to 16", "On a success")
        elseif f == "lore" then
            return R(where .. ": someone pokes at " .. what .. " and rolls 17 or more", "On a success")
        elseif f == "react" then
            local lvl = p[6]
            local list = (b.react or {})[lvl] or {}
            local entry = list[p[7]]
            local cond_words = type(entry) == "table" and entry.when and if_(entry.when) or ""
            if lvl == "any" then
                return R(where .. ": often, a friend's reaction to someone poking at " .. what .. ", whatever you answer" .. cond_words,
                    "Sometimes")
            end
            return R(where .. ": often, a friend's reaction after " .. (ANSWER_WORDS[lvl] or "your answer") .. " about " .. what
                .. cond_words, one_of(#list))
        elseif f == "see" then
            return R(where .. ": what you describe first, before a friend pokes at " .. what, "Sometimes")
        elseif f == "what" then
            return R(where .. ": its name on the natural 20 or 1 card", "Sometimes")
        elseif f == "crit1" then
            return R(where .. ": a natural 1 poking at " .. what .. ", if you pick the mishap", "If chosen")
        elseif f == "crit20" then
            if p[6] == "find" then
                return R(where .. ": a find you can hide, on a natural 20 poking at " .. what, "Your pick")
            end
            return R(where .. ": a natural 20 poking at " .. what .. ", if you pick the clue", "If chosen")
        end
    elseif part == "npc_questions" then
        local who = b.who == "telpur" and "Telpur" or (b.who == "flitwidget" and "Flitwidget") or tostring(b.who)
        if f == "ask" then
            return R(where .. ": a friend asks " .. who .. " this, in character" .. if_(b.when), "Sometimes")
        elseif f == "better" then
            return R(where .. ": " .. who .. "'s fuller answer, if the asker rolls 15 or more", "On a success")
        elseif f == "answer" then
            return R(where .. ": " .. who .. "'s answer, if the asker rolls under 15", "On a failure")
        end
    elseif part == "table_bits" then
        local kind = TL_KIND[b.kind] or "a little table business"
        if f == "keepsake" then
            return R("Not shown yet: the souvenir " .. HERO[b.who] .. " pockets " .. at_room(room) .. " is noted, never named", "Never")
        end
        return R(where .. ": " .. kind .. ", told by the table" .. if_(b.when), "Sometimes")
    end
end

-- Adventure cards (game/data/museum/cards.lua), as game night plays them ---------------------------

local CARD_ROOM = {}     -- card id -> room id, by the rooms' comps
for id, r in pairs(MODULE.rooms) do
    for _, cid in pairs(r.comps or {}) do
        CARD_ROOM[cid] = CARD_ROOM[cid] or id
    end
end

-- A room played as a full scene with checks (night:play_scene's quick_checks): not a short room, and
-- not one that's always a fight.
local function has_checks(rid)
    local r = MODULE.rooms[rid]
    if not r or r.quick or r.virtual then
        return false
    end
    if (r.type == "combat" or r.type == "set_piece") then
        return false
    end
    return true
end

-- A goal's variant (museum_night alt_holds): its when, who fled, the ending, a purchase. Returns the
-- words that must hold ("x and y") and the ones that mustn't ("z"), either may be nil.
local function alt_words(alt)
    local bits, nots = {}, nil
    local c = cond(alt.when)
    if c then
        local pos, neg = string.match(c, "^(.-), unless (.+)$")
        if not pos then
            neg = string.match(c, "^unless (.+)$")
            pos = not neg and c or nil
        end
        if pos and pos ~= "" then
            table.insert(bits, pos)
        end
        nots = neg
    end
    if alt.fled == true then
        table.insert(bits, "some foes ran")
    elseif alt.fled == false then
        table.insert(bits, "none ran")
    end
    if alt.ending then
        local e = MODULE.endings[alt.ending]
        table.insert(bits, "the ending is " .. Q(e and e.name or alt.ending, 4))
    end
    if alt.bought == true then
        table.insert(bits, "they bought something")
    elseif alt.bought == false then
        table.insert(bits, "they bought nothing")
    end
    return #bits > 0 and table.concat(bits, " and ") or nil, nots
end
-- ", if x, unless z" (after a clause) or " and x, unless z" (after "if it went well").
local function alt_tail(alt, joined)
    local pos, neg = alt_words(alt)
    local out = ""
    if pos then
        out = (joined and " and " or ", if ") .. pos
    end
    if neg then
        out = out .. ", unless " .. neg
    end
    return out
end

local function card_line(p)
    local C = require "game.data.museum.cards"
    if p[1] == "goal_play" then
        local gid = p[2]
        local rid = CARD_ROOM[gid]
        local where = in_room(rid)
        local f = p[3]
        local gp = C.goal_play[gid]
        if MODULE.rooms[rid] and MODULE.rooms[rid].quick then
            return R("Not said: " .. rname(rid) .. " is a short room, played without these", "Never")
        end
        if f == "intent" then
            return R("As they enter " .. rname(rid) .. ", a friend says what the party is after", one_of(#gp.intent))
        end
        if not has_checks(rid) then
            return R("Not said: " .. rname(rid) .. " is a fight, and these are for rooms worked without one", "Never")
        end
        if f == "talk" then
            return R(where .. ", if there's no fight: a friend's aside as the heroes work", "Sometimes")
        elseif f == "approaches" then
            local g = p[5]
            if g == "say" then
                return R(where .. ", if there's no fight: a hero tries this toward the goal", "Sometimes")
            elseif g == "win" then
                return R(where .. ": a hero's try at the goal works", "On a success")
            else
                return R(where .. ": a hero's try at the goal doesn't work", "On a failure")
            end
        elseif f == "moment" then
            if MODULE.rooms[rid].epilogue then
                return R("Not said: Flitwidget's thanks has no big final roll", "Never")
            end
            return R(where .. ", if there's no fight: the room's big final roll", "Always")
        end
        return nil
    end
    local c = C.cards[p[2]]
    local f = p[3]
    local rid = CARD_ROOM[c.id]
    local room = rid and rname(rid) or "the museum"
    local where = rid and in_room(rid) or "In the museum"
    if c.kind == "location" then
        if f == "name" then
            return R("The scene's title on the mat in " .. room .. ", and in the report", "Always")
        elseif f == "short" then
            return R("How " .. room .. " is named in passing: the report, the recap", "Always")
        end
        return R("Not said in the museum: each room's own read-aloud is used instead", "Never")
    elseif c.kind == "cast" then
        local who = c.short or c.name
        if f == "name" then
            return R("Over " .. poss(who) .. " mini and in the captions", "Always")
        elseif f == "short" then
            return R("How " .. who .. " is named in passing lines", "Always")
        elseif f == "line" then
            if c.line_if then
                return R(where .. ", when the party first sees " .. who .. ", unless a variant below fits", "Always")
            end
            return R(where .. ", when the party first sees " .. who, "Always")
        elseif f == "line_if" then
            return R(where .. ", when the party first sees " .. who .. if_(c.line_if[p[4]].when), "Always")
        elseif f == "again" then
            return R("When the party meets " .. who .. " again later", "Always")
        elseif f == "deal" or f == "secret" then
            return R("Not said: no line in the museum asks for " .. poss(who) .. " " .. f, "Never")
        end
    elseif c.kind == "goal" then
        if f == "name" then
            return R("The goal in " .. room .. ", in the top bar and on the room's end card", "Always")
        elseif f == "line" then
            return R("As they enter " .. room .. ": the party's goal there", "Always")
        elseif f == "ask" then
            if MODULE.rooms[rid] and MODULE.rooms[rid].quick then
                return R("Not said: " .. room .. " is a short room, and short rooms have no talk card", "Never")
            end
            return R("On the " .. Q("Talk as Flitwidget") .. " card at his thanks: what the hero asks him about", "Sometimes")
        elseif f == "got" then
            return R("In the recap and the story so far: what the party got from " .. room
                .. (c.got_if and ", unless a variant below fits" or ""), "Always")
        elseif f == "got_if" then
            return R("In the recap and the story so far, what they got from " .. room .. alt_tail(c.got_if[p[4]], false), "Always")
        elseif f == "win" then
            return R("At the end of " .. room .. ", if it went well" .. (c.win_if and ", unless a variant below fits" or ""), "Always")
        elseif f == "win_if" then
            return R("At the end of " .. room .. ", if it went well" .. alt_tail(c.win_if[p[4]], true), "Always")
        elseif f == "lose" then
            return R("At the end of " .. room .. ", if it went badly", "Always")
        elseif f == "lose_if" then
            return R("At the end of " .. room .. ", if it went badly" .. alt_tail(c.lose_if[p[4]], true), "Always")
        end
    elseif c.kind == "complication" then
        if not has_checks(rid) then
            return R("Not said: " .. room .. (MODULE.rooms[rid] and MODULE.rooms[rid].quick and " is a short room" or " is a fight")
                .. ", and a room's snag only plays while heroes work a room", "Never")
        end
        if f == "name" then
            return R("Not shown: the museum never names a room's snag on screen, only its lines", "Never")
        elseif f == "line" then
            return R(where .. ", if there's no fight: the snag, as the heroes get to work", "Always")
        elseif f == "moment" then
            if p[4] == "text" then
                return R(where .. ", if there's no fight: the snag's roll, midway", "Sometimes")
            elseif p[4] == "success" then
                return R(where .. ": the snag's roll succeeds", "On a success")
            else
                return R(where .. ": the snag's roll fails", "On a failure")
            end
        end
    elseif c.kind == "reward" then
        local rooms = {}
        for id, r in pairs(MODULE.rooms) do
            if r.comps and r.comps.reward == c.id then
                table.insert(rooms, id)
            end
        end
        table.sort(rooms)
        local rn = #rooms == 1 and rname(rooms[1]) or "a room"
        if f == "name" or f == "got" then
            return R("In the report's " .. Q("Picked up") .. " and the room's end card, once they have it", "Always")
        elseif f == "line" then
            if c.owner or (c.francs and c.said) then
                return R("Not said: " .. (c.owner and "a moment in the room hands this over" or "the room says its own line instead"), "Never")
            end
            return R("At the end of " .. rn .. ", if it went well: " .. Q("They earn …"), "Always")
        elseif f == "said" then
            local list = {}
            for _, id in ipairs(rooms) do
                table.insert(list, rname(id))
            end
            return R("At the end of " .. util.join_names(list, "or") .. ", if it went well, as the Franc is counted", "Always")
        elseif f == "lost" then
            return R("At the end of " .. rn .. ", if it went badly", "Always")
        end
    end
    return nil
end

-- Shared lines --------------------------------------------------------------------------------------

-- Fight barks (game/data/barks.lua, game/model/barks.lua, fight.lua).
local FACT = { nat20 = "on a natural 20", crit19 = "on a 19 that crits", more_left = "with foes still left",
               last = "and it's the last one", cleric = "as a cleric" }
local FACT_FITS = { nat20 = "the die shows a natural 20", more_left = "foes are still standing", small_foe = "the foe isn't the boss",
                    big_hit = "the hit took nearly half their hit points", low_hp = "they're badly hurt",
                    was_winning = "they'd dealt damage first", concentrating = "they're holding a spell",
                    round3 = "it's round 3 or later", long_fight = "it's round 5 or later", surge_ready = "Action Surge is ready",
                    party_hurt = "someone's hurt", target_down = "the target is down", fire = "the spell is a fire spell",
                    dmg19 = "the damage was exactly 19", never = "never", spell_fire_bolt = "the spell is Fire Bolt",
                    spell_sacred_flame = "the spell is Sacred Flame", spell_bless = "the spell is Bless", survivors = "some foes got away",
                    no_slots = "they're out of spells" }
local BARK_WHAT = { crit = "lands a critical hit", kill = "takes down a foe", ally_down = "sees a friend drop",
                    big_hit = "deals 12 or more damage", down_self = "drops to 0 hit points", fight_chat = "chats between rounds",
                    hit = "lands a hit", miss = "misses every attack", ouch = "takes a big hit and stays up", spell = "casts a spell",
                    thanks = "is healed back up", up_again = "is back on {pos} feet", walk = "spends a turn only walking" }

local function bark_line(p)
    local B = require "game.data.barks"
    if p[1] == "charmed_captions" then
        return R("In a fight, when a charmed hero won't attack the one who charmed them", one_of(#B.charmed_captions))
    elseif p[1] == "walk_captions" then
        return R("In a fight, after a round of only walking with the foes still far off (twice a fight at most)",
            one_of(#B.walk_captions))
    elseif p[1] == "fits" then
        local rule = B.fits[p[2]]
        return R("Not said: a fight line with " .. Q(rule[1], 4) .. " in it only plays when "
            .. (FACT_FITS[rule[2]] or "it fits"), "Never")
    elseif p[1] == "context" then
        local CTX = { nobody_here = "nobody's there to talk to", someone_here = "someone's there to talk to",
                      fight_here = "the room has a fight in it", no_fight_here = "the room has no fight in it",
                      calm = "the room's danger is settled", clue_found = "something was learned earlier tonight",
                      big_foe = "the one leading the fight is Large or bigger", several_foes = "there's more than one foe",
                      boss_is_a_thing = "the one leading the fight is a creature, not a person" }
        local rule = B.context[p[2]]
        return R("Not said: a table line with " .. Q(rule[1], 4) .. " in it only plays when " .. (CTX[rule[2]] or "it fits"), "Never")
    elseif p[1] == "made" then
        local tr, who = p[2], p[3]
        local l = B.made[tr][who][p[4]]
        local extra = l.when and (" " .. (FACT[l.when] or "when it fits")) or ""
        local what = string.gsub(BARK_WHAT[tr] or tr, "{pos}", POS[who] or "their")
        return R("In a fight, when " .. HERO[who] .. " " .. what .. extra, one_of(#B.made[tr][who]))
    end
end

-- First-session introductions (game/data/intros.lua, game/model/intros.lua).
local function intro_line(p)
    local D = require "game.data.intros"
    if p[1] == "PLAYERS" then
        local who, f = p[2], p[3]
        if f == "hello" then
            return R("At the first session's introductions, " .. NAME[who] .. " says hello", one_of(#D.PLAYERS[who].hello))
        elseif f == "story" then
            local h = MODULE.hooks[who] and MODULE.hooks[who][p[4]]
            return R("At the first session's introductions, if you picked " .. Q(h and h.name or "this reason", 4) .. " for " .. HERO[who],
                "If chosen")
        elseif f == "all_in" then
            return R("At the first session's introductions, if " .. NAME[who] .. " is all in", one_of(#D.PLAYERS[who].all_in))
        end
    elseif p[1] == "REACT" then
        local k = p[2]
        if k == "grim" then
            return R("Not said in the museum: it answers a sad backstory, and every museum reason is light", "Never")
        end
        local what = (k == "all_in" and "someone who's all in") or (k == "short" and "a shy friend's short intro")
            or "an intro"
        return R("At the first session's introductions, a friend's reaction to " .. what, one_of(#D.REACT[k]))
    end
end

-- Killing blows (game/data/killing_blows.lua, night:killing_blow).
local function kb_line(p)
    local K = require "game.data.killing_blows"
    if p[1] == "told" then
        local who = p[2]
        return R("In a fight, when another hero drops a boss and the telling is handed to " .. NAME[who], one_of(#K.told[who]))
    end
    local key = CLASS_KEY[p[1]]
    local l = K[p[1]][p[2]]
    return R("In a fight, when " .. HERO[key] .. " drops a boss and you let " .. NAME[key] .. " describe it"
        .. ((l.level or 0) >= 3 and ", from level 3" or ""), one_of(#K[p[1]]))
end

-- Thoughts (game/data/thoughts.lua, game/model/thoughts.lua).
local NEED = { spotlight = "wants a turn in the spotlight", story = "wants a mystery to chew on", pace = "loses the thread in a long fight",
               challenge = "wants some danger", social = "wants to talk to someone", reward = "wants some loot",
               off_spot = "has just had every eye at the table on them", fairness = "doubts a roll or a harsh call", plan = "is about to go off alone",
               glow = "is having a great time", tired = "is tired from the week", stressed = "has had a rough week",
               distracted = "is half somewhere else", celebrating = "has good news", chatty = "is in a mood to talk" }
-- plural: "they want" rather than "she wants".
local function need_words(need, plural)
    local base = string.match(need, "^(.-)_after$")
    local w = NEED[base or need] or "wants something"
    if plural then
        if string.find(w, "^has ") then
            w = string.gsub(w, "^has ", "have ")
        elseif string.find(w, "^is ") then
            w = string.gsub(w, "^is ", "are ")
        else
            w = string.gsub(w, "^(%a+)s ", "%1 ")
        end
    end
    if base then
        return w .. ", just after a call that cost them"
    end
    return w
end

local function thought_line(p)
    local T = require "game.data.thoughts"
    if p[1] == "lines" then
        local who, need = p[2], p[3]
        return R("On game night, " .. NAME[who] .. "'s unspoken thought when " .. SUBJ[who] .. " " .. need_words(need),
            one_of(#T.lines[who][need]))
    elseif p[1] == "generic" then
        local need = p[2]
        return R("Anyone's unspoken thought (when they've none of their own), if they " .. need_words(need, true), one_of(#T.generic[need]))
    elseif p[1] == "answers" then
        local a = T.answers[p[2]]
        local for_needs = {}
        for k, d in pairs(T.needs) do
            for _, aid in ipairs(d.answers or {}) do
                if aid == p[2] then
                    table.insert(for_needs, k)
                end
            end
        end
        table.sort(for_needs)
        local about = #for_needs == 1 and (" (a friend who " .. need_words(for_needs[1]) .. ")") or ""
        if p[3] == "label" then
            return R("On a thought you've read" .. about .. ": an answer you can give", "Your pick")
        end
        return R("If you answer a thought with " .. Q(a.label, 6), "If chosen")
    elseif p[1] == "ask_straight" then
        if p[2] == "label" then
            return R("On a thought you couldn't read: ask them straight out", "Your pick")
        end
        return R("If you ask a friend straight out about a thought you couldn't read", "If chosen")
    elseif p[1] == "reads" then
        local k = p[2]
        local map = { book = { "When your read of a thought rolls a natural 20", "On a success" },
                      clear = { "When your read of a thought succeeds", "On a success" },
                      gist = { "When your read of a thought misses by 4 or less", "On a failure" },
                      miss = { "When your read of a thought misses", "On a failure" },
                      misread = { "When your read of a thought rolls a natural 1 (you get it wrong)", "On a failure" },
                      asked = { "After you ask a friend straight out", "If chosen" } }
        local m = map[k]
        if m then
            return R(m[1], m[2])
        end
    elseif p[1] == "misread_after" then
        return R("Later that night, after you answered a thought you'd misread", "Always")
    elseif p[1] == "news" then
        return R("If you make room for " .. NAME[p[2]] .. "'s good news, a thought you've read", "If chosen")
    end
end

-- Table behaviour (game/data/table_behaviors.lua, night:table_behavior, night:stunt).
local TB_WHEN = { start = "at the start of game night", idle = "in a quiet stretch while the heroes work a room",
                  after_crit = "right after a natural 20", after_fail = "right after a failed roll", combat = "between rounds of a fight",
                  social = "when the heroes start talking to someone in a room", rules = "when a rules call comes up",
                  long_scene = "when a room runs long", late = "late in the evening", ["end"] = "as the session ends" }
local function tb_line(p)
    local T = require "game.data.table_behaviors"
    if p[1] == "behaviors" then
        local b = T.behaviors[p[2]]
        local who
        if b.archetype and b.archetype ~= "any" then
            who = names(ARCH_WHO[b.archetype] or {})
        end
        local by = (b.by == "roller" and "the one who rolled") or (b.by == "other" and "a friend, to the one who rolled") or nil
        local speaker = who and (by and (who .. ", as " .. by) or who) or (by or "anyone")
        local line = b.lines[p[4]]
        if type(line) == "table" and line.late then
            return R("Sometimes, " .. (TB_WHEN[b.when] or "at the table") .. ": whoever the group chat said would be late this week"
                .. (line.late ~= "any" and (", because of the " .. line.late) or "") .. ", out of character", "Sometimes")
        end
        return R("Sometimes, " .. (TB_WHEN[b.when] or "at the table") .. ": " .. speaker .. ", out of character", one_of(#b.lines))
    elseif p[1] == "stunts" then
        local st = T.stunts[p[2]]
        local who = st.archetype and names(ARCH_WHO[st.archetype] or {}) or "a hero"
        if p[3] == "say" then
            return R("Sometimes, as a fight starts: " .. who .. "'s stunt on the boss", "Sometimes")
        elseif p[3] == "win" then
            return R("As a fight starts, the stunt " .. Q(st.say, 5) .. " works", "On a success")
        else
            return R("As a fight starts, the stunt " .. Q(st.say, 5) .. " fails", "On a failure")
        end
    end
end

-- Friends and friction (game/data/friction.lua, MODULE.friction, night:party_moment).
local FR_WHEN = { fight = "after a won fight", social = "in a room with someone to talk to", explore = "after exploring or a puzzle",
                  loot = "after a room with a prize", story = "in a room tied to someone's reason for coming", any = "at a room's end" }
local function friction_def(part, id_or_i)
    local F = require "game.data.friction"
    local list = F[part] or {}
    if type(id_or_i) == "number" then
        return list[id_or_i]
    end
    for _, d in ipairs(list) do
        if d.id == id_or_i then
            return d
        end
    end
end
local function friction_line(part, key, field)
    local d = friction_def(part, key)
    if part == "acts" then
        local who = d and d.class and HERO[CLASS_KEY[d.class]] or "a friend"
        return R("Sometimes, " .. (FR_WHEN[d and d.when or "any"] or "at a room's end") .. ": something " .. who
            .. " does that rubs the others (once a prologue)", "Sometimes")
    elseif part == "bonds" then
        return R("Sometimes, " .. (FR_WHEN[d and d.when or "any"] or "at a room's end") .. ": a kind turn between two friends", "Sometimes")
    elseif part == "responses" then
        if field == "label" then
            return R("On the card " .. Q("At the table") .. ", after a friend's act rubs someone: your answer", "Your pick")
        end
        return R("If you answer a friend's act with " .. Q(d and d.label or "this", 5), "If chosen")
    elseif part == "jabs" then
        local F = require "game.data.friction"
        return R("Right after a friend's act annoys someone: the look they give", one_of(#F.jabs))
    end
end

-- Session Zero (game/data/session_zero.lua with the museum's swapped in, game/ui/session_zero_view.lua).
-- Which friend's reaction a table rule shows once it's picked: whoever feels most strongly (a tie goes
-- to the first at the table); the last rule, drawn compact, shows the first who has one.
local function s0_shown(rk, ok)
    local content = require "game.model.content"
    local S = content.session_zero
    local r = S.rules[rk]
    local o = r and r[ok]
    if not (o and o.says) then
        return nil
    end
    local order = content.players.order or { "mara", "dev", "jess", "sam" }
    local last = S.rules.order and S.rules.order[#S.rules.order] == rk and r.compact
    local best, bv
    for _, key in ipairs(order) do
        if o.says[key] then
            local v = math.abs((o.like or {})[key] or 0)
            if last then
                return key
            end
            if not bv or v > bv then
                best, bv = key, v
            end
        end
    end
    return best
end
local function s0_says(rk, ok, who, on, rn)
    local shown = s0_shown(rk, ok)
    if shown and shown ~= who then
        return R("Not shown: picking " .. on .. " for " .. rn .. " shows " .. NAME[shown] .. "'s reaction instead", "Never")
    end
    return R("At Session Zero, " .. NAME[who] .. "'s reaction if you pick " .. on .. " for " .. rn, "If chosen")
end

local function s0_line(p)
    local content = require "game.model.content"
    local S = content.session_zero
    local f = p[1]
    if f == "pitch" then
        return R("At Session Zero: the question over the tones", "Always")
    elseif f == "tones" then
        local t = S.tones[p[2]]
        if p[3] == "name" then
            return R("At Session Zero: a tone you can pitch", "Your pick")
        elseif p[3] == "blurb" then
            return R("At Session Zero, under the tone " .. Q(t.name, 5), "Always")
        elseif p[3] == "says" then
            return R("At Session Zero, " .. NAME[p[4]] .. "'s reaction when you pitch " .. Q(t.name, 5), "If chosen")
        end
    elseif f == "asks" then
        local who = NAME[p[2]]
        local a = S.asks[p[2]]
        if p[3] == "text" then
            return R("At Session Zero, " .. who .. "'s ask for the table", "Always")
        end
        local o = a[p[3]] or {}
        if p[4] == "label" then
            return R("At Session Zero, a reply to " .. who .. "'s ask", "Your pick")
        end
        return R("At Session Zero, " .. who .. "'s answer if you pick " .. Q(o.label or "agree", 5), "If chosen")
    elseif f == "rules" then
        local r = S.rules[p[2]]
        local rn = Q(r and r.name or p[2], 5)
        if p[3] == "name" then
            return R("At Session Zero: the heading of a table rule", "Always")
        elseif p[3] == "about" then
            return R("At Session Zero, under the table rule " .. rn, "Always")
        end
        local o = r and r[p[3]] or {}
        local on = Q(o.name or p[3], 5)
        if p[4] == "name" then
            return R("At Session Zero, a choice for " .. rn, "Your pick")
        elseif p[4] == "about" then
            return R("At Session Zero, the note for " .. on .. " under " .. rn, "Always")
        elseif p[4] == "says" then
            return s0_says(p[2], p[3], p[5], on, rn)
        end
    end
end

-- Death (game/data/death.lua with adventure.museum_death's words, game/model/death.lua).
local function death_line(p)
    local D = require "game.data.death"
    local f = p[1]
    if f == "MODE" then
        local m = D.MODE[p[2]]
        if p[3] == "name" then
            return R("On the death card, " .. Q("Session Zero said: …") .. ", when a hero dies", "Always")
        elseif p[3] == "short" then
            return R("On a hero's sheet: " .. Q("If they die: …"), "Always")
        end
        return R("At Session Zero, explaining the death rule " .. Q(m.name, 5), "Always")
    elseif f == "RULE" then
        if p[2] == "name" then
            return R("At Session Zero: the heading of the death rule", "Always")
        end
        local S = require("game.model.content").session_zero
        local on = Q((S.rules.death and S.rules.death[p[2]] and S.rules.death[p[2]].name) or D.MODE[p[2]].name, 5)
        return s0_says("death", p[2], p[4], on, Q(D.RULE.name, 5))
    elseif f == "INTRO" then
        local who = {}
        for _, list in pairs(D.PREGENS) do
            for _, g in ipairs(list) do
                if g.intro == p[2] then
                    table.insert(who, g.name)
                end
            end
        end
        table.sort(who)
        return R("The night after a hero dies for good, as their new hero turns up, if it's " .. util.join_names(who, "or"), "Always")
    elseif f == "LAST_WORDS" then
        local key = CLASS_KEY[p[2]]
        return R("When " .. HERO[key] .. " dies and you say goodbye: " .. NAME[key] .. "'s last words", one_of(#D.LAST_WORDS[p[2]]))
    elseif f == "PREGENS" then
        local key = CLASS_KEY[p[2]]
        local nth = p[3] == 1 and "the first time" or "the second time"
        return R("The night after " .. HERO[key] .. " dies for good, " .. nth .. ": " .. NAME[key] .. "'s new hero", "Always")
    elseif f == "QUEST" then
        return R("Not said in the museum: an adventure offers no quest back from death", "Never")
    elseif f == "SCARS" then
        return R("When a dead hero is brought back, at a cost", one_of(#D.SCARS))
    elseif f == "WAKE" then
        return R("After a fallen hero's last words: the wake", "Always")
    end
end

-- Shared cards (game/data/decisions.lua) as game night deals them.
local CARD_WHEN = {
    killing_blow = "In a fight, when a boss is about to fall to a hero",
    kb_share = "In a fight, when the hero offers the killing blow to a friend who's waited all night",
    escape_earned = "In a fight, when the boss is beaten and edging toward a way out",
    escape_cheap = "In a fight, when the boss is nearly done but nothing set up an escape",
    boss_crit = "In a fight, when a hero is about to drop the boss early",
    tactics = "In a fight, when the foes regroup and you run them",
    cornered = "In a fight, when several foes pin a badly hurt hero",
    death_roll = "In a fight, when your hidden roll would drop a hero",
    last_save = "When a hero fails their third death save",
    dragging_fight = "In a fight that's dragging on",
    grapple = "When someone insists grappling doesn't work like that",
    stacking = "When someone asks if Oswin's Bless stacks",
    potion_action = "In a fight, when someone drinks a potion and asks if that's their turn",
    flanking = "In a fight, when someone claims flanking",
    split_party = "In a room, when two heroes want to split up",
    stuck_puzzle = "In a puzzle room, when they've been stuck a while",
    rules_lookup = "When someone's sure there's a rule and the book comes out",
    pip_show = "In a room with someone to talk to, when Jess has been doing Pip's voice for ages",
    rules_spat = "When Dev and Sam have been arguing about a rule since the last fight",
}
local TYPE_NAME = { agency = "where-to", screen = "behind-the-screen", skew = "player's pull", talk = "talk", story = "story",
                    rules = "rules", combat = "fight", pacing = "pacing", table = "table" }
local function shared_card_line(p)
    local D = require "game.data.decisions"
    if p[1] == "types" then
        if p[2] == "agency" or p[2] == "skew" then
            -- (Open scenes and players' pulls are the older game's; the museum's forks and requests replace them.)
            return R("Not shown in the museum: it has forks and requests instead of these cards", "Never")
        end
        return R("The label at the top of a " .. (TYPE_NAME[p[2]] or p[2]) .. " card", "Always")
    end
    local c = D[p[1]]
    if type(c) ~= "table" then
        return nil
    end
    local where = CARD_WHEN[c.id] or "On game night"
    local title = Q(c.title or c.id, 5)
    if p[2] == "title" then
        return R(where .. ": the card's title", "Always")
    elseif p[2] == "text" then
        return R(where .. ": the card " .. title, "Always")
    elseif p[2] == "options" then
        local o = c.options[p[3]] or {}
        local lab = Q(o.label, 5)
        local f = p[4]
        if f == "label" then
            return R(where .. ": an option on " .. title, "Your pick")
        elseif f == "sub" then
            return R(where .. ": the note under " .. lab .. " on " .. title, "Your pick")
        elseif f == "log" then
            return R(where .. ", if you pick " .. lab, "If chosen")
        elseif f == "canon" then
            return R("Kept in the story log, if you pick " .. lab .. " on " .. title, "If chosen")
        elseif f == "roll" then
            local ok = p[5] == "success"
            return R(where .. ": " .. lab .. ", and the roll " .. (ok and "succeeds" or "fails"), ok and "On a success" or "On a failure")
        end
    end
end

-- Rests (game/data/rests.lua beats, night:rest_beat).
local function rest_line(p)
    local Rs = require "game.data.rests"
    local b = Rs.beats[p[2]]
    local pair = {}
    for _, who in ipairs(b and b.pair or {}) do
        local k = string.match(who, "^pc:(.+)$")
        if k then
            table.insert(pair, k)
        end
    end
    local with = #pair > 0 and (", with " .. names(pair) .. " at the table") or ""
    return R("During a rest in the gift shop" .. with .. " (once a prologue)", "Sometimes")
end

-- Table talk (game/data/dialogue/lines.json): the friends' library lines, by moment.
local TT = {
    arrive = "At the start of game night, as {name} sits down",
    scene_like = "As a room starts that's just {name}'s kind of room (not the short rooms)",
    scene_dislike = "As a room starts that isn't {name}'s kind of room (not the short rooms)",
    check_win = "Sometimes, right after {hero} passes a check while the heroes work a room",
    check_lose = "Sometimes, right after {hero} fails a check while the heroes work a room",
    fumble = "When {name} rolls a natural 1 on a check",
    groan_other = "Sometimes, while the heroes work a room, when a friend's check fails",
    cheer_other = "Sometimes, while the heroes work a room, when a friend's check succeeds",
    boss_appears = "As a fight starts and its leader shows up",
    turn = "In a fight, sometimes, as {hero}'s turn starts",
    hit = "In a fight, sometimes, after {hero} lands a hit",
    big_hit = "In a fight, after {hero} deals 12 or more damage in a turn",
    miss = "In a fight, after {hero} misses every attack in a turn",
    kill = "In a fight, when {hero} takes down a foe",
    ouch = "In a fight, when {hero} takes a big hit and stays up",
    ally_down = "In a fight, when another hero drops to 0 hit points",
    fight_chat = "Between rounds of a fight, sometimes: table chatter",
    victory = "When the party wins a fight",
    victory_close = "When the party wins a fight, but only just",
    defeat = "When the party loses a fight or has to fall back",
    bored = "In a quiet stretch while the heroes work a room, if {name} is losing interest",
    phone = "In a quiet stretch while the heroes work a room, if {name} has nearly tuned out: back from {pos} phone",
    ruling_good = "When you rule {hero}'s roll generously",
    ruling_rueful = "When you rule {hero}'s near miss kindly: still a miss, but {subj} learns from it",
    ruling_bad = "When you rule a roll harshly against the party",
    open_roll = "When you roll a big moment in the open",
    suspicious = "Under {pos} breath, when your hidden rolls look convenient",
    callout = "When {name} asks to see your hidden roll",
    level_up = "When you announce the party levels up",
    wrap = "At the end of the session, packing up",
    crit = "When {name} rolls a natural 20",
    down_self = "In a fight, when {hero} drops to 0 hit points",
    up_again = "In a fight, when {hero} is back on {pos} feet",
    thanks = "In a fight, when someone heals or saves {hero}",
    snack = "In a quiet stretch while the heroes work a room: snack talk",
    npc_talk = "At Flitwidget's thanks, when {hero} speaks up to him first",
    spell = "In a fight, sometimes, when {hero} casts a spell",
    rules_lawyer = "When a rules call comes up and {name} has an opinion",
    heal_cast = "In a fight, when Oswin heals someone",
    spotlight_shy = "When you put {name} on the spot, and {subj} would rather you didn't",
}
local TIER = { loved = "{subj} loved the night", fun = "{subj} had fun", fine = "{subj} found it fine", bored = "{subj} was bored",
               out = "{subj} checked out" }
local MOOD = { warm = "the talk goes warm", guarded = "the talk stays guarded", lie_caught = "{subj} catches the lie",
               lie_believed = "{subj} believes the lie" }

local LIB, LIB_BY_ID
local function lib()
    if not LIB then
        LIB = json.decode(assert(io.open("game/data/dialogue/lines.json")):read("*a")).lines or {}
        LIB_BY_ID = {}
        for _, l in ipairs(LIB) do
            LIB_BY_ID[l.id] = l
        end
    end
    return LIB_BY_ID
end

local function table_talk(e, cells)
    local l = lib()[e.path[2]] or {}
    local tr = e.moment or l.trigger
    local who = e.speaker
    local function fill(s)
        s = string.gsub(s, "{name}", NAME[who] or "a friend")
        s = string.gsub(s, "{hero}", HERO[who] or "their hero")
        s = string.gsub(s, "{pos}", POS[who] or "their")
        s = string.gsub(s, "{subj}", SUBJ[who] or "they")
        return s
    end
    local split = l.tier or l.mood
    local n = one_of(cells[(tr or "") .. "|" .. (who or "") .. "|" .. (split or "")])
    if tr == "report_quote" then
        return R(fill("After the session, {name}'s quote on the report, if " .. (TIER[l.tier] or "the night went that way")), n)
    elseif tr == "talk_reply" then
        return R(fill("When you talk as Flitwidget at his thanks: {hero}'s answer when " .. (MOOD[l.mood] or "it fits")), n)
    elseif tr == "banter" then
        return R("While the heroes work a room without a fight: " .. HERO[who] .. " to " .. (HERO[l.to] or "a friend") .. ", who answers", n)
    elseif tr and string.sub(tr, 1, 5) == "pick_" then
        local SUB = { life = "Life Domain", hearth = "Hearth Domain", mischief = "Mischief Domain", banner_captain = "Banner Captain",
                      mirror_mage = "Mirror Mage" }
        local sub = SUB[string.sub(tr, 6)] or util.capitalize((string.gsub(string.sub(tr, 6), "_", " ")))
        return R("At level 3, when " .. NAME[who] .. " picks " .. sub .. " for " .. HERO[who], n)
    end
    local t = tr and TT[tr]
    if t then
        local s = fill(t)
        if l.to and not l.reply then
            s = s .. ", when it's about " .. (HERO[l.to] or "a friend")
        end
        return R(s, n)
    end
    return nil
end

-- Dispatch ----------------------------------------------------------------------------------------

local FILE = {
    ["game/data/barks.lua"] = bark_line,
    ["game/data/intros.lua"] = intro_line,
    ["game/data/killing_blows.lua"] = kb_line,
    ["game/data/thoughts.lua"] = thought_line,
    ["game/data/table_behaviors.lua"] = tb_line,
    ["game/data/session_zero.lua"] = s0_line,
    ["game/data/death.lua"] = death_line,
    ["game/data/decisions.lua"] = shared_card_line,
    ["game/data/rests.lua"] = rest_line,
    ["game/data/museum/cards.lua"] = card_line,
    ["game/data/museum/table_life.lua"] = small_moment,
    ["game/data/friction.lua"] = function(p)
        return friction_line(p[1], p[2], p[3])
    end,
}

local function adventure_line(p)
    local top = p[1]
    if top == "table_life" then
        local q = {}
        for i = 2, #p do
            table.insert(q, p[i])
        end
        return small_moment(q)
    elseif top == "session_zero" then
        local q = {}
        for i = 2, #p do
            table.insert(q, p[i])
        end
        return s0_line(q)
    elseif top == "friction" then
        return friction_line(p[2], p[3], p[4])
    end
    local h = A[top]
    return h and h(p) or nil
end

-- Lines kept in the game's code (export.lua's CODE_TABLES) --------------------------------------

-- Who looks round first by their main type (museum_night look_card: LOOK_SAY[p.primary], else casual).
local PRIMARY_WHO = { storyteller = "mara", butt_kicker = "dev", method_actor = "jess", casual = "sam" }
local CLASS_WHO = { wizard = "mara", fighter = "dev", rogue = "jess", cleric = "sam" }

local function code_line(p)
    local top, k, i = p[1], p[2], p[3]
    if top == "LOOK_SAY" then
        local who = PRIMARY_WHO[k]
        if not who then
            return R("Not said: looking round, a friend speaks by their main type, and none of the four is " ..
                string.gsub(k, "_", " ") .. " first", "Never")
        end
        return R("Looking round a room, before its business: " .. NAME[who] .. " walks over to something on the map " ..
            "and says what " .. SUBJ[who] .. " makes of it", one_of(#(require("game.model.museum_night").LOOK_SAY[k] or {})))
    elseif top == "LEAN_WHY" then
        local who = ARCH_WHO[k] or {}
        return R("When the table talks over a choice: " .. names(who) .. "'s reason for leaning one way, when the " ..
            "option suits " .. (#who == 1 and (POS[who[1]] or "their") or "their") .. " " .. string.gsub(k, "_", " ") ..
            " side (at most twice a night, each line once, never two talks running)", "Sometimes")
    elseif top == "BREAK_START" then
        return R("The break, once a night, about a third of the way in (or before the lair): the DM calls it", one_of(4))
    elseif top == "BREAK_END" then
        return R("The break, once a night: everyone comes back to the table", one_of(4))
    elseif top == "READY" then
        local who = CLASS_WHO[k]
        return R("Just before a fight, about half the time (not when the party's ambushed or given away): " ..
            (who and (HERO[who] .. ", if it's " .. HERO[who] .. " who reacts first") or "whoever reacts first"),
            "Sometimes")
    elseif top == "REACTED" then
        if k == "success" then
            return R("Just before a fight: the party reacts first, on a good Perception or Insight roll", "On a success")
        end
        return R("Just before a fight: the party is too slow, on a poor Perception or Insight roll", "On a failure")
    elseif top == "BREAK_LOGS" then
        local pick = ({ nothing = "nothing happens in the game", short = "the heroes take a short rest",
                        long = "the heroes take a long rest (in the gift shop)", research = "the heroes read up" })[k] or k
        return R("The break, once a night, if you say " .. pick .. " meanwhile",
            one_of(#(require("game.model.museum_night").BREAK_LOGS[k] or {})))
    elseif top == "WEEKLY" then
        local W2 = require("game.model.museum_night").WEEKLY
        local what = ({ ready = "As game night starts, once everyone's sat down",
                        ask_look = "When the table can't settle a choice and a friend asks you (a card or a fork)",
                        thread = "When a room is the one a hero came to the museum for",
                        skim = "The first room tonight you never read, as it starts",
                        skim_again = "Any later room tonight you never read, as it starts",
                        improv = "The first room tonight you chose to make up, as it starts",
                        improv_again = "Any later room tonight you chose to make up, as it starts",
                        close = "When you call the night",
                        stop_fight = "When you call the night right after a fight",
                        stop_flat = "When you call the night after a quiet room",
                        book_down = "When you choose to make up a room you never prepped",
                        from_book = "The first room tonight you read from the book at the table",
                        from_book_again = "Any later room tonight you read from the book at the table",
                        easy = "At a fork, when a friend who doesn't much mind comes round to the others" })[k] or "Game night"
        return R(what, one_of(#(W2[k] or {})))
    elseif top == "INSPIRE_LINES" then
        return R("When you give a hero Heroic Inspiration (from a card or their tile)", one_of(#require("game.model.night").INSPIRE_LINES))
    elseif top == "WRAP_LINES" then
        return R("The very end of game night, after the goodbyes", one_of(#require("game.model.night").WRAP_LINES))
    elseif top == "FRANC_LINES" then
        return R("When you rule a great roll " .. Q("Yes, and...") .. ": the Franc that turns up",
            one_of(#require("game.model.night").FRANC_LINES))
    elseif top == "FIGHT_CAPTIONS" then
        local what = ({ start = "As a fight starts", party_win = "When the party wins a fight against several",
                        party_win_one = "When the party wins a fight against one foe, by name",
                        party_win_fled = "When the party wins and the rest of the foes run" })[k] or "In a fight"
        return R(what, one_of(#(require("game.model.night").FIGHT_CAPTIONS[k] or {})))
    end
end

-- e: an exported line. cells: table-talk cell sizes ("trigger|speaker|split" -> n).
-- Returns { when, odds } and whether a rule matched (false: the fallback).
function W.describe(e, cells)
    local ok, r
    if e.file == "game/data/dialogue/lines.json" then
        ok, r = pcall(table_talk, e, cells or {})
    elseif e.file == "game/data/museum/module.lua" then
        ok, r = pcall(adventure_line, e.path)
    elseif e.file == "game/model/museum_night.lua" or e.file == "game/model/night.lua" then
        ok, r = pcall(code_line, e.path)
    elseif FILE[e.file] then
        ok, r = pcall(FILE[e.file], e.path)
    end
    if ok and r then
        return r, true
    end
    local where = e.room and lowfirst(in_room(e.room)) or "somewhere in the game"
    return { when = sentence(util.capitalize(e.group or "A line") .. " line, " .. where .. "; not worked out in detail"),
             odds = "Sometimes" }, false
end

-- The table-talk cells: how many exported lines share a moment, a speaker and a tier or mood.
function W.cells(lines)
    local by_id = lib()
    local out = {}
    for _, e in ipairs(lines) do
        if e.file == "game/data/dialogue/lines.json" then
            local l = by_id[e.path[2]] or {}
            local key = (e.moment or l.trigger or "") .. "|" .. (e.speaker or "") .. "|" .. (l.tier or l.mood or "")
            out[key] = (out[key] or 0) + 1
        end
    end
    return out
end

return W
