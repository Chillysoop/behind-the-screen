-- How well you know each friend at the table (v2, October 30). Empathy is how well you read a table
-- in general; this is how well you know one person: what their quiet means, what they want when they
-- drum on the table. It grows by playing with them, by reading them right, and by talking to them,
-- and it's what makes a friend's thoughts easier to read (game/model/thoughts.lua's Insight roll).
-- A first step toward a fuller you-as-a-DM progression. Pure Lua.

local M = {}

M.XP = { 0, 3, 7, 12, 18 }   -- xp for levels 1..5
M.NAMES = { "New to you", "Getting to know", "Familiar", "Know them well", "Like a book" }
M.START = 2                   -- Session Zero: you've met them, played a little
M.GAIN = { night = 1,         -- a game night together
           clear = 1,         -- a clear read of one of their thoughts
           good = 1,          -- an answer that landed with them
           asked = 1,         -- you asked them straight out
           book = 1,          -- a natural 20 on a read: something clicks
           talk = 2 }         -- a talk away from the table (prep)
M.READ_CAP = 2                -- xp from reading one friend in one night

local function store(campaign)
    campaign.familiar = campaign.familiar or {}
    return campaign.familiar
end

function M.xp(campaign, key)
    return store(campaign)[key] or M.START
end

function M.level(campaign, key)
    local xp = M.xp(campaign, key)
    local level = 1
    for l = 1, #M.XP do
        if xp >= M.XP[l] then
            level = l
        end
    end
    return level
end

function M.name(campaign, key)
    return M.NAMES[M.level(campaign, key)]
end

-- The bonus it gives a read: 0 when they're new to you, +4 when you could read them blindfold.
function M.bonus(campaign, key)
    return M.level(campaign, key) - 1
end

-- Progress to the next level, 0..1.
function M.progress(campaign, key)
    local l = M.level(campaign, key)
    if l >= #M.XP then
        return 1
    end
    return (M.xp(campaign, key) - M.XP[l]) / (M.XP[l + 1] - M.XP[l])
end

-- Grow it. night (optional) caps what reading one friend gives in one night. Returns true if they
-- went up a level.
function M.gain(campaign, key, kind, night)
    local n = M.GAIN[kind] or 0
    if n <= 0 or not key then
        return false
    end
    if night and kind ~= "night" and kind ~= "talk" then
        night.fam_gain = night.fam_gain or {}
        local got = night.fam_gain[key] or 0
        n = math.min(n, M.READ_CAP - got)
        if n <= 0 then
            return false
        end
        night.fam_gain[key] = got + n
    end
    local before = M.level(campaign, key)
    store(campaign)[key] = M.xp(campaign, key) + n
    local up = M.level(campaign, key) > before
    if up then
        campaign.familiar_up = campaign.familiar_up or {}
        campaign.familiar_up[key] = M.level(campaign, key)
    end
    return up
end

-- After a night: everyone who sat at the table.
function M.night_played(campaign, players)
    for _, p in ipairs(players or {}) do
        if p.present ~= false then
            M.gain(campaign, p.key, "night")
        end
    end
end

-- Dots for the screens: { filled, of }.
function M.dots(campaign, key)
    return M.level(campaign, key), #M.XP
end

return M
