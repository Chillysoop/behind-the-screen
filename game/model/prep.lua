-- The week's prep: a hand of components, three scene cards with five slots
-- each, a budget of prep hours, the pacing curve and a forecast per player.
-- Pure Lua.

local content = require "game.model.content"
local score = require "game.model.score"
local bars = require "game.model.bars"
local util = require "game.model.util"
local seeds = require "game.model.seeds"
local convo = require "game.model.convo"

local function places_mod()
    return require "game.model.places"
end

local M = {}
M.__index = M

M.BUDGET = 12
M.SCENES = 3
M.HAND_PER_KIND = 5      -- (the old random draw, kept for reference; the hand comes from the deck now)
M.TALK_COST = 2
M.BASE_QUALITY = 0.62

local IMPROV_ORDER = { "goal", "cast", "location", "complication", "reward" }
M.IMPROV_ORDER = IMPROV_ORDER

function M.new(campaign)
    local self = setmetatable({}, M)
    self.campaign = campaign
    self.budget = M.BUDGET
    self.hand = require("game.model.deck").hand(campaign)   -- the story deck (the slice rework)
    self.talked = {}
    self.scenes = {}
    for i = 1, M.SCENES do
        self.scenes[i] = { type = nil, slots = {} }
    end
    -- M6: time spent on conversations, inspiration and seeds; cards that came from them.
    self.extra = 0
    self.payoffs = {}        -- payoff card id -> seed id (ready to pay off this week)
    self.inspired = {}       -- card id -> the activity that drew it
    self.inspired_by = {}    -- activity id -> cards drawn
    self.inspirations = 0
    self.planted = nil       -- the seed planted this week
    self.seed_ideas = campaign.seeds and seeds.offer(campaign, content.seeds.OFFERED) or {}
    self.convos = {}         -- conversation id -> thread
    self.arc_cards = {}      -- (M7) this week's story cards, by id
    -- S6, bringing them in: cards the DM pinned into the hand, and why.
    self.pins = {}           -- card id -> { why = "spotlight" | "guest" | "screen", note, guest, added }
    self.pin_order = {}
    self.guests = {}         -- person or place id -> { cards = { id... } }
    self.spot = nil          -- the player this session is for
    return self
end

-- What a card costs to prep this week: a place you already know is free (A15: Your places).
function M:cost_of(c)
    if c.kind == "location" and places_mod().is_known(self.campaign, c.id) then
        return 0
    end
    -- A shower thought (B5) costs nothing to place.
    local pin = self.pins and self.pins[c.id]
    if pin and pin.free then
        return 0
    end
    return c.cost
end

function M:spent()
    local total = 0
    local places = {}
    for _, s in ipairs(self.scenes) do
        -- A published adventure (A13): one price for the whole scene, plus each swap.
        if s.module then
            local n = 0
            for _ in pairs(s.module.swaps) do
                n = n + 1
            end
            total = total + content.books.MODULE_COST + n * content.books.SWAP_COST
        end
        for kind, c in pairs(s.module and {} or s.slots) do
            -- A place you've prepped once can host more than one scene (A6).
            if kind ~= "location" or not places[c.id] then
                total = total + self:cost_of(c)
            end
            if kind == "location" then
                places[c.id] = true
            end
        end
        -- An open scene's spots (A15): a quick sketch each, free if it's already yours.
        for _, id in ipairs(s.spots or {}) do
            local c = content.components[id]
            if c and not places[id] then
                places[id] = true
                total = total + (self:cost_of(c) > 0 and content.open_scenes.SPOT_COST or 0)
            end
        end
    end
    for _ in pairs(self.talked) do
        total = total + M.TALK_COST
    end
    -- Handouts made for cards on the board (game/model/handouts.lua).
    total = total + require("game.model.handouts").cost(self)
    return total + self.extra
end

function M:left()
    return self.budget - self:spent()
end

-- Where a component is placed on the board, if anywhere.
function M:placed_at(id)
    for i, s in ipairs(self.scenes) do
        for kind, c in pairs(s.slots) do
            if c.id == id then
                return i, kind
            end
        end
    end
    return nil
end

function M:can_place(i, id)
    local c = content.components[id]
    if not c then
        return false, "Unknown card."
    end
    if self.scenes[i].module then
        return false, "This scene is a published adventure. Swap its reward or its person instead."
    end
    local refund = 0
    local cur = self.scenes[i].slots[c.kind]
    if cur then
        refund = refund + self:cost_of(cur)
    end
    local at = self:placed_at(id)
    if at then
        refund = refund + self:cost_of(c)
    end
    if self:cost_of(c) > self:left() + refund then
        return false, "Not enough prep time left."
    end
    -- A cliffhanger ends the night (the story playtest): it can only close the last scene.
    if c.cliffhanger and i ~= #self.scenes then
        return false, "A cliffhanger ends the night. It goes in the last scene."
    end
    -- It has to make sense where the scene happens: no floor to give way on a forest road.
    local others = {}
    for kind, other in pairs(self.scenes[i].slots) do
        if kind ~= c.kind then
            others[kind] = other
        end
    end
    local clash = content.setting_clash(c, others)
    if clash then
        local loc = c.kind == "location" and c or clash
        local odd = c.kind == "location" and clash or c
        return false, "\"" .. odd.name .. "\" can't happen at " .. util.lower_first(loc.name) .. ".", clash
    end
    -- A card tied to one place happens there (the abbot's candles are in the chapel, not the
    -- fighting pit: the story playtest).
    local loc = c.kind == "location" and c or others.location
    for _, card in pairs(c.kind == "location" and others or { c }) do
        if loc and card.kind ~= "location" and not content.belongs_at(card, loc) then
            local home = content.tied_place(card)
            return false, "\"" .. card.name .. "\" happens at " .. (home and util.lower_first(home.name) or "another place")
                .. ", not " .. util.lower_first(loc.name) .. ".", c.kind == "location" and card or loc
        end
    end
    return true
