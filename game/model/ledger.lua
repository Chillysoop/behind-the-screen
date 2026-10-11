-- The campaign notebook (the slice rework, S5): who's who in the Vale, how they feel about the
-- party, what the party has done to and for them, and where the factions stand. Real DMs keep
-- this as a campaign status document (The Alexandrian) or in a campaign manager (Kanka); the
-- game keeps it as the story happens. The people and factions are game/data/factions.lua.
-- Pure Lua.
--
-- campaign.notebook = {           this table's side: how the Vale feels about THIS party
--   log     = { entry... }       every interaction, oldest first (the one event log)
--   people  = { [person] = { att, warm = { [key] = n }, met, last, knows = { text... }, exposed } }
--   factions = { [faction] = { shift, crossed, pushed, helped } }
--   changes = { { week, kind = "att" | "status" | "standing", id, from, to, why } }
-- }
-- The world's side (statuses, sides, projects, places) is in campaign.world: see world_state.
-- entry = { w = week, s = scene, who = player key | "party", to = person | faction, did, ok, at = location, d }
--
-- Game night writes its entries to night.ledger as it goes (so quitting halfway and playing
-- the night again doesn't count anything twice); after_night files them here.

local content = require "game.model.content"
local util = require "game.model.util"
local data = require "game.data.factions"

local M = {}
M.data = data

-- What each kind of interaction does to how someone feels about the party: delta when it
-- works, delta when it doesn't, and the words for each.
M.ACTS = {
    persuasion = { 1, 0, "charmed", "tried to charm" },
    history = { 1, 0, "talked old times with", "got the history wrong with" },
    medicine = { 1, 0, "patched up", "tried to patch up" },
    insight = { 0, 0, "saw through", "couldn't read" },
    intimidation = { -1, -1, "threatened", "tried to scare" },
    sleight_of_hand = { 0, -1, "picked the pocket of", "was caught picking the pocket of" },
    deception = { 0, -1, "lied to", "was caught lying to" },
    performance = { 1, 0, "won over", "bored" },
}
-- Scene-level things: { delta, words }.
M.EVENTS = {
    met = { 0, "met" },
    helped = { 1, "helped" },
    let_down = { 0, "let down" },
    deal = { 1, "made a deal with" },
    no_deal = { 0, "couldn't strike a deal with" },
    exposed = { -2, "exposed" },
    crossed = { -1, "crossed" },
    fought = { -1, "fought" },
    beat = { -1, "beat" },
    lost_to = { 0, "lost a fight to" },
    escaped = { 0, "let slip" },
    outplayed = { 0, "outplayed" },
    -- Taking over (B8): the DM spoke for them.
    talk_warm = { 1, "got a straight answer from" },
    talk_guarded = { 0, "got nothing out of" },
    talk_lie = { 0, "was lied to by" },
    talk_caught = { -1, "caught a lie from" },
}

local function clamp(v)
    return util.clamp(v, data.ATT_MIN, data.ATT_MAX)
end

-- The notebook, made the first time it's asked for.
function M.get(campaign)
    local nb = campaign.notebook
    if nb then
        return nb
    end
    nb = { log = {}, people = {}, factions = {}, changes = {} }
    for pid, def in pairs(data.people) do
        local warm = {}
        for k, v in pairs(def.warm or {}) do
            warm[k] = v
        end
        nb.people[pid] = { att = def.att or 0, warm = warm, knows = {} }
    end
    for _, fid in ipairs(data.order) do
        nb.factions[fid] = { shift = 0 }
    end
    campaign.notebook = nb
    M.world_state(campaign)
    return nb
end

-- The world's side of it, kept apart from this table's notebook so a second table can share
-- the world later (GDD: A second table): where everyone is and whose side they're on, each
-- faction's project, and what's become of places. It lives in campaign.world, beside the
-- world turn's moves and timeline (world.lua).
--   people   { [person] = { status, status_week, faction } }
--   factions { [faction] = { clock, done } }
--   places   { [location] = { state, since } }
function M.world_state(campaign)
    local w = campaign.world
    if not w then
        w = {}
        campaign.world = w
    end
    if not w.people then
        w.people = {}
        for pid, def in pairs(data.people) do
            w.people[pid] = { status = def.status or "around", faction = def.faction }
        end
    end
    if not w.factions then
        w.factions = {}
        for _, fid in ipairs(data.order) do
            w.factions[fid] = { clock = 0 }
        end
    end
    w.places = w.places or {}
    return w
end

function M.status(campaign, pid)
    local wp = M.world_state(campaign).people[pid]
    return wp and wp.status or "around"
end

function M.faction_of(campaign, pid)
    local wp = M.world_state(campaign).people[pid]
    return wp and wp.faction or nil
end

function M.set_faction(campaign, pid, fid)
    local wp = M.world_state(campaign).people[pid]
    if wp then
        wp.faction = fid
    end
end

-- A faction's project state in the world: { clock, done }.
function M.project_state(campaign, fid)
    return M.world_state(campaign).factions[fid]
end

-- The person a cast card is, if the notebook keeps them (beasts and the dead it doesn't).
local alias
function M.person_of(card)
    if not alias then
        alias = {}
        for pid, def in pairs(data.people) do
            alias[pid] = pid
            for _, cid in ipairs(def.cards or {}) do
                alias[cid] = pid
            end
        end
    end
    local id = type(card) == "table" and card.id or card
    return id and alias[id] or nil
end

-- The cast card that is this person right now (Wren is the stranger until she isn't).
function M.card_of(campaign, pid)
    local def = data.people[pid]
    if not def then
        return nil
    end
    local deck = require "game.model.deck"
    local cards = def.cards or { pid }
    for i = #cards, 1, -1 do
        local c = content.components[cards[i]]
        if c and deck.state(campaign, c.id) ~= nil and not deck.is_spent(campaign, c.id) then
            return c
        end
    end
    return content.components[cards[#cards]]
end

-- Name, role, blurb and mini, from arc.lua's people or the factions file.
function M.about(pid)
    for _, p in ipairs(content.arc.people or {}) do
        if p.id == pid then
            local def = data.people[pid] or {}
            return { name = p.name, role = p.role, about = p.about, sprite = def.sprite or p.sprite }
        end
    end
    local n = data.names[pid]
    local def = data.people[pid] or {}
    local c = content.components[pid]
    return { name = n and n.name or (c and c.name) or pid, role = n and n.role or "", about = n and n.about or "",
             sprite = def.sprite }
end

function M.person(campaign, pid)
    return M.get(campaign).people[pid]
end

function M.label(att)
    return data.LABELS[clamp(math.floor(att + 0.5))] or "Indifferent"
end

-- How someone feels about the party now, with tonight's entries counted if a night is on.
function M.att(campaign, pid, night)
    local p = M.person(campaign, pid)
    if not p then
        return 0
    end
    local a = p.att
    for _, e in ipairs(night and night.ledger or {}) do
        if e.to == pid then
            a = a + (e.d or 0)
        end
    end
    return clamp(a)
end

-- SRD 5.2.1: a Friendly creature gives Advantage on checks to influence it, a Hostile one
-- Disadvantage. Returns "adv", "dis" or nil.
function M.influence(campaign, pid, skill, night)
    if not pid or not data.INFLUENCE[skill] then
        return nil
    end
    local a = M.att(campaign, pid, night)
    if a >= 2 then
        return "adv"
    elseif a <= -2 then
        return "dis"
    end
    return nil
end

local function note_change(nb, week, kind, id, from, to, why)
    table.insert(nb.changes, { week = week, kind = kind, id = id, from = from, to = to, why = why })
end

-- Move someone's attitude (and one hero's warmth with them). why: a line for the report.
function M.adjust(campaign, pid, d, why, key)
    local p = M.person(campaign, pid)
    if not p or d == 0 then
        return
    end
    local nb = M.get(campaign)
    local before = M.label(p.att)
    p.att = clamp(p.att + d)
    if key and key ~= "party" then
        p.warm[key] = clamp((p.warm[key] or 0) + d)
    end
    local after = M.label(p.att)
    if before ~= after then
        note_change(nb, campaign.week, "att", pid, before, after, why)
    end
end

function M.set_status(campaign, pid, status, why)
    local wp = M.world_state(campaign).people[pid]
    if not wp or wp.status == status then
        return
    end
    local nb = M.get(campaign)
    note_change(nb, campaign.week, "status", pid, wp.status, status, why)
    wp.status = status
    wp.status_week = campaign.week
end

-- Is this person still around to bring in (not missing, gone or beaten)?
function M.around(campaign, pid)
    if not M.person(campaign, pid) then
        return false
    end
    local st = M.status(campaign, pid)
    return st == "around" or st == "got away"
end

-- The words for one entry: "Pip charmed her at the Kettle."
local function pronoun_obj(pid)
    local c = content.components[pid] or content.components[(data.people[pid] and data.people[pid].cards or {})[1] or ""]
    if c and c.group then
        return "them"
    end
    local pr = c and c.pronoun or "they"
    return ({ he = "him", she = "her", it = "it", they = "them" })[pr] or "them"
end

function M.words(entry)
    local act = M.ACTS[entry.did]
    local ev = M.EVENTS[entry.did]
    if act then
        return entry.ok and act[3] or act[4]
    elseif ev then
        return ev[2]
    end
    return entry.did
end

function M.entry_text(campaign, entry, opts)
    opts = opts or {}
    -- An event (M8, B1) carries its own line.
    if entry.ev then
        return entry.text or (util.capitalize(entry.ev) .. ".")
    end
    local who
    if entry.who == "party" or not entry.who then
        who = "The party"
    else
        local p = campaign:player(entry.who)
        who = p and p.char or "Someone"
    end
    local target
    if opts.short_target then
        target = pronoun_obj(entry.to)
    else
        target = M.about(entry.to).name
        target = util.lower_first and string.match(target, "^The ") and util.lower_first(target) or target
    end
    local at = ""
    if entry.at and content.components[entry.at] then
        local loc = content.components[entry.at]
        at = " at " .. (loc.short or util.lower_first(loc.name))
    end
    return who .. " " .. M.words(entry) .. " " .. target .. at .. "."
end

-- After game night: file tonight's entries, move attitudes and statuses, and note what changed.
function M.after_night(campaign, night)
    local nb = M.get(campaign)
    night.filed = true
    for _, e in ipairs(night.ledger or {}) do
        e.w = campaign.week
        table.insert(nb.log, e)
        local p = nb.people[e.to]
        if p then
            p.met = p.met or campaign.week
            p.last = campaign.week
            local why = M.entry_text(campaign, e)
            if (e.d or 0) ~= 0 then
                M.adjust(campaign, e.to, e.d, why, e.who)
            end
            if e.status then
                M.set_status(campaign, e.to, e.status, why)
            end
            if e.know then
                local have = false
                for _, k in ipairs(p.knows) do
                    have = have or k == e.know
                end
                if not have then
                    table.insert(p.knows, e.know)
                end
            end
            if e.did == "exposed" then
                p.exposed = campaign.week
            end
        end
        local f = nb.factions[e.to]
        if f and (e.d or 0) ~= 0 then
            M.shift(campaign, e.to, e.d, M.entry_text(campaign, e))
        end
    end
    -- Factions crossed or helped tonight: by their cards in scenes the party won.
    for _, sc in ipairs(night.scenes or {}) do
        local deck = require "game.model.deck"
        if deck.outcome_of(sc) == "win" then
            for _, fid in ipairs(data.order) do
                local fd = data[fid]
                for _, c in pairs(sc.comps) do
                    if util.contains(fd.cards or {}, c.id) or util.contains(fd.against or {}, c.id) then
                        nb.factions[fid].crossed = campaign.week
                        nb.factions[fid].pushed = campaign.week
                    end
                    if c.kind == "goal" and util.contains(fd.helps or {}, c.id) then
                        nb.factions[fid].helped = campaign.week
                    end
                end
            end
        end
    end
    -- Anyone the party hurt tonight crossed their faction too.
    for _, e in ipairs(night.ledger or {}) do
        local fid = nb.people[e.to] and M.faction_of(campaign, e.to)
        if fid and (e.d or 0) < 0 and nb.factions[fid] then
            nb.factions[fid].crossed = campaign.week
        end
    end
end

-- A faction's standing moves on its own (a favour, a grudge).
function M.shift(campaign, fid, d, why)
    local nb = M.get(campaign)
    local f = nb.factions[fid]
    if not f or d == 0 then
        return
    end
    local before = M.standing(campaign, fid)
    f.shift = f.shift + d
    local after = M.standing(campaign, fid)
    if before ~= after then
        note_change(nb, campaign.week, "standing", fid, before, after, why)
    end
end

-- Who's in a faction now (people can change sides off screen, S7). Hidden members only once
-- they've been exposed, unless all = true.
function M.members(campaign, fid, all)
    local nb = M.get(campaign)
    local out = {}
    for pid, p in pairs(nb.people) do
        local def = data.people[pid]
        if M.faction_of(campaign, pid) == fid and (all or not def.hidden or p.exposed) then
            table.insert(out, pid)
        end
    end
    table.sort(out)
    return out
end

-- A faction's standing with the party, -3 (war) to +3 (allies): where it started, what it's
-- done since, and how its members feel (on average, from where they started).
function M.standing(campaign, fid)
    local nb = M.get(campaign)
    local fd = data[fid]
    local f = nb.factions[fid]
    if not fd or not f then
        return 0
    end
    local sum, n = 0, 0
    for _, pid in ipairs(M.members(campaign, fid, true)) do
        local def = data.people[pid]
        sum = sum + (nb.people[pid].att - (def.att or 0))
        n = n + 1
    end
    local avg = n > 0 and sum / n or 0
    local v = (fd.start or 0) + f.shift + (avg >= 0 and math.floor(avg + 0.5) or -math.floor(-avg + 0.5))
    return util.clamp(v, -3, 3)
end

M.STANDING = { [-3] = "At war", [-2] = "Hostile", [-1] = "Cold", [0] = "Neutral", [1] = "Friendly", [2] = "Helpful",
               [3] = "Allies" }

-- What changed this week (or a given week), for the report.
function M.changes(campaign, week)
    local out = {}
    for _, ch in ipairs(M.get(campaign).changes) do
        if ch.week == (week or campaign.week) then
            table.insert(out, ch)
        end
    end
    return out
end

-- The report's line for a change: "Madame Sable: Indifferent to Hostile, after Pip lied to her."
function M.change_text(campaign, ch)
    local name
    if ch.kind == "standing" then
        name = data[ch.id] and data[ch.id].name or ch.id
        return name .. ": " .. M.STANDING[ch.from] .. " to " .. M.STANDING[ch.to] .. "."
    end
    name = M.about(ch.id).name
    local from, to = ch.from, ch.to
    if ch.kind == "status" then
        from, to = data.STATUS[from] or from, data.STATUS[to] or to
    end
    local why = ch.why and (", after: " .. string.gsub(ch.why, "%.$", "")) or ""
    return name .. ": " .. from .. " to " .. to .. why .. "."
end

-- Every entry about one person (or faction), newest first.
function M.history(campaign, id, night)
    local out = {}
    for _, e in ipairs(night and night.ledger or {}) do
        if e.to == id then
            table.insert(out, 1, e)
        end
    end
    local log = M.get(campaign).log
    for i = #log, 1, -1 do
        if log[i].to == id then
            table.insert(out, log[i])
        end
    end
    return out
end

-- Everything that happened at a place, newest first.
function M.at_place(campaign, lid)
    local out = {}
    local log = M.get(campaign).log
    for i = #log, 1, -1 do
        if log[i].at == lid then
            table.insert(out, log[i])
        end
    end
    return out
end

-- The last thing that soured someone, for an agenda card ("hasn't forgotten Pip's lie").
function M.grudge(campaign, pid)
    local log = M.get(campaign).log
    for i = #log, 1, -1 do
        local e = log[i]
        if e.to == pid and (e.d or 0) < 0 then
            return e
        end
    end
end

-- Grudge (M8, B6): how much a villain who got away holds against the party, worked out from
-- the log: every escape, every time they beat the party, every time the party hurt them. 0 to 5.
M.GRUDGE_MAX = 5
function M.grudge_level(campaign, pid)
    if not pid then
        return 0
    end
    local g = 0
    for _, e in ipairs(M.get(campaign).log) do
        if e.to == pid and not e.ev then
            if e.did == "escaped" then
                g = g + 2
            elseif e.did == "lost_to" then
                g = g + 1
            elseif (e.d or 0) < 0 then
                g = g + 0.5
            end
        end
    end
    return math.min(M.GRUDGE_MAX, math.floor(g))
end

-- What a person brings when the DM brings them in (S6): an agenda card from their wants, by
-- how they feel about the party, or nil when they simply come as themselves (Indifferent).
-- warm: a goal (a favour, a job); cold: a complication; back: a villain who got away.
local SUBJ = { he = "He", she = "She", it = "It", they = "They" }

function M.agenda_kind(campaign, pid)
    local def = data.people[pid]
    local wants = def and def.wants
    local p = M.person(campaign, pid)
    if not wants or not p then
        return nil
    end
    if M.status(campaign, pid) == "got away" and wants.back then
        return "back"
    elseif p.att >= 1 and wants.warm then
        return "warm"
    elseif p.att <= -1 and wants.cold then
        return "cold"
    end
    return nil
end

function M.agenda_card(campaign, pid)
    local which = M.agenda_kind(campaign, pid)
    if not which then
        return nil
    end
    local w = data.people[pid].wants[which]
    local cast = M.card_of(campaign, pid)
    local line = w.line
    if which == "back" and M.grudge_level(campaign, pid) >= 2 then
        -- A villain back with a Grudge (B6) says so.
        line = line .. " The Grudge is personal now (" .. util.int(M.grudge_level(campaign, pid)) .. " of "
            .. util.int(M.GRUDGE_MAX) .. ")."
    end
    if which ~= "warm" then
        local g = M.grudge(campaign, pid)
        if g then
            local subj = SUBJ[cast and not cast.group and cast.pronoun or "they"] or "They"
            local what = string.gsub(M.entry_text(campaign, g, { short_target = true }), "%.$", "")
            line = line .. " " .. subj .. (subj == "They" and " haven't" or " hasn't") .. " forgotten the time "
                .. util.lower_first(what) .. "."
        end
    end
    campaign.agenda_n = (campaign.agenda_n or 0) + 1
    local warm = which == "warm"
    local c = content.register({
        runtime = true, agenda = pid, agenda_kind = which,
        id = "agenda_" .. pid .. "_" .. util.int(campaign.agenda_n),
        kind = warm and "goal" or "complication", name = w.name, cost = 1,
        difficulty = which == "back" and 2 or (warm and 0 or 1),
        fits = warm and { "social", "downtime", "mystery", "exploration" }
            or { "combat", "social", "exploration", "mystery", "set_piece", "downtime", "puzzle" },
        tags = warm and { "heart", "talk" } or { "danger", "talk" },
        meters = warm and { social = 4, story = 3 } or { challenge = 4, story = 3 },
        line = line, win = w.win, lose = w.lose,
        with = cast and { cast.id } or nil, suits = cast and cast.suits or nil, where = cast and cast.where or nil,
        thread = cast and cast.thread or nil,
    })
    campaign.registered = campaign.registered or {}
    table.insert(campaign.registered, c)
    return c
end

-- A place's state, once the world has changed it: { label, line } or nil.
function M.place_state(campaign, lid)
    local pl = M.world_state(campaign).places[lid]
    local states = data.places[lid]
    return pl and states and states[pl.state] or nil
end

function M.set_place(campaign, lid, state)
    M.world_state(campaign).places[lid] = { state = state, since = campaign.week }
end

-- Who at the table someone is warm or cold toward: { { key, n } }, strongest first.
function M.warmth(campaign, pid)
    local p = M.person(campaign, pid)
    local out = {}
    for k, v in pairs(p and p.warm or {}) do
        if v ~= 0 and campaign:player(k) then
            table.insert(out, { key = k, n = v })
        end
    end
    table.sort(out, function(a, b)
        if math.abs(a.n) ~= math.abs(b.n) then
            return math.abs(a.n) > math.abs(b.n)
        end
        return a.key < b.key
    end)
    return out
end

-- Has the party met them (a scene with them played, or everyone knows them)?
function M.met(campaign, pid)
    local p = M.person(campaign, pid)
    if p and p.met then
        return true
    end
    local story = require "game.model.story"
    for _, ap in ipairs(content.arc.people or {}) do
        if ap.id == pid then
            return ap.known or story.init(campaign).met[pid] ~= nil
        end
    end
    return false
end

-- Everyone, for the People page: met first (most recent first), then the rest.
function M.people(campaign)
    local nb = M.get(campaign)
    local out = {}
    for pid in pairs(nb.people) do
        table.insert(out, pid)
    end
    table.sort(out, function(a, b)
        local ma, mb = M.met(campaign, a), M.met(campaign, b)
        if ma ~= mb then
            return ma
        end
        local la, lb = nb.people[a].last or 0, nb.people[b].last or 0
        if la ~= lb then
            return la > lb
        end
        return M.about(a).name < M.about(b).name
    end)
    return out
end

return M
