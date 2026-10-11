-- Game night: the director. Plays the three prepped scenes as a stream of beats
-- for the table (scenery, minis, speech bubbles, dice), runs fights on the M3
-- rules engine, and pauses for the DM: decision cards of six kinds, improv hands,
-- big rolls in front of or behind the screen, and rulings on how they land. Pure Lua.
--
-- The screen calls night:advance(answer) and gets the next beat back. Every beat
-- carries t, its playing time in seconds at normal speed (game/model/pacing.lua).
--   scene      { index, total, title, type, type_name, terrain, party, npc, cast, goal, story }
--   narrate    { text, style }                            a caption (narration, goal, twist...)
--   npc        { name, text, cast, line }                 the DM voicing a character
--   say        { who, text, ic, line, part }              a speech bubble over a player (line: its id in
--                                                         the dialogue library; part "reply" for banter replies)
--   react      { poses = { key = pose } }                 players lean in, cheer, gasp...
--   check      { actor, char, skill, skill_name, roll, bonus, total, dc, success, crit, fumble, text }
--                the player rolls d20 + their modifier for the skill against the DC
--   clue       { text, id }                                  the party learns something (DM's notes)
--   battle     { phase = "start", party, foes, terrain, danger } / { phase = "end", winner }
--   round      { round }
--   turn       { who, side, steps = { move, attack, damage, down, ... }, say, brisk }
--   decision   { card = { id, type, type_name, title, text, options } }    answer = option index
--   improv     { prompt, cards, pick = { 1, 3 }, slot, drift }            answer = { indices } or index
--   roll_where { text, dc, actor, char, skill_name, mod, by }            answer = "open" | "hidden"
--                by = "player": the player rolls their own check; "open" says the DC out loud,
--                "hidden" keeps it behind the screen. by = "dm": a secret check the DM rolls for
--                them, in the open or behind the screen.
--   roll       { where, dc, actor, by }                                  answer = the d20 value
--   cook       { value, total, mod, dc, success, by }                    answer = true to cook it
--                (a player's roll: move the secret DC; the DM's own roll: misreport the die)
--   ruling     { tier, prompt, value, total, mod, dc, options }          answer = option index
--   done       {}
-- Unanswered questions (nil) take a sensible default, so a headless run never stalls.

local content = require "game.model.content"
local score = require "game.model.score"
local prep_mod = require "game.model.prep"
local util = require "game.model.util"
local talk_mod = require "game.model.talk"
local pacing = require "game.model.pacing"
local fight = require "game.model.fight"
local social = require "game.model.social"
local seeds = require "game.model.seeds"
local story = require "game.model.story"
local skills = require "game.rules.skills"

local M = {}
M.__index = M

local CHECKS_PER_SCENE = 4
local HAND_SIZE = 5
local LATE_AFTER = 11.5 * 60      -- seconds into the night before "It's getting late" can come up

-- "The old bridge" -> "the old bridge", but leave names like "Ilsa's ring" alone.
local function find_present(players, key)
    for _, p in ipairs(players) do
        if p.key == key then
            return p
        end
    end
end

local function soft_lower(text)
    for _, w in ipairs({ "A ", "An ", "The ", "Fresh " }) do
        if string.sub(text, 1, #w) == w then
            return string.lower(string.sub(text, 1, 1)) .. string.sub(text, 2)
        end
    end
    return text
end

-- Snapshot long-term bars so the report can show changes.
local function snapshot(players)
    local s = {}
    for _, p in ipairs(players) do
        s[p.key] = {}
        for _, k in ipairs(score.LONG) do
            s[p.key][k] = p[k]
        end
    end
    return s
end

function M.new(campaign, prep, opts)
    opts = opts or {}
    local self = setmetatable({}, M)
    self.campaign = campaign
    self.rng = campaign.rng
    self.prep = prep
    self.players = campaign:present()
    self.before = snapshot(campaign.players)
    self.highlights = {}
    self.canon = {}
    self.decisions = {}
    self.rulings = {}
    self.rolls = { open = 0, hidden = 0, cooked = 0 }
    self.callouts = 0
    self.cooks = 0
    self.used_cards = {}
    self.table_card_used = false
    self.drift_used = false
    self.checks = {}
    self.unused = prep:unused()
    self.improvised = {}
    self.talk = talk_mod.new(self.rng)
    self.talk:set_present(self.players)
    self.clock = 0
    self.counts = { decision = 0, improv = 0, ruling = 0 }
    self.fights = 0
    -- "Every roll in the open" at Session Zero covers the DM's own combat rolls too.
    local open_table = campaign.table and campaign.table.rules.dice == "open"
    self.dm_rolls = opts.dm_rolls or campaign.dm_rolls or (open_table and "open") or "hidden"
    self.hidden_dm_rolls, self.open_dm_rolls = 0, 0
    self.lucky_streak = 0
    -- M6: the table conflicts, Session Zero promises, seeds.
    self.conflict_moves = {}   -- { id, pressure, progress, resolve, promise, topic } from conflict cards
    self.rules_calls = {}      -- { card, leans, topic } for every rules card
    self.conflict_dealt = {}   -- conflict id -> true once its card came up tonight
    self.safety = {}           -- what happened with lines and veils tonight
    self.planted = prep.planted
    self.payoffs = {}          -- seeds paid off tonight
    self.promise_noted = {}
    for _, p in ipairs(self.players) do
        score.reset_session(p)
    end
    -- Build the scenes from the board.
    self.scenes = {}
    for i, s in ipairs(prep.scenes) do
        local comps = {}
        for k, c in pairs(s.slots) do
            comps[k] = c
        end
        local missing = {}
        for _, kind in ipairs(prep_mod.IMPROV_ORDER) do
            if not comps[kind] then
                table.insert(missing, kind)
            end
        end
        self.scenes[i] = {
            index = i,
            type = s.type,
            comps = comps,
            missing = missing,
            quality = prep_mod.quality(s.type, comps, prep.inspired),
            difficulty = prep_mod.difficulty(comps),
            encounter = s.encounter,   -- the fight the DM built in prep (combat and set pieces)
        }
    end
    self.pacing = prep_mod.pacing(prep.scenes, self.players)
    self.co = coroutine.create(function()
        self:run()
    end)
    return self
end

function M:advance(answer)
    if coroutine.status(self.co) == "dead" then
        return { kind = "done", t = 0 }
    end
    local ok, ev = coroutine.resume(self.co, answer)
    if not ok then
        error(ev)
    end
    return ev or { kind = "done", t = 0 }
end

-- The DM can flip where their own combat rolls land at any time.
function M:set_dm_rolls(mode)
    self.dm_rolls = (mode == "open") and "open" or "hidden"
    self.campaign.dm_rolls = self.dm_rolls
end

-- Every beat goes out through here: timed, counted, and yielded to the screen.
function M:emit(ev)
    ev.t = pacing.duration(ev)
    self.clock = self.clock + ev.t
    if pacing.DECISION_KINDS[ev.kind] then
        self.counts[ev.kind] = self.counts[ev.kind] + 1
    end
    if pacing.DECISION_KINDS[ev.kind] or ev.kind == "roll_where" then
        self.last_input = self.clock
    end
    return coroutine.yield(ev)
end

-- Seconds since the DM last had a choice to make.
function M:idle()
    return self.clock - (self.last_input or 0)
end

function M:decision_count()
    return self.counts.decision + self.counts.improv + self.counts.ruling
end

-- Room for one more optional call under this cap? Before the last scene, two calls are kept
-- back for it: a last scene with nothing for the DM to decide runs long.
function M:room(cap)
    local last = self.scenes[#self.scenes]
    local reserve = (last and self.scene ~= last) and 2 or 0
    return self:decision_count() < cap - reserve
end

-- Helpers ---------------------------------------------------------------------

function M:vars(extra)
    local v = {}
    if self.actor then
        v.actor, v.actor_char = self.actor.name, self.actor.char
    end
    if self.other then
        v.other, v.other_char, v.other_key = self.other.name, self.other.char, self.other.key
    end
    local low = self:lowest()
    if low then
        v.lowest, v.lowest_char = low.name, low.char
    end
    local sc = self.scene
    if sc then
        -- A card that was veiled or X-carded isn't named either.
        local function shown(c)
            return c and not self:muted(c) and c or nil
        end
        v.cast = shown(sc.comps.cast) and soft_lower(sc.comps.cast.name) or "the locals"
        v.Cast = util.capitalize(v.cast)
        v.location = shown(sc.comps.location) and soft_lower(sc.comps.location.name) or "this place"
        v.goal = shown(sc.comps.goal) and soft_lower(sc.comps.goal.name) or "what they came for"
        v.boss = sc.boss_name or "the villain"
    end
    for k, val in pairs(extra or {}) do
        v[k] = val
    end
    return v
end

-- Skill checks (real-session pass) ---------------------------------------------------------

-- A hero's modifier for a skill, from their character sheet at the party's level.
function M:mod_for(p, skill)
    local c = self.campaign
    local sub = c.subclasses and c.subclasses[p.class]
    return skills.mod(p.class, skill, c.level or 2, sub)
end

-- A hero's best skill from a list (or the one skill): skill, modifier.
function M:best_skill(p, list)
    if type(list) == "string" then
        return list, self:mod_for(p, list)
    end
    local best, bm
    for _, sk in ipairs(list or { "perception" }) do
        local m = self:mod_for(p, sk)
        if not bm or m > bm then
            best, bm = sk, m
        end
    end
    return best, bm
end

-- The location's settings, for "where" checks.
function M:location()
    local sc = self.scene
    return sc and sc.comps.location
end

-- A caption.
function M:say(text, style, extra)
    return self:emit({ kind = "narrate", text = util.fill(text, self:vars(extra)), style = style or "narration" })
end

-- A speech bubble from a player, picked from the table talk for this trigger.
function M:bark(p, trigger, extra)
    if not p then
        return
    end
    local v = self:vars(extra)
    local text, line = self.talk:line(trigger, p, v)
    if text then
        self:emit({ kind = "say", who = p.key, text = text, ic = talk_mod.in_character(trigger), line = line.id })
    end
    return text
end

-- The DM voicing the scene's cast.
function M:npc_line(what, extra)
    local sc = self.scene
    local cast = sc and sc.comps.cast
    if not cast then
        return
    end
    local text, line = self.talk:npc(cast.id, what, self:vars(extra))
    if text then
        self:emit({ kind = "npc", name = cast.name, cast = cast.id, text = text, line = line.id })
    end
end

function M:react(poses)
    if next(poses) then
        self:emit({ kind = "react", poses = poses })
    end
end

function M:lowest()
    local low
    for _, p in ipairs(self.players) do
        if not low or p.engagement < low.engagement then
            low = p
        end
    end
    return low
end

-- Pick a present player, preferring these archetypes (primary first).
function M:pick_actor(prefs, exclude)
    for _, pass in ipairs({ "primary", "secondary" }) do
        for _, a in ipairs(prefs or {}) do
            local found = {}
            for _, p in ipairs(self.players) do
                if p ~= exclude and p[pass] == a then
                    table.insert(found, p)
                end
            end
            if #found > 0 then
                return self.rng:pick(found)
            end
        end
    end
    local others = {}
    for _, p in ipairs(self.players) do
        if p ~= exclude then
            table.insert(others, p)
        end
    end
    if #others == 0 then
        return self.players[1]
    end
    return self.rng:pick(others)
end

function M:highlight(score_value, text, who)
    table.insert(self.highlights, { score = score_value, text = text })
    for _, p in ipairs(who or {}) do
        if not p.best or score_value > p.best.score then
            p.best = { score = score_value, text = text }
        end
    end
end

-- Targets for an effect selector, as { player, scale } pairs.
function M:targets(sel)
    local out = {}
    if sel == "all" then
        for _, p in ipairs(self.players) do
            table.insert(out, { p, 1 })
        end
    elseif sel == "actor" then
        if self.actor then
            table.insert(out, { self.actor, 1 })
        end
    elseif sel == "other" then
        if self.other then
            table.insert(out, { self.other, 1 })
        end
    elseif sel == "others" then
        for _, p in ipairs(self.players) do
            if p ~= self.actor then
                table.insert(out, { p, 1 })
            end
        end
    elseif sel == "lowest" then
        local low = self:lowest()
        if low then
            table.insert(out, { low, 1 })
        end
    elseif sel == "perceptive" then
        for _, p in ipairs(self.players) do
            table.insert(out, { p, p.perception })
        end
    elseif string.sub(sel, 1, 5) == "arch:" then
        local key = string.sub(sel, 6)
        for _, p in ipairs(self.players) do
            local w = score.arch(p, key)
            if w > 0 then
                table.insert(out, { p, w })
            end
        end
    end
    return out
end

-- Apply a list of effects and nudge engagement for everyone touched.
function M:apply(effects)
    local touched = {}
    for _, eff in ipairs(effects or {}) do
        for _, t in ipairs(self:targets(eff[1])) do
            local p, scale = t[1], t[2]
            local g = {}
            for k, v in pairs(eff) do
                if k ~= 1 then
                    score.add(p, k, v * scale)
                    g[k] = v * scale
                end
            end
            touched[p] = touched[p] or {}
            for k, v in pairs(g) do
                touched[p][k] = (touched[p][k] or 0) + v
            end
        end
    end
    for p, g in pairs(touched) do
        score.nudge_engagement(p, score.enjoyment(p, g) + 6)
    end
end

function M:apply_meters(sel, meters)
    local eff = { sel }
    for k, v in pairs(meters) do
        eff[k] = v
    end
    self:apply({ eff })
end

-- Where everyone's at: a pose for each player's mini-me at the table.
-- lean (into it), neutral, arms (crossed), yawn, phone.
function M:poses()
    local out = {}
    for _, p in ipairs(self.players) do
        local e = p.engagement
        local pose = "neutral"
        if e >= 0.68 then
            pose = "lean"
        elseif e < 0.2 then
            pose = "phone"
        elseif e < 0.3 then
            pose = "yawn"
        elseif e < 0.42 and score.fun(p) < 45 then
            pose = "arms"
        end
        out[p.key] = pose
    end
    return out
end

-- Live view for the screen: everyone's tell and rough Fun right now.
function M:tells()
    local out = {}
    local tells = content.chat.tells
    local poses = self:poses()
    for _, p in ipairs(self.players) do
        local text = tells[#tells].text
        for _, t in ipairs(tells) do
            if p.engagement >= t.at then
                text = t.text
                break
            end
        end
        local mood = score.mood(p)
        if mood.tell and p.engagement < 0.5 then
            text = mood.tell
        end
        out[p.key] = { text = text, engagement = p.engagement, fun = score.fun(p), pose = poses[p.key] }
    end
    return out
end

-- Scenes --------------------------------------------------------------------------

-- A scene is called by where it happens (the location is always settled before it starts).
function M:scene_title(sc)
    local loc = sc.comps.location
    if not loc then
        return content.scenes[sc.type].name
    end
    return util.capitalize(loc.name)
end

-- Does this card make sense where the scene is? (An improvised place at a stretch can leave
-- a floor to give way on a forest road; then it simply doesn't happen.)
function M:fits_here(c)
    local sc = self.scene
    return not c or c.kind == "location" or content.fits_setting(c, sc and sc.comps.location)
end

-- The story (real-session pass): describe a card on the scene, the way this week's story
-- tells it if it's one of the story cards, and note the clue it gives the party.
function M:describe(c, style)
    local sc = self.scene
    if not c or self:muted(c) or not self:fits_here(c) then
        return
    end
    local rev, clue = story.reveal(self.campaign, c)
    self:say(rev or content.line_for(c, sc and sc.comps.location), style or "narration")
    if rev then
        self.story_found = self.story_found or {}
        for _, f in ipairs(self.story_found) do
            if f.id == c.id then
                return
            end
        end
        if clue and not story.has_clue(self.campaign, c.id) then
            table.insert(self.story_found, { id = c.id, text = clue })
            self:emit({ kind = "clue", id = c.id, text = clue })
        end
    end
    if c.kind == "cast" then
        self.met = self.met or {}
        self.met[c.id] = rev and "revealed" or true
    end
end

function M:terrain_for(sc)
    local t = content.terrain
    local loc = sc.comps.location
    return (loc and t.by_location[loc.id]) or t.by_scene[sc.type] or "blank"
end

-- Where the party stands when a scene opens, and who the DM is voicing.
function M:staging(sc)
    local blocked, layout = fight.blocked_set(sc.terrain)
    local taken = {}
    local party = {}
    local spots = fight.squares_near(blocked, taken, layout.party[1], layout.party[2], #self.players, 1,
        content.terrain_layout.W, content.terrain_layout.H)
    for i, p in ipairs(self.players) do
        local sq = spots[i] or { 2, i + 3 }
        table.insert(party, { id = p.key, class = p.class, x = sq[1], y = sq[2] })
    end
    local npc
    local cast = sc.comps.cast
    if cast and not (sc.type == "combat" or sc.type == "set_piece") then
        local sq = fight.squares_near(blocked, taken, layout.npc[1], layout.npc[2], 1, 1,
            content.terrain_layout.W, content.terrain_layout.H)[1]
        if sq then
            npc = { id = "npc", cast = cast.id, name = cast.name, x = sq[1], y = sq[2] }
        end
    end
    return party, npc
end

-- Improv -------------------------------------------------------------------------------

local FIT_SCORE = { great = 2, good = 1, poor = -1 }

local function stock_cards(self, n, fit_fn)
    local stock = {}
    local loc = self:location()
    for _, s in ipairs(content.improv.stock) do
        if content.fits_setting(s, loc) then
            table.insert(stock, s)
        end
    end
    self.rng:shuffle(stock)
    local out = {}
    for i = 1, math.min(n, #stock) do
        local s = stock[i]
        table.insert(out, { stock = s, name = s.name, kind_name = "Stock move", fit = fit_fn and fit_fn(s.tags) or "good" })
    end
    return out
end

-- Score a combination of 1 to 3 cards: the best card counts fully, the others half;
-- a card that doesn't fit always hurts. Returns "great", "good" or "poor".
function M.combo_fit(cards)
    if #cards == 0 then
        return "poor", -1
    end
    local scores = {}
    for _, c in ipairs(cards) do
        table.insert(scores, FIT_SCORE[c.fit] or 0)
    end
    table.sort(scores, function(a, b) return a > b end)
    local total = scores[1]
    for i = 2, #scores do
        total = total + (scores[i] > 0 and scores[i] * 0.5 or scores[i])
    end
    if total >= 2.5 then
        return "great", total
    elseif total >= 1 then
        return "good", total
    end
    return "poor", total
end

local function picks_from(answer, cards)
    local picks = {}
    local seen = {}
    if type(answer) == "number" then
        answer = { answer }
    end
    if type(answer) == "table" then
        for _, i in ipairs(answer) do
            i = math.floor(tonumber(i) or 0)
            if cards[i] and not seen[i] and #picks < 3 then
                seen[i] = true
                table.insert(picks, cards[i])
            end
        end
    end
    if #picks == 0 then
        -- Nothing picked before the timer ran out: the best single card in the hand.
        local best, bs = cards[1], -9
        for _, c in ipairs(cards) do
            if (FIT_SCORE[c.fit] or 0) > bs then
                best, bs = c, FIT_SCORE[c.fit] or 0
            end
        end
        picks = { best }
    end
    return picks
end

function M:improv_cards(kind)
    local sc = self.scene
    local cards = {}
    local pool = {}
    -- Only what could happen here: a location has to suit what's already on the scene,
    -- anything else has to suit the location.
    local function fits(c)
        if c.kind == "location" then
            return content.setting_clash(c, sc.comps) == nil
        end
        return content.fits_setting(c, sc.comps.location)
    end
    for _, c in ipairs(self.unused) do
        if c.kind == kind and not self.improvised[c.id] and fits(c) then
            table.insert(pool, c)
        end
    end
    for _, id in ipairs(self.campaign.improv_deck) do
        local c = content.components[id]
        if c and c.kind == kind and not self.improvised[c.id] and fits(c) then
            if not util.contains(pool, c) then
                table.insert(pool, c)
            end
        end
    end
    self.rng:shuffle(pool)
    for i = 1, math.min(2, #pool) do
        local c = pool[i]
        local fit = util.contains(c.fits, sc.type) and "great" or "poor"
        local flag = social.content_flags(self.campaign, { c })[1]
        local warn
        if flag and find_present(self.players, flag.key) then
            local who = find_present(self.players, flag.key).name
            warn = flag.kind == "line" and (who .. "'s line") or (flag.kind == "veil" and (who .. "'s veil") or (who .. " asked"))
        end
        table.insert(cards, { comp = c, name = c.name, kind_name = content.kind_names[c.kind], fit = fit,
                              payoff = c.payoff_of ~= nil, warn = warn })
    end
    -- A recurring face or place from the improv deck can join the mix.
    local extra = {}
    for _, id in ipairs(self.campaign.improv_deck) do
        local c = content.components[id]
        if c and (c.kind == "cast" or c.kind == "location") and c.kind ~= kind and not self.improvised[c.id]
            and not sc.comps[c.kind] and fits(c) then
            table.insert(extra, c)
        end
    end
    if #extra > 0 then
        local c = self.rng:pick(extra)
        local fit = util.contains(c.fits, sc.type) and "good" or "poor"
        table.insert(cards, { comp = c, name = c.name, kind_name = content.kind_names[c.kind], fit = fit, extra = true })
    end
    if kind == "location" then
        -- Somewhere to be, nothing else: stock moves don't say where the scene is. Three places
        -- to pick from: the ones in hand first, then any place that suits the scene and isn't on
        -- tonight's board.
        local only = {}
        local have = {}
        for _, card in ipairs(cards) do
            if card.comp and card.comp.kind == "location" and not have[card.comp.id] then
                have[card.comp.id] = true
                table.insert(only, card)
            end
        end
        if #only < 3 then
            local board = {}
            for _, other in ipairs(self.scenes) do
                if other.comps.location then
                    board[other.comps.location.id] = true
                end
            end
            local extra_locs = {}
            for _, c in ipairs(content.by_kind.location) do
                if not board[c.id] and not have[c.id] and not self.improvised[c.id] and fits(c) then
                    table.insert(extra_locs, c)
                end
            end
            self.rng:shuffle(extra_locs)
            for i = 1, math.min(3 - #only, #extra_locs) do
                local c = extra_locs[i]
                table.insert(only, { comp = c, name = c.name, kind_name = content.kind_names[c.kind],
                                     fit = util.contains(c.fits, sc.type) and "good" or "poor" })
            end
        end
        if #only < 3 then
            -- What's on the scene already doesn't sit well anywhere: any place will do, at a stretch.
            local rest = {}
            for _, c in ipairs(content.by_kind.location) do
                if not have[c.id] and not self.improvised[c.id] then
                    local used = false
                    for _, o in ipairs(only) do
                        used = used or o.comp == c
                    end
                    if not used then
                        table.insert(rest, c)
                    end
                end
            end
            self.rng:shuffle(rest)
            for i = 1, math.min(3 - #only, #rest) do
                local c = rest[i]
                table.insert(only, { comp = c, name = c.name, kind_name = content.kind_names[c.kind], fit = "poor" })
            end
        end
        return only
    end
    for _, s in ipairs(stock_cards(self, HAND_SIZE - #cards)) do
        table.insert(cards, s)
    end
    return cards
end

-- Play the picked cards: fill the slot, add stock moves, write canon.
function M:play_improv(picks, kind, replace)
    local sc = self.scene
    -- One card per kind: a second goal on top of the first makes no sense.
    local seen, kept = {}, {}
    for _, card in ipairs(picks) do
        local k = card.comp and card.comp.kind or (card.quantum and "quantum") or (card.stock and card.stock.id)
        if not seen[k] then
            seen[k] = true
            table.insert(kept, card)
        end
    end
    picks = kept
    local fit = M.combo_fit(picks)
    local moved = false
    for _, card in ipairs(picks) do
        if card.comp then
            local ck = card.comp.kind
            self.improvised[card.comp.id] = true
            if ck == "cast" or ck == "location" then
                table.insert(self.canon, card.comp.name)
            end
            self:say("You improvise: " .. card.comp.name .. ".", "dm")
            -- Mid-scene cards get the same Session Zero care as prepped ones.
            local mid = replace or not (sc and ck == kind)
            if sc and mid then
                self:safety_check(sc, { card.comp })
            end
            local function describe()
                self:describe(card.comp, "narration")
            end
            if sc and (ck == kind or replace) and (ck == kind or ck == "location" or ck == "cast") then
                sc.comps[ck] = card.comp
                if ck == "location" then
                    moved = true
                end
                -- The scene narrates its own slots once it's set up; mid-scene, say it now.
                if replace then
                    describe()
                end
            elseif sc and not sc.comps[ck] and (ck == "cast" or ck == "location") then
                sc.comps[ck] = card.comp
                moved = moved or ck == "location"
                describe()
            else
                describe()
            end
        elseif card.quantum then
            self.quantum = (self.quantum or 0) + 1
            self:say(card.line, "narration")
        else
            self:apply_meters("all", card.stock.meters)
            self:say(card.stock.line, "narration")
        end
    end
    if moved and sc and not self.pre_scene then
        self:restage(sc)
    end
    return fit
end

-- The scenery changes mid-scene (an improvised location, or they wandered off).
function M:restage(sc)
    local t = self:terrain_for(sc)
    if t == sc.terrain then
        return
    end
    sc.terrain = t
    local party, npc = self:staging(sc)
    self:emit({ kind = "stage", terrain = t, party = party, npc = npc, title = self:scene_title(sc) })
end

function M:improvise(kind)
    local sc = self.scene
    local cards = self:improv_cards(kind)
    local prompt = util.fill(content.improv.sketched[kind], self:vars())
    local answer = self:emit({ kind = "improv", prompt = prompt, cards = cards, slot = content.kind_names[kind],
                               pick = { 1, 3 } })
    local picks = picks_from(answer, cards)
    local fit = self:play_improv(picks, kind)
    if fit == "great" then
        sc.quality = sc.quality + 0.06
    elseif fit == "good" then
        sc.quality = sc.quality + 0.03
    end
    local critic
    local poses = {}
    if fit == "poor" then
        critic = self:pick_actor({ "storyteller", "tactician" })
        self:apply({ { "arch:storyteller", fun = -3 }, { "arch:tactician", fun = -2 } })
        poses[critic.key] = "arms"
    else
        local fan = self:pick_actor({ "storyteller", "method_actor", "explorer" })
        poses[fan.key] = "lean"
    end
    self:say(content.improv.outcomes[fit], fit == "poor" and "warn" or "dm", { critic = critic and critic.name or "Someone" })
    self:react(poses)
    if fit == "great" or (fit == "poor" and critic) then
        self:bark(critic or self:pick_actor({ "storyteller", "method_actor" }), fit == "great" and "improv_great" or "improv_poor")
    end
    self.improv_count = (self.improv_count or 0) + 1
end

-- The party goes off-script.
function M:drift()
    self.drift_used = true
    self.actor = self:pick_actor({ "instigator", "explorer", "method_actor" })
    self.other = nil
    local prompt = util.fill(self.rng:pick(content.improv.drift), self:vars())
    local actor = self.actor
    local function fit_for(tags)
        local best = 0
        for _, t in ipairs(tags) do
            best = best + score.like(actor, t)
        end
        if best >= 1 then
            return "great"
        elseif best < 0 then
            return "poor"
        end
        return "good"
    end
    local pool = {}
    local loc = self:location()
    for _, c in ipairs(self.unused) do
        if (c.kind == "location" or (c.kind == "cast" and content.fits_setting(c, loc))) and not self.improvised[c.id] then
            table.insert(pool, c)
        end
    end
    self.rng:shuffle(pool)
    local cards = {}
    for i = 1, math.min(2, #pool) do
        local c = pool[i]
        table.insert(cards, { comp = c, name = c.name, kind_name = content.kind_names[c.kind], fit = fit_for(c.tags) })
    end
    -- The quantum ogre: move an unused fight onto their new path.
    for _, c in ipairs(self.unused) do
        if c.kind == "cast" and content.encounters.by_cast[c.id] and not self.improvised[c.id] then
            table.insert(cards, { quantum = true, comp_id = c.id, name = "Quantum ogre: " .. c.name, kind_name = "Unused encounter",
                                  fit = "good", line = "Wherever they go, " .. soft_lower(c.name) .. " turns out to be there too." })
            break
        end
    end
    for _, s in ipairs(stock_cards(self, HAND_SIZE - #cards, fit_for)) do
        table.insert(cards, s)
    end
    self:say(prompt, "twist")
    self:react({ [actor.key] = "lean" })
    local answer = self:emit({ kind = "improv", prompt = "They're off your map. Where does it lead?", cards = cards,
                               drift = true, pick = { 1, 3 } })
    local picks = picks_from(answer, cards)
    local fit = self:play_improv(picks, nil, true)
    local used_quantum = false
    for _, c in ipairs(picks) do
        if c.quantum then
            used_quantum = true
            self.improvised[c.comp_id] = true
            -- The prepped fight moves onto their new path.
            if self.scene then
                self.scene.comps.cast = content.components[c.comp_id]
            end
        end
    end
    if used_quantum then
        -- Cheap and often invisible. Explorers notice when their choices stop mattering.
        self:apply({ { "arch:explorer", trust = -3 * (self.campaign.quantum_ogres or 0) - 1 } })
        self.campaign.quantum_ogres = (self.campaign.quantum_ogres or 0) + 1
    end
    if fit == "poor" then
        self:apply({ { "actor", spotlight = 6, fun = -2 }, { "all", story = 2 } })
        self:say(util.fill(content.improv.outcomes.poor, { critic = actor.name }), "warn")
    else
        self:apply({ { "actor", spotlight = 10, fun = fit == "great" and 6 or 3 }, { "arch:explorer", story = 4 },
                     { "arch:instigator", fun = 3 }, { "all", story = 2 } })
        self:say(content.improv.outcomes[fit], "dm")
        self:highlight(fit == "great" and 7 or 4, actor.char .. " drags everyone off the map", { actor })
        self:bark(actor, "improv_great")
    end
    self.improv_count = (self.improv_count or 0) + 1
end

-- Quick checks: fast rolls that stream into the dice strip, moving the scene's
-- progress track toward its big moment ----------------------------------------------------------

-- A hero in character, talking to another (the scene's little back-and-forths).
function M:banter()
    local l, p = self.talk:banter(self.players)
    if not l then
        return
    end
    local q
    for _, x in ipairs(self.players) do
        if x.key == l.to then
            q = x
        end
    end
    local v = self:vars({ char = p.char, name = p.name })
    self:emit({ kind = "say", who = p.key, text = util.fill(l.text, v), ic = true, line = l.id })
    self:emit({ kind = "say", who = q.key, text = util.fill(l.reply, self:vars({ char = q.char, name = q.name })), ic = true,
                line = l.id, part = "reply" })
    score.add(p, "social", 3)
    score.add(q, "social", 3)
end

-- Actions the hero could take here: the scene type's list, minus what doesn't fit the
-- location, needs a cast that isn't there, or was already done this scene.
function M:actions_for(sc, used)
    local list = content.actions[sc.type] or {}
    local loc = sc.comps.location
    local cast = sc.comps.cast and not self:muted(sc.comps.cast)
    local out = {}
    for i, a in ipairs(list) do
        if not used[i] and content.fits_setting(a, loc) and (not a.cast or cast) and (not a.other or #self.players > 1) then
            table.insert(out, { i = i, a = a })
        end
    end
    if #out == 0 then
        -- Everything's been tried: let the table repeat the ones that fit.
        for i, a in ipairs(list) do
            if content.fits_setting(a, loc) and (not a.cast or cast) and (not a.other or #self.players > 1) then
                table.insert(out, { i = i, a = a })
            end
        end
    end
    return out
end

-- One hero's go: they say what they try, the DM calls the check, they roll, the DM says how it lands.
function M:hero_action(sc, used, dc, need, spots)
    local st = content.scenes[sc.type]
    -- Players who shine here act more; quiet players get a turn too.
    local weights = {}
    for j, p in ipairs(self.players) do
        local shine = st.shine[p.class] or 0
        weights[j] = 1 + 2 * shine + math.max(0, (40 - p.m.spotlight) / 20)
    end
    local p = self.rng:weighted(self.players, weights)
    self.actor = p
    self.other = self:pick_actor(nil, p)
    -- What they'd try: whatever they're good at, mostly.
    local options = self:actions_for(sc, used)
    local aw = {}
    for k, o in ipairs(options) do
        local m = self:mod_for(p, o.a.skill)
        aw[k] = 2 ^ (util.clamp(m, -2, 8) / 2)
    end
    local pick = self.rng:weighted(options, aw)
    local a = pick and pick.a
    if not a then
        return nil
    end
    used[pick.i] = true
    local vars = self:vars({ char = p.char, other_char = self.other and self.other.char or "" })
    -- The player says it, in character.
    self:emit({ kind = "say", who = p.key, text = util.capitalize(util.fill(a.say, vars)), ic = true })
    local mod = self:mod_for(p, a.skill)
    local roll = self.rng:d20()
    local total = roll + mod
    local success = total >= dc
    local name = skills.name(a.skill)
    local result
    if roll == 20 then
        result = "natural 20"
    elseif roll == 1 then
        result = "natural 1"
    else
        result = success and "success" or "miss"
    end
    local text = p.char .. ": " .. name .. " " .. util.int(roll) .. skills.signed(mod) .. " = " .. util.int(total)
        .. " vs DC " .. util.int(dc) .. ", " .. result
    table.insert(self.checks, success)
    if success then
        local big = roll == 20
        sc.progress.wins = sc.progress.wins + (big and 2 or 1)
        score.add(p, "spotlight", big and 10 or 5)
        score.add(p, "fun", big and 4 or 1)
        if big then
            self:highlight(8, p.char .. " rolls a natural 20 on " .. name, { p })
        end
    else
        sc.progress.setbacks = sc.progress.setbacks + 1
        score.add(p, "spotlight", 1)
        for _, q in ipairs(self.players) do
            score.add(q, "story", 1)
        end
        if roll == 1 then
            self:highlight(3, p.char .. " rolls a 1 at the worst possible moment", { p })
        end
    end
    score.nudge_engagement(p, success and 14 or 6)
    local spot = #spots > 0 and self.rng:pick(spots) or nil
    self:emit({ kind = "check", text = text, roll = roll, bonus = mod, total = total, dc = dc, success = success,
                actor = p.key, char = p.char, skill = a.skill, skill_name = name, crit = roll == 20,
                fumble = roll == 1, spot = spot,
                progress = { wins = math.min(sc.progress.wins, need), setbacks = sc.progress.setbacks, need = need,
                             max = content.scene_beats.setbacks } })
    -- How it lands in the story, then at the table.
    self:say(util.capitalize(util.fill(success and a.win or a.lose, vars)), success and "good" or "bad")
    if roll == 20 then
        local poses = { [p.key] = "cheer" }
        for _, q in ipairs(self.players) do
            if q ~= p then
                poses[q.key] = "lean"
            end
        end
        self:react(poses)
        self:bark(p, "crit")
    elseif roll == 1 then
        self:react({ [p.key] = "gasp" })
        self:bark(p, "fumble")
    elseif self.rng:chance(0.22) then
        self:bark(p, success and "check_win" or "check_lose")
    elseif self.rng:chance(0.22) and #self.players > 1 then
        local q = self:pick_actor(nil, p)
        self:bark(q, success and "cheer_other" or "groan_other", { other = p.name, other_char = p.char, other_key = p.key })
    end
    if sc.comps.cast and not self:muted(sc.comps.cast) and self.rng:chance(0.25) then
        self:npc_line(success and "good" or "bad")
    end
    return success
end

-- The heroes work the scene: one check at a time, each moving its progress track toward the
-- big moment (or a setback away from it).
function M:quick_checks(sc)
    local beats = content.scene_beats
    local need = beats.track[sc.type] or 3
    local comp = sc.comps.complication
    if comp and comp.difficulty > 0 then
        need = need + 1
    end
    local max_checks = sc.cut and 2 or (need + 3)
    local dc = (content.actions.DC[util.clamp(sc.difficulty, 1, 3)] or 12) + ((comp and comp.difficulty > 0) and 1 or 0)
    sc.dc = dc
    local layout = content.terrain_layout.sets[sc.terrain] or content.terrain_layout.sets.blank
    local spots = layout.spots or {}
    sc.progress = { wins = 0, setbacks = 0, need = need }
    local used = {}
    local i = 0
    while i < max_checks and sc.progress.wins < need and sc.progress.setbacks < beats.setbacks do
        i = i + 1
        -- In a social scene with someone to talk to, the cast speaks up first now and then.
        if i == 1 and sc.comps.cast and not self:muted(sc.comps.cast)
            and (sc.type == "social" or sc.type == "mystery" or sc.type == "downtime") then
            self:npc_line("greet")
        end
        if self:hero_action(sc, used, dc, need, spots) == nil then
            break
        end
        if i == 1 and comp and not comp.cliffhanger and not self:muted(comp) and self:fits_here(comp) then
            self:say(content.line_for(comp, sc.comps.location), "twist")
        elseif i == 2 then
            self:banter()
            if not sc.cut and not self.end_early then
                self:moment(sc)
            end
        elseif i == 4 then
            self:scene_card(sc)
            if self.rng:chance(0.6) then
                self:banter()
            end
        end
        self:table_life()
    end
    self:scene_card(sc)
    -- The track sets up the big moment: ahead makes it easier, behind makes it harder.
    sc.edge = (sc.progress.wins >= need) and -2 or ((sc.progress.setbacks >= beats.setbacks) and 2 or 0)
    if sc.edge < 0 then
        self:say("They've done the groundwork. The big moment is within reach.", "good")
    elseif sc.edge > 0 then
        self:say("Too many setbacks. The big moment will be hard now.", "bad")
    end
end

-- Little things that happen around the table between beats: snacks, phones, yawns.
function M:table_life()
    if not self.rng:chance(0.3) then
        return
    end
    local low = self:lowest()
    if low and low.engagement < 0.25 and self.rng:chance(0.6) then
        self:react({ [low.key] = "phone" })
        self:bark(low, "phone")
    elseif low and low.engagement < 0.38 and self.rng:chance(0.5) then
        self:bark(low, "bored")
    else
        local p = self.rng:pick(self.players)
        self:bark(p, "snack")
    end
end

function M:pick_decision(sc, kinds)
    local eligible, weights = {}, {}
    local last = self.campaign.last_cards or {}
    for _, d in ipairs(content.decisions) do
        if not d.table_only and not self.used_cards[d.id] and (d.scenes == nil or util.contains(d.scenes, sc.type))
            and (not kinds or kinds[d.type]) and content.fits_setting(d, sc.comps.location)
            and (not d.actor_class or self:by_class(d.actor_class)) then
            local w = last[d.id] and 0.3 or 1
            -- Prefer cards whose actor is actually at the table.
            for _, a in ipairs(d.actor or {}) do
                for _, p in ipairs(self.players) do
                    if p.primary == a then
                        w = w + 0.5
                    end
                end
            end
            table.insert(eligible, d)
            table.insert(weights, w)
        end
    end
    if #eligible == 0 then
        return nil
    end
    return self.rng:weighted(eligible, weights)
end

-- Big rolls and rulings -----------------------------------------------------------------------

-- How a check landed: a natural 20 or beating the DC by 5 is a triumph, a natural 1 or
-- missing by 5 a flop.
local function tier_of(total, dc, natural)
    if natural == 20 or total >= dc + 5 then
        return "triumph"
    elseif total >= dc then
        return "success"
    elseif natural == 1 or total <= dc - 5 then
        return "flop"
    end
    return "near"
end

-- Big rolls are checks the table stops for. Raw DCs in the card data are on the old d20-only
-- scale; a hero adds their modifier now, so the DC the DM sets is this much higher.
M.DC_SHIFT = 4

-- A big moment's check. Normally the hero's player rolls it themselves, in front of everyone:
-- the DM decides whether to say the DC out loud or keep it behind the screen, where it could
-- quietly move after the die lands (that's cooking it). spec.secret: a secret check the DM
-- rolls for them behind the screen (a Perception check they mustn't know about); then the DM
-- rolls it in the open or hidden, and a hidden die can be misread.
function M:big_roll(spec, record)
    local p = self.actor or self:pick_actor(nil)
    self.actor = p
    local skill, mod = self:best_skill(p, spec.skill or { "perception" })
    local dc = spec.dc + M.DC_SHIFT
    local by = spec.secret and "dm" or "player"
    local name = skills.name(skill)
    local text
    if by == "player" then
        text = util.fill("{actor_char} rolls " .. name .. " (" .. skills.signed(mod) .. "). You'd set the DC at {dc}.",
            self:vars({ dc = util.int(dc) }))
    else
        text = util.fill("A secret " .. name .. " check for {actor_char} (" .. skills.signed(mod) .. "), DC {dc}. You roll it for them.",
            self:vars({ dc = util.int(dc) }))
    end
    local where = self:emit({ kind = "roll_where", dc = dc, text = text, actor = p and p.key, char = p and p.char,
                              skill = skill, skill_name = name, mod = mod, by = by })
    if where ~= "hidden" then
        where = "open"
    end
    if where == "open" and self.rng:chance(0.35) then
        self:bark(self:pick_actor(nil), "open_roll")
    end
    local value = self:emit({ kind = "roll", where = where, dc = dc, actor = p and p.key, by = by,
                              skill_name = name, mod = mod })
    value = util.clamp(math.floor(tonumber(value) or self.rng:d20()), 1, 20)
    local total = value + mod
    local success = total >= dc
    local reported, shown_dc = value, dc
    local cooked = false
    if where == "hidden" then
        self.rolls.hidden = self.rolls.hidden + 1
        local cook = self:emit({ kind = "cook", value = value, total = total, mod = mod, dc = dc, success = success,
                                 by = by, char = p and p.char, skill_name = name })
        if cook then
            cooked = true
            success = not success
            if by == "player" then
                -- Everyone saw the die. What moves is the DC nobody heard.
                if success then
                    shown_dc = math.max(1, total - self.rng:int(0, 2))
                else
                    shown_dc = total + self.rng:int(1, 3)
                end
            else
                if success then
                    reported = util.clamp(dc - mod + self.rng:int(0, 3), 1, 20)
                else
                    reported = util.clamp(dc - mod - self.rng:int(1, 4), 1, 20)
                end
            end
        end
    else
        self.rolls.open = self.rolls.open + 1
        -- Doing it in the open builds Trust, less so when the table expects nothing else.
        local dice = self.campaign.table and self.campaign.table.rules.dice
        local gain = dice == "open" and 0.5 or 1
        for _, q in ipairs(self.players) do
            score.add(q, "trust", (1 + q.perception) * gain)
            score.add(q, "suspicion", -3)
        end
    end
    if where == "hidden" and self.campaign.table and self.campaign.table.rules.dice == "open" then
        -- Session Zero said everything happens in the open.
        for _, q in ipairs(self.players) do
            score.add(q, "trust", -1.5)
            score.add(q, "suspicion", 2 * q.perception)
        end
        if not self.promise_noted.dice then
            self.promise_noted.dice = true
            self:say("A few eyebrows go up. You agreed everything would happen in the open.", "warn")
        end
    end
    if cooked then
        self.rolls.cooked = self.rolls.cooked + 1
        self.cooks = self.cooks + 1
        local convenient = (success and spec.convenient == "success") or (not success and spec.convenient == "fail")
        self:add_cook_suspicion(convenient)
    end
    -- A third lucky break in a row looks convenient even when it's honest.
    if success and where == "hidden" then
        self.lucky_streak = self.lucky_streak + 1
        if self.lucky_streak >= 3 then
            for _, q in ipairs(self.players) do
                score.add(q, "suspicion", 2 * q.perception)
            end
        end
    elseif not success then
        self.lucky_streak = 0
    end
    local reported_total = reported + mod
    local line
    if by == "player" then
        line = (p and p.char or "They") .. " rolls a " .. util.int(value) .. ", " .. skills.signed(mod) .. ": "
            .. util.int(reported_total) .. ". " .. (where == "open" and ("You said DC " .. util.int(shown_dc) .. ".")
            or ("Behind the screen, the DC was " .. util.int(shown_dc) .. "."))
    else
        line = (where == "open" and "Everyone watches the die land on " or "Behind the screen, the die says ")
            .. util.int(reported) .. ": " .. util.int(reported_total) .. " against DC " .. util.int(dc) .. "."
    end
    self:say(line, "dice")
    -- The ruling: the die sets the tier, the DM decides how generous to be.
    local tier = tier_of(reported_total, shown_dc, reported)
    if cooked then
        -- A cooked result lands on the side the DM chose, however the numbers fall.
        if success and (tier == "near" or tier == "flop") then
            tier = "success"
        elseif not success and (tier == "success" or tier == "triumph") then
            tier = "near"
        end
    end
    local rule = content.rulings[tier]
    local opts = {}
    for i, o in ipairs(rule.options) do
        opts[i] = { label = o.label, tone = o.tone }
    end
    local pick = self:emit({ kind = "ruling", tier = tier, prompt = rule.prompt, value = reported, total = reported_total,
                             mod = mod, dc = shown_dc, options = opts, where = where, by = by,
                             char = p and p.char, skill_name = name, actor = p and p.key })
    pick = util.clamp(math.floor(tonumber(pick) or 1), 1, #rule.options)
    local ro = rule.options[pick]
    table.insert(self.rulings, { tier = tier, option = pick })
    if ro.success ~= nil and ro.success ~= success then
        -- "Yes, at a cost" on a near miss: the success branch plays.
        success = ro.success
    end
    local branch = success and spec.success or spec.fail
    self:say(branch.log, success and "good" or "bad")
    self:apply(branch.effects)
    self:apply(ro.effects)
    if ro.tone == "good" then
        self:react({ [self.actor and self.actor.key or self.players[1].key] = "cheer" })
        self:bark(self.actor, "ruling_good")
    elseif ro.tone == "bad" then
        local poses = {}
        for _, q in ipairs(self.players) do
            poses[q.key] = "gasp"
        end
        self:react(poses)
        self:bark(self:pick_actor({ "butt_kicker", "instigator" }), "ruling_bad")
    elseif ro.tone == "twist" then
        self:say(ro.log, "twist")
    end
    if success and self.actor then
        local first = string.match(util.fill(branch.log, self:vars()), "^(.-)[%.!?]") or branch.log
        self:highlight(6, first, { self.actor })
    end
    local rec = record or (self.decisions[#self.decisions] and self.decisions[#self.decisions].rolls)
    if rec then
        table.insert(rec, { where = where, value = value, cooked = cooked, success = success, tier = tier, ruling = pick,
                            skill = skill, mod = mod, dc = shown_dc, by = by })
    end
    if cooked then
        self:maybe_callout(0.35)
    end
    return success
end

function M:add_cook_suspicion(convenient)
    for _, p in ipairs(self.players) do
        local s = 8 * p.perception * (convenient and 1.6 or 1) * (1 + 0.3 * (self.cooks - 1))
        score.add(p, "suspicion", s)
    end
    -- The sharpest eye at the table might say it under their breath.
    local sharp
    for _, p in ipairs(self.players) do
        if not sharp or p.perception > sharp.perception then
            sharp = p
        end
    end
    if sharp and sharp.suspicion > 30 and self.rng:chance(0.5) then
        self:react({ [sharp.key] = "arms" })
        self:bark(sharp, "suspicious")
    end
end

-- Someone suspicious enough says it out loud.
function M:maybe_callout(base)
    local worst
    for _, p in ipairs(self.players) do
        if not worst or p.suspicion > worst.suspicion then
            worst = p
        end
    end
    if not worst or worst.suspicion < 45 then
        return
    end
    local chance = base + (worst.suspicion - 45) / 50
    if not self.rng:chance(chance) then
        return
    end
    self.callouts = self.callouts + 1
    self:react({ [worst.key] = "arms" })
    if not self:bark(worst, "callout") then
        self:emit({ kind = "say", who = worst.key, text = "Hang on. Can we see that roll?", ic = false })
    end
    self:say("The table goes quiet. A few people look at your screen.", "warn")
    score.add(worst, "trust", -15)
    score.add(worst, "fun", -6)
    worst.suspicion = worst.suspicion * 0.5
    for _, p in ipairs(self.players) do
        if p ~= worst then
            score.add(p, "trust", -5)
        end
    end
    score.nudge_engagement(worst, -10)
end

-- Decision cards ---------------------------------------------------------------------------

-- Who at the table would enjoy these effects, and who wouldn't: { key = 1 | -1 }, the DM's
-- read of the table (strong feelings only).
function M:leans(effects)
    local gain = {}
    for _, eff in ipairs(effects or {}) do
        for _, t in ipairs(self:targets(eff[1])) do
            local p, scale = t[1], t[2]
            local g = gain[p] or {}
            for k, v in pairs(eff) do
                if k ~= 1 then
                    g[k] = (g[k] or 0) + v * scale
                end
            end
            gain[p] = g
        end
    end
    local out = {}
    for p, g in pairs(gain) do
        local e = score.enjoyment(p, g)
        if e >= 4 then
            out[p.key] = 1
        elseif e <= -3 then
            out[p.key] = -1
        end
    end
    return out
end

-- The present player whose character has this class, if any.
function M:by_class(cls)
    for _, p in ipairs(self.players) do
        if p.class == cls then
            return p
        end
    end
end

-- Show a card, take the DM's pick, play it out. Returns the chosen option.
function M:decision(card, extra)
    self.used_cards[card.id] = true
    if card.actor_class and self:by_class(card.actor_class) then
        self.actor = self:by_class(card.actor_class)
        self.other = card.other and self:pick_actor(card.other, self.actor) or nil
    elseif not self.actor or not card.trigger then
        self.actor = self:pick_actor(card.actor)
        self.other = card.other and self:pick_actor(card.other, self.actor) or nil
    end
    local vars = self:vars(extra)
    local view = {
        id = card.id,
        type = card.type,
        type_name = content.decision_types[card.type],
        title = util.fill(card.title, vars),
        text = util.fill(card.text, vars),
        options = {},
    }
    for i, o in ipairs(card.options) do
        view.options[i] = { label = util.fill(o.label, vars), roll = o.roll ~= nil, cooked = o.cooked,
                            skill = o.roll and o.roll.skill and skills.name(select(1, self:best_skill(self.actor or self.players[1], o.roll.skill))),
                            leans = self:leans(o.effects) }
    end
    if card.type == "rules" and self.rng:chance(0.7) then
        self:bark(self:pick_actor({ "tactician", "power_gamer" }), "rules_lawyer")
    end
    local pick = self:emit({ kind = "decision", card = view, actor = self.actor and self.actor.key })
    pick = util.clamp(math.floor(tonumber(pick) or 1), 1, #card.options)
    local o = card.options[pick]
    table.insert(self.decisions, { card = card.id, option = pick, rolls = {} })
    if o.log then
        self:say(o.log, "dm", extra)
    end
    if o.canon then
        table.insert(self.canon, util.fill(o.canon, self:vars(extra)))
    end
    if o.spotlight_lowest then
        local low = self:lowest()
        if low then
            if low.shy then
                score.add(low, "fun", -5)
                if not self:bark(low, "spotlight_shy") then
                    self:emit({ kind = "say", who = low.key, text = "Uh. I guess " .. low.char .. "... waves?", ic = false })
                end
            else
                score.add(low, "fun", 8)
                self:react({ [low.key] = "lean" })
                self:highlight(5, low.char .. " steals the scene", { low })
            end
        end
    end
    self:apply(o.effects)
    if o.cooked then
        -- Overruling a hidden die is cooking it.
        self.rolls.cooked = self.rolls.cooked + 1
        self.cooks = self.cooks + 1
        self:add_cook_suspicion(o.convenient)
        self:maybe_callout(0.3)
    end
    if o.cut and self.scene then
        self.scene.cut = true
        self:keep_promise("no_cut")
    end
    if o.cooked and (card.id == "death_roll" or card.id == "last_save") then
        self:keep_promise("open_death", self.actor)
        local tbl = self.campaign.table
        if tbl and tbl.rules.dice == "big_open" then
            -- You said the big moments happen in the open.
            for _, p in ipairs(self.players) do
                score.add(p, "trust", -2 * p.perception)
            end
        end
    end
    if card.conflict and o.conflict then
        local mv = { id = card.conflict }
        for k, v in pairs(o.conflict) do
            mv[k] = v
        end
        mv.topic = extra and extra.topic
        table.insert(self.conflict_moves, mv)
    end
    if card.type == "rules" and o.leans then
        table.insert(self.rules_calls, { card = card.id, leans = o.leans, looked = o.looked,
                                         topic = content.conflicts.rules_topics[card.id] })
    end
    if o.cliffhanger then
        self.end_early = true
    end
    if o.roll then
        self:big_roll(o.roll)
    end
    if card.type == "rules" then
        self:conflict_rules(card)
    end
    return o
end

-- Session Zero promises (M6) ------------------------------------------------------------------

-- The DM just did something a player asked them not to at Session Zero.
function M:keep_promise(id, who)
    local tbl = self.campaign.table
    local key = tbl and tbl.promises[id]
    if not key then
        return
    end
    local p
    for _, q in ipairs(self.players) do
        if q.key == key then
            p = q
        end
    end
    if not p or (who and who ~= p) then
        return
    end
    if id == "open_death" then
        score.add(p, "trust", -8)
        score.add(p, "suspicion", 10)
        self:react({ [p.key] = "arms" })
        self:say(p.name .. " noticed. At Session Zero he asked you never to save him behind the screen.", "warn")
    elseif id == "no_cut" then
        score.add(p, "trust", -4)
        score.add(p, "fun", -3)
        self:react({ [p.key] = "arms" })
        self:say(p.name .. "'s face falls. You promised not to cut her scenes short.", "warn")
    end
    table.insert(self.safety, { kind = "promise", id = id, key = p.key })
end

-- Lines and veils: a card on the table touches something a player raised at Session Zero.
-- Runs before any of the scene's cards are described (and again for anything improvised
-- mid-scene). A veiled card plays off screen and an X-carded one is skipped: either way its
-- description is muted. cards: the cards to check (default: the whole scene).
function M:safety_check(sc, cards)
    local tbl = self.campaign.table
    if not tbl or not sc then
        return
    end
    if not cards then
        cards = {}
        for _, kind in ipairs(content.kinds) do
            if sc.comps[kind] then
                table.insert(cards, sc.comps[kind])
            end
        end
    end
    sc.muted = sc.muted or {}
    sc.safety_done = sc.safety_done or {}
    local xcard = tbl.rules.xcard == "on"
    for _, f in ipairs(social.content_flags(self.campaign, cards)) do
        local p
        for _, q in ipairs(self.players) do
            if q.key == f.key then
                p = q
            end
        end
        if p then
            local done = sc.safety_done[f.tag]
            local outcome
            if f.kind == "veil" then
                outcome = "veil"
            elseif xcard then
                outcome = "xcard"
            else
                outcome = "hurt"
            end
            if outcome ~= "hurt" then
                sc.muted[f.card.id] = true
            end
            if not done then
                sc.safety_done[f.tag] = outcome
                local what = f.tag == "kids" and "the kids" or f.tag
                if outcome == "veil" then
                    -- Agreed at Session Zero: it happens off screen.
                    self:say("You keep " .. what .. " off screen, like you promised " .. p.name .. ".", "dm")
                    score.add(p, "trust", 1)
                    table.insert(self.safety, { kind = "veil", key = p.key, tag = f.tag })
                elseif outcome == "xcard" then
                    self:react({ [p.key] = "arms" })
                    self:say(p.name .. " taps the X-card. You skip it, no questions asked, and the scene moves on.", "system")
                    score.add(p, "fun", -2)
                    score.add(p, "trust", f.kind == "line" and -3 or 1)
                    table.insert(self.safety, { kind = "xcard", key = p.key, tag = f.tag, broke = f.kind == "line" })
                else
                    self:react({ [p.key] = "arms" })
                    if f.kind == "line" then
                        self:say(p.name .. " goes quiet. She drew a line at this at Session Zero.", "warn")
                        score.add(p, "trust", -10)
                        score.add(p, "commitment", -3)
                    else
                        self:say(p.name .. " goes quiet. They asked you about this at Session Zero.", "warn")
                        score.add(p, "trust", -4)
                        score.add(p, "commitment", -2)
                    end
                    score.add(p, "fun", -8)
                    score.add(p, "boredom", 6)
                    table.insert(self.safety, { kind = "hurt", key = p.key, tag = f.tag, broke = f.kind == "line" })
                end
            end
        end
    end
end

-- Is this card's description skipped tonight (veiled or X-carded)?
function M:muted(c)
    local sc = self.scene
    return c ~= nil and sc ~= nil and sc.muted ~= nil and sc.muted[c.id] == true
end

-- Table conflicts at the table (M6) -------------------------------------------------------

local function find(players, key)
    for _, p in ipairs(players) do
        if p.key == key then
            return p
        end
    end
end

local function live(self, id)
    local c = self.campaign.conflicts and self.campaign.conflicts[id]
    return c and social.is_live(c) and not self.conflict_dealt[id] and c
end

-- Pip fills a scene: the spotlight conflict's card.
function M:conflict_spotlight(sc)
    local c = live(self, "spotlight")
    local jess = find(self.players, "jess")
    if not c or not jess or #self.players < 3 or not self:room(13) then
        return
    end
    if not self.rng:chance(c.state == "active" and 0.9 or 0.65) then
        return
    end
    self.conflict_dealt.spotlight = true
    self.actor, self.other = jess, nil
    self:decision(content.triggered.conflict_spotlight)
end

-- A joke lands in Mara's serious moment: the tone conflict's card.
function M:conflict_tone(sc)
    local c = live(self, "tone")
    local mara, jess = find(self.players, "mara"), find(self.players, "jess")
    if not c or not mara or not jess or not self:room(13) then
        return
    end
    if not self.rng:chance(c.state == "active" and 0.95 or 0.8) then
        return
    end
    self.conflict_dealt.tone = true
    self.actor, self.other = mara, jess
    self:decision(content.triggered.conflict_tone)
end

-- After a rules call: Dev and Sam start arguing about it.
function M:conflict_rules(card)
    local c = live(self, "rules")
    local dev, sam = find(self.players, "dev"), find(self.players, "sam")
    if not c or not dev or not sam or not self:room(13) then
        return
    end
    if not self.rng:chance(c.state == "active" and 0.85 or 0.5) then
        return
    end
    self.conflict_dealt.rules = true
    local topic = content.conflicts.rules_topics[card.id] or "the rules"
    self.actor, self.other = dev, sam
    self:decision(content.triggered.conflict_rules, { topic = topic })
end

-- Seeds (M6) -----------------------------------------------------------------------------------

function M:plant_seed()
    local def = self.planted and content.seeds[self.planted]
    if not def then
        return
    end
    self:say(def.plant, "seed")
    local poses = {}
    local fans = {}
    for _, p in ipairs(self.players) do
        if seeds.is_fan(p, def) then
            poses[p.key] = "lean"
            table.insert(fans, p)
            score.add(p, "story", 3)
        end
    end
    self:react(poses)
    if #fans > 0 then
        self:bark(self.rng:pick(fans), "seed_planted", { seed = def.theory })
    end
end

-- This week's story cards (M7): the arc moves when one hits the table.
function M:story_beat(sc)
    local arc_cards = self.prep and self.prep.arc_cards
    if not arc_cards then
        return
    end
    self.story_hits = self.story_hits or {}
    for _, kind in ipairs(content.kinds) do
        local c = sc.comps[kind]
        if c and arc_cards[c.id] and not self:muted(c) and not util.contains(self.story_hits, c.id) then
            table.insert(self.story_hits, c.id)
            if #self.story_hits == 1 then
                -- The first one each night: the people who came for the story notice.
                local fans = {}
                for _, p in ipairs(self.players) do
                    if score.arch(p, "storyteller") + score.arch(p, "explorer") > 0 then
                        score.add(p, "investment", content.arc.STORY_INVESTMENT)
                        score.add(p, "story", 4)
                        table.insert(fans, p)
                    end
                end
                self:highlight(5, "The story moves: " .. c.name, fans)
            end
        end
    end
end

function M:pay_off(c)
    local s = seeds.pay_off(self.campaign, c)
    if not s then
        return
    end
    local def = content.seeds[s.id]
    table.insert(self.payoffs, s.id)
    local weeks = self.campaign.week - s.week
    self:say("The seed from " .. (weeks == 1 and "last week" or (util.int(weeks) .. " weeks ago")) .. " pays off: "
        .. string.lower(string.sub(def.name, 1, 1)) .. string.sub(def.name, 2) .. ".", "thread")
    local poses, fans = {}, {}
    for _, p in ipairs(self.players) do
        local fan = seeds.is_fan(p, def)
        poses[p.key] = fan and "cheer" or "lean"
        score.add(p, "story", fan and 10 or 6)
        score.add(p, "fun", fan and 4 or 2)
        score.add(p, "investment", (fan and 3 or 1) + (s.hype or 0))
        if fan then
            table.insert(fans, p)
        end
    end
    self:react(poses)
    local who = self.rng:pick(fans) or self.rng:pick(self.players)
    self:bark(who, "seed_payoff", { seed = def.theory })
    self:highlight(9, def.name .. " paid off", fans)
    table.insert(self.canon, def.name .. " paid off")
end

function M:table_check(sc)
    if self.table_card_used or not self:room(14) then
        return
    end
    local low = self:lowest()
    if not low then
        return
    end
    local by_id = {}
    for _, d in ipairs(content.decisions) do
        if d.table_only then
            by_id[d.id] = d
        end
    end
    local card
    if low.engagement < 0.22 then
        card = by_id.phone              -- someone has checked out
    elseif low.engagement < 0.4 then
        card = by_id.voices             -- two people are running the show
    elseif sc and sc.index == 1 and self.rng:chance(0.45) then
        card = by_id.pizza              -- real life knocks on the door
    end
    if not card then
        return
    end
    self.table_card_used = true
    self.actor = nil
    self:decision(card)
end

-- Fights ---------------------------------------------------------------------------------

-- Hand the turn's collected engine events to the table as one beat.
function M:flush_turn()
    local steps = self.turn_steps
    if not steps or #steps == 0 then
        return steps
    end
    self.turn_steps = {}
    local who = self.turn_who
    local ev = { kind = "turn", steps = steps, who = who and who.mini, side = who and who.side }
    -- Once the DM has been watching a while, the table plays the fight briskly (and after a
    -- long while, faster still: everyone knows their turn by now).
    if self:idle() > 100 then
        ev.brisk = "very"
    elseif self:idle() > 60 then
        ev.brisk = true
    end
    -- Now and then a player says something about their turn: what they're about to
    -- do, or how it went (a hit, a whiff, a big number, a spell).
    if who and who.pc and self.rng:chance(ev.brisk and 0.12 or 0.22) then
        local p
        for _, q in ipairs(self.players) do
            if q.key == who.player_key then
                p = q
            end
        end
        local trigger, at, target = self:turn_trigger(steps, who)
        if p and trigger then
            local text, line = self.talk:line(trigger, p, self:vars({ target = target }))
            if text then
                ev.say = { who = p.key, text = text, ic = talk_mod.in_character(trigger), line = line.id, at = at }
            end
        end
    end
    self:emit(ev)
    return steps
end

-- Which line fits a hero's turn: "turn" (said as it starts) or how it went
-- (said once it's done). Crits and takedowns get their own reactions instead.
function M:turn_trigger(steps, who)
    local hits, misses, damage, spell, heal, target_id = 0, 0, 0, nil, false, nil
    for _, s in ipairs(steps) do
        if s.kind == "attack" and s.id == who.mini then
            if s.crit then
                return nil
            end
            target_id = target_id or s.target
            if s.hit then
                hits = hits + 1
            else
                misses = misses + 1
            end
        elseif s.kind == "damage" and s.id ~= who.mini then
            damage = damage + (s.amount or 0)
        elseif s.kind == "death" then
            return nil
        elseif s.kind == "spell" and s.id == who.mini then
            spell = true
        elseif s.kind == "heal" and s.by == who.mini then
            heal = true
        end
    end
    local target
    if type(target_id) == "string" and self.battle then
        for _, c in ipairs(self.battle.creatures) do
            if c.mini == target_id then
                target = c.name
            end
        end
    end
    if heal then
        return "heal_cast", "end", target
    elseif spell and self.rng:chance(0.6) then
        return "spell", "start", target
    elseif damage >= 12 then
        return "big_hit", "end", target
    elseif hits > 0 then
        return "hit", "end", target
    elseif misses > 0 then
        return "miss", "end", target
    end
    return "turn", "start", target
end

function M:combat_scene(sc)
    fight.party(self)
    if #self.pc_list == 0 then
        return
    end
    local plan = fight.plan(self, sc)
    sc.boss_name = plan.boss_name
    sc.plan = plan
    -- A card for this fight: a rules question waits for round two, anything else comes first.
    local card = self:pick_decision(sc)
    if card and card.type == "rules" then
        sc.rules_card = card
    elseif card then
        self:decision(card)
    end
    -- Who sees whom first: a paused roll before the fight.
    sc.surprise = nil
    if (self.rng:chance(0.55) or self:idle() > 50) and self:decision_count() < 13 then
        self:scout(sc)
    end
    self:say(self.talk:fight("start", self:vars()), "dm")
    local boss_fan = self:pick_actor({ "butt_kicker", "tactician", "storyteller" })
    self:bark(boss_fan, "boss_appears")
    if sc.comps.cast and content.encounters.by_cast[sc.comps.cast.id] then
        self:npc_line("taunt")
    end
    local result = fight.run(self, sc, plan)
    sc.result = result
    if result.winner == "party" then
        self:say(self.talk:fight("party_win", self:vars()), "good")
        local poses = {}
        for _, p in ipairs(self.players) do
            poses[p.key] = "cheer"
        end
        self:react(poses)
        self:bark(self:pick_actor({ "butt_kicker", "casual", "tactician" }), "victory")
        for _, p in ipairs(self.players) do
            score.add(p, "challenge", 6)
            score.add(p, "fun", 2)
        end
    else
        self:say(self.talk:fight("party_lose", self:vars()), "bad")
        self:say("They wake up later, bruised, robbed and very much alive. The story goes on.", "narration")
        local poses = {}
        for _, p in ipairs(self.players) do
            poses[p.key] = "gasp"
            score.add(p, "challenge", 10)
            score.add(p, "fun", -4)
        end
        self:react(poses)
        self:bark(self:pick_actor(nil), "defeat")
    end
    -- Tactical fun: close fights thrill Tacticians, stomps bore them.
    local downs = result.pc_downs or 0
    if downs == 0 and (result.rounds or 0) <= 2 then
        self:apply({ { "arch:tactician", fun = -3, challenge = -4 } })
    elseif downs >= 1 and result.winner == "party" then
        self:apply({ { "arch:tactician", fun = 4 }, { "arch:butt_kicker", fun = 3 } })
        self:highlight(6, "a fight that came down to the wire", self.players)
    end
    fight.short_rest(self)
end

-- Before a fight: someone scouts ahead (or tries to talk first). The result sets who's surprised.
local SCOUT = {
    rogue = "{actor_char} creeps ahead to scout.",
    fighter = "{actor_char} stands watch at the front.",
    wizard = "{actor_char} sends a light ahead to check the way.",
    cleric = "{actor_char} listens hard for trouble.",
}

function M:scout(sc)
    local best, bw
    for _, p in ipairs(self.players) do
        local w = (p.class == "rogue" and 2 or 0) + score.arch(p, "explorer") + score.arch(p, "tactician") + self.rng:next()
        if not bw or w > bw then
            best, bw = p, w
        end
    end
    self.actor = best
    self.other = nil
    self:say(SCOUT[best.class] or SCOUT.rogue, "goal")
    self:react({ [best.key] = "lean" })
    local spec = { dc = 12 + (sc.difficulty - 2), convenient = "success", skill = { "stealth", "perception" },
                   success = { log = "They spot the enemy first. Weapons out, quietly.",
                               effects = { { "actor", spotlight = 8 }, { "arch:tactician", fun = 4 } } },
                   fail = { log = "A twig snaps. Every head turns their way.",
                            effects = { { "all", challenge = 6 }, { "arch:butt_kicker", fun = 2 } } } }
    table.insert(self.decisions, { card = "scout", option = 0, rolls = {} })
    local ok = self:big_roll(spec)
    sc.surprise = ok and "foes" or "party"
end

-- The scene's decision card (once per scene), dealt partway through the checks.
function M:scene_card(sc)
    if sc.card_done then
        return
    end
    sc.card_done = true
    local card = self:pick_decision(sc)
    if card then
        self:decision(card)
        local rec = self.decisions[#self.decisions]
        if rec and #rec.rolls > 0 then
            sc.had_roll = true
        end
    end
end

-- A short back-and-forth with the scene's cast, the DM doing the voice.
function M:conversation(sc)
    if not sc.comps.cast then
        return
    end
    local talkers = {}
    for _, p in ipairs(self.players) do
        local w = score.arch(p, "method_actor") * 2 + score.arch(p, "storyteller") + score.arch(p, "casual") * 0.5
            + self.rng:next()
        table.insert(talkers, { p, w })
    end
    table.sort(talkers, function(a, b) return a[2] > b[2] end)
    for i = 1, math.min(2, #talkers) do
        local p = talkers[i][1]
        self.actor = p
        self:bark(p, "npc_talk")
        self:npc_line(self.rng:chance(0.6) and "good" or "greet")
        score.add(p, "social", 4)
        score.add(p, "spotlight", 2)
    end
end

-- Halfway through a scene: one moment worth a paused roll, and the DM's ruling on it.
function M:moment(sc)
    local beats = content.scene_beats.moment
    local comp = sc.comps.complication
    local m = (comp and not comp.cliffhanger and not self:muted(comp) and self:fits_here(comp) and beats.complication)
        or beats[sc.type]
    if not m or not self:room(12) then
        return
    end
    local skill = (m == beats.complication and comp and comp.skill) or m.skill
    -- Whoever's had the least of the spotlight, and is any good at this.
    local best, bw
    for _, p in ipairs(self.players) do
        local _, mod = self:best_skill(p, skill)
        local w = (60 - p.m.spotlight) / 30 + self.rng:next() * 1.5 + mod / 4
        if not bw or w > bw then
            best, bw = p, w
        end
    end
    self.actor = best
    self.other = nil
    local extra = { complication = comp and soft_lower(comp.name) or "" }
    self:say(m.text, "goal", extra)
    self:react({ [best.key] = "lean" })
    table.insert(self.decisions, { card = "moment_" .. sc.type, option = 0, rolls = {} })
    local ok = self:big_roll({ dc = m.dc + (sc.difficulty - 2), convenient = "success", success = m.success, fail = m.fail,
                               skill = skill })
    if ok then
        sc.progress.wins = sc.progress.wins + 1
    else
        sc.progress.setbacks = sc.progress.setbacks + 1
    end
end

-- A non-combat scene's big moment: one paused roll, then the DM's ruling.
function M:climax(sc)
    local st = content.scenes[sc.type]
    local cl = st.climax
    if not cl or sc.cut or sc.had_roll then
        return
    end
    -- The same big moment, told the way it fits this place (and whether anyone's there to talk to).
    local loc = sc.comps.location
    local has_cast = sc.comps.cast and not self:muted(sc.comps.cast)
    local function ok(v)
        return content.fits_setting(v, loc) and (not v.cast or has_cast)
    end
    if not ok(cl) then
        for _, v in ipairs(cl.variants or {}) do
            if ok(v) then
                cl = { text = v.text, dc = cl.dc, prefer = cl.prefer, skill = v.skill or cl.skill,
                       success = cl.success, fail = cl.fail }
                break
            end
        end
    end
    -- Whoever this scene is made for steps up (and is good at what it asks).
    local best, bw
    for _, p in ipairs(self.players) do
        local _, mod = self:best_skill(p, cl.skill)
        local w = (util.contains(cl.prefer or {}, p.class) and 2 or 0) + (60 - p.m.spotlight) / 30 + self.rng:next()
            + mod / 4
        if not bw or w > bw then
            best, bw = p, w
        end
    end
    self.actor = best
    self.other = nil
    self:say(cl.text, "goal")
    self:react({ [best.key] = "lean" })
    local spec = { dc = cl.dc + (sc.difficulty - 2) + (sc.edge or 0), convenient = "success", success = cl.success,
                   fail = cl.fail, skill = cl.skill }
    table.insert(self.decisions, { card = "climax_" .. sc.type, option = 0, rolls = {} })
    self:big_roll(spec)
end

function M:play_scene(sc)
    self.scene = sc
    self.actor, self.other = nil, nil
    -- Nobody wrote down where this happens: the DM makes it up before anyone asks. That's
    -- the scene's one improvised slot; anything else left empty just plays thinner.
    local improvised_first = false
    if not sc.comps.location then
        self.pre_scene = true
        self:improvise("location")
        self.pre_scene = false
        improvised_first = true
        for k, kind in ipairs(sc.missing) do
            if kind == "location" then
                table.remove(sc.missing, k)
                break
            end
        end
    end
    sc.terrain = self:terrain_for(sc)
    sc.title = self:scene_title(sc)
    local party, npc = self:staging(sc)
    local cast = sc.comps.cast
    local goal = sc.comps.goal
    local is_story = false
    for _, kind in ipairs(content.kinds) do
        local c = sc.comps[kind]
        if c and self.prep.arc_cards and self.prep.arc_cards[c.id] then
            is_story = true
        end
    end
    self:emit({ kind = "scene", index = sc.index, total = #self.scenes, title = sc.title, type = sc.type,
                type_name = content.scenes[sc.type].name, terrain = sc.terrain, party = party, npc = npc,
                cast = cast and cast.name, goal = goal and goal.name, story = is_story })
    if improvised_first then
        sc.quality = sc.quality - 0.03 * #sc.missing
    elseif #sc.missing > 0 then
        self:improvise(sc.missing[1])
        sc.quality = sc.quality - 0.03 * (#sc.missing - 1)
    end
    self:safety_check(sc)
    self:describe(sc.comps.location, "narration")
    if sc.comps.cast and not self:muted(sc.comps.cast) then
        self:describe(sc.comps.cast, "narration")
        if not (sc.type == "combat" or sc.type == "set_piece") then
            self:npc_line("greet")
        end
    end
    self:describe(sc.comps.goal, "goal")
    if sc.index == 1 then
        self:plant_seed()
    end
    for _, kind in ipairs(content.kinds) do
        local c = sc.comps[kind]
        if c and c.payoff_of and kind ~= "reward" then
            self:pay_off(c)
        end
    end
    self:story_beat(sc)
    -- Backstory threads in this scene.
    local announced = {}
    for _, kind in ipairs(content.kinds) do
        local c = sc.comps[kind]
        if c and c.thread then
            for _, p in ipairs(self.players) do
                if p.key == c.thread then
                    p.thread_hits = p.thread_hits + 1
                    if not announced[p.key] then
                        announced[p.key] = true
                        self:react({ [p.key] = "lean" })
                        self:say(p.name .. " sits up. This is about " .. p.char .. "'s past.", "thread")
                        self:bark(p, "thread")
                        self:highlight(7, p.char .. "'s backstory finally comes up", { p })
                        if p.key == "mara" then
                            self:conflict_tone(sc)
                        end
                    end
                end
            end
        end
    end
    -- What the scene gives everyone, and who's into it.
    local fans, grumps = {}, {}
    for _, p in ipairs(self.players) do
        local g = score.scene_gains(p, sc, score.mood(p))
        for _, k in ipairs(score.METERS) do
            score.add(p, k, g[k])
        end
        p.fun_bonus = p.fun_bonus + g.fun
        score.add(p, "boredom", g.boredom)
        score.nudge_engagement(p, score.enjoyment(p, g))
        local taste = score.taste(p, sc.type)
        if taste >= 1.3 then
            table.insert(fans, p)
        elseif taste <= 0.7 then
            table.insert(grumps, p)
        end
    end
    local poses = {}
    for _, p in ipairs(fans) do
        poses[p.key] = "lean"
    end
    self:react(poses)
    if #fans > 0 then
        self:bark(self.rng:pick(fans), "scene_like")
    end
    if #grumps > 0 and self.rng:chance(0.6) then
        self:bark(self.rng:pick(grumps), "scene_dislike")
    end
    if not self.drift_used and sc.index >= 2 and self:room(12) then
        local pull = 0.2
        for _, p in ipairs(self.players) do
            pull = pull + 0.1 * (score.arch(p, "instigator") + score.arch(p, "explorer"))
        end
        if self.rng:chance(pull) then
            self:drift()
        end
    end
    if sc.type == "combat" or sc.type == "set_piece" then
        self:combat_scene(sc)
    else
        self:conversation(sc)
        self:conflict_spotlight(sc)
        self:quick_checks(sc)
        if not self.end_early then
            self:climax(sc)
        end
    end
    if sc.comps.reward and not self.end_early then
        local r = sc.comps.reward
        if not self:muted(r) then
            local rev = story.reveal(self.campaign, r)
            if rev then
                self:describe(r, "reward")
            else
                self:say("They earn " .. soft_lower(r.line), "reward")
            end
        end
        if r.payoff_of then
            self:pay_off(r)
        end
        local fans2 = {}
        local rposes = {}
        for _, p in ipairs(self.players) do
            local like = 0
            for _, t in ipairs(r.tags) do
                like = like + score.like(p, t)
            end
            if like >= 1.2 or r.thread == p.key then
                table.insert(fans2, p)
                score.add(p, "fun", 3)
                rposes[p.key] = "cheer"
            end
        end
        self:react(rposes)
        if #fans2 > 0 then
            self:bark(self.rng:pick(fans2), "reward_like")
        end
    end
    -- A cliffhanger is the last thing that happens in its scene.
    if sc.comps.complication and sc.comps.complication.cliffhanger and not self:muted(sc.comps.complication) then
        self:describe(sc.comps.complication, "twist")
        self.ended_on_cliff = sc.index == #self.scenes
    end
    if sc.index < #self.scenes then
        self:table_check(sc)
        -- Between scenes the table chats while you reset the terrain.
        local p = self.rng:pick(self.players)
        self:bark(p, "between")
    end
    self:maybe_callout(0)
end

function M:intro()
    local who = {}
    for _, p in ipairs(self.players) do
        table.insert(who, p)
    end
    self.rng:shuffle(who)
    for i = 1, math.min(2, #who) do
        self:bark(who[i], "arrive")
    end
    self:say("Everyone's here. Dice out.", "system")
    -- The DM's opening: last time, then where tonight starts.
    local recap = story.recap(self.campaign)
    if recap then
        self:say(recap, "recap")
    end
    local beat = self.campaign:arc_beat()
    if beat and beat.open then
        local open = beat.open
        if beat.open_if and story.has_clue(self.campaign, beat.open_if.clue) then
            open = beat.open_if.text
        end
        self:say(open, "opening")
    end
end

function M:run()
    self:intro()
    for i, sc in ipairs(self.scenes) do
        if self.end_early then
            break
        end
        -- The escape valve: running long before the last scene.
        if i == #self.scenes and i > 1 and self.clock > LATE_AFTER and not self.used_cards.running_late
            and self:decision_count() < 14 then
            self.actor = nil
            self:decision(content.triggered.late)
            if self.end_early then
                local prev = self.scenes[i - 1]
                prev.ended_on_cliffhanger = true
                self.ended_on_cliff = true
                break
            end
        end
        self:play_scene(sc)
    end
    -- How the shape of the night landed.
    local pv = self.pacing
    for _, p in ipairs(self.players) do
        p.fun_bonus = p.fun_bonus + pv.fun_all
        if pv.repeat_type and score.taste(p, pv.repeat_type) < 1 then
            score.add(p, "boredom", 10)
        end
    end
    local played = {}
    for _, sc in ipairs(self.scenes) do
        if sc.terrain then
            table.insert(played, sc)
        end
    end
    local last = played[#played]
    if self.end_early then
        self:say("Groans all round. Nobody wants to wait a whole week.", "good")
    elseif last and last.comps.complication and last.comps.complication.cliffhanger then
        self:say("Groans all round. Nobody wants to wait a whole week.", "good")
    elseif pv.finish_high then
        self:say("It ends on a high. Somebody actually applauds.", "good")
    elseif pv.flat then
        self:say("The night never quite catches fire.", "warn")
    end
    -- A couple of goodbyes, not a speech from everyone.
    local leaving = {}
    for _, p in ipairs(self.players) do
        table.insert(leaving, p)
    end
    self.rng:shuffle(leaving)
    for i = 1, math.min(2, #leaving) do
        self:bark(leaving[i], "wrap")
    end
    self:say("That's a wrap. Chairs scrape, someone stacks the dice.", "system")
    self:emit({ kind = "done" })
end

return M