end

-- Every scene a component is on (a location can host several; anything else is on one).
function M:placed_all(id)
    local list = {}
    for i, s in ipairs(self.scenes) do
        for _, c in pairs(s.slots) do
            if c.id == id then
                table.insert(list, i)
            end
        end
    end
    return list
end

-- Put a component in its slot on scene i. A card can only be in one place, so placing it
-- again moves it; a location can be in several (the riddle and the fight both in the bell
-- tower, A6), prepped once.
function M:place(i, id)
    local pc = content.components[id]
    if pc and pc.kind == "location" and self.scenes[i].open then
        return self:add_spot(i, id)   -- an open scene takes places as spots (A15)
    end
    local ok, why = self:can_place(i, id)
    if not ok then
        return false, why
    end
    local c = content.components[id]
    local at_i, at_kind = self:placed_at(id)
    if at_i and c.kind ~= "location" then
        self.scenes[at_i].slots[at_kind] = nil
    end
    self.scenes[i].slots[c.kind] = c
    return true
end

function M:clear(i, kind)
    self.scenes[i].slots[kind] = nil
end

function M:set_type(i, scene_type)
    if self.scenes[i].module then
        return false          -- a published adventure brings its own type (A13)
    end
    self.scenes[i].type = scene_type
    return true
end

-- The table clock (A14): roughly how long the board will run at the table, and how long you
-- all agreed to play. Fights and choices still run long or short on the night.
M.SCENE_MIN = { combat = 70, set_piece = 80, social = 55, mystery = 60, exploration = 60, puzzle = 55, downtime = 45 }

function M:estimate_minutes()
    local m = 25
    for _, s in ipairs(self.scenes) do
        m = m + (M.SCENE_MIN[s.type] or 55) + (s.open and 10 or 0)
    end
    return m
end

function M:planned_minutes()
    local tbl = self.campaign.table
    local len = tbl and tbl.rules and tbl.rules.length
    local opt = len and content.session_zero.rules.length[len]
    return ((opt and opt.hours) or 3.5) * 60
end

