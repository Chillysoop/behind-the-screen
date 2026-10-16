-- Session report labels and the tells shown under each player on game night.
-- What players write in the group chat and say for the report lives in the
-- dialogue library (game/data/dialogue/, triggers chat_* and report_quote).
-- Data only: tune freely.

return {
    verdicts = { loved = "Loved it", fun = "Had fun", fine = "It was fine", bored = "A bit bored", out = "Checked out" },
    -- The same, said ahead of time (the prep board's forecast for Thursday: the re-test, October 16,
    -- "it was fine" in the past tense before the night had happened).
    forecasts = { loved = "Will love it", fun = "Should enjoy it", fine = "Probably fine", bored = "May be bored",
                  out = "May check out" },

    -- Tells shown under each player during game night, by engagement.
    tells = {
        { at = 0.72, text = "leaning in" },
        { at = 0.50, text = "grinning" },
        { at = 0.32, text = "listening" },
        { at = 0.18, text = "doodling" },
        { at = 0.0, text = "on their phone" },
    },
}
