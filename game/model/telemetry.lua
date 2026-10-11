-- Playtest records: one JSON line per finished week, so a playtest can be
-- read back afterwards. Pure Lua; the game script writes the line to disk.

local score = require "game.model.score"

local M = {}

-- fmt: how non-integer numbers are written (default two decimals).
local function encode(v, fmt)
    local t = type(v)
    if t == "nil" then
        return "null"
    elseif t == "boolean" then
        return v and "true" or "false"
    elseif t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then
            return "null"
        end
        if v == math.floor(v) then
            return string.format("%d", v)
        end
        return string.format(fmt or "%.2f", v)
    elseif t == "string" then
        local s = string.gsub(v, '[%c"\\]', function(c)
            if c == '"' then
                return '\\"'
            elseif c == "\\" then
                return "\\\\"
            elseif c == "\n" then
                return "\\n"
            end
            return string.format("\\u%04x", string.byte(c))
        end)
        return '"' .. s .. '"'
    elseif t == "table" then
        if #v > 0 or next(v) == nil then
            local parts = {}
            for i = 1, #v do
                parts[i] = encode(v[i], fmt)
            end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        local keys = {}
        for k in pairs(v) do
            table.insert(keys, tostring(k))
        end
        table.sort(keys)
        local parts = {}
        for _, k in ipairs(keys) do
            table.insert(parts, encode(k) .. ":" .. encode(v[k], fmt))
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "null"
end
M.encode = encode

-- prep_seconds: real time spent on the prep board; night_seconds: real time spent
-- watching game night (both measured by the game, not the model).
function M.week_record(campaign, prep_seconds, night_seconds)
    local prep = campaign.prep
    local night = campaign.night
    local rep = campaign.report
    local board = {}
    for i, s in ipairs(prep.scenes) do
        local slots = {}
        for kind, c in pairs(s.slots) do
            slots[kind] = c.id
        end
        board[i] = { type = s.type, slots = slots }
    end
    local players = {}
    for _, row in ipairs(rep.players) do
        local p = campaign:player(row.key)
        local long = {}
        for _, k in ipairs(score.LONG) do
            long[k] = math.floor(p[k] + 0.5)
        end
        players[row.key] = {
            present = row.present,
            on_break = p.on_break,
            standing = rep.standing and rep.standing[row.key] or nil,
            wavering = p.wavering,
            mood = p.mood,
            fun = row.fun and math.floor(row.fun + 0.5) or nil,
            long = long,
        }
    end
    local talked = {}
    for k in pairs(prep.talked) do
        table.insert(talked, k)
    end
    -- M6: the table's conflicts, conversations, seeds and level.
    local conflicts = {}
    for id, c in pairs(campaign.conflicts or {}) do
        conflicts[id] = { state = c.state, pressure = math.floor(c.pressure + 0.5), fixed = c.how }
    end
    local convos = {}
    for id, th in pairs(prep.convos or {}) do
        table.insert(convos, { id = id, done = th.done, cost = th.cost })
    end
    local inspired = {}
    for id in pairs(prep.inspired_by or {}) do
        table.insert(inspired, id)
    end
    local seeds = {}
    for _, sd in ipairs(campaign.seeds and campaign.seeds.planted or {}) do
        table.insert(seeds, { id = sd.id, state = sd.state, week = sd.week, hype = sd.hype })
    end
    local safety = {}
    for _, e in ipairs(night.safety or {}) do
        table.insert(safety, e.kind .. ":" .. e.key)
    end
    return encode({
        type = "week",
        seed = campaign.seed,
        week = campaign.week,
        prep_seconds = math.floor((prep_seconds or 0) + 0.5),
        night_seconds = night_seconds and math.floor(night_seconds + 0.5) or nil,
        story = rep.story_hits and #rep.story_hits or 0,
        chapter = rep.chapter,
        arc_session = campaign:arc_beat() and campaign.week or nil,
        prep_hours_used = prep:spent(),
        sketched = prep:sketched(),
        talked = talked,
        board = board,
        decisions = night.decisions,
        rolls = night.rolls,
        callouts = night.callouts,
        improvised = night.improv_count or 0,
        players = players,
        average_fun = math.floor(rep.average + 0.5),
        empathy = campaign:empathy(),
        session_zero = campaign.table and { tone = campaign.table.tone, rules = campaign.table.rules,
                                            asks = campaign.table.asks, held = campaign.table.held } or nil,
        conflicts = conflicts,
        convos = convos,
        inspired = inspired,
        planted = prep.planted,
        guide = campaign.guide and { seen = campaign.guide.shown or 0, off = campaign.guide.off or false } or nil,
        -- The real-session pass: clues found tonight, fights the DM built, how often they opened
        -- their notes and the character sheets.
        clues = rep.clues and #rep.clues or 0,
        built_fights = (function()
            local n = 0
            for _, sc in ipairs(prep.scenes or {}) do
                if sc.encounter then
                    n = n + 1
                end
            end
            return n
        end)(),
        looked = campaign.looked,
        seeds = seeds,
        safety = safety,
        level = campaign.level,
        subclasses = campaign.subclasses,
    })
end

-- Playtest answers (M7) ----------------------------------------------------------------------

-- The two quick questions after a week: how prep felt, how watching it felt.
function M.week_survey(campaign, week, answers)
    return encode({
        type = "week_survey",
        seed = campaign.seed,
        week = week,
        prep = answers.prep,
        watch = answers.watch,
        skipped = answers.skipped or nil,
    })
end

-- The end-of-slice survey, with a summary of how the slice went for the DM.
function M.slice_survey(campaign, answers)
    local players = {}
    for _, p in ipairs(campaign.players) do
        players[p.key] = {
            commitment = math.floor(p.commitment + 0.5),
            investment = math.floor(p.investment + 0.5),
            trust = math.floor(p.trust + 0.5),
            on_break = p.on_break,
            subclass = campaign.subclasses and campaign.subclasses[p.class] or nil,
        }
    end
    local fixes, payoffs = {}, {}
    for _, e in ipairs(campaign.journal or {}) do
        for _, id in ipairs(e.fixes) do
            table.insert(fixes, id)
        end
        for _, id in ipairs(e.payoffs) do
            table.insert(payoffs, id)
        end
    end
    local last = campaign.journal and campaign.journal[#campaign.journal]
    return encode({
        type = "slice_survey",
        seed = campaign.seed,
        week = campaign.week,
        satisfying = answers.satisfying,
        payoff = answers.payoff,
        homework = answers.homework,
        gut = answers.gut,
        next = answers.next,
        drag = answers.text and answers.text.drag or "",
        favourite = answers.text and answers.text.favourite or "",
        level = campaign.level,
        players = players,
        fixes = fixes,
        payoffs = payoffs,
        chapter = last and last.chapter or nil,
        empathy = campaign:empathy(),
    })
end

return M
