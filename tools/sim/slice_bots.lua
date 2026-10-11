-- The simulated DMs for the M7 slice (tools/sim/slice.lua, tools/tests/save_check.lua):
-- a careful one, one who plans for fun only, and a careless one. Each is a table of
-- habits; the helpers below act them out on a week's prep board and game night.

local content = require "game.model.content"
local social = require "game.model.social"
local seeds = require "game.model.seeds"
local styles = require "dm_styles"

local B = {}

local CAREFUL_S0 = { tone = "mixed", asks = { mara = "agree", sam = "agree", dev = "agree", jess = "push" },
                     rules = { xcard = "on", dice = "big_open", rulings = "quick" } }
local CARELESS_S0 = { tone = "silly", asks = { mara = "push", sam = "push", dev = "push", jess = "agree" },
                      rules = { xcard = "off", dice = "screen", rulings = "cool" } }

-- Put this week's story cards on the board where they fit (a DM following the arc).
function B.play_story(c, prep)
    local beat = c:arc_beat()
    if not beat then
        return
    end
    -- Make sure at least one scene suits the first story card, the way a DM would plan it.
    local first = content.components[beat.cards[1]]
    local fits_any = false
    for i = 1, 3 do
        for _, f in ipairs(first.fits) do
            fits_any = fits_any or f == prep.scenes[i].type
        end
    end
    if not fits_any and prep.arc_cards[first.id] then
        prep:set_type(1, first.fits[1])
    end
    for _, id in ipairs(beat.cards) do
        local card = content.components[id]
        if prep.arc_cards[id] and not prep:placed_at(id) then
            for i = 1, 3 do
                local s = prep.scenes[i]
                local fits = false
                for _, f in ipairs(card.fits) do
                    fits = fits or f == s.type
                end
                -- Write the story where it belongs: not the chapel's map on the forest road.
                fits = fits and content.belongs_at(card, s.slots.location)
                for _, other in pairs(s.slots) do
                    if card.kind == "location" and other.kind ~= "location" then
                        fits = fits and content.belongs_at(other, card)
                    end
                end
                if fits and not s.slots[card.kind] and prep:can_place(i, id) then
                    prep:place(i, id)
                    break
                end
            end
        end
    end
    if beat.finale and prep.arc_cards.cliffhanger and not prep:placed_at("cliffhanger") then
        prep:clear(3, "complication")
        prep:place(3, "cliffhanger")
    end
end

function B.plant_and_pay(c, prep)
    if c.week <= 2 and prep.seed_ideas[1] and #seeds.growing(c) == 0 then
        prep:plant(prep.seed_ideas[1])
    end
    for card_id in pairs(prep.payoffs) do
        local card = content.components[card_id]
        if not prep:placed_at(card_id) then
            for i = 1, 3 do
                local s = prep.scenes[i]
                for _, f in ipairs(card.fits) do
                    if f == s.type then
                        prep:clear(i, card.kind)
                        if prep:place(i, card_id) then
                            goto placed
                        end
                    end
                end
            end
            prep:set_type(2, card.fits[1])
            prep:clear(2, card.kind)
            prep:place(2, card_id)
            ::placed::
        end
    end
end

-- Answer messages kindly and fix live conflicts in DMs (the careful DM).
function B.tend_table(c, prep)
    for i, m in ipairs(c.chat) do
        if m.choices then
            c:answer_chat(i, 1)
        end
    end
    local replies = { spotlight_sam = 2, spotlight_mara = 2, spotlight_dev = 2, rules_sam = 2, rules_dev = 2,
                      tone_mara = 1, tone_jess = 1 }
    local starts = { spotlight = { "spotlight_jess", 1 }, rules = { "rules_house", 1 }, tone = { "tone_check", 1 } }
    for _, oc in ipairs(c.open_convos or {}) do
        if replies[oc.id] or oc.id == "rules_followup" then
            local th = prep:open_convo(oc.id)
            if th then
                prep:reply(oc.id, replies[oc.id] or 1)
                local guard = 0
                while not th.done and guard < 4 do
                    guard = guard + 1
                    prep:reply(oc.id, 1)
                end
            end
        end
    end
    for _, id in ipairs(content.conflicts.order) do
        local plan = starts[id]
        if social.is_live(c.conflicts[id]) and plan then
            local th = prep:open_convo(plan[1])
            if th and not th.done then
                prep:reply(plan[1], plan[2])
                local guard = 0
                while not th.done and guard < 4 do
                    guard = guard + 1
                    prep:reply(plan[1], 1)
                end
            end
        end
    end
end

B.DMS = {
    careful = {
        label = "Careful DM",
        about = "Careful Session Zero, plays the story cards, plants a seed and pays it off, tends the table, levels when offered.",
        s0 = CAREFUL_S0, story = true, seeds = true, tend = true, level = true, open_rolls = true, open = 0.35,
    },
    plain = {
        label = "Plans for fun only",
        about = "Careful Session Zero and good prep, but ignores the story cards, seeds and messages; levels when offered.",
        s0 = CAREFUL_S0, level = true, open_rolls = true,
    },
    careless = {
        label = "Careless DM",
        about = "Careless Session Zero, random prep, never answers anyone, never levels up, cooks the dice.",
        s0 = CARELESS_S0, random = true, cook = true,
    },
}
B.ORDER = { "careful", "plain", "careless" }

