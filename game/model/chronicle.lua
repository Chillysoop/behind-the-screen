-- The Story log (October 13): every storyline told the way it happened, scene by scene, so the
-- DM can see the whole of a story at a glance while they prep the next part of it. Each played
-- scene is filed after the night: where it was, what kind of scene, how it went, the cards on
-- it and what the table heard about each, what the heroes did there (the notebook's ledger),
-- and what it opened for the weeks ahead. A storyline's log is then its premise (a hero's
-- backstory, or the story's own hook), one bullet per scene that moved it, this week's board
-- and tonight's scenes as they play, the leads waiting in the deck, and who and where it
-- involves. Names in it are keywords: the Story log view lights them up and explains them on
-- hover (game/ui/story_log_view.lua). Pure Lua.
--
-- campaign.chronicle = { v = 1, scenes = { record... } }, one record per played scene:
--   w, s       the week (session) and scene number;  title, type, loc: where and what kind
--   out        "win" or "lose";  heroes: { [player key] = char } at the time
--   cards      { { id, kind, name, got, foe, stories = { storyline ids it moved } } }
--   stories    every storyline the scene moved (storylines.on_scene decides)
--   beats      { { k, card, who, to, did, ok, skill, text } }: k is "told" (what the table heard
--              about a card), "did" (a hero to a person: the ledger), or an event kind (clue, goal,
--              fail_card, killing_blow, villain_falls, escape, defeat, death, payoff, theory, retort)
--   opened     { { id, name, why } }: cards the scene opened for the weeks ahead

local content = require "game.model.content"
local util = require "game.model.util"
local ledger = require "game.model.ledger"
local storylines = require "game.model.storylines"
local glossary = require "game.data.glossary"

local M = {}
M.glossary = glossary

local KEEP = { clue = true, goal = true, fail_card = true, killing_blow = true, villain_falls = true, escape = true,
               defeat = true, death = true, payoff = true, theory = true, retort = true, thread_back = true, down = true }

local function deck()
    return require "game.model.deck"
end

function M.get(campaign)
    local ch = campaign.chronicle
    if not ch then
        ch = { v = 1, scenes = M.backfill(campaign) }
        campaign.chronicle = ch
    end
    ch.scenes = ch.scenes or {}
    return ch
end

-- Recording -------------------------------------------------------------------------------------

local function card_row(c, stories)
    return { id = c.id, kind = c.kind, name = c.name, got = c.got, foe = (c.foe or c.villain) and true or nil,
             stories = stories }
end

-- One scene as it stands now: after the night, or live while it plays (out stays nil until the
-- scene is settled, and nothing's opened yet).
function M.record(campaign, night, sc, opened)
    local loc = sc.comps and sc.comps.location
    local title = sc.title or (loc and util.capitalize(loc.name))
        or (content.scenes[sc.type] and content.scenes[sc.type].name) or "A scene"
    -- Somewhere else by the end (the party moved on, mid-scene): both places.
    if loc and sc.title and sc.title ~= util.capitalize(loc.name) then
        title = sc.title .. ", then " .. util.lower_first(loc.name)
    end
    local rec = { w = campaign.week, s = sc.index, title = title,
                  type = sc.type, loc = loc and loc.id, out = sc.outcome, cards = {}, stories = {}, beats = {},
                  opened = {}, heroes = {} }
    for _, p in ipairs(campaign.players or {}) do
        rec.heroes[p.key] = p.char
    end
    local moved = {}
    for _, id in ipairs(sc.stories or {}) do
        moved[id] = true
        table.insert(rec.stories, id)
    end
    local ids = {}
    for _, kind in ipairs(content.kinds) do
        local c = sc.comps and sc.comps[kind]
        if c then
            local list = {}
            for _, id in ipairs(storylines.of_card(campaign, c)) do
                if moved[id] or not sc.stories then
                    table.insert(list, id)
                end
            end
            table.insert(rec.cards, card_row(c, list))
            ids[c.id] = true
            if not sc.stories then
                for _, id in ipairs(list) do
                    if not moved[id] then
                        moved[id] = true
                        table.insert(rec.stories, id)
                    end
                end
            end
        end
    end
    for _, t in ipairs(night and night.told or {}) do
        if t.s == sc.index then
            table.insert(rec.beats, { k = "told", card = t.card, text = t.text })
        end
    end
    for _, e in ipairs(night and night.ledger or {}) do
        if e.s == sc.index then
            if e.ev then
                if KEEP[e.ev] and e.text then
                    table.insert(rec.beats, { k = e.ev, who = e.who, to = e.to, card = e.clue, skill = e.skill, text = e.text })
                end
            elseif e.did and e.to then
                table.insert(rec.beats, { k = "did", who = e.who, to = e.to, did = e.did, ok = e.ok,
                                          text = ledger.entry_text(campaign, e) })
            end
        end
    end
    for _, o in ipairs(opened or {}) do
        if ids[o.from] then
            local c = content.components[o.id]
            table.insert(rec.opened, { id = o.id, from = o.from, why = o.why, name = c and c.name or o.id })
        end
    end
    return rec
end

-- After the night (campaign.finish_night): file every scene that played.
function M.after_night(campaign, night, opened)
    local ch = M.get(campaign)
    local out = {}
    for _, sc in ipairs(night.scenes or {}) do
        if sc.terrain then
            local rec = M.record(campaign, night, sc, opened)
            rec.out = rec.out or deck().outcome_of(sc)
            table.insert(ch.scenes, rec)
            table.insert(out, rec)
        end
    end
    -- A card on two scenes opened what it opens once: keep it with the later scene.
    local seen = {}
    for i = #out, 1, -1 do
        local keep = {}
        for _, o in ipairs(out[i].opened) do
            if not seen[o.id] then
                seen[o.id] = true
                table.insert(keep, o)
            end
        end
        out[i].opened = keep
    end
    return out
end

-- A save from before the Story log: rebuild what we can from the notebook's ledger (where each
-- scene was, the clues, who they dealt with, whose backstory came up). The lines the table heard
-- weren't kept then, so these read thinner.
function M.backfill(campaign)
    local nb = campaign.notebook
    local groups, order = {}, {}
    for _, e in ipairs(nb and nb.log or {}) do
        if e.w and e.s and e.w < (campaign.week or 0) + 1 then
            local key = e.w * 100 + e.s
            if not groups[key] then
                groups[key] = { w = e.w, s = e.s, entries = {} }
                table.insert(order, key)
            end
            table.insert(groups[key].entries, e)
        end
    end
    table.sort(order)
    local out = {}
    for _, key in ipairs(order) do
        local g = groups[key]
        local rec = { w = g.w, s = g.s, cards = {}, stories = {}, beats = {}, opened = {}, heroes = {}, backfilled = true }
        for _, p in ipairs(campaign.players or {}) do
            rec.heroes[p.key] = p.char
        end
        local have, moved = {}, {}
        local function add_card(c)
            if not c or have[c.id] then
                return
            end
            have[c.id] = true
            local list = storylines.of_card(campaign, c)
            table.insert(rec.cards, card_row(c, list))
            for _, id in ipairs(list) do
                if not moved[id] then
                    moved[id] = true
                    table.insert(rec.stories, id)
                end
            end
        end
        for _, e in ipairs(g.entries) do
            if e.at and not rec.loc then
                rec.loc = e.at
                local loc = content.components[e.at]
                rec.title = loc and util.capitalize(loc.name) or nil
                add_card(loc)
            end
            if e.ev == "clue" and e.clue then
                add_card(content.components[e.clue])
            elseif e.ev == "thread" and e.who and campaign:player(e.who) then
                local id = "bs_" .. e.who
                if not moved[id] then
                    moved[id] = true
                    table.insert(rec.stories, id)
                end
            elseif e.did and e.to then
                add_card(ledger.card_of(campaign, e.to))
            end
            if e.ev then
                if KEEP[e.ev] and e.text then
                    table.insert(rec.beats, { k = e.ev, who = e.who, to = e.to, card = e.clue, text = e.text })
                end
            elseif e.did and e.to then
                table.insert(rec.beats, { k = "did", who = e.who, to = e.to, did = e.did, ok = e.ok,
                                          text = ledger.entry_text(campaign, e) })
            end
        end
        rec.title = rec.title or ("Scene " .. util.int(g.s))
        if #rec.stories > 0 then
            table.insert(out, rec)
        end
    end
    return out
end

-- Reading a storyline -------------------------------------------------------------------------

-- Every card that belongs to a storyline (the deck's cards and any the campaign made).
function M.cards_of(campaign, id)
    local out, seen = {}, {}
    local function try(c)
        if c and not seen[c.id] then
            seen[c.id] = true
            if util.contains(storylines.of_card(campaign, c), id) then
                table.insert(out, c)
            end
        end
    end
    for _, kind in ipairs(content.kinds) do
        for _, c in ipairs(content.by_kind[kind] or {}) do
            try(c)
        end
    end
    for _, c in ipairs(campaign.registered or {}) do
        try(c)
    end
    return out
end

local function lower_first(s)
    return util.lower_first(s or "")
end

local function sentence(s)
    s = s or ""
    if s == "" then
        return s
    end
    s = util.capitalize(s)
    if not string.match(s, "[%.!?\"']$") then
        s = s .. "."
    end
    return s
end

local function skill_name(skill)
    local ok, skills = pcall(require, "game.rules.skills")
    if ok and skills.name then
        return skills.name(skill)
    end
    return util.capitalize((string.gsub(skill or "", "_", " ")))
end

-- A hero's name as it was in that scene (a fallen hero's scenes keep their name).
local function hero_name(campaign, rec, key)
    if not key or key == "party" then
        return nil
    end
    local was = rec and rec.heroes and rec.heroes[key]
    if was then
        return was
    end
    local p = campaign:player(key)
    return p and p.char or nil
end

-- "Pip failed a Stealth check: seen, and there are more of them than anyone thought."
local function fail_text(campaign, b, rec)
    local char = hero_name(campaign, rec, b.who)
    local text = b.text or ""
    if not (char and b.skill) then
        return sentence(text)
    end
    local prefix = char .. ": "
    local head = char .. " failed " .. util.fill("{a} {skill} check", { a = string.match(skill_name(b.skill), "^[AEIOU]") and "an" or "a",
                                                                     skill = skill_name(b.skill) })
    if string.sub(text, 1, #prefix) == prefix then
        local names = { I = true }
        for _, q in ipairs(campaign.players or {}) do
            names[q.char] = true
        end
        for _, c in pairs(rec and rec.heroes or {}) do
            names[c] = true
        end
        local rest = util.mid_sentence(string.sub(text, #prefix + 1), names)
        if not string.match(rest, "[%.!?\"']$") then
            rest = rest .. "."
        end
        return head .. ": " .. rest
    end
    return head .. ". " .. sentence(text)
end

-- "him", "her", "them": how to say a person a second time.
local function pronoun_of(pid)
    local def = ledger.data.people[pid] or {}
    local c = content.components[pid] or content.components[(def.cards or {})[1] or ""]
    if c and c.group then
        return "them"
    end
    return ({ he = "him", she = "her", it = "it" })[c and c.pronoun or ""] or "them"
end

-- Everything the heroes did to one person in a scene, in one sentence: "The party met Corin, Pip
-- caught a lie from him and Brannoc charmed him." (The scene's heading already says where.)
local POSSESSIVE = { him = "his", her = "her", them = "their", it = "its" }

local function deeds_text(campaign, list, rec)
    local pieces, seen = {}, {}
    local to = list[1].to
    local name = ledger.about(to).name or to
    if string.match(name, "^The ") then
        name = util.lower_first(name)
    end
    local last_who
    for _, b in ipairs(list) do
        local who = hero_name(campaign, rec, b.who) or ((not b.who or b.who == "party") and "the party") or "someone"
        local words = ledger.words({ did = b.did, ok = b.ok }) or b.did
        local key = who .. "|" .. tostring(words)
        if not seen[key] and #pieces < 4 then
            seen[key] = true
            local obj = #pieces == 0 and name or pronoun_of(to)
            local phrase = tostring(words) .. " " .. obj
            if b.did == "sleight_of_hand" and #pieces > 0 then
                phrase = (b.ok and "picked " or "was caught picking ") .. (POSSESSIVE[obj] or "their") .. " pocket"
            end
            -- The same hero again: "Pip charmed him and picked his pocket".
            table.insert(pieces, (who == last_who and "" or (who .. " ")) .. phrase)
            last_who = who
        end
    end
    return util.join_names(pieces) .. "."
end

-- Is this record about the storyline's hero as they are now (a fallen hero's story ended with them)?
local function same_hero(campaign, d, rec)
    if not d or d.kind ~= "backstory" then
        return true
    end
    local was = rec.heroes and rec.heroes[d.key]
    if d.ended then
        return was == d.char
    end
    local p = campaign:player(d.key)
    return not (p and was) or was == p.char
end

-- A storyline by id, including a fallen hero's story that ended with them
-- ("ended_bs_sam_Oswin" in storylines.lua): { ..., ended = true, char }.
function M.def(campaign, id)
    local d = storylines.def(campaign, id)
    if d or type(id) ~= "string" then
        return d
    end
    local key, char = string.match(id, "^ended_bs_([%w_]-)_(.+)$")
    local st = storylines.get(campaign)[id]
    if key and st then
        local bs = storylines.data.backstory or {}
        return { id = id, key = key, kind = "backstory", ended = true, char = char, name = char .. "'s story", short = char,
                 color = bs.color, about = "" }
    end
    return nil
end

-- The people a storyline is about: its own (the bells' Wren and Vask), and whoever its cast
-- cards are.
function M.people_of(campaign, d, cards)
    local out = {}
    for _, pid in ipairs((storylines.data[d.id] or {}).people or {}) do
        out[pid] = true
    end
    for _, c in ipairs(cards or M.cards_of(campaign, d.id)) do
        if c.kind == "cast" then
            local pid = ledger.person_of(c.id)
            if pid then
                out[pid] = true
            end
        end
    end
    return out
end

-- The sentences of one scene, as part of one storyline, and the heroes in them.
function M.compose(campaign, d, rec, story_people, filed)
    local id = filed or d.id
    local hero = d.kind == "backstory" and d.key or nil
    local mine, has_comp, has_foe, goal_mine = {}, false, false, false
    local people = {}
    for pid in pairs(story_people or M.people_of(campaign, d)) do
        people[pid] = true
    end
    for _, c in ipairs(rec.cards or {}) do
        if util.contains(c.stories or {}, id) then
            mine[c.id] = c
            if c.kind == "cast" then
                local pid = ledger.person_of(c.id)
                if pid then
                    people[pid] = true
                end
                has_foe = has_foe or c.foe
            elseif c.kind == "complication" then
                has_comp = true
            elseif c.kind == "goal" then
                goal_mine = true
            end
        end
    end
    local parts, said, whos = {}, {}, {}
    local function add(text, who)
        text = sentence(text)
        if text ~= "" and not said[text] then
            said[text] = true
            table.insert(parts, text)
            if who and who ~= "party" then
                whos[who] = true
            end
        end
    end
    -- What the table heard about this story's cards (or, for a card on the scene nobody read out
    -- word for word, what the DM wrote on it).
    local told, heard = 0, {}
    for _, b in ipairs(rec.beats or {}) do
        if b.k == "told" and mine[b.card] then
            heard[b.card] = true
            if told < 3 then
                told = told + 1
                add(b.text)
            end
        end
    end
    if not rec.backfilled then
        local loc = rec.loc and content.components[rec.loc]
        for _, c in ipairs(rec.cards or {}) do
            local card = content.components[c.id]
            if mine[c.id] and not heard[c.id] and card and c.kind ~= "reward" and c.kind ~= "location" and told < 3 then
                -- Nobody read it out word for word: say what it was, not the DM's prep line (the
                -- table never heard that).
                local name = card.name or ""
                local line = (c.kind == "goal" and ("Goal: " .. util.lower_first(name)))
                    or (c.kind == "cast" and ("With " .. util.lower_first(name))) or name
                if line ~= "" then
                    told = told + 1
                    add(line)
                end
            end
        end
    end
    -- What the heroes did about it.
    local fell, dealt = {}, {}
    for _, b in ipairs(rec.beats or {}) do
        local by_hero = hero and b.who == hero
        if b.k == "fail_card" and (by_hero or (not hero and has_comp)) then
            add(fail_text(campaign, b, rec), b.who)
        elseif (b.k == "villain_falls" or b.k == "killing_blow") and (by_hero or has_foe) then
            local key = b.who or "party"
            if not fell[key] then
                fell[key] = true
                add(b.text, b.who)
            end
        elseif (b.k == "escape" or b.k == "retort" or b.k == "theory" or b.k == "payoff" or b.k == "thread_back")
            and (by_hero or people[b.to] or b.k == "thread_back") then
            add(b.text, b.who)
        elseif (b.k == "defeat" or b.k == "death") and (by_hero or has_foe or not hero) then
            add(b.text, b.who)
        elseif b.k == "down" and by_hero then
            add(b.text, b.who)
        elseif b.k == "did" and people[b.to] and not dealt[b.to] then
            dealt[b.to] = true
            local list = {}
            for _, o in ipairs(rec.beats or {}) do
                if o.k == "did" and o.to == b.to then
                    table.insert(list, o)
                    if o.who and o.who ~= "party" then
                        whos[o.who] = true
                    end
                end
            end
            add(deeds_text(campaign, list, rec))
        elseif b.k == "clue" and (mine[b.card] or (b.card and content.components[b.card]
            and util.contains(storylines.of_card(campaign, content.components[b.card]), id))) then
            add(b.text)
        elseif b.k == "goal" and goal_mine then
            add(b.text)
        end
    end
    -- What they came away with.
    for _, c in ipairs(rec.cards or {}) do
        if mine[c.id] and c.kind == "reward" and rec.out then
            if rec.out == "win" then
                add("They came away with " .. lower_first(c.got or c.name))
            else
                add(util.capitalize(c.name) .. " is still out there")
            end
        end
    end
    -- Where it goes from here.
    local next_names = {}
    for _, o in ipairs(rec.opened or {}) do
        if mine[o.from] then
            table.insert(next_names, o.name)
        end
    end
    if #next_names > 0 then
        local quoted = {}
        for _, n in ipairs(next_names) do
            table.insert(quoted, '"' .. n .. '"')
        end
        -- Cards it opened for the weeks ahead: what could come next, not what happened.
        add("Could come next: " .. util.join_names(quoted) .. ".")
    end
    -- Nothing kept but that it moved (a backfilled week): say where at least.
    if #parts == 0 then
        local names = {}
        for _, c in ipairs(rec.cards or {}) do
            if mine[c.id] and c.kind ~= "location" then
                table.insert(names, c.name)
            end
        end
        if #names > 0 then
            add("In play: " .. table.concat(names, "; ") .. ".")
        elseif hero then
            local p = campaign:player(hero)
            add((p and p.char or "Their") .. "'s past came up here")
        else
            add("The story moved here")
        end
    end
    if hero then
        whos[hero] = true
    end
    return parts, whos
end

-- This week's board, as plans: the cards that move the storyline and what they'll say.
local function planned(campaign, d, prep, focus, tag, scenes)
    local out = {}
    local story = require "game.model.story"
    for i, s in ipairs(scenes or {}) do
        local slots = s.slots or s.comps or {}
        local loc = slots.location
        local mine, parts, has_focus = {}, {}, false
        for _, kind in ipairs(content.kinds) do
            local c = slots[kind]
            if c and util.contains(storylines.of_card(campaign, c), d.id) then
                table.insert(mine, c)
                has_focus = has_focus or c.id == focus
                local rev = story.pending_reveal(campaign, c)
                local again = c.again and deck().returning(campaign, c) and c.again
                local line = rev or again or content.line_for(c, c.kind ~= "location" and loc or nil) or c.name
                table.insert(parts, sentence(line))
            end
        end
        if #mine > 0 then
            table.insert(out, { tag = tag, w = campaign.week, s = s.index or i, where = loc and util.capitalize(loc.name)
                                    or ("Scene " .. util.int(s.index or i)),
                                type = s.type, loc = loc and loc.id, parts = parts, focus = has_focus, cards = mine })
        end
    end
    return out
end

-- Live: tonight's night, still going.
local function live(night)
    return night and not night.filed and night.scenes and night or nil
end

-- A storyline, told: { def, heat, since, state, premise, quote, woven, entries, leads, cast }.
-- opts: night (tonight's, if it's on), prep (this week's board), focus (a card id just placed).
function M.story(campaign, id, opts)
    opts = opts or {}
    local d = M.def(campaign, id)
    if not d then
        return nil
    end
    local st = storylines.get(campaign)[id]
    local heat, since = storylines.heat(campaign, id)
    local view = { def = d, heat = heat, since = since, state = st, entries = {}, leads = {} }
    -- The scenes file a backstory under "bs_<player>", whoever the hero was then.
    local filed = d.ended and ("bs_" .. d.key) or id
    -- The premise: the hero's backstory, about the party; or the story's hook.
    if d.kind == "backstory" then
        local p = campaign:player(d.key)
        local pd = content.players[d.key] or {}
        local char = d.ended and d.char or (p and p.char)
        local original = pd.char == nil or pd.char == char
        view.premise = (original and pd.premise) or util.capitalize((not d.ended and p and p.thread) or "")
        if view.premise == "" then
            view.premise = d.ended and (char .. " fell, and the story ended with them.") or nil
        end
        local idx = campaign.intro_told and campaign.intro_told[d.key]
        local said = require("game.data.intros").PLAYERS[d.key]
        if idx and said and said.story and said.story[idx] and p and original then
            view.quote = { who = p.name, char = char, text = said.story[idx] }
        end
        view.hero = d.key
    else
        view.premise = d.about
    end
    -- What Session Zero wrote into a hero's past (game/model/backstory.lua) opens their log.
    if d.kind == "backstory" then
        local char = d.ended and d.char or (campaign:player(d.key) or {}).char
        local lines = require("game.model.backstory").lines(campaign, d.key, char)
        if lines and #lines > 0 then
            local parts = {}
            for _, l in ipairs(lines) do
                table.insert(parts, sentence(l))
            end
            table.insert(view.entries, { tag = "zero", w = 0, s = 0, parts = parts, whos = { [d.key] = true } })
        end
    end
    -- Every scene that moved it, oldest first.
    local cards = M.cards_of(campaign, filed)
    view.cards = cards
    local people = M.people_of(campaign, d, cards)
    local woven = {}
    for _, rec in ipairs(M.get(campaign).scenes) do
        if util.contains(rec.stories or {}, filed) and same_hero(campaign, d, rec) then
            local parts, whos = M.compose(campaign, d, rec, people, filed)
            table.insert(view.entries, { tag = "past", w = rec.w, s = rec.s, where = rec.title, type = rec.type,
                                         out = rec.out, loc = rec.loc, parts = parts, whos = whos, rec = rec })
            for _, other in ipairs(rec.stories or {}) do
                if other ~= filed and same_hero(campaign, storylines.def(campaign, other), rec) then
                    woven[other] = (woven[other] or 0) + 1
                end
            end
        end
    end
    if d.ended then
        view.cast = M.cast(campaign, d, view, cards)
        view.woven = {}
        return view
    end
    -- Tonight, as it plays; or this week's board.
    local night = live(opts.night)
    if night then
        for _, sc in ipairs(night.scenes) do
            if sc.terrain then
                local rec = M.record(campaign, night, sc, nil)
                if util.contains(rec.stories, id) then
                    local parts, whos = M.compose(campaign, d, rec, people)
                    table.insert(view.entries, { tag = "tonight", w = rec.w, s = rec.s, where = rec.title, type = rec.type,
                                                 out = rec.out, loc = rec.loc, parts = parts, whos = whos,
                                                 rec = rec, now = night.scene == sc and not sc.outcome })
                end
            else
                for _, e in ipairs(planned(campaign, d, nil, nil, "later", { sc })) do
                    table.insert(view.entries, e)
                end
            end
        end
    elseif opts.prep then
        for _, e in ipairs(planned(campaign, d, opts.prep, opts.focus, "planned", opts.prep.scenes)) do
            table.insert(view.entries, e)
        end
    end
    -- What it's woven with: the storylines that keep sharing its scenes.
    local wl = {}
    for other, n in pairs(woven) do
        if storylines.def(campaign, other) then
            table.insert(wl, { id = other, n = n })
        end
    end
    table.sort(wl, function(a, b)
        if a.n ~= b.n then
            return a.n > b.n
        end
        return a.id < b.id
    end)
    view.woven = {}
    for k = 1, math.min(3, #wl) do
        table.insert(view.woven, wl[k].id)
    end
    -- Leads: its cards waiting in the deck, not on this week's board.
    local on_board = {}
    for _, s in ipairs(opts.prep and opts.prep.scenes or {}) do
        for _, c in pairs(s.slots or {}) do
            on_board[c.id] = true
        end
    end
    for _, c in ipairs(cards) do
        local e = deck().entry(campaign, c.id)
        if e and e.state == "deck" and (e.plays or 0) == 0 and not on_board[c.id] and c.kind ~= "location"
            and deck().thread_live(campaign, c) then
            table.insert(view.leads, { id = c.id, name = c.name, kind = c.kind,
                                       when = (e.since or 0) > campaign.week and "next week" or "in your deck" })
        end
    end
    view.cast = M.cast(campaign, d, view, cards)
    return view
end

-- Who and where a storyline involves.
function M.cast(campaign, d, view, cards)
    local out = { people = {}, places = {}, heroes = {}, factions = {} }
    local seen_p, seen_l, seen_f = {}, {}, {}
    local function person(pid)
        if not pid or seen_p[pid] then
            return
        end
        seen_p[pid] = true
        local ab = ledger.about(pid)
        local known = ledger.data.people[pid] ~= nil
        table.insert(out.people, { id = pid, name = ab.name, role = ab.role, met = ledger.met(campaign, pid),
                                   label = known and ledger.label(ledger.att(campaign, pid)) or nil,
                                   status = known and ledger.status(campaign, pid) or nil })
        local fid = known and ledger.faction_of(campaign, pid)
        local def = ledger.data.people[pid] or {}
        if fid and not seen_f[fid] and (not def.hidden or (ledger.person(campaign, pid) or {}).exposed) then
            seen_f[fid] = true
            table.insert(out.factions, { id = fid, name = ledger.data[fid].name, standing = ledger.standing(campaign, fid) })
        end
    end
    for _, pid in ipairs((storylines.data[d.id] or {}).people or {}) do
        person(pid)
    end
    for _, c in ipairs(cards or {}) do
        if c.kind == "cast" then
            person(ledger.person_of(c.id))
        end
    end
    for _, e in ipairs(view.entries) do
        for _, c in ipairs(e.rec and e.rec.cards or {}) do
            if c.kind == "cast" and util.contains(c.stories or {}, d.id) then
                person(ledger.person_of(c.id))
            end
        end
    end
    -- People the stories talk about who aren't in the notebook (Ilsa).
    local ids = {}
    for _, c in ipairs(cards or {}) do
        ids[c.id] = true
    end
    for xid, x in pairs(glossary.extra or {}) do
        local tied = (d.kind == "backstory" and x.thread == d.key)
        for _, cid in ipairs(x.cards or {}) do
            tied = tied or ids[cid]
        end
        if tied and not seen_p[xid] then
            seen_p[xid] = true
            table.insert(out.people, 1, { id = xid, name = x.name, role = x.role, extra = true })
        end
    end
    -- Places: its own, then wherever its scenes were.
    local visits = {}
    for _, e in ipairs(view.entries) do
        if e.loc and e.tag ~= "planned" and e.tag ~= "later" then
            visits[e.loc] = (visits[e.loc] or 0) + 1
        end
    end
    local function place(lid)
        if not lid or seen_l[lid] then
            return
        end
        local c = content.components[lid]
        if not c then
            return
        end
        seen_l[lid] = true
        local ps = ledger.place_state(campaign, lid)
        table.insert(out.places, { id = lid, name = util.capitalize(c.name), visits = visits[lid] or 0,
                                   state = ps and ps.label or nil })
    end
    for _, e in ipairs(view.entries) do
        place(e.loc)
    end
    for _, c in ipairs(cards or {}) do
        if c.kind == "location" then
            place(c.id)
        end
    end
    -- Factions whose doings are its cards.
    for _, fid in ipairs(ledger.data.order) do
        local fd = ledger.data[fid]
        if not seen_f[fid] then
            for _, cid in ipairs(fd.cards or {}) do
                if ids[cid] and not seen_f[fid] then
                    seen_f[fid] = true
                    table.insert(out.factions, { id = fid, name = fd.name, standing = ledger.standing(campaign, fid) })
                end
            end
        end
    end
    -- Heroes: whose story it is, then whoever's been in its scenes.
    local count = {}
    for _, e in ipairs(view.entries) do
        for k in pairs(e.whos or {}) do
            count[k] = (count[k] or 0) + 1
        end
    end
    for _, p in ipairs(campaign.players or {}) do
        if d.kind == "backstory" and p.key == d.key then
            table.insert(out.heroes, 1, { key = p.key, char = p.char, name = p.name, own = true, scenes = count[p.key] or 0 })
        elseif (count[p.key] or 0) > 0 then
            table.insert(out.heroes, { key = p.key, char = p.char, name = p.name, scenes = count[p.key] })
        end
    end
    return out
end

-- Which storylines to list, most pressing first: the ones this week touches, then by how
-- recently they moved; not-started ones last.
function M.list(campaign, prep, night)
    local defs = storylines.defs(campaign)
    local touched = {}
    for _, s in ipairs((night and not night.filed and night.scenes) or (prep and prep.scenes) or {}) do
        for _, c in pairs(s.slots or s.comps or {}) do
            for _, id in ipairs(storylines.of_card(campaign, c)) do
                touched[id] = true
            end
        end
    end
    local st = storylines.get(campaign)
    local last = {}
    for _, rec in ipairs(M.get(campaign).scenes) do
        for _, id in ipairs(rec.stories or {}) do
            last[id] = math.max(last[id] or 0, rec.w * 10 + rec.s)
        end
    end
    local order = {}
    for i, d in ipairs(defs) do
        local s = st[d.id]
        local open = s and (s.state == "open" or s.state == "resolved")
        local rank = (touched[d.id] and 3) or ((last[d.id] or 0) > 0 and 2) or (open and 1) or 0
        table.insert(order, { d = d, rank = rank, last = last[d.id] or 0, i = i, touched = touched[d.id] })
    end
    table.sort(order, function(a, b)
        if a.rank ~= b.rank then
            return a.rank > b.rank
        end
        if a.last ~= b.last then
            return a.last > b.last
        end
        return a.i < b.i
    end)
    local out = {}
    for _, o in ipairs(order) do
        table.insert(out, { def = o.d, touched = o.touched, started = o.rank >= 1 })
    end
    -- Fallen heroes' stories, last: they ended with them, but they happened.
    local ended = {}
    for id, s in pairs(st) do
        if s.state == "ended" and string.sub(id, 1, 6) == "ended_" then
            table.insert(ended, id)
        end
    end
    table.sort(ended)
    for _, id in ipairs(ended) do
        local d = M.def(campaign, id)
        if d then
            table.insert(out, { def = d, started = true, ended = true })
        end
    end
    return out
end

-- At a glance (October 13) -------------------------------------------------------------------
-- The whole story as a chain of short steps, to read in a second and decide what to do with it:
-- "Pip owes the Velvet Hand -> S1 The Kettle: Sable's collectors come calling. Won. -> ...".

local VERB = { combat = "fight", set_piece = "showdown", social = "talk", mystery = "mystery", exploration = "exploring",
               puzzle = "puzzle", downtime = "downtime" }

local function words(text, n)
    local out, k = {}, 0
    for w in string.gmatch(text or "", "%S+") do
        k = k + 1
        if k > n then
            return table.concat(out, " ") .. "..."
        end
        table.insert(out, w)
    end
    return table.concat(out, " ")
end

-- A sentence cut to its first clause, a few words long.
function M.squeeze(text, n)
    n = n or 9
    text = string.gsub(text or "", "^They found out: ", "")
    text = string.gsub(text, "^Goal: ", "")
    local first = string.match(text, "^(.-[%.!?])%s") or text
    local count = select(2, string.gsub(first, "%S+", ""))
    if count > n then
        local clause = string.match(first, "^(.-)[,:;]%s")
        if clause and select(2, string.gsub(clause, "%S+", "")) >= 3 then
            first = clause
        end
    end
    first = string.gsub(first, "[%.!?,:;]+$", "")
    return words(first, n)
end

local function place_short(id)
    local c = id and content.components[id]
    if not c then
        return nil
    end
    local s = c.short and string.gsub(c.short, "^the ", "") or (string.match(c.name, "^([^,]+)") or c.name)
    s = string.gsub(s, "^The ", "")
    return util.capitalize(s)
end

-- A card's name mid-sentence: lower case, unless it starts with a name ("Pip owes the Hand").
local proper_cache
local function soft(campaign, name)
    name = name or ""
    if not proper_cache then
        proper_cache = { I = true }
        for _, k in ipairs(M.keywords(campaign)) do
            local first = string.match(k.term, "^(%u[%w]*)")
            if first then
                proper_cache[first] = true
            end
        end
    end
    local first = string.match(name, "^([%a]+)")
    if first and proper_cache[first] then
        return name
    end
    return (string.gsub(name, "^%u", string.lower))
end

local function card_gist(campaign, c, rec)
    local card = content.components[c.id]
    if c.kind == "goal" then
        return soft(campaign, c.name)
    elseif c.kind == "complication" then
        return soft(campaign, c.name)
    elseif c.kind == "cast" then
        local short = card and card.short or c.name
        local met = false
        for _, b in ipairs(rec and rec.beats or {}) do
            met = met or (b.k == "did" and b.did == "met")
        end
        if c.foe then
            return "against " .. short
        end
        return (met and "met " or "with ") .. short
    elseif c.kind == "reward" then
        local got = soft(campaign, c.got or c.name)
        if rec and rec.out == "lose" then
            return "missed " .. got
        end
        return "got " .. got
    end
    return nil
end

-- One step: "S2 Hale's Crossing (talk): met the abbot; learned Oswin's relic is the tongue... Won."
local function glance_step(campaign, d, rec, id, planned_cards)
    local where = place_short(rec.loc) or rec.title or "Somewhere"
    local bits = {}
    local order = { goal = 1, complication = 2, cast = 3, reward = 4, location = 5 }
    local mine = {}
    for _, c in ipairs(planned_cards or rec.cards or {}) do
        if planned_cards or util.contains(c.stories or {}, id) then
            table.insert(mine, c)
        end
    end
    table.sort(mine, function(a, b)
        return (order[a.kind] or 9) < (order[b.kind] or 9)
    end)
    for _, c in ipairs(mine) do
        local g = card_gist(campaign, c, rec)
        if g and #bits < 2 then
            table.insert(bits, g)
        end
    end
    if #bits == 0 and mine[1] and mine[1].kind == "location" then
        -- Been there before this scene?
        local before = 0
        local at = (rec.w or campaign.week + 1) * 100 + (rec.s or 0)
        for _, r in ipairs(M.get(campaign).scenes) do
            if r.loc == rec.loc and r.w * 100 + r.s < at then
                before = before + 1
            end
        end
        table.insert(bits, before > 0 and "back again" or "first visit")
    end
    -- The first thing they learned about it.
    for _, b in ipairs(rec.beats or {}) do
        if b.k == "clue" and #bits < 3 then
            local cc = b.card and content.components[b.card]
            if cc and util.contains(storylines.of_card(campaign, cc), id) then
                table.insert(bits, "clue: " .. M.squeeze(b.text, 10))
                break
            end
        end
    end
    local text = table.concat(bits, "; ")
    if text == "" then
        text = "the story moved"
    end
    local kind = rec.type and VERB[rec.type]
    return where .. (kind and (" (" .. kind .. ")") or "") .. ": " .. text
end

-- { title, gist, steps = { { label, text, tag, out } }, next = { names }, heat }
function M.glance(campaign, id, opts)
    opts = opts or {}
    local d = M.def(campaign, id)
    if not d then
        return nil
    end
    local view = M.story(campaign, id, opts)
    local out = { title = d.name, heat = view.heat, steps = {}, next = {} }
    if d.kind == "backstory" then
        local pd = content.players[d.key] or {}
        local p = campaign:player(d.key)
        local char = d.ended and d.char or (p and p.char)
        out.gist = (pd.char == char and pd.gist) or M.squeeze(view.premise or "", 10)
    else
        out.gist = d.gist or M.squeeze(d.about or "", 10)
    end
    local filed = d.ended and ("bs_" .. d.key) or id
    for _, e in ipairs(view.entries) do
        if e.tag == "zero" then
            local b = require("game.model.backstory").written(campaign, d.key)
            local c = b and b.hook and content.components[b.hook]
            if c then
                table.insert(out.steps, { label = "S0", text = "you wrote in " .. soft(campaign, c.name), tag = "zero" })
            end
        elseif e.tag == "past" or e.tag == "tonight" then
            local label = e.tag == "past" and ("S" .. util.int(e.w)) or "Tonight"
            table.insert(out.steps, { label = label, text = glance_step(campaign, d, e.rec, filed), tag = e.tag, out = e.out,
                                      now = e.now })
        elseif e.tag == "planned" or e.tag == "later" then
            local rec = { loc = e.loc, type = e.type, title = e.where, beats = {} }
            local cards = {}
            for _, c in ipairs(e.cards or {}) do
                table.insert(cards, { id = c.id, kind = c.kind, name = c.name, got = c.got, foe = (c.foe or c.villain) and true or nil })
            end
            table.insert(out.steps, { label = e.tag == "planned" and "This week" or "Later tonight",
                                      text = glance_step(campaign, d, rec, filed, cards), tag = e.tag, focus = e.focus })
        end
    end
    for k, l in ipairs(view.leads or {}) do
        if k <= 3 then
            table.insert(out.next, l.name)
        end
    end
    return out
end

-- "Previously on" for the prep board (playtest, October 13: the veteran needed 14 actions to say
-- what the story was). Last session, a line a scene, in the glance's shorthand; before week 2,
-- what Session Zero wrote into each hero's past.
-- { title, sub, lines = { { text, out, id } }, open = a storyline id }, or nil.
local function scene_step(campaign, rec)
    local where = place_short(rec.loc) or rec.title or "Somewhere"
    local order = { goal = 1, cast = 2, complication = 3, reward = 4 }
    local cards = {}
    for _, c in ipairs(rec.cards or {}) do
        if order[c.kind] then
            table.insert(cards, c)
        end
    end
    table.sort(cards, function(a, b)
        return order[a.kind] < order[b.kind]
    end)
    -- What it was about, then what they learned (else a second card): two bits, kept short.
    local clue
    for _, b in ipairs(rec.beats or {}) do
        if b.k == "clue" and b.text then
            clue = "clue: " .. M.squeeze(b.text, 9)
            break
        end
    end
    local bits = {}
    for _, c in ipairs(cards) do
        local g = card_gist(campaign, c, rec)
        local short = c.kind == "cast" and content.components[c.id] and content.components[c.id].short
        local said = short and string.find(string.lower(table.concat(bits, " ")), string.lower(short), 1, true)
        if g and not said and #bits < (clue and 1 or 2) then
            table.insert(bits, g)
        end
    end
    if clue then
        table.insert(bits, clue)
    end
    -- Nothing on the cards to say: what the table heard first.
    if #bits == 0 then
        for _, b in ipairs(rec.beats or {}) do
            if b.k == "told" and b.text then
                table.insert(bits, soft(campaign, M.squeeze(b.text, 9)))
                break
            end
        end
    end
    local kind = rec.type and VERB[rec.type]
    return where .. (kind and (" (" .. kind .. ")") or "") .. ": " .. (#bits > 0 and table.concat(bits, "; ") or "the story moved")
end

function M.previously(campaign)
    local week = campaign.week or 0
    if week <= 1 then
        local lines = {}
        for _, p in ipairs(campaign.players or {}) do
            local b = require("game.model.backstory").written(campaign, p.key)
            local c = b and b.hook and content.components[b.hook]
            if c and p.present ~= false then
                table.insert(lines, { text = p.char .. ": " .. c.name, id = "bs_" .. p.key })
            end
        end
        if #lines == 0 then
            return nil
        end
        return { title = "SESSION ZERO", sub = "What turns up first from each past. It's at the front of your hand.",
                 lines = lines, open = lines[1].id, zero = true, label = "SESSION ZERO: what you wrote in" }
    end
    local recs = {}
    for _, r in ipairs(M.get(campaign).scenes) do
        if r.w == week - 1 then
            table.insert(recs, r)
        end
    end
    if #recs == 0 then
        return nil
    end
    table.sort(recs, function(a, b)
        return (a.s or 0) < (b.s or 0)
    end)
    local title
    for _, le in ipairs(campaign.session_log or {}) do
        if le.week == week - 1 and le.recap and le.recap.titles then
            title = le.recap.titles[le.recap.title or 1]
        end
    end
    local lines, open = {}, nil
    for _, r in ipairs(recs) do
        local out = (r.out == "win" and " Won.") or (r.out == "lose" and " Lost.") or ""
        local id = r.stories and r.stories[1] or nil
        open = open or id
        local t = scene_step(campaign, r)
        if not string.find(t, "[%.!?]$") then
            t = t .. "."
        end
        table.insert(lines, { text = "S" .. util.int(r.s or 0) .. " " .. t .. out, out = r.out, id = id })
    end
    return { title = "LAST TIME", sub = "Session " .. util.int(week - 1) .. (title and (": \"" .. title .. "\"") or ""),
             lines = lines, open = open, label = "LAST TIME: session " .. util.int(week - 1) }
end

-- The same in one line, for a card's hover: the gist, then the last few steps.
function M.glance_line(campaign, id, n)
    local g = M.glance(campaign, id)
    if not g then
        return nil
    end
    local parts = { g.gist }
    local past = {}
    for _, st in ipairs(g.steps) do
        if st.tag == "past" or st.tag == "zero" or st.tag == "tonight" then
            table.insert(past, st)
        end
    end
    n = n or 2
    if #past > n then
        table.insert(parts, "...")
    end
    for i = math.max(1, #past - n + 1), #past do
        local st = past[i]
        table.insert(parts, st.label .. " " .. st.text .. (st.out == "win" and ", won" or (st.out == "lose" and ", lost" or "")))
    end
    return table.concat(parts, " -> ")
end

-- Keywords -------------------------------------------------------------------------------------

local function strip_article(s)
    s = s or ""
    s = string.gsub(s, "^[Tt]he ", "")
    s = string.gsub(s, "^An? ", "")
    return s
end

local function proper(s)
    return s ~= "" and string.match(s, "^%u") ~= nil
end

-- Every name the Story log lights up: { term, kind, id }, longest first. kind: hero, story,
-- faction, person, place, item.
function M.keywords(campaign)
    local list, seen = {}, {}
    local function add(term, kind, id)
        if not term or term == "" or seen[term] or #term < 3 then
            return
        end
        seen[term] = true
        table.insert(list, { term = term, kind = kind, id = id })
    end
    local aliases = glossary.aliases or {}
    for _, p in ipairs(campaign.players or {}) do
        add(p.char, "hero", p.key)
    end
    for _, fid in ipairs(ledger.data.order) do
        add(strip_article(ledger.data[fid].name), "faction", fid)
        local short = strip_article(ledger.data[fid].short or "")
        if proper(short) then
            add(short, "faction", fid)
        end
        for _, a in ipairs(aliases[fid] or {}) do
            add(a, "faction", fid)
        end
    end
    for _, d in ipairs(storylines.defs(campaign)) do
        add(strip_article(d.name), "story", d.id)
    end
    local people = {}
    for pid in pairs(ledger.data.people) do
        table.insert(people, pid)
    end
    for pid in pairs(ledger.data.names or {}) do
        table.insert(people, pid)
    end
    for _, ap in ipairs(content.arc.people or {}) do
        table.insert(people, ap.id)
    end
    table.sort(people)
    for _, pid in ipairs(people) do
        local name = strip_article(ledger.about(pid).name)
        name = string.match(name, "^([^,]+)") or name
        if proper(name) then
            add(name, "person", pid)
        end
        for _, a in ipairs(aliases[pid] or {}) do
            add(a, "person", pid)
        end
    end
    local extra = {}
    for xid in pairs(glossary.extra or {}) do
        table.insert(extra, xid)
    end
    table.sort(extra)
    for _, xid in ipairs(extra) do
        add(glossary.extra[xid].name, "person", xid)
    end
    for _, c in ipairs(content.by_kind.location or {}) do
        local name = strip_article(string.match(c.name, "^([^,]+)") or c.name)
        if proper(name) then
            add(name, "place", c.id)
        end
        local short = strip_article(c.short or "")
        if proper(short) then
            add(short, "place", c.id)
        end
        for _, a in ipairs(aliases[c.id] or {}) do
            add(a, "place", c.id)
        end
    end
    for _, c in ipairs(content.by_kind.reward or {}) do
        local name = strip_article(c.name)
        if proper(name) and not string.find(name, ",", 1, true) and #storylines.of_card(campaign, c) > 0 then
            add(name, "item", c.id)
        end
    end
    table.sort(list, function(a, b)
        if #a.term ~= #b.term then
            return #a.term > #b.term
        end
        return a.term < b.term
    end)
    return list
end

local function word_char(ch)
    return ch ~= "" and string.match(ch, "[%w]") ~= nil
end

-- Text split into runs, the keywords marked: { { text, kw = keyword or nil } }.
function M.mark(text, kws)
    text = text or ""
    local taken = {}   -- { start, finish, kw }
    local function free(a, b)
        for _, t in ipairs(taken) do
            if a <= t[2] and b >= t[1] then
                return false
            end
        end
        return true
    end
    for _, kw in ipairs(kws or {}) do
        local init = 1
        while true do
            local a, b = string.find(text, kw.term, init, true)
            if not a then
                break
            end
            local before = a > 1 and string.sub(text, a - 1, a - 1) or ""
            local after = string.sub(text, b + 1, b + 1)
            if not word_char(before) and not word_char(after) and free(a, b) then
                table.insert(taken, { a, b, kw })
            end
            init = b + 1
        end
    end
    table.sort(taken, function(x, y)
        return x[1] < y[1]
    end)
    local out, pos = {}, 1
    for _, t in ipairs(taken) do
        if t[1] > pos then
            table.insert(out, { text = string.sub(text, pos, t[1] - 1) })
        end
        table.insert(out, { text = string.sub(text, t[1], t[2]), kw = t[3] })
        pos = t[2] + 1
    end
    if pos <= #text then
        table.insert(out, { text = string.sub(text, pos) })
    end
    return out
end

-- The storylines a keyword is part of, by name.
function M.storylines_of(campaign, kw)
    local out, seen = {}, {}
    local function add(id)
        if id and not seen[id] then
            local d = storylines.def(campaign, id)
            if d then
                seen[id] = true
                table.insert(out, d)
            end
        end
    end
    if kw.kind == "hero" then
        add("bs_" .. kw.id)
        for _, rec in ipairs(M.get(campaign).scenes) do
            for _, b in ipairs(rec.beats or {}) do
                if b.who == kw.id then
                    for _, id in ipairs(rec.stories or {}) do
                        add(id)
                    end
                    break
                end
            end
        end
    elseif kw.kind == "person" then
        local x = glossary.extra[kw.id]
        if x then
            if x.thread then
                add("bs_" .. x.thread)
            end
            for _, cid in ipairs(x.cards or {}) do
                local c = content.components[cid]
                for _, id in ipairs(c and storylines.of_card(campaign, c) or {}) do
                    add(id)
                end
            end
        else
            local def = ledger.data.people[kw.id] or {}
            for _, cid in ipairs(def.cards or { kw.id }) do
                local c = content.components[cid]
                for _, id in ipairs(c and storylines.of_card(campaign, c) or {}) do
                    add(id)
                end
            end
            for _, id in ipairs(storylines.data.order) do
                if util.contains(storylines.data[id].people or {}, kw.id) then
                    add(id)
                end
            end
        end
    elseif kw.kind == "place" or kw.kind == "item" then
        local c = content.components[kw.id]
        for _, id in ipairs(c and storylines.of_card(campaign, c) or {}) do
            add(id)
        end
        if kw.kind == "place" then
            for _, rec in ipairs(M.get(campaign).scenes) do
                if rec.loc == kw.id then
                    for _, id in ipairs(rec.stories or {}) do
                        add(id)
                    end
                end
            end
        end
    elseif kw.kind == "faction" then
        local fd = ledger.data[kw.id] or {}
        for _, cid in ipairs(fd.cards or {}) do
            local c = content.components[cid]
            for _, id in ipairs(c and storylines.of_card(campaign, c) or {}) do
                add(id)
            end
        end
        for _, pid in ipairs(ledger.members(campaign, kw.id, true)) do
            for _, d in ipairs(M.storylines_of(campaign, { kind = "person", id = pid })) do
                add(d.id)
            end
        end
    elseif kw.kind == "story" then
        add(kw.id)
    end
    return out
end

-- What a keyword means, for its hover: { title, sub, lines = { { text, tone } }, stories }.
-- tone: "text", "dim", "good", "bad", "warn", "gold".
function M.define(campaign, kw, night)
    local out = { lines = {} }
    local function line(text, tone)
        if text and text ~= "" then
            table.insert(out.lines, { text = text, tone = tone or "text" })
        end
    end
    if kw.kind == "hero" then
        local p = campaign:player(kw.id)
        out.title = p and p.char or kw.term
        out.sub = p and ((p.class_name or "") .. ", played by " .. p.name) or nil
        local pd = content.players[kw.id] or {}
        line(not (p and p.pregen) and pd.premise or util.capitalize(p and p.thread or ""))
        for k, l in ipairs(require("game.model.backstory").lines(campaign, kw.id, p and p.char) or {}) do
            if k <= 3 then
                line(l, "dim")
            end
        end
        local heat = storylines.heat(campaign, "bs_" .. kw.id)
        line("Their story: " .. (M.HEAT_WORDS[heat] or heat) .. ".", heat == "loose" and "bad" or "dim")
    elseif kw.kind == "person" then
        local x = glossary.extra[kw.id]
        if x then
            out.title, out.sub = x.name, x.role
            line(x.about)
        else
            local ab = ledger.about(kw.id)
            out.title, out.sub = ab.name, ab.role ~= "" and ab.role or nil
            if ledger.data.people[kw.id] then
                local label = ledger.label(ledger.att(campaign, kw.id, night))
                line(ledger.met(campaign, kw.id) and ("Toward the party: " .. label .. ".") or "The party hasn't met them yet.",
                    ledger.met(campaign, kw.id) and ((label == "Hostile" or label == "Wary") and "bad"
                        or ((label == "Warm" or label == "Friendly") and "good" or "dim")) or "dim")
                local status = ledger.status(campaign, kw.id)
                if status ~= "around" then
                    line(ledger.data.STATUS[status] or status, "warn")
                end
                local fid = ledger.faction_of(campaign, kw.id)
                local def = ledger.data.people[kw.id] or {}
                if fid and (not def.hidden or (ledger.person(campaign, kw.id) or {}).exposed) then
                    line("One of " .. lower_first(ledger.data[fid].name) .. ".", "gold")
                end
                local last = ledger.history(campaign, kw.id, night)[1]
                if last then
                    line((last.w and ("Session " .. util.int(last.w) .. ": ") or "Tonight: ") .. ledger.entry_text(campaign, last), "dim")
                end
            end
            line(ab.about, "dim")
        end
    elseif kw.kind == "place" then
        local c = content.components[kw.id]
        out.title = c and util.capitalize(c.name) or kw.term
        local ps = ledger.place_state(campaign, kw.id)
        if ps then
            line(ps.label, "warn")
        end
        local e = deck().entry(campaign, kw.id)
        local visits = e and e.plays or 0
        out.sub = visits == 0 and "Not visited yet" or (visits == 1 and "Visited once" or ("Visited " .. util.int(visits) .. " times"))
        line(ps and ps.line or (c and c.line))
        local n = 0
        for i = #M.get(campaign).scenes, 1, -1 do
            local rec = M.get(campaign).scenes[i]
            if rec.loc == kw.id and n < 3 then
                n = n + 1
                local tn = content.scenes[rec.type] and content.scenes[rec.type].name
                line("Session " .. util.int(rec.w) .. ": " .. (tn and (lower_first(tn) .. " scene") or "a scene")
                    .. (rec.out == "win" and ", won." or (rec.out == "lose" and ", lost." or ".")), "dim")
            end
        end
    elseif kw.kind == "faction" then
        local fd = ledger.data[kw.id] or {}
        out.title = fd.name or kw.term
        local stv = ledger.standing(campaign, kw.id)
        out.sub = ledger.STANDING and ledger.STANDING[stv] or nil
        line("Wants: " .. (fd.goal or "?"), "dim")
        local names = {}
        for _, pid in ipairs(ledger.members(campaign, kw.id)) do
            if ledger.met(campaign, pid) then
                table.insert(names, ledger.about(pid).name)
            end
        end
        if #names > 0 then
            line("Members you know: " .. util.join_names(names) .. ".", "text")
        end
        local tl = require("game.model.world").timeline(campaign, kw.id)
        if tl[1] then
            line("Session " .. util.int(tl[1].week) .. ": " .. tl[1].text .. (tl[1].know == "secret" and " (only you know)" or ""), "dim")
        end
    elseif kw.kind == "story" then
        local d = storylines.def(campaign, kw.id)
        out.title = d and d.name or kw.term
        local heat = storylines.heat(campaign, kw.id)
        out.sub = util.capitalize(M.HEAT_WORDS[heat] or heat)
        line(d and d.about)
        local n = 0
        for _, rec in ipairs(M.get(campaign).scenes) do
            if util.contains(rec.stories or {}, kw.id) then
                n = n + 1
            end
        end
        line(n == 0 and "No scenes yet." or (util.int(n) .. (n == 1 and " scene so far." or " scenes so far.")), "dim")
        line("Click to read it.", "gold")
    elseif kw.kind == "item" then
        local c = content.components[kw.id]
        out.title = c and util.capitalize(c.name) or kw.term
        line(c and c.line)
        local e = deck().entry(campaign, kw.id)
        local hist = e and e.history or {}
        if hist[#hist] == "win" then
            line("The party has it.", "good")
        elseif e and e.state == "deck" then
            line("Still out there: it's in your deck.", "dim")
        else
            line("Not in play yet.", "dim")
        end
    end
    local names = {}
    for _, d in ipairs(M.storylines_of(campaign, kw)) do
        if not (kw.kind == "story" and d.id == kw.id) then
            table.insert(names, d.name)
        end
    end
    out.stories = names
    return out
end

M.HEAT_WORDS = { warm = "moving", cooling = "cooling", cold = "touch it this week, or the table notices",
                 loose = "a loose end", unopened = "not started", resolved = "tied off", ended = "over" }

return M
