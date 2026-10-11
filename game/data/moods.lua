-- How each player walks in this week. Rolled every week. Data only.
--
-- fun:      flat change to tonight's Fun.
-- boredom:  multiplier on boredom (tired players drift faster).
-- meters:   multipliers on what each session meter is worth tonight.
-- cancel:   added chance they cancel this week.
-- pressure: life pulling on them; drags Commitment down a little this week.
-- tell:     what shows under them at the table. What they say about it in the
--           group chat is the chat_mood trigger in the dialogue library.

return {
    order = { "fine", "fine", "fine", "tired", "celebrating", "stressed", "chatty", "distracted" },

    fine = { pressure = 0, name = "Fine", fun = 0, boredom = 1.0, cancel = 0 },
    tired = { pressure = 1.5, name = "Tired", fun = -4, boredom = 1.4, meters = { social = 1.2, challenge = 0.8 }, cancel = 0.10, tell = "yawning" },
    celebrating = { pressure = -1, name = "Celebrating", fun = 6, boredom = 0.8, meters = { social = 1.2 }, cancel = 0, tell = "beaming" },
    stressed = { pressure = 2, name = "Stressed", fun = -2, boredom = 1.2, meters = { challenge = 1.3, social = 0.9 }, cancel = 0.05, tell = "tapping the table" },
    chatty = { pressure = 0, name = "Chatty", fun = 2, boredom = 1.0, meters = { social = 1.3 }, cancel = 0, tell = "chatting away" },
    distracted = { pressure = 1.5, name = "Distracted", fun = -3, boredom = 1.3, meters = { spotlight = 1.3 }, cancel = 0.08, tell = "eyeing their phone" },
}