-- watch(ev, night), if given, sees every event before the bot answers it (tests use it).
function B.play_night(night, rng, dm, watch)
    local ev = night:advance()
    local guard = 0
    local decisions = 0
    while ev.kind ~= "done" and guard < 800 do
        guard = guard + 1
        if watch then
            watch(ev, night)
        end
        local a
        if ev.kind == "decision" then
            decisions = decisions + 1
            local card = ev.card
            if dm.tend and (card.id == "pip_show" or card.id == "joke_moment") then
                a = 2
            elseif dm.tend and card.id == "rules_spat" then
                a = 2
            else
                a = rng:int(1, #card.options)
            end
        elseif ev.kind == "improv" then
            a = 1
            for i, cd in ipairs(ev.cards) do
                if cd.fit == "great" then
                    a = i
                end
            end
        elseif ev.kind == "roll_where" then
            a = dm.open_rolls and "open" or "hidden"
        elseif ev.kind == "roll" then
            a = rng:d20()
        elseif ev.kind == "ruling" then
            -- Cooking is the ruling card's last button behind the screen (A11).
            a = (ev.cook and dm.cook and rng:chance(0.5)) and "cook" or nil
        end
        ev = night:advance(a)
    end
    return decisions, night.clock
end


-- The start of prep (S6, S7): what the world does this week, who the session is for, and who
-- shows up. The careful DM brings the biggest threat on screen, spotlights whoever's least
-- invested and brings in people tied to the table; the plain DM lets the world happen and
-- spotlights someone; the careless DM doesn't look (the moves play out on their own).
local world = require "game.model.world"
local ledger = require "game.model.ledger"

function B.plan_week(dm, c, prep, rng)
    if dm.random then
        return
    end
    local w = world.get(c)
    if dm.tend then
        -- On screen: a strike back first, else a front's move, else nothing.
        local best, best_v
        for i, m in ipairs(w.moves) do
            local mv = world.move_def(m.faction, m.move)
            local v = (mv.when and mv.when.crossed and 3 or 0) + (world.is_front(c, m.faction) and 2 or 0)
                + (ledger.standing(c, m.faction) < 0 and 1 or 0)
            if v > 0 and world.screen_card(c, m.faction, mv) and (not best_v or v > best_v) then
                best, best_v = i, v
            end
        end
        if best then
            world.decide(c, best, "screen")
        end
    end
    for i, m in ipairs(w.moves) do
        if m.state == "pending" then
            world.decide(c, i, "let")
        end
    end
    -- Spotlight: the least invested player whose story has a card ready.
    local pick, low
    for _, p in ipairs(c:present()) do
        if prep:spotlight_card(p.key) and (not low or p.investment < low) then
            pick, low = p, p.investment
        end
    end
    if pick then
        prep:spotlight(pick.key)
    end
    if dm.tend then
        -- Guests: people whose story is someone's at the table, or who like the party.
        local opts = prep:guest_options()
        local scored = {}
        for _, pid in ipairs(opts.people) do
            local card = ledger.card_of(c, pid)
            local v = (card and card.thread and 2 or 0) + math.abs(ledger.att(c, pid)) + rng:next()
            table.insert(scored, { pid = pid, v = v })
        end
        table.sort(scored, function(a, b) return a.v > b.v end)
        for k = 1, math.min(ledger.data.GUESTS, #scored) do
            prep:bring_in(scored[k].pid)
        end
    end
end

-- Put pinned cards on the board where they fit (the careful and plain DMs wanted them).
function B.place_pins(c, prep)
    for _, id in ipairs(prep.pin_order) do
        local card = content.components[id]
        if card and not prep:placed_at(id) then
            for i = 1, 3 do
                local s = prep.scenes[i]
                local fits = false
                for _, f in ipairs(card.fits or {}) do
                    fits = fits or f == s.type
                end
                if fits and not s.slots[card.kind] and prep:can_place(i, id) then
                    prep:place(i, id)
                    break
                end
            end
        end
    end
end

-- One week of prep the way this DM does it.
-- An open scene now and then (A15): scene 2 becomes "what do you do?", with a few spots: places
-- of your own first (free), then suggestions, then the hand, while there's time.
function B.open_scene(c, prep, rng)
    local i = math.min(2, #prep.scenes)
    prep:set_open(i, true)
    local places = require "game.model.places"
    local tries = {}
    for _, pl in ipairs(places.list(c)) do
        table.insert(tries, pl.id)
    end
    for _, sg in ipairs(prep:spot_suggestions(i)) do
        table.insert(tries, sg.id)
    end
    for _, card in ipairs(prep.hand.location or {}) do
        table.insert(tries, card.id)
    end
    for _, id in ipairs(tries) do
        if #prep.scenes[i].spots >= 3 then
            break
        end
        prep:add_spot(i, id)
    end
    if #prep.scenes[i].spots == 0 then
        prep:set_open(i, false)
    end
end

function B.prep(dm, c, prep, rng)
    if dm.open and c.week >= 2 and rng:chance(dm.open) then
        B.open_scene(c, prep, rng)
    end
    B.plan_week(dm, c, prep, rng)
    if dm.tend then
        B.tend_table(c, prep)
    end
    if dm.seeds then
        B.plant_and_pay(c, prep)
    end
    if dm.story then
        B.play_story(c, prep)    -- story cards first, while there's prep time
    end
    if dm.random then
        styles.random.prep(prep, rng, c)
    else
        styles.balanced.prep(prep, rng, c)
    end
    if dm.story then
        B.play_story(c, prep)
    end
    if not dm.random then
        B.place_pins(c, prep)
    end
    if dm.seeds then
        B.plant_and_pay(c, prep)
    end
end

return B
