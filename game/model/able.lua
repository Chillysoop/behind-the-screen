-- Who can act right now (round three, A1; the third playtest: "Oswin is dead, but he keeps acting
-- through the epilogue", "Pip is stone now, mid-step" then Pip pockets something, a charmed Brannoc
-- flanking). One owner for a hero's state at the table: dead, down, stone, or (while a fight's on)
-- charmed or out of it (asleep, sat down to listen). Everything that picks a hero to do something
-- asks here (night:at_hand, the pickers, the fight's cards); what's said about a hero who can't act
-- is about them, never them acting. Their player still talks, as themselves. Pure Lua.

local M = {}

local function key_of(p)
    return type(p) == "table" and p.key or p
end

-- "dead", "down", "stone", "charmed", "out", or nil when the hero can act.
function M.state(night, p)
    local key = key_of(p)
    if not (night and key) then
        return nil
    end
    if night.watching and night.watching[key] then
        return "dead"
    end
    local pc = night.pcs and night.pcs[key]
    if not pc then
        return nil
    end
    if pc.dead then
        return "dead"
    end
    if pc.down or (pc.hp or 1) <= 0 then
        return "down"
    end
    for _, e in ipairs(pc.effects or {}) do
        if e.stone then
            return "stone"
        end
    end
    if night.battle then
        for _, e in ipairs(pc.effects or {}) do
            local by = e.charmed_by
            if by and not by.dead and not by.removed then
                return "charmed"
            end
        end
        for _, e in ipairs(pc.effects or {}) do
            local cd = e.conds
            if cd and (cd.incapacitated or cd.unconscious or cd.paralyzed) then
                return "out"
            end
        end
    end
    return nil
end

-- Can this hero do something in the scene (walk over, pick up, roll, talk in character)? A charmed
-- hero can: they just won't raise a hand against whoever charmed them (M.can_fight).
function M.can_act(night, p)
    local s = M.state(night, p)
    return s == nil or s == "charmed"
end

-- Can this hero make a move in the fight (flank, a stunt, a shove)? Not charmed, not out of it.
function M.can_fight(night, p)
    return M.state(night, p) == nil
end

-- A hero who's gone for good tonight: dead, or stone with nobody to break it yet.
function M.gone(night, p)
    local s = M.state(night, p)
    return s == "dead"
end

-- The ones of `list` who can act (a new list).
function M.only(night, list, fight)
    local out = {}
    for _, p in ipairs(list or {}) do
        if (fight and M.can_fight(night, p)) or (not fight and M.can_act(night, p)) then
            table.insert(out, p)
        end
    end
    return out
end

-- The table after a loss (B17, the third playtest: "Okay, round two. Pip is angry now." and a fist bump
-- right after Oswin died; "Too easy." after Hans was destroyed). "death": a hero died tonight (the rest
-- of the night); "ally": someone fighting beside them was destroyed (the rest of that scene); "wipe": the
-- whole party went down (the rest of the night); "lost": Euryale beat them and sent them back down her
-- stairs (the rest of the night: the merge of round three heard "Everyone comes back warm" right after).
-- nil when the table can laugh.
function M.somber(night)
    if not night then
        return nil
    end
    if night.watching and next(night.watching) then
        return "death"
    end
    for _, pc in ipairs(night.pc_list or {}) do
        if pc.dead then
            return "death"
        end
    end
    local sc = night.scene
    local loss = night.loss
    if loss and (loss.night or (sc and loss.scene == sc)) then
        return loss.kind
    end
    return nil
end

-- Lines that cheer, joke or brag ("Too easy.", a crit's whoop, a fist bump, "Dice jail!", "YES! I love
-- this DM!", "Who finished the salsa?", "Pip would like to file a complaint.", "Can Brannoc attack the
-- scenery?"): they wait while the table's grieving. Getting back up after a death is said quietly
-- instead (M.UP_QUIET), and the goodbyes come from their own quiet pool (M.QUIET).
M.CHEER = { victory = true, victory_close = true, crit = true, kill = true, cheer_other = true, scene_like = true,
            big_hit = true, fight_chat = true, hit = true, boss_appears = true, thanks = true, fumble = true,
            ruling_good = true, snack = true, banter = true, check_win = true, level_up = true, miss = true, ouch = true,
            groan_other = true, scene_dislike = true, bored = true }
function M.hush(night, trigger)
    return M.CHEER[trigger] == true and M.somber(night) ~= nil
end

-- The table talk that has a quiet pool of its own for a night like that (game/data/dialogue: the
-- goodbyes, "Good game!" and "Same time next week" after a death; the report card's word, "Best night in
-- ages", for the friends who still had a good night of it). The rest of the gate, in one place for every
-- line source that can cheer: night:bark (above), night:react (no cheering faces), the break
-- (museum_night.BREAK_SAD; none after a lost boss fight, the night ends there), a won fight's caption
-- (night.FIGHT_CAPTIONS.party_win_sad), the wrap (night:run_tail), people.line (a person's `<what>_sad`
-- lines: Flitwidget's thanks and reward), night:npc_line (a person's "@sad" greeting and praise), a card's
-- `again_sad`, `win_sad`, `line_sad`, `intent_sad`, `talk_sad`, an ending's `flit_sad`, a room's callback
-- `sad`, a companion's `up_sad` and `react_sad`, `want_more_sad`, Flitwidget's `done_sad` talk, the
-- thoughts that glow (thoughts.CHEERY), small moments and rest scenes (none).
M.QUIET = { wrap = "wrap_sad", report_quote = "report_sad" }
function M.quiet_trigger(night, trigger)
    return (M.somber(night) ~= nil and M.QUIET[trigger]) or trigger
end

-- A list's quiet version on a night like that, else the list itself (a table or a string). sad: the
-- quiet version (nil: the list stands; false: nothing's said).
function M.pick(night, list, sad)
    if sad ~= nil and M.somber(night) ~= nil then
        return sad or nil
    end
    return list
end

-- A hero back on their feet while the table grieves ({char}: who got up; {lost}: who they lost).
M.UP_QUIET = {
    "{char} is up. Nobody cheers.",
    "{char} gets back up and looks at {lost}. Nobody says anything.",
    "{char} is on {char_their} feet again. It doesn't feel like winning.",
}

-- Lines that say what's happening to a hero who can't act, rather than have them act: their state
-- itself, coming out of it, someone else doing something to them.
M.ABOUT = { " is stone", " cracks out", " crack out", " comes round", " goes down", " is dead", " died", " dies",
            " shakes it off", " is down", " hesitates", " can't bring", " is still under", " sits down",
            " is out", " gets last words", " won't fight", " lies ", " is on the floor", " is gone",
            " turns to stone", " starts turning", " is turning", " stays stone", " stops moving",
            " is a statue", " goes still", " slumps", " drops", " falls" }
function M.about_them(text, char)
    local rest = string.sub(text, #char + 1)
    for _, pat in ipairs(M.ABOUT) do
        if string.sub(rest, 1, #pat) == pat then
            return true
        end
    end
    -- ("Oswin's" something: about them.)
    return string.sub(rest, 1, 2) == "'s"
end

return M
