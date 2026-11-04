-- Who comes along with the party (the playtest, November 3: "Pip asks to adopt a rat named Exhibit
-- B... a system that covers more companions in the future"; "NPCs that join the party should be in
-- initiative with a mini, piloted by one of the players"). The adventure lists them (MODULE.
-- companions): a pet that rides in a pocket, or a person who walks with them. Each belongs to a
-- friend at the table, who talks about them, plays them in a fight, and gets the help they give
-- when the party looks around. Pure Lua.
--
-- campaign.adv.companions = { [id] = { week = joined, found = true|nil } }; campaign.adv.companion_find = id

local util = require "game.model.util"

local M = {}

local function data()
    local ok, adv = pcall(require, "game.model.adventure")
    return ok and adv.data and adv.data.companions or nil
end

function M.def(id)
    local d = data()
    return d and d[id] or nil
end

-- Join the party (a chat answer, a flag, a find).
function M.join(campaign, id)
    if not M.def(id) then
        return false
    end
    campaign.adv = campaign.adv or {}
    campaign.adv.companions = campaign.adv.companions or {}
    if campaign.adv.companions[id] then
        return false
    end
    campaign.adv.companions[id] = { week = campaign.week or 0 }
    if campaign.adv.companion_find == id then
        campaign.adv.companion_find = nil
    end
    return true
end

-- Who's with them now: joined, or a flag the story set (Telpur coming along), and whose friend is
-- at the table. Each: the def with its id.
function M.active(campaign, players)
    local d = data()
    if not d then
        return {}
    end
    local adv = campaign.adv or {}
    local out = {}
    for _, id in ipairs(d.order or {}) do
        local def = d[id]
        local joined = adv.companions and adv.companions[id]
        if not joined and def.joins and def.joins.flag and adv.flags and adv.flags[def.joins.flag] then
            joined = true
        end
        local owner = def.owner
        local here = true
        if players and owner then
            here = false
            for _, p in ipairs(players) do
                if p.key == owner then
                    here = true
                end
            end
        end
        if joined and here then
            local e = {}
            for k, v in pairs(def) do
                e[k] = v
            end
            e.id = id
            table.insert(out, e)
        end
    end
    return out
end

-- The ones who fight: an ally in initiative with its mini, played by its owner.
function M.fighters(night)
    local out = {}
    for _, e in ipairs(M.active(night.campaign, night.players)) do
        if e.monster and not e.pocket then
            -- (Someone whose hero fell tonight can take them over: death.after_fall.)
            local pilot = (night.pilots and night.pilots[e.id]) or e.owner
            table.insert(out, { id = e.monster, name = e.name, commander = pilot, pilot = pilot })
        end
    end
    return out
end

-- Whose companion is this hero's? (the first one they own)
function M.of(night, p)
    for _, e in ipairs(M.active(night.campaign, night.players)) do
        if p and e.owner == p.key then
            return e
        end
    end
    return nil
end

-- A line about them, by their owner (a pet) or from them (a person who talks), once in a while.
-- kind: start | look | fight | win.
function M.say(night, e, kind)
    -- (hint: "something's here", said only when there is; a companion without hints just looks.)
    local lines = e and e.lines and (e.lines[kind] or (kind == "hint" and e.lines.look))
    -- (What they think of the party now comes first, when it shows: lines.<kind>_if, R11.)
    for _, alt in ipairs(e and e.lines and e.lines[kind .. "_if"] or {}) do
        if util.lazy("game.model.adventure").test(night.campaign, alt.when) then
            lines = alt.text
            kind = kind .. "_if"
            break
        end
    end
    if not lines or #lines == 0 then
        return false
    end
    local owner = night.campaign:player(e.owner)
    local text = night:fresh(lines, "companion_" .. e.id .. "_" .. kind)
    if e.kind == "person" then
        night:say(text, "quote")
    elseif owner then
        night:emit({ kind = "say", who = owner.key, text = text, ic = false })
    else
        return false
    end
    return true
end