-- Open scenes (A15) ------------------------------------------------------------------------------
-- The DM sets the stage and the players choose: a scene marked open has a few spots (places,
-- sketched for an hour each, free if they're already yours) instead of one location. Its other
-- slots are the DM's hook, waiting at the first spot. The night asks the table where they go.

function M:set_open(i, on)
    local s = self.scenes[i]
    if on then
        self:clear_module(i)
        s.open = true
        s.spots = s.spots or {}
        s.type = s.type or "social"
        local loc = s.slots.location
        if loc and #s.spots < content.open_scenes.SPOTS and not util.contains(s.spots, loc.id) then
            table.insert(s.spots, 1, loc.id)
        end
        s.slots.location = nil
    else
        s.open = nil
        if s.spots and s.spots[1] and not s.slots.location then
            s.slots.location = content.components[s.spots[1]]
        end
        s.spots = nil
    end
end

function M:can_add_spot(i, id)
    local s = self.scenes[i]
    local c = content.components[id]
    if not (s.open and c and c.kind == "location") then
        return false, "Only places can be spots."
    end
    if util.contains(s.spots, id) then
        return false, "Already a spot."
    end
    if #s.spots >= content.open_scenes.SPOTS then
        return false, util.int(content.open_scenes.SPOTS) .. " spots is plenty. Take one out first."
    end
    if self:cost_of(c) > 0 and content.open_scenes.SPOT_COST > self:left() then
        return false, "Not enough prep time left."
    end
    return true
end

function M:add_spot(i, id)
    local ok, why = self:can_add_spot(i, id)
    if not ok then
        return false, why
    end
    table.insert(self.scenes[i].spots, id)
    return true
end

function M:remove_spot(i, id)
    local s = self.scenes[i]
    for k, v in ipairs(s.spots or {}) do
        if v == id then
            table.remove(s.spots, k)
            return true
        end
    end
    return false
end

-- Spots the campaign suggests (A15): your places, people the notebook last saw somewhere,
-- and places from the hand tied to someone's story. { id, why }, best first.
function M:spot_suggestions(i)
    local s = self.scenes[i]
    local out, seen = {}, {}
    local function add(id, why)
        if id and not seen[id] and not util.contains(s.spots or {}, id) and content.components[id]
            and content.components[id].kind == "location" then
            seen[id] = true
            table.insert(out, { id = id, why = why })
        end
    end
    local ledger = require "game.model.ledger"
    for _, pe in ipairs(ledger.people(self.campaign)) do
        local pid = pe.id or pe
        if type(pid) == "string" and ledger.met(self.campaign, pid) then
            local last = ledger.history(self.campaign, pid)[1]
            if last and last.at then
                add(last.at, ledger.about(pid).name .. " was last seen here")
            end
        end
    end
    for _, c in ipairs(self.hand.location or {}) do
        if c.thread then
            add(c.id, self.campaign:player(c.thread).char .. "'s past")
        end
    end
    -- A way on to the styles next door (A18): a port, a stair down, a road out of town.
    local styles = require "game.model.styles"
    local reach = styles.reachable(self.campaign)
    for _, c in ipairs(self.hand.location or {}) do
        for _, t in ipairs(c.cross or {}) do
            if reach[t] then
                add(c.id, "A way on to " .. styles.def(t).name)
                break
            end
        end
    end
    for _, pl in ipairs(places_mod().list(self.campaign)) do
        add(pl.id, "One of your places (free)")
    end
    return out
end

-- Published adventures (A13) -----------------------------------------------------------------
-- A module pulled in from a book fills a whole scene: every slot, the scene type and the fight,
-- for books.MODULE_COST hours. Swap its reward for a card from your hand, or recast its person
-- with someone from the notebook, for books.SWAP_COST each. s.module = { id, swaps = { kind = id } }.

local function books_mod()
    return require "game.model.books"
end

function M:can_place_module(i, mid)
    local s = self.scenes[i]
    local m = books_mod().module(mid)
    if not m or not books_mod().get(self.campaign).modules[mid] then
        return false, "Pull it in from a book first."
    end
    if s.open then
        return false, "An open scene lets the players choose. Close it first."
    end
    for j, o in ipairs(self.scenes) do
        if j ~= i and o.module and o.module.id == mid then
            return false, "It's already on stop " .. util.int(j) .. "."
        end
    end
    -- What this scene's cards cost now comes back.
    local refund = 0
    if s.module then
        refund = self:module_cost(i)
    else
        for _, c in pairs(s.slots) do
            refund = refund + self:cost_of(c)
        end
    end
    if content.books.MODULE_COST > self:left() + refund then
        return false, "Not enough prep time left."
    end
    return true
end

function M:module_cost(i)
    local s = self.scenes[i]
    if not s.module then
        return 0
    end
    local n = 0
    for _ in pairs(s.module.swaps) do
        n = n + 1
    end
    return content.books.MODULE_COST + n * content.books.SWAP_COST
end

function M:place_module(i, mid)
    local ok, why = self:can_place_module(i, mid)
    if not ok then
        return false, why
    end
    local s = self.scenes[i]
    local m = books_mod().module(mid)
    s.slots = {}
    for kind, c in pairs(m.cards) do
        s.slots[kind] = content.components[c.id]
    end
    s.type = m.type
    s.module = { id = mid, swaps = {} }
    if m.encounter then
        local ids = {}
        for k, id in ipairs(m.encounter.ids) do
            ids[k] = id
        end
        s.encounter = { ids = ids, boss_name = m.encounter.boss_name, built = true, module = true }
    else
        s.encounter = nil
    end
    return true
end

function M:clear_module(i)
    local s = self.scenes[i]
    if s.module then
        s.module = nil
        s.slots = {}
        s.encounter = nil
    end
end

-- Swap a module's reward (a reward from your hand) or person (a cast card of someone in the notebook).
function M:can_swap(i, id)
    local s = self.scenes[i]
    local c = content.components[id]
    if not (s.module and c) then
        return false, "Not a published adventure."
    end
    if c.kind ~= "reward" and c.kind ~= "cast" then
        return false, "Only its reward or its person can change."
    end
    if c.module then
        return false, "That's the book's own."
    end
    if c.kind == "cast" then
        local ledger = require "game.model.ledger"
        local pid = ledger.person_of(c)
        if not (pid and ledger.met(self.campaign, pid)) then
            return false, "Recast it with someone the party knows (from your notebook)."
        end
    end
    if self:placed_at(id) then
        return false, "Already on the board."
    end
    if not s.module.swaps[c.kind] and content.books.SWAP_COST > self:left() then
        return false, "Not enough prep time left."
    end
    return true
end

function M:swap(i, id)
    local ok, why = self:can_swap(i, id)
    if not ok then
        return false, why
    end
    local s = self.scenes[i]
    local c = content.components[id]
    s.slots[c.kind] = c
    s.module.swaps[c.kind] = id
    return true
end

-- Who from the notebook could play the module's person: people the party has met, still around.
function M:recast_options(i)
    local ledger = require "game.model.ledger"
    local out = {}
    for _, pid in ipairs(ledger.people(self.campaign)) do
        if ledger.met(self.campaign, pid) and ledger.around(self.campaign, pid) then
            local c = ledger.card_of(self.campaign, pid)
            if c and c.kind == "cast" and not c.foe and not c.villain and self:can_swap(i, c.id) then
                table.insert(out, { pid = pid, card = c })
            end
        end
    end
    return out
end

function M:unswap(i, kind)
    local s = self.scenes[i]
    if not (s.module and s.module.swaps[kind]) then
        return false
    end
    local m = books_mod().module(s.module.id)
    s.module.swaps[kind] = nil
    s.slots[kind] = content.components[m.cards[kind].id]
    return true
end

-- The encounter builder (real-session pass) ----------------------------------------------
-- A combat or set-piece scene's fight. Until the DM builds their own, game night uses the
-- one the scene suggests (its cast's monsters, else its location's, sized by the meter).

local function fight_mod()
    return require "game.model.fight"
end

function M:suggested_encounter(i)
    local s = self.scenes[i]
    local camp = self.campaign
    local n = 0
    for _, p in ipairs(camp.players) do
        if p.present then
            n = n + 1
        end
    end
    local sc = { comps = s.slots, type = s.type, difficulty = M.difficulty(s.slots), hazard = s.hazard }
    local ids, fam = fight_mod().suggest(sc, camp.level or 2, math.max(1, n))
    return ids, fam
end

-- The fight as it stands: { ids, boss_name, built }.
function M:encounter(i)
    local s = self.scenes[i]
    if s.encounter then
        return s.encounter
    end
    local ids, fam = self:suggested_encounter(i)
    return { ids = ids, boss_name = fam.name, built = false }
end

-- A hazard on the mat (A10): one of game/rules/data/hazards.lua, or nil for none. Otherwise the
-- scene's complication may bring one (a fire, a flood, a floor giving way).
function M:set_hazard(i, id)
    self.scenes[i].hazard = id
end

function M:hazard(i)
    local s = self.scenes[i]
    return fight_mod().hazard_of({ comps = s.slots, hazard = s.hazard, encounter = s.encounter })
end

-- The DM's own fight: monster ids, the first one leads it. nil goes back to the suggestion.
function M:set_encounter(i, ids)
    local s = self.scenes[i]
    if not ids or #ids == 0 then
        s.encounter = nil
        return
    end
    local fam = fight_mod().family({ comps = s.slots })
    local monsters = require "game.rules.data.monsters"
    local lead = monsters[ids[1]]
    local name = (ids[1] == fam.boss) and fam.name or ("the " .. string.lower(lead and lead.name or ids[1]))
    local copy = {}
    for k, id in ipairs(ids) do
        copy[k] = id
    end
    s.encounter = { ids = copy, boss_name = name, built = true }
end

-- A fighting cast on a fight you built yourself that someone else leads (A7: cast and fight
-- stay in sync). The prep board asks before the cast takes over the lead.
function M:cast_would_lead(i, c)
    local s = self.scenes[i]
    local fam = c and content.encounters.by_cast[c.id]
    return fam ~= nil and s.encounter ~= nil and (s.type == "combat" or s.type == "set_piece") and s.encounter.boss_name ~= fam.name
end

-- The cast leads the scene's fight: their monster takes the lead, the rest of yours stay.
function M:cast_leads(i)
    local s = self.scenes[i]
    local fam = s.slots.cast and content.encounters.by_cast[s.slots.cast.id]
    if not (fam and s.encounter) then
        return false
    end
    local ids = { fam.boss }
    for k = 2, #s.encounter.ids do
        table.insert(ids, s.encounter.ids[k])
    end
    self:set_encounter(i, ids)
    return true
end

function M:can_talk(key)
    return not self.talked[key] and self:left() >= M.TALK_COST
end

-- A one-on-one chat before the session: learn their mood, and they feel heard.
function M:talk(key)
    if not self:can_talk(key) then
        return false
    end
    self.talked[key] = true
    local p = self.campaign:player(key)
    if p.on_break then
        -- Checking in on someone who's taking a break: they feel missed.
        bars.check_in(p)
        self.campaign:gain_empathy("check_in")
    else
        p.mood_known = true
        score.add(p, "investment", 3)
        self.campaign:gain_empathy("talk")
    end
    return true
end

function M:ready()
    for _, s in ipairs(self.scenes) do
        if not s.type then
            return false
        end
    end
    return true
end

function M:sketched()
    local n = 0
    for _, s in ipairs(self.scenes) do
        for _, kind in ipairs(content.kinds) do
            if not s.slots[kind] then
                n = n + 1
            end
        end
    end
    return n
end

-- Quality from prep alone: each written slot helps, fitting ones help more, and cards
-- the DM was inspired by (or that pay off a seed) a little more again.
function M.quality(scene_type, slots, inspired)
    local q = M.BASE_QUALITY
    for _, c in util.sorted_pairs(slots) do
        q = q + 0.06
        if scene_type and util.contains(c.fits, scene_type) then
            q = q + 0.03
        end
        if (inspired and inspired[c.id]) or c.payoff_of or c.callback then
            q = q + content.inspiration.QUALITY
        end
    end
    return q
end

-- Seeds (M6) ----------------------------------------------------------------------------

function M:can_plant(id)
    if self.planted and self.planted ~= id then
        return false, "One seed a week is plenty."
    end
    if self.planted == id then
        return true
    end
    if self:left() < content.seeds.COST then
        return false, "Not enough prep time left."
    end
    return true
end

function M:plant(id)
    if self.planted == id then
        return true
    end
    local ok, why = self:can_plant(id)
    if not ok then
        return false, why
    end
    self.planted = id
    self.extra = self.extra + content.seeds.COST
    return true
end

function M:unplant()
    if self.planted then
        self.planted = nil
        self.extra = self.extra - content.seeds.COST
    end
end

-- Inspiration (M6): an evening off that draws extra cards.
function M:inspire(id)
    return seeds.inspire(self.campaign, self, id)
end

function M:can_inspire(id)
    return seeds.can_inspire(self.campaign, self, id)
end

-- Conversations (M6) ----------------------------------------------------------------------

-- Open (or reopen) a conversation. Starting one yourself costs prep time, paid when
-- you send the first message (so you can read your options first).
function M:open_convo(id)
    if self.convos[id] then
        return self.convos[id]
    end
    local cost = convo.cost(self.campaign, id)
    if cost > self:left() then
        return nil, "Not enough prep time left: this one takes " .. util.int(cost) .. "h."
    end
    local thread = convo.open(self.campaign, id)
    thread.cost = cost
    thread.unpaid = cost > 0
    self.convos[id] = thread
    return thread
end

-- Close a conversation you opened but never sent anything in: it costs nothing.
function M:close_convo(id)
    local thread = self.convos[id]
    if thread and thread.unpaid then
        self.convos[id] = nil
    end
end

function M:convo_cost(id)
    local thread = self.convos[id]
    if thread and not thread.unpaid then
        return 0
    end
    return convo.cost(self.campaign, id)
end

function M:reply(id, i)
    local thread = self.convos[id]
    if not thread or thread.done then
        return nil
    end
    if thread.unpaid then
        -- What it costs now: it may have become free since you opened it.
        local cost = convo.cost(self.campaign, id)
        if cost > self:left() then
            return nil, "Not enough prep time left."
        end
        self.extra = self.extra + cost
        thread.cost = cost
        thread.unpaid = false
    end
    return convo.choose(self.campaign, thread, i)
end

function M.difficulty(slots)
    local d = 1
    if slots.cast then
        d = math.max(d, slots.cast.difficulty)
    end
    if slots.complication then
        d = d + slots.complication.difficulty
    end
    return util.clamp(d, 1, 3)
end

function M.tension(scene_type, slots, last)
    if not scene_type then
        return 0
    end
    local t = content.scenes[scene_type].tension
    if slots.complication and slots.complication.difficulty > 0 then
        t = t + 1
    end
    if slots.cast and slots.cast.difficulty >= 3 then
        t = t + 1
    end
    if last and slots.complication and slots.complication.cliffhanger then
        t = t + 1
    end
    return util.clamp(t, 1, 5)
end

-- The pacing curve and the warnings a seasoned DM would mutter.
-- scenes: list of { type, slots }; players: present players.
function M.pacing(scenes, players)
    local out = { tensions = {}, warnings = {}, fun_all = 0, good = {} }
    local n = #scenes
    local types = {}
    for i, s in ipairs(scenes) do
        out.tensions[i] = M.tension(s.type, s.slots, i == n)
        types[i] = s.type
    end
    if not (types[1] and types[2] and types[3]) then
        table.insert(out.warnings, "Pick a type for every stop to see the full curve.")
        return out
    end
    local t1, t2, t3 = out.tensions[1], out.tensions[2], out.tensions[3]
    local hi = math.max(t1, t2, t3)
    local lo = math.min(t1, t2, t3)
    local last = scenes[n].slots.complication
    out.finish_high = t3 >= 4 or (last ~= nil and last.cliffhanger == true)
    out.builds = t3 >= t2 and t2 >= t1 and t3 > t1
    out.flat = hi == lo

    if out.finish_high then
        out.fun_all = out.fun_all + 4
        table.insert(out.good, "It ends on a high.")
    end
    if out.builds then
        out.fun_all = out.fun_all + 2
        table.insert(out.good, "The tension builds all night.")
    end
    if out.flat then
        out.fun_all = out.fun_all - 5
        table.insert(out.warnings, "Every scene sits at the same tension. It may feel flat.")
    elseif hi <= 2 then
        out.fun_all = out.fun_all - 3
        table.insert(out.warnings, "No peak tonight. Nothing gets above a simmer.")
    end
    if t3 < hi and t3 <= 2 and not out.finish_high then
        table.insert(out.warnings, "It ends on a low. A fight or a cliffhanger would land better.")
    end

    local function names_where(pred)
        local names = {}
        for _, p in ipairs(players) do
            if pred(p) then
                table.insert(names, p.name)
            end
        end
        return names
    end

    if types[1] == types[2] and types[2] == types[3] then
        out.repeat_type = types[1]
        local tuned_out = names_where(function(p) return score.taste(p, types[1]) < 1 end)
        local tname = content.scenes[types[1]].name
        if #tuned_out > 0 then
            table.insert(out.warnings, "Three " .. tname .. " scenes in a row. " .. util.join_names(tuned_out) .. " will tune out.")
        else
            table.insert(out.warnings, "Three " .. tname .. " scenes in a row.")
        end
    else
        for i = 1, n - 1 do
            if types[i] == types[i + 1] then
                table.insert(out.warnings, "Two " .. content.scenes[types[i]].name .. " scenes back to back.")
                break
            end
        end
    end

    local has = {}
    for _, t in ipairs(types) do
        has[t] = true
    end
    if not (has.combat or has.set_piece) then
        local who = names_where(function(p) return score.arch(p, "butt_kicker") >= 1 or score.arch(p, "power_gamer") >= 1 end)
        if #who > 0 then
            table.insert(out.warnings, "No fight this week. " .. util.join_names(who) .. " will get restless.")
        end
    end
    if not (has.social or has.downtime) then
        local who = names_where(function(p) return score.arch(p, "method_actor") >= 1 or score.arch(p, "casual") >= 1 end)
        if #who > 0 then
            table.insert(out.warnings, util.join_names(who) .. " won't get anyone to talk to.")
        end
    end
    if not (has.mystery or has.exploration or has.puzzle) then
        local who = names_where(function(p) return score.arch(p, "storyteller") >= 1 or score.arch(p, "explorer") >= 1 end)
        if #who > 0 then
            table.insert(out.warnings, "Nothing to figure out. " .. util.join_names(who) .. " likes a mystery.")
        end
    end
    return out
end

function M:pacing_now()
    return M.pacing(self.scenes, self.campaign:present())
end

-- Threads on the board, by player key.
function M:threads()
    local t = {}
    for _, s in ipairs(self.scenes) do
        for _, c in pairs(s.slots) do
            if c.thread then
                t[c.thread] = true
            end
        end
    end
    return t
end

-- What the DM expects each player's night to feel like, from prep alone.
-- Moods only count once you know them.
function M:forecast()
    local out = {}
    local present = self.campaign:present()
    local pacing = self:pacing_now()
    for _, p in ipairs(present) do
        local saved_m, saved_b, saved_f = p.m, p.boredom, p.fun_bonus
        score.reset_session(p)
        local mood = p.mood_known and score.mood(p) or content.moods.fine
        local ready = true
        for i, s in ipairs(self.scenes) do
            if s.type then
                local slots = s.slots
                local missing = 0
                for _, kind in ipairs(content.kinds) do
                    if not slots[kind] then
                        missing = missing + 1
                    end
                end
                local q = M.quality(s.type, slots, self.inspired) + (missing > 0 and 0.03 or 0) - 0.03 * math.max(0, missing - 1)
                local sc = { type = s.type, comps = slots, quality = q, difficulty = M.difficulty(slots) }
                local g = score.scene_gains(p, sc, mood)
                for _, k in ipairs(score.METERS) do
                    p.m[k] = util.clamp(p.m[k] + g[k], 0, 100)
                end
                -- an average night of quick checks and decisions on top
                local shine = content.scenes[s.type].shine[p.class] or 0
                p.m.spotlight = util.clamp(p.m.spotlight + 6 + 5 * shine, 0, 100)
                p.fun_bonus = p.fun_bonus + g.fun + 3
                p.boredom = p.boredom + g.boredom
            else
                ready = false
            end
        end
        p.fun_bonus = p.fun_bonus + pacing.fun_all
        if pacing.repeat_type and score.taste(p, pacing.repeat_type) < 1 then
            p.boredom = p.boredom + 10
        end
        out[p.key] = ready and score.fun(p, mood) or nil
        p.m, p.boredom, p.fun_bonus = saved_m, saved_b, saved_f
    end
    return out
end

-- Why the forecast says what it says (A6): the reasons that move this player's night most,
-- strongest first, e.g. "Long talky scenes lose Dev, and stops 1 and 2 are social."
local function scene_list(idx)
    if #idx == 1 then
        return "stop " .. util.int(idx[1]) .. " is"
    end
    local parts = {}
    for k, i in ipairs(idx) do
        parts[k] = util.int(i)
    end
    return "stops " .. table.concat(parts, ", ", 1, #parts - 1) .. " and " .. parts[#parts] .. " are"
end

function M:forecast_reasons(key)
    local p = self.campaign:player(key)
    if not p then
        return {}
    end
    local out = {}
    local function add(w, text)
        table.insert(out, { w = w, text = text })
    end
    local by_type = {}
    for i, s in ipairs(self.scenes) do
        if s.type then
            by_type[s.type] = by_type[s.type] or {}
            table.insert(by_type[s.type], i)
        end
        for _, c in util.sorted_pairs(s.slots) do
            if c.thread == key then
                add(1.3, "Stop " .. util.int(i) .. " is about " .. p.char .. "'s past.")
            end
            for _, t in ipairs(c.tags or {}) do
                local v = score.like(p, t)
                if v <= -0.5 then
                    add(0.6 + -v * 0.3, p.name .. " isn't keen on " .. t .. " (" .. c.name .. ", stop " .. util.int(i) .. ").")
                elseif v >= 1 then
                    add(0.4 + v * 0.2, p.name .. " loves " .. t .. " (" .. c.name .. ", stop " .. util.int(i) .. ").")
                end
            end
        end
    end
    local types = {}
    for t in pairs(by_type) do
        table.insert(types, t)
    end
    table.sort(types)
    for _, t in ipairs(types) do
        local idx = by_type[t]
        local v = score.taste(p, t)
        local name = string.lower(content.scenes[t].name)
        if v <= 0.7 then
            add((1 - v) * #idx + 0.2, "Long " .. name .. " scenes lose " .. p.name .. ", and " .. scene_list(idx) .. " " .. name .. ".")
        elseif v >= 1.4 then
            add((v - 1) * #idx, p.name .. " loves " .. name .. " scenes, and " .. scene_list(idx) .. " " .. name .. ".")
        end
    end
    local pv = self:pacing_now()
    if pv.repeat_type and score.taste(p, pv.repeat_type) < 1 then
        add(1.1, "The same kind of scene over and over will drag for " .. p.name .. ".")
    end
    if p.mood_known and p.mood ~= "fine" then
        local m = score.mood(p)
        add(math.abs(m.fun or 0) / 4 + 0.3, p.name .. " is " .. string.lower(m.name) .. " this week.")
    end
    local n = self.talk_notes and self.talk_notes[key]
    if n and n.want_type and by_type[n.want_type] then
        add(1.5, "You're giving " .. p.name .. " what they asked for: " .. n.want .. ".")
    elseif n and n.want_type then
        add(0.8, p.name .. " asked for " .. n.want .. ", and there isn't one yet.")
    end
    table.sort(out, function(a, b) return a.w > b.w end)
    local texts = {}
    for i = 1, math.min(3, #out) do
        texts[i] = out[i].text
    end
    return texts
end

-- Bringing them in (the slice rework, S6) --------------------------------------------------
-- The DM's three questions at the start of prep pin cards into the hand: who this session is
-- for (their thread's next card), who shows up (people and places from the notebook, with
-- an agenda card that fits how they feel), and which faction's move happens on screen
-- (world.lua). Pins come first in their kind and show why they're there.

M.PAGE = 10   -- cards of a kind the prep board shows at once (two rows of five)

local function deck_mod()
    return require "game.model.deck"
end
local function ledger_mod()
    return require "game.model.ledger"
end

local function remove_from(list, id)
    for i = #list, 1, -1 do
        if list[i].id == id then
            table.remove(list, i)
        end
    end
end

-- A card that joined the deck mid-prep (a move the DM let happen) goes into the hand, after
-- the pins.
function M:take_new(c)
    local list = self.hand[c.kind]
    for _, h in ipairs(list) do
        if h.id == c.id then
            return
        end
    end
    local at = 1
    while list[at] and self.pins[list[at].id] do
        at = at + 1
    end
    table.insert(list, at, c)
    self:trim(c.kind)
end

function M:drop_from_hand(id)
    local c = content.components[id]
    if c then
        remove_from(self.hand[c.kind], id)
        if self:placed_at(id) then
            local i, kind = self:placed_at(id)
            self.scenes[i].slots[kind] = nil
        end
    end
end

-- Keep a kind to one page: the plainest cards drop back into the deck (never a pin, a story
-- card, a payoff, an inspired card or one on the board).
function M:trim(kind)
    local list = self.hand[kind]
    local i = #list
    while #list > M.PAGE and i >= 1 do
        local c = list[i]
        if not (self.pins[c.id] or self.arc_cards[c.id] or self.payoffs[c.id] or self.inspired[c.id] or self:placed_at(c.id)) then
            table.remove(list, i)
        end
        i = i - 1
    end
end

function M:pin(id, why, note, extra)
    local c = content.components[id]
    if not c then
        return false
    end
    local list = self.hand[c.kind]
    remove_from(list, id)
    local at = 1
    while list[at] and self.pins[list[at].id] do
        at = at + 1
    end
    table.insert(list, at, c)
    local p = { why = why, note = note }
    for k, v in pairs(extra or {}) do
        p[k] = v
    end
    self.pins[id] = p
    table.insert(self.pin_order, id)
    self:trim(c.kind)
    return true
end

-- Take a pin back out. A card that only came in for the pin leaves the hand (and an agenda
-- card leaves the deck); one that was in the deck anyway stays in the hand.
function M:unpin(id)
    local p = self.pins[id]
    if not p then
        return
    end
    self.pins[id] = nil
    for i = #self.pin_order, 1, -1 do
        if self.pin_order[i] == id then
            table.remove(self.pin_order, i)
        end
    end
    local c = content.components[id]
    if p.added or (c and c.agenda) then
        self:drop_from_hand(id)
        local d = deck_mod().get(self.campaign)
        if d.cards[id] and (d.cards[id].plays or 0) == 0 then
            d.cards[id] = nil
        end
    end
end

function M:pinned(id)
    return self.pins[id]
end

-- Who's this session for? The next open card of their backstory thread.
function M:spotlight_card(key)
    local deck = deck_mod()
    -- What you wrote in at Session Zero comes first, until it's played (playtest, October 13:
    -- "Next" showed the thread's first card, whatever you'd chosen to lead with).
    local bs = self.campaign.backstories and self.campaign.backstories[key]
    if bs and bs.hook and deck.available(self.campaign, bs.hook) then
        local e = deck.entry(self.campaign, bs.hook)
        if not (e and (e.plays or 0) > 0) then
            local c = content.components[bs.hook]
            if c then
                return c
            end
        end
    end
    for _, st in ipairs(deck.threads(self.campaign)[key] or {}) do
        if st.state == "open" and deck.available(self.campaign, st.card.id) then
            return st.card
        end
    end
    -- Every step played: a recurring thread card (a person, a place) can still come back.
    for _, st in ipairs(deck.threads(self.campaign)[key] or {}) do
        if deck.available(self.campaign, st.card.id) then
            return st.card
        end
    end
    return nil
end

function M:spotlight(key)
    local p = self.campaign:player(key)
    if not p or not p.present then
        return false, "They're not at the table this week."
    end
    if self.spot == key then
        return true
    end
    local c = self:spotlight_card(key)
    if not c then
        return false, "Nothing in " .. p.char .. "'s story is ready to come up this week."
    end
    self:clear_spotlight()
    if self.pins[c.id] then
        -- Already at the front of the hand (what you wrote in at Session Zero): keep that pin.
        self.pins[c.id].spot = key
    else
        self:pin(c.id, "spotlight", "Spotlight: " .. p.name, { key = key })
    end
    self.spot = key
    return true
end

function M:clear_spotlight()
    for id, pin in pairs(self.pins) do
        if pin.why == "spotlight" then
            self:unpin(id)
        else
            pin.spot = nil
        end
    end
    self.spot = nil
end

-- Who can be brought in this week: people the party has met who are still around and whose
-- card is in the deck, and places in the deck. { people = { pid... }, places = { card... } }
function M:guest_options()
    local deck = deck_mod()
    local ledger = ledger_mod()
    local out = { people = {}, places = {} }
    for _, pid in ipairs(ledger.people(self.campaign)) do
        local card = ledger.card_of(self.campaign, pid)
        if card and ledger.met(self.campaign, pid) and ledger.around(self.campaign, pid)
            and deck.available(self.campaign, card.id) and (not card.thread or self.campaign:player(card.thread).present) then
            table.insert(out.people, pid)
        end
    end
    for _, c in ipairs(deck.cards(self.campaign, "location")) do
        if not c.thread or self.campaign:player(c.thread).present then
            table.insert(out.places, c)
        end
    end
    return out
end

function M:guest_count()
    local n = 0
    for _ in pairs(self.guests) do
        n = n + 1
    end
    return n
end

-- Bring someone (a person id) or somewhere (a location id) in. Returns the cards it pinned.
function M:bring_in(id)
    local ledger = ledger_mod()
    local deck = deck_mod()
    if self.guests[id] then
        return true
    end
    if self:guest_count() >= ledger.data.GUESTS then
        return false, "Two guests a week. Send one home first."
    end
    local c = content.components[id]
    if c and c.kind == "location" then
        if not deck.available(self.campaign, id) then
            return false, "That place isn't in your deck."
        end
        self:pin(id, "guest", "You brought it in")
        self.guests[id] = { cards = { id } }
        return true, { c }
    end
    local card = ledger.card_of(self.campaign, id)
    if not card or not deck.available(self.campaign, card.id) or not ledger.around(self.campaign, id) then
        return false, "They can't come this week."
    end
    local att = ledger.att(self.campaign, id)
    local note = ledger.about(id).name .. ": " .. ledger.label(att)
    if ledger.status(self.campaign, id) == "got away" then
        note = ledger.about(id).name .. ": got away last time"
    end
    self:pin(card.id, "guest", note, { guest = id })
    local cards = { card }
    local agenda = ledger.agenda_card(self.campaign, id)
    if agenda then
        deck.add(self.campaign, agenda.id, self.campaign.week, card.id, "agenda")
        self:pin(agenda.id, "guest", note, { guest = id, added = true })
        table.insert(cards, agenda)
    end
    local ids = {}
    for _, x in ipairs(cards) do
        table.insert(ids, x.id)
    end
    self.guests[id] = { cards = ids }
    return true, cards
end

-- Someone's feelings changed while the DM was still prepping (the world turned): what they
-- bring this week changes with them. The old agenda card comes off (and off the board, if it was
-- placed); a new one comes in if they want something now.
function M:refresh_guest(pid)
    local g = self.guests and self.guests[pid]
    if not g then
        return
    end
    local ledger = ledger_mod()
    local old
    for _, cid in ipairs(g.cards) do
        local c = content.components[cid]
        if c and c.agenda == pid then
            old = c
        end
    end
    local want = ledger.agenda_kind(self.campaign, pid)
    if (old and old.agenda_kind) == want then
        return
    end
    if old then
        local i, kind = self:placed_at(old.id)
        if i then
            self:clear(i, kind)
        end
        self:unpin(old.id)
        for k = #g.cards, 1, -1 do
            if g.cards[k] == old.id then
                table.remove(g.cards, k)
            end
        end
    end
    local agenda = want and ledger.agenda_card(self.campaign, pid)
    if agenda then
        local person = ledger.card_of(self.campaign, pid)
        local note = ledger.about(pid).name .. ": " .. ledger.label(ledger.att(self.campaign, pid))
        deck_mod().add(self.campaign, agenda.id, self.campaign.week, person and person.id, "agenda")
        self:pin(agenda.id, "guest", note, { guest = pid, added = true })
        table.insert(g.cards, agenda.id)
    end
end

function M:send_home(id)
    local g = self.guests[id]
    if not g then
        return
    end
    for _, cid in ipairs(g.cards) do
        self:unpin(cid)
    end
    self.guests[id] = nil
end

-- Shelve a card from the hand (the notebook can bring it back).
function M:shelve(id)
    if self:placed_at(id) then
        return false, "Take it off the board first."
    end
    if self.pins[id] then
        return false, "You pinned that one this week."
    end
    local ok, why = deck_mod().shelve(self.campaign, id)
    if not ok then
        return false, why
    end
    self:drop_from_hand(id)
    return true
end

function M:unshelve(id)
    if deck_mod().unshelve(self.campaign, id) then
        local c = content.components[id]
        if c then
            self:take_new(c)
        end
        return true
    end
    return false
end

-- Cards from the hand that didn't make it onto the board.
function M:unused()
    local list = {}
    for _, kind in ipairs(content.kinds) do
        for _, c in ipairs(self.hand[kind]) do
            if not self:placed_at(c.id) then
                table.insert(list, c)
            end
        end
    end
    return list
end

return M
