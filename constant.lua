u = "ghost-entity-combinator-mod-create-"
return {
	ghost_entity = "entity-ghost",
	ghost_tile = "tile-ghost",
	roboport = "roboport",
	combinator = "ghost-entity-combinator",
	technology = "construction-robotics",
	original_combinator = "constant-combinator",
	triggers = {
		create_ghost = u .. "ghost",
		create_combinator = u .. "combinator",
		create_roboport = u .. "roboport",
	},
	is_array = function(table)
		-- I know tables can have both types, but this will do
		if type(table) ~= "table" then
			return false
		end
		if #table > 0 then
			return true
		end
		for _, _ in pairs(table) do
			return false
		end
		return true
	end,
}
