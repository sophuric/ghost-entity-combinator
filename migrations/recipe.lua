local c = require("constant")

for _, force in pairs(game.forces) do
	force.recipes[c.combinator].enabled = force.technologies[c.technology].researched
end
