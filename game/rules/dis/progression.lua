-- Death in Space's progression: no levels. A crew gets better between sessions by what it owns and what it's survived
-- (the book's improvement rules, p. 50), not by a level-up night; for a short adventure that's nothing to count yet.
-- The shared game asks this through game/model/ruleset.lua's "progression" part. Pure Lua.

local M = {}

function M.init(campaign)
    campaign.level = nil
    campaign.level_nights = 0
    campaign.levelups = {}
end

-- Where the crew stands: never ready for a level (there aren't any), `none` for the screens.
function M.status(campaign)
    return { level = nil, nights = campaign.level_nights or 0, ready = false, overdue = false, max = true, none = true }
end

function M.after_night(campaign)
    campaign.level_nights = (campaign.level_nights or 0) + 1
end

function M.start_week()
end

function M.level_up()
    return nil
end

return M
