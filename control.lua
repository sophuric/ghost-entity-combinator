local c = require("constant")

local function get_ghost_signals(n_id, update)
	if not n_id then
		return
	end
	if not update and storage.ghost_signals[n_id] then
		-- don't regenerate signals here
		return storage.ghost_signals[n_id]
	end

	local ghosts = storage.logistic_ghosts[n_id]
	if not ghosts then
		storage.ghost_signals[n_id] = nil
		return
	end
	local signals = {}
	-- loop through each ghost
	for _, ghost in pairs(ghosts) do
		if ghost and ghost.valid then
			-- get the item and quality from it
			local quality = ghost.quality
			local entity = ghost.ghost_prototype

			local items = entity.items_to_place_this
			if items and #items >= 1 then
				-- unique key for this item and quality,
				-- so we don't have duplicate signals.
				-- I don't think this really matters tbh
				local item = items[1]
				local key = "item_" .. quality.name .. "_" .. item.name
				if signals[key] == nil then
					signals[key] = { min = 0, value = { quality = quality, name = item.name } }
				end
				-- min is the quantity
				signals[key].min = signals[key].min + item.count
			end
		end
	end

	storage.ghost_signals[n_id] = signals
	return signals
end

local function update_combinator(entity, signals)
	if not entity or not entity.valid then
		return
	end

	local control = entity.get_or_create_control_behavior()
	if not control then
		return
	end

	entity.operable = false -- prevent player from opening its GUI
	control.enabled = true

	-- set signal/logistic sections of ghost entity combinator control

	-- ensure there is only one section
	while control.sections_count > 1 do
		control.remove_section(2)
	end
	if control.sections_count == 0 then
		control.add_section()
	elseif not control.sections[1].is_manual then
		control.remove_section(1)
		control.add_section()
	end
	local section = control.sections[1]

	-- set to defaults
	section.group = ""
	section.active = true
	section.multiplier = 1

	if not signals then
		local e_id = entity.unit_number
		local n_id = storage.combinator_logistic_network[e_id]
		signals = get_ghost_signals(n_id) or {}
	end

	section.filters = signals
end

local function update_combinators_in_network(n_id, update)
	local combinators = storage.logistic_combinators[n_id]
	if not combinators then
		return
	end
	local signals = get_ghost_signals(n_id, update)
	for e_id, entity in pairs(combinators) do
		update_combinator(entity, signals)
	end
end

local function add_ghost(entity, register_network)
	if not (entity and entity.valid and (entity.type == c.ghost_entity or entity.type == c.ghost_tile)) then
		return
	end

	local e_id = entity.unit_number

	-- what construction areas the ghost is in
	local networks = entity.surface.find_logistic_networks_by_construction_area(entity.position, entity.force)
	if #networks == 0 then
		return
	end

	script.register_on_object_destroyed(entity)

	if not storage.ghost_logistic_networks[e_id] then
		storage.ghost_logistic_networks[e_id] = {}
	end
	for _, network in ipairs(networks) do
		if register_network then
			-- notify us when this logistic network or its cells are destroyed
			script.register_on_object_destroyed(network)
			for _, cell in ipairs(network.cells) do
				script.register_on_object_destroyed(cell)
			end
		end

		-- add to two-way mapping
		local n_id = network.network_id
		if not storage.logistic_ghosts[n_id] then
			storage.logistic_ghosts[n_id] = {}
		end
		storage.logistic_ghosts[n_id][e_id] = entity
		storage.ghost_logistic_networks[e_id][n_id] = true

		update_combinators_in_network(n_id, true)
	end
end

local function add_combinator(entity, register_network)
	if not entity or not entity.valid or entity.name ~= c.combinator then
		return
	end

	local e_id = entity.unit_number

	local network = entity.surface.find_logistic_network_by_position(entity.position, entity.force)
	if network then
		local n_id = network.network_id
		storage.combinator_logistic_network[e_id] = n_id
		if not storage.logistic_combinators[n_id] then
			storage.logistic_combinators[n_id] = {}
		end
		storage.logistic_combinators[n_id][e_id] = entity
	else
		storage.combinator_logistic_network[e_id] = nil
	end

	script.register_on_object_destroyed(entity)

	if register_network and network then
		-- notify us when this logistic network is destroyed
		script.register_on_object_destroyed(network)
	end

	update_combinator(entity)
end

local function scan_entities()
	storage.logistic_ghosts = {}
	storage.ghost_logistic_networks = {}
	storage.logistic_combinators = {}
	storage.combinator_logistic_network = {}
	storage.ghost_signals = {}

	for _, surface in pairs(game.surfaces) do
		for _, ghosts in pairs({
			surface.find_entities_filtered({ type = c.ghost_entity }),
			surface.find_entities_filtered({ type = c.ghost_tile }),
		}) do
			for _, ghost in pairs(ghosts) do
				add_ghost(ghost, false)
			end
		end
		for _, entity in pairs(surface.find_entities_filtered({ name = c.combinator })) do
			add_combinator(entity, false)
		end
	end
end

local function scan_cells()
	for _, force in pairs(game.forces) do
		for _, networks in pairs(force.logistic_networks) do
			for _, network in pairs(networks) do
				script.register_on_object_destroyed(network)
				for _, cell in pairs(network.cells) do
					script.register_on_object_destroyed(cell)
				end
			end
		end
	end
end

local function scan_all()
	scan_entities()
	scan_cells()
end

script.on_init(scan_all)
commands.add_command("scan_all", nil, scan_all)

local function add_logistic_cell(entity)
	if not entity or not entity.valid or not entity.logistic_cell then
		return
	end
	scan_entities()
	script.register_on_object_destroyed(entity.logistic_cell)
	local network = entity.logistic_cell.logistic_network
	if network then
		script.register_on_object_destroyed(network)
	end
end

script.on_event(defines.events.on_script_trigger_effect, function(event)
	local entity = event.cause_entity
	if not entity then
		return
	end
	local name = event.effect_id

	if name == c.triggers.create_ghost then
		add_ghost(entity, true)
	elseif name == c.triggers.create_combinator then
		add_combinator(entity, true)
	elseif name == c.triggers.create_roboport then
		add_logistic_cell(entity)
	end
end)

script.on_event(defines.events.on_object_destroyed, function(event)
	if event.type == defines.target_type.entity then
		local e_id = event.useful_id

		-- remove combinator if it is one
		local n_id = storage.combinator_logistic_network[e_id]
		storage.combinator_logistic_network[e_id] = nil
		if n_id and storage.logistic_combinators[n_id] then
			storage.logistic_combinators[n_id][e_id] = nil
		end

		-- remove logistic network if it is one
		local networks = storage.ghost_logistic_networks[e_id]
		storage.ghost_logistic_networks[e_id] = nil
		if networks then
			-- ghost entity
			for n_id, _ in pairs(networks) do
				if storage.logistic_ghosts[n_id] then
					storage.logistic_ghosts[n_id][e_id] = nil
					update_combinators_in_network(n_id, true)
				end
			end
		end
	elseif event.type == defines.target_type.logistic_network then
		scan_entities()
	elseif event.type == defines.target_type.logistic_cell then
		scan_entities()
	end
end)
