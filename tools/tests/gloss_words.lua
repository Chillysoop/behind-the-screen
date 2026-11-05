-- The game's own words a new player may not know, for the hover audit (GLOSS_AUDIT=1 lua
-- tools/tests/museum_smoke.lua): { Lua pattern on screen text, the glossary term that explains it
-- (game/data/rules_glossary.lua) }. Every one on screen should have its hover.
return {
    { "SECRET CHECK", "secret_check" }, { "BIG ROLL", "big_roll" }, { "FINAL ROLL", "big_roll" },
    { "%f[%a]Breezy%f[%A]", "danger" }, { "%f[%a]Tense%f[%A]", "danger" }, { "%f[%a]Dangerous%f[%A]", "danger" },
    { "%f[%a]Deadly%f[%A]", "danger" },
    { "%f[%a]Graze%f[%A]", "graze" }, { "%f[%a]Advantage%f[%A]", "advantage" }, { "%f[%a]Disadvantage%f[%A]", "disadvantage" },
    { "%f[%a]DC%f[%A]", "dc" }, { "%f[%a]AC%f[%A]", "ac" }, { "Heroic Inspiration", "inspiration" },
    { "%f[%a]Concentration%f[%A]", "concentration" }, { "Bonus Action", "bonus_action" }, { "Action Surge", "action_surge" },
    { "Second Wind", "second_wind" }, { "Sneak Attack", "sneak" }, { "%f[%a]cantrip", "cantrip" },
    { "spell slot", "slots" }, { "Hit Dice", "hit_dice" }, { "short rest", "short_rest" }, { "long rest", "long_rest" },
    { "Short Rest", "short_rest" }, { "Long Rest", "long_rest" },
    { "%f[%a]Initiative%f[%A]", "initiative" }, { "%f[%a]Prone%f[%A]", "prone" }, { "%f[%a]Charmed%f[%A]", "charmed" },
    { "%f[%a]Frightened%f[%A]", "frightened" }, { "%f[%a]Petrified%f[%A]", "petrified" },
    { "%f[%a]Restrained%f[%A]", "restrained" }, { "%f[%a]Incapacitated%f[%A]", "incapacitated" },
    { "%f[%a]Unconscious%f[%A]", "unconscious" }, { "death save", "death_save" }, { "resists it", "resist" }, { "fails to resist", "resist" },
    { "%f[%a]Resistance%f[%A]", "resistance" }, { "%f[%a]vulnerable%f[%A]", "vulnerable" },
    { "%f[%a]Multiattack%f[%A]", "multiattack" },
    { "Fair warning", "fair_warning" }, { "FAIR WARNING", "fair_warning" }, { "Flitwidget Francs", "francs" },
    { "%f[%a]FRANCS%f[%A]", "francs" }, { "PREP HOURS", "prep_hours" }, { "Prep hours", "prep_hours" },
    { "%f[%a]Empathy%f[%A]", "empathy" }, { "Table Score", "table_score" }, { "%f[%a]Commitment%f[%A]", "commitment" },
    { "%f[%a]Investment%f[%A]", "investment" }, { "%f[%a]Suspicion%f[%A]", "suspicion" },
    { "Session Zero", "session_zero" }, { "X%-card", "xcard" }, { "behind your screen", "screen" },
    { "%f[%a]subclass", "subclass" }, { "house rule", "house_rule" }, { "railroad", "railroad" },
    { "Euryale's card", "boss_card" }, { "EURYALE'S CARD", "boss_card" },
    { "Ties and locks", "ties" }, { "LOOSE END", "loose_end" }, { "A REQUEST", "request" },
    -- The third playtest's newcomer and lapsed DM (screens_newcomer 15).
    { "[Vv]orpal sword", "vorpal" }, { "Mage Armor", "mage_armor" }, { "%f[%a]Aid%f[%A]", "aid" },
    { "%f[%a]Mastery%f[%A]", "mastery" }, { "%f[%a]Minis%f[%A]", "minis" }, { "%f[%a]Inspire%f[%A]", "inspire" },
    { "[Ff]inal roll", "final_roll" }, { "%f[%a]EMPATHY%f[%A]", "empathy" }, { "[Rr]ule of cool", "cool" },
    { "[Dd]ice jail", "dice_jail" }, { "Honour it", "honour" }, { "%f[%a]Goodwill%f[%A]", "goodwill" },
    { "%f[%a]Trust%f[%A]", "trust" },
    -- The confirming playtest: a fudged roll's word, and the Mech's mode on its status tag.
    { "%f[%a][Cc]ooked%f[%A]", "cooked" }, { "Hyper Destroyer Mode", "hyper" },
}
