local c = require("constant")

local combinator = table.deepcopy(data.raw[c.original_combinator][c.original_combinator])
combinator.name = c.combinator

local item = table.deepcopy(data.raw["item"][c.original_combinator])
item.name = c.combinator
item.place_result = c.combinator
item.order = "c[combinators]-e[ghost-entity-combinator]"

local recipe = table.deepcopy(data.raw["recipe"][c.original_combinator])
recipe.name = c.combinator
recipe.results = { { type = "item", name = c.combinator, amount = 1 } }

data:extend({ combinator, item, recipe })

table.insert(data.raw["technology"][c.technology].effects, {
	type = "unlock-recipe",
	recipe = c.combinator,
})

local function run_script_trigger_on_create(entity, trigger_name)
	if not entity.created_effect then
		entity.created_effect = {}
	end
	if not c.is_array(entity.created_effect) then
		entity.created_effect = { entity.created_effect }
	end
	table.insert(entity.created_effect, {
		type = "direct",
		action_delivery = {
			type = "instant",
			source_effects = {
				type = "script",
				effect_id = trigger_name,
			},
		},
	})
end

run_script_trigger_on_create(combinator, c.triggers.create_combinator)
run_script_trigger_on_create(data.raw[c.ghost_entity][c.ghost_entity], c.triggers.create_ghost)
run_script_trigger_on_create(data.raw[c.ghost_tile][c.ghost_tile], c.triggers.create_ghost)
for _, roboport in pairs(data.raw[c.roboport]) do
	run_script_trigger_on_create(roboport, c.triggers.create_roboport)
end
