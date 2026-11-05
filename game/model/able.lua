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
-- whole party went down (the rest of that scene). nil when the table can laugh.
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
    if loss and sc and loss.scene == sc then
        return loss.kind
    end
    return nil
end

-- Lines that cheer, joke or brag ("Too easy.", a crit's whoop, a fist bump): they wait while the table's
-- grieving. Getting back up after a death is said quietly instead (M.UP_QUIET).
M.CHEER = { victory = true, crit = true, kill = true, cheer_other = true, scene_like = true, big_hit = true,
            fight_chat = true, hit = true, boss_appears = true, thanks = true }
function M.hush(night, trigger)
    return M.CHEER[trigger] == true and M.somber(night) ~= nil
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
