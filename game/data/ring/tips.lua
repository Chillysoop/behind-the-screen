-- Lore tips for Welcome to the Ring: what can point the party the right way, separate from the bag. The shape is the
-- museum's (game/data/museum/tips.lua): room, hints, when, moot. Our words; the book's pages for what they point at.

return {
    { id = "tip_debt", name = "Ezra's in a hurry", room = "dock", hints = "ezra_owes", page = 81, moot = { flag = "debt_settled" },
      text = "Someone who's bought a debt and wants paying today is usually in a hole of their own." },
    { id = "tip_two_fixers", name = "Two ways to a repair", room = "bar_machine", hints = "rumour_fixers", page = 79,
      moot = { flag = "repaired" },
      text = "Two gangs, and either could fix a hub in three hours. Whatever each asks for will cost the other." },
    { id = "tip_fuel", name = "Hina's fuel", room = "common", hints = "hina_out", page = 83, moot = { flag = "fuelled" },
      text = "Hina has more fuel than a bar needs, and she keeps asking how far a spacecraft can go." },
    { id = "tip_flowers", name = "Fuel and flowers", room = "common", hints = "hina_hola", page = 83,
      text = "Fuel and flowers make something here, and the dreamers in the computer center always have plenty of it." },
    { id = "tip_back_door", name = "The dish", room = "engine_room", page = 85, moot = { flag = "water_changed" },
      text = "Monotone's computers aren't the only way to the water signal. Something outside, by the big dish, tells the "
          .. "water systems what to do." },
    { id = "tip_board", name = "Read the board", room = "computer_center", hints = "monotone_board", page = 89,
      moot = { flag = "monotone_deal_done" },
      text = "Nobody gives away a favor that's only half an hour's work. Look at what the board actually does." },
    { id = "tip_photos", name = "The photos", room = "computer_center", hints = "monotone_lonely", page = 89,
      text = "A gang leader with a wall full of photos of their enemy isn't finished with them." },
    { id = "tip_mother", name = "Roy and non-phys", room = "engine_room", hints = "roy_mother", page = 85,
      text = "Roy hates non-phys more than he hates anything. Hate like that usually has a name on it." },
    { id = "tip_ragosa", name = "Ragosa wants it settled", room = "shuttle", page = 79,
      text = "Ragosa doesn't care who's right. She wants Aurum 80 quiet, and she wants to be the one who made it quiet." },
}