-- The start of a night: each companion gets a line. The first night they're along, the table
-- hears that they've come (the playtest review, November 4: Telpur was suddenly in the backpack,
-- settled in a private message nobody at the table saw).
function M.night_start(night)
    local adv = night.campaign.adv or {}
    adv.introduced = adv.introduced or {}
    for _, e in ipairs(M.active(night.campaign, night.players)) do
        if not adv.introduced[e.id] and e.lines and e.lines.join then
            adv.introduced[e.id] = night.campaign.week or 0
            night:say(e.lines.join, "good")
        else
            M.say(night, e, "start")
        end
    end
    -- Anything else the week between gave them that comes along (the adventure's asides with an
    -- `intro`: Telpur's talking shoelace): its first night, the table hears it's there before it
    -- pipes up in a fight (F5: the shoelace's first line was mid-fight, with no introduction).
    local adventure = util.lazy("game.model.adventure")
    for _, a in ipairs((adventure.data or {}).asides or {}) do
        local key = "aside:" .. a.id
        if a.intro and not adv.introduced[key] and adventure.test(night.campaign, a.when) then
            local owner = a.owner and night.campaign:player(a.owner)
            if not a.owner or (owner and util.contains(night.players, owner)) then
                adv.introduced[key] = night.campaign.week or 0
                night:say(a.intro, "good")
            end
        end
    end
end

-- An ally who fights beside them for the first time tonight without having walked in with them
-- (the Steam Mech, woken a session ago, joining the boss fight): the table hears it arrive (F5:
-- El Roboto joined the fight unannounced). lines: the adventure's `ally_join` by monster id.
function M.ally_arrives(night, allies)
    local adventure = util.lazy("game.model.adventure")
    local lines = (adventure.data or {}).ally_join or {}
    night.allies_announced = night.allies_announced or {}
    local out = {}
    for _, a in ipairs(allies or {}) do
        local id = type(a) == "table" and a.id or a
        local line = lines[id]
        if line and not night.allies_announced[id] then
            night.allies_announced[id] = true
            local st = night.campaign.adv or {}
            table.insert(out, util.fill(line, { mech = st.mech_name or "The Mech" }))
        end
    end
    return out
end

-- Looking around: the looker's companion helps. Returns the bonus for the look, and whether they
-- found something (once a night each).
function M.help_look(night, p)
    local e = M.of(night, p)
    if not e or not e.helps then
        return 0, nil
    end
    night.companion_found = night.companion_found or {}
    if not night.companion_found[e.id] and night.rng:chance(e.helps.find or 0) then
        night.companion_found[e.id] = true
        M.say(night, e, "hint")         -- (the nose leads somewhere: the find comes next)
        return e.helps.bonus or 0, e
    end
    M.say(night, e, "look")
    return e.helps.bonus or 0, nil
end

-- A pet that hides when the fight starts; a person who's in it.
function M.fight_start(night)
    for _, e in ipairs(M.active(night.campaign, night.players)) do
        if night.rng:chance(0.6) then
            M.say(night, e, "fight")
        end
    end
end

-- Someone fighting on the party's side drops (F4, the second playtest review: "Telpur -14 (0
-- left)" and the fight carried on as if nothing happened). It's said out loud, the friend who
-- plays them (or brought them) reacts, and the adventure remembers: a person who fell comes round
-- after the fight (M.after_fight), and the wrap-up can say so (flag "<id>_fell").
function M.fell(night, c, captioned)
    if not c then
        return
    end
    night.allies_fell = night.allies_fell or {}
    if night.allies_fell[c] then
        return
    end
    night.allies_fell[c] = true
    local e
    for _, a in ipairs(M.active(night.campaign, night.players)) do
        if a.monster and a.monster == c.monster_id then
            e = a
        end
    end
    local name = (e and e.name) or c.name or "Their ally"
    local lines = e and e.lines or {}
    if not captioned then
        night:say(util.fill(lines.down or "{name} goes down, and doesn't get up.", { name = name }), "bad")
    end
    -- Who reacts: whoever was playing them, else the friend who brought them, else anyone.
    local key = c.pilot or (e and e.owner)
    local p = key and night.campaign:player(key)
    if not (p and util.contains(night.players, p)) then
        p = night.players[1]
    end
    if p then
        night:emit({ kind = "say", who = p.key, text = util.fill(lines.react or "{name}! No!", { name = name }), ic = false })
        night:react({ [p.key] = "gasp" })
    end
    if e then
        local adv = night.campaign.adv
        adv.flags = adv.flags or {}
        adv.flags[e.id .. "_fell"] = true
        night.mus = night.mus or {}
        night.mus.allies_fell = night.mus.allies_fell or {}
        table.insert(night.mus.allies_fell, e.id)
    end
end

-- After the fight: a person who fell comes round, sore and talking (they're a companion, not a
-- foe: nobody leaves them on the floor), and the table hears it.
function M.after_fight(night)
    -- (In a set order, by stat block and name: the keys are the creatures themselves.)
    local fell = {}
    for c in pairs(night.allies_fell or {}) do
        table.insert(fell, c)
    end
    table.sort(fell, function(a, b)
        local ka, kb = tostring(a.monster_id) .. "/" .. tostring(a.name), tostring(b.monster_id) .. "/" .. tostring(b.name)
        return ka < kb
    end)
    for _, c in ipairs(fell) do
        if not night.allies_back or not night.allies_back[c] then
            night.allies_back = night.allies_back or {}
            night.allies_back[c] = true
            for _, e in ipairs(M.active(night.campaign, night.players)) do
                if e.monster and e.monster == c.monster_id and e.kind == "person" then
                    night:say(util.fill(e.lines and e.lines.up or "{name} comes round, sore, and very glad it's over.", { name = e.name }), "good")
                end
            end
        end
    end
end

-- "If Pip can find one": the next time their owner looks around, they find the pet.
function M.maybe_find(night, p)
    local adv = night.campaign.adv or {}
    local id = adv.companion_find
    local def = id and M.def(id)
    if not (def and p and def.owner == p.key) then
        return false
    end
    M.join(night.campaign, id)
    night:say(util.fill("Something small and whiskery is watching {char} from under an exhibit. It's a rat. {char} names him "
        .. def.name .. " on the spot.", { char = p.char }), "good")
    -- (Being found is how they're introduced: "Pip has a new friend tonight" a week after Pip named
    -- him was the second playtest review's first find. F5.)
    adv.introduced = adv.introduced or {}
    adv.introduced[id] = night.campaign.week or 0
    night:react({ [p.key] = "cheer" })
    require("game.model.score").add(p, "fun", 5)
    return true
end

return M
