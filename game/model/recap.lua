-- The session report's recap and verdict (M8, B7; the GDD's "The session report and the
-- scrapbook"). The recap is for the DM only: built from pre-written templates, 4 to 6 variants
-- per kind of event, read off the event log (B1). Three title suggestions; pin a beat to keep it
-- for the scrapbook, cut one to drop it, add a one-line note. The verdict is the Table Score:
-- everyone's Fun, weighted so a great night can't come from delighting three and losing one.
-- Pure Lua.

local util = require "game.model.util"

local M = {}

-- Templates per event kind. {who} the player's name, {char} their hero, {text} the event's own
-- line, {place} where it happened, {boss} the one who fell.
M.TEMPLATES = {
    -- What a scene's goal came to (the story playtest: losing the relic never reached the recap).
    goal = { "{text}" },
    start = { "It started at {place}.", "The night opened at {place}.", "First stop: {place}.",
              "They began at {place}, as planned.", "{place} first, where it all kicked off." },
    crit = { "{char} rolled a natural 20 and the table lost its mind.", "A natural 20 from {char}, right when it counted.",
             "{who}'s die came up 20. Nobody has stopped talking about it.", "{char} landed the roll of the night.",
             "The 20 that {char} rolled will be in the group chat for weeks." },
    fumble = { "{char} rolled a 1. Of course {char} did.", "A natural 1 for {char}, at the worst moment.",
               "{who}'s die betrayed them: a 1.", "{char} found out what a 1 looks like up close." },
    jail = { "{who}'s d20 went to dice jail.", "One d20 is serving time tonight: {who}'s.", "{who} jailed a die. It had it coming.",
             "Dice jail claimed {who}'s d20." },
    down = { "{char} went down, and the table held its breath.", "{char} hit the floor mid-fight.",
             "For a moment it looked bad for {char}.", "{char} dropped, and everyone leaned in." },
    death = { "{text}.", "The table lost {char} tonight.", "{char} didn't make it.",
              "{char}'s story ended tonight." },
    goodbye = { "They said goodbye to {char} properly.", "{char}'s last words got a silence after them.",
                "{who} gave {char} a send-off nobody will forget." },
    back = { "{char} came back, changed.", "Death didn't keep {char}, but it left a mark.", "{char} is back. Mostly." },
    killing_blow = { "{char} landed the killing blow. {who} described every second of it.", "{text}.",
                     "The final hit went to {char}.", "{who} got to finish it, and did it in style.",
                     "{char} ended the fight." },
    villain_falls = { "{text}.", "The one leading them went down, and the rest lost heart.", "The fight's big name hit the floor." },
    escape = { "{text}.", "The villain got away, and will remember.", "Someone slipped out the back, swearing revenge.",
               "One of them escaped." },
    stunt = { "{text}.", "{char} pulled off a stunt.", "A flashy opening from {char}.", "{char} showed off, and it worked." },
    -- (Its own words, mostly: a token spent isn't one "earned". The playtest, Nov 2.)
    inspiration = { "{text}", "{text}", "Heroic Inspiration changed hands." },
    new_character = { "{text}", "A new face at the table: {char}.", "{who} brought someone new: {char}.",
                      "{char} joined the party." },
    callout = { "{text}", "Someone asked to see a roll.", "The table noticed something behind the screen.",
                "A callout. Awkward." },
    moment = { "{text}." },
    talk = { "{text}.", "{text}, in your own words." },
    boss_turn = { "{text}" },
}

-- Title suggestions, by the night's biggest event.
M.TITLES = {
    death = { "The Night We Lost {char}", "{char}'s Last Stand", "Goodbye, {char}" },
    death_back = { "{char} Comes Back", "The Price of Coming Back", "Not Yet, {char}" },
    villain_falls = { "The Fall of {boss}", "{char} and the Final Blow", "Down Goes {boss}" },
    killing_blow = { "{char} Finishes It", "The Final Hit", "How {char} Ended It" },
    escape = { "The One That Got Away", "{boss} Runs", "Unfinished Business" },
    crit = { "The Natural 20", "{char}'s Big Roll", "Twenty" },
    fumble = { "The Natural 1", "{char} and the Die", "One" },
    moment = { "Session {week}" },
}

M.VERDICTS = {
    { 82, "One for the stories" }, { 68, "Great session" }, { 54, "Good session" }, { 40, "Okay" }, { 0, "Rough night" },
}

-- The Table Score: the average Fun pulled toward the unhappiest player, so three delighted
-- players can't carry a night the fourth hated. 0 to 100, and its word.
function M.table_score(funs)
    if #funs == 0 then
        return 0, "Rough night"
    end
    local sum, low = 0, 100
    for _, f in ipairs(funs) do
        sum = sum + f
        low = math.min(low, f)
    end
    local avg = sum / #funs
    local s = 0.6 * avg + 0.4 * low
    for _, v in ipairs(M.VERDICTS) do
        if s >= v[1] then
            return s, v[2]
        end
    end
    return s, "Rough night"
end

local function pick(list, rng)
    return list[rng:int(1, #list)]
end

local function vars_for(campaign, night, e)
    local p = e.who and e.who ~= "party" and campaign:player(e.who)
    local text = e.text or ""
    text = string.gsub(text, "[%.!]+$", "")
    return {
        who = p and p.name or "The party", char = p and p.char or "the party", text = text,
        text_lower = util.lower_first and util.lower_first(text) or text,
        boss = night.battle_boss_name and util.capitalize(night.battle_boss_name) or "the villain",
        week = util.int(campaign.week),
    }
end

-- Build the recap for a finished night: { titles = {3}, title = 1, beats = { {kind, text, weight} },
-- note = "", snapshots = {...} }.
-- Drops any beat whose sentence is the opening of another's.
-- (And one that's inside another: "The Lecturer falls." beside "Oswin's blow lands, and the Lecturer
-- falls.", the second playtest review, F20.)
function M.drop_echoes(beats)
    local function stem(t)
        return string.lower((string.gsub(t or "", "[%.!?\"'%s]+$", "")))
    end
    for i = #beats, 1, -1 do
        local a = stem(beats[i].text)
        for j, b in ipairs(beats) do
            local sb = stem(b.text)
            if j ~= i and #a > 0 and #sb > #a and (string.sub(sb, 1, #a) == a or (#a >= 12 and string.find(sb, a, 1, true))) then
                table.remove(beats, i)
                break
            end
        end
    end
    return beats
end

function M.build(campaign, night, rng)
    local beats = {}
    -- Where it started.
    local first = night.scenes and night.scenes[1]
    local loc = first and first.comps and first.comps.location
    if loc and first.terrain then
        table.insert(beats, { kind = "start", weight = 2, order = 0,
                              text = util.sentence_case(util.fill(pick(M.TEMPLATES.start, rng),
                                  { place = loc.short and util.lower_first(loc.short) or util.lower_first(loc.name) })) })
    end
    -- The night's events, biggest first, one per kind (two for moments).
    local evs = {}
    for i, e in ipairs(night.ledger or {}) do
        if e.ev and M.TEMPLATES[e.ev] then
            table.insert(evs, { e = e, i = i })
        end
    end
    table.sort(evs, function(a, b)
        if (a.e.weight or 0) ~= (b.e.weight or 0) then
            return (a.e.weight or 0) > (b.e.weight or 0)
        end
        return a.i < b.i
    end)
    local per, used_text = {}, {}
    local top
    for _, x in ipairs(evs) do
        local e = x.e
        local cap = e.ev == "moment" and 2 or 1
        if (per[e.ev] or 0) < cap and #beats < 6 and not used_text[e.text or e.ev] then
            local tpl = (e.ev == "death" and M.DEATH_BACK[e.outcome or ""]) or pick(M.TEMPLATES[e.ev], rng)
            local text = util.sentence_case(util.fill(tpl, vars_for(campaign, night, e)))
            text = string.gsub(text, "%.%.", ".")
            text = string.gsub(text, "([%.!?]['\"])%.$", "%1")   -- ("hollow.'." from a "{text}." template)
            if not string.find(text, "[%.!?\"']$") then   -- ("'This wall is hollow.'", no extra full stop)
                text = text .. "."
            end
            -- Two events can come out as the same sentence (playtest, October 13: one beat twice).
            if not used_text[text] then
                per[e.ev] = (per[e.ev] or 0) + 1
                used_text[e.text or e.ev] = true
                used_text[text] = true
                top = top or e
                table.insert(beats, { kind = e.ev, weight = e.weight or 3, order = x.i, text = text, who = e.who })
            end
        end
    end
    -- One beat that's the start of another says it twice ("The relic, wrapped in the thief's own
    -- cloak." and the same with what Oswin did next): keep the longer (October 15).
    M.drop_echoes(beats)
    -- In the order they happened.
    table.sort(beats, function(a, b) return a.order < b.order end)
    -- Titles from the biggest event.
    local tk = top and (M.TITLES[top.ev] and top.ev or "moment") or "moment"
    if top and top.ev == "death" and M.DEATH_BACK[top.outcome or ""] then
        tk = "death_back"
    end
    local tv = vars_for(campaign, night, top or {})
    tv.boss = util.title_case(tv.boss)
    -- One name per session (October 15: one name in prep, "Brannoc Comes Back" on the report and a
    -- third after a click were three names for one night). The name it was planned
    -- under comes first and stays unless the DM picks another, which then names it everywhere.
    local titles = {}
    local planned
    -- (v2: an adventure's night is named for its rooms, "The Garden and the Entrance Hall".)
    if night.mus and campaign.adv then
        local MODULE = util.lazy("game.model.adventure").data
        local names = {}
        for _, r in ipairs(night.mus.rooms or {}) do
            local room = MODULE.rooms[r.room]
            if room and not room.virtual and not r.back and not r.side and not room.epilogue and #names < 2
                and not util.contains(names, room.name) then
                table.insert(names, room.name)
            end
        end
        if #names > 0 then
            planned = util.title_case(table.concat(names, " and "))
        end
    end
    if planned then
        table.insert(titles, planned)
    end
    -- (A title another night already had is passed over: "The One That Got Away", twice.)
    local used = campaign.recap_titles or {}
    for _, t in ipairs(M.TITLES[tk]) do
        local name = util.title_case(util.fill(t, tv))
        if not util.contains(titles, name) and not util.contains(used, name) and not string.find(name, "{", 1, true) then
            table.insert(titles, name)
        end
    end
    if #titles == 0 then
        table.insert(titles, "Session " .. util.int(campaign.week or 1))
    end
    campaign.recap_titles = campaign.recap_titles or {}
    if not util.contains(campaign.recap_titles, titles[1]) then
        table.insert(campaign.recap_titles, titles[1])
    end
    return { titles = titles, title = 1, planned = planned, beats = beats, note = "" }
end

-- A death that didn't stick: the recap says so.
M.DEATH_BACK = { scar = "{char} died, and came back at a cost." }

-- The session log (B7): every report, kept with the campaign so the notebook can reopen it.
function M.file(campaign, rep)
    campaign.session_log = campaign.session_log or {}
    local players = {}
    for _, row in ipairs(rep.players or {}) do
        table.insert(players, { key = row.key, name = row.name, char = row.char, fun = row.fun, tier = row.tier,
                                quote = row.quote, why = row.why })
    end
    local entry = { week = rep.week, recap = rep.recap, score = rep.score, verdict = rep.verdict, players = players,
                    headline = rep.headline, snapshots = rep.snapshots }
    for i = #campaign.session_log, 1, -1 do
        if campaign.session_log[i].week == rep.week then
            table.remove(campaign.session_log, i)
        end
    end
    table.insert(campaign.session_log, entry)
    return entry
end

return M
