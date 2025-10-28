--------------------------------------------------------------------------------
-- Wagon manifest, formerly known as "wagon control"
--------------------------------------------------------------------------------

local tlib = require("lib.core.table")
local relm = require("lib.core.relm.relm")
local ultros = require("lib.core.relm.ultros")
local signal_lib = require("lib.signal")
local stlib = require("lib.core.strace")
local cs2 = _G.cs2
local combinator_settings = _G.cs2.combinator_settings
local gui = _G.cs2.gui

local strace = stlib.strace
local Delivery = _G.cs2.Delivery
local signal_to_key = signal_lib.signal_to_key
local key_to_signal = signal_lib.key_to_signal
local key_is_fluid = signal_lib.key_is_fluid
local key_to_stacksize = signal_lib.key_to_stacksize
local get_quality_name = signal_lib.get_quality_name
local ceil = math.ceil
local floor = math.floor
local min = math.min
local empty = tlib.empty
local Pr = relm.Primitive
local VF = ultros.VFlow

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

cs2.register_combinator_setting(
	cs2.lib.make_flag_setting("no_wagon_manifest", "wagon_flags", 0)
)
cs2.register_combinator_setting(
	cs2.lib.make_flag_setting("live_wagon_inventory", "wagon_flags", 1)
)

--------------------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------------------

relm.define_element({
	name = "CombinatorGui.Mode.Wagon",
	render = function(props)
		return ultros.WellSection(
			{ caption = { "cybersyn2-combinator-modes-labels.settings" } },
			{
				gui.InnerHeading({
					caption = { "cybersyn2-combinator-modes-labels.flags" },
				}),
				gui.Checkbox(
					{ "cybersyn2-combinator-mode-wagon.per-wagon-manifest" },
					{ "cybersyn2-combinator-mode-wagon.per-wagon-manifest-tooltip" },
					props.combinator,
					combinator_settings.no_wagon_manifest,
					true
				),
				gui.Checkbox(
					{ "cybersyn2-combinator-mode-wagon.live-wagon-inventory" },
					{ "cybersyn2-combinator-mode-wagon.live-wagon-inventory-tooltip" },
					props.combinator,
					combinator_settings.live_wagon_inventory
				),
			}
		)
	end,
})

relm.define_element({
	name = "CombinatorGui.Mode.Wagon.Help",
	render = function(props)
		return VF({
			ultros.RtMultilineLabel({ "cybersyn2-combinator-mode-wagon.desc" }),
			Pr({
				type = "label",
				font_color = { 255, 230, 192 },
				font = "default-bold",
				caption = { "cybersyn2-combinator-modes-labels.signal-outputs" },
			}),
			Pr({ type = "line", direction = "horizontal" }),
			Pr({
				type = "table",
				column_count = 2,
			}, {
				ultros.BoldLabel({ "cybersyn2-combinator-modes-labels.signal" }),
				ultros.BoldLabel({ "cybersyn2-combinator-modes-labels.value" }),
				ultros.RtLabel("[item=iron-ore][item=copper-plate][fluid=water]..."),
				ultros.RtMultilineLabel({
					"cybersyn2-combinator-mode-wagon.output-signals",
				}),
			}),
		})
	end,
})

--------------------------------------------------------------------------------
-- Mode registration
--------------------------------------------------------------------------------

cs2.register_combinator_mode({
	name = "wagon",
	localized_string = "cybersyn2-combinator-modes.wagon",
	settings_element = "CombinatorGui.Mode.Wagon",
	help_element = "CombinatorGui.Mode.Wagon.Help",
	is_output = true,
})

--------------------------------------------------------------------------------
-- Modal functions
--------------------------------------------------------------------------------

local O_RED = defines.wire_connector_id.combinator_output_red
local O_GREEN = defines.wire_connector_id.combinator_output_green
local O_CHEST_RED = defines.wire_connector_id.circuit_red
local O_CHEST_GREEN = defines.wire_connector_id.circuit_green
local SCRIPT = defines.wire_origin.script

---@param combinator Cybersyn.Combinator
---@param force_destroy boolean?
local function create_or_destroy_hidden_chest(combinator, force_destroy)
	if
		combinator.mode == "wagon"
		and combinator:read_setting(combinator_settings.live_wagon_inventory)
		and not force_destroy
	then
		local assoc_entities = combinator.associated_entities
		if not assoc_entities then
			combinator.associated_entities = {}
			assoc_entities = combinator.associated_entities
		end
		---@cast assoc_entities table<string, LuaEntity>
		if
			not assoc_entities.proxy_chest or not assoc_entities.proxy_chest.valid
		then
			local combinator_entity = combinator.entity --[[@as LuaEntity]]

			local chest = combinator_entity.surface.create_entity({
				name = "cybersyn2-proxy-chest",
				position = combinator.entity.position,
				force = combinator.entity.force,
			})

			if not chest then
				strace(
					stlib.ERROR,
					"cs2",
					"combinator",
					"message",
					"Failed to create hidden proxy chest entity"
				)
				return
			end

			-- Wire chest to combinator outputs
			local comb_red = combinator_entity.get_wire_connector(O_RED, true)
			local comb_green = combinator_entity.get_wire_connector(O_GREEN, true)
			local chest_red = chest.get_wire_connector(O_CHEST_RED, true)
			local chest_green = chest.get_wire_connector(O_CHEST_GREEN, true)
			chest_red.connect_to(comb_red, false, SCRIPT)
			chest_green.connect_to(comb_green, false, SCRIPT)

			strace(
				stlib.DEBUG,
				"cs2",
				"combinator",
				"message",
				"Created hidden proxy chest entity"
			)

			assoc_entities.proxy_chest = chest
		end
	else
		local chest = combinator.associated_entities
			and combinator.associated_entities.proxy_chest
		if chest then
			if chest.valid then chest.destroy() end
			combinator.associated_entities.proxy_chest = nil
			strace(
				stlib.DEBUG,
				"cs2",
				"combinator",
				"message",
				"Destroyed hidden proxy chest entity"
			)
		end
	end
end

---@param stop Cybersyn.TrainStop
local function check_per_wagon_mode(stop)
	local combs = stop:get_associated_combinators(
		function(c) return c.mode == "wagon" end
	)
	local is_per_wagon = false
	for _, comb in pairs(combs) do
		if not comb:read_setting(combinator_settings.no_wagon_manifest) then
			is_per_wagon = true
			break
		end
	end

	if (not is_per_wagon) and stop.per_wagon_mode then
		stop.per_wagon_mode = nil
		cs2.raise_node_data_changed(stop)
	elseif is_per_wagon and not stop.per_wagon_mode then
		stop.per_wagon_mode = true
		cs2.raise_node_data_changed(stop)
	end
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

cs2.on_combinator_created(create_or_destroy_hidden_chest)

cs2.on_combinator_node_associated(function(comb, new, prev)
	if comb.mode == "wagon" then
		if new then check_per_wagon_mode(new) end
		if prev then check_per_wagon_mode(prev) end
	end
end)

cs2.on_combinator_setting_changed(function(combinator, setting, new, prev)
	if
		setting == nil
		or (setting == "mode" and (new == "wagon" or prev == "wagon"))
		or setting == "live_wagon_inventory"
	then
		local stop = combinator:get_node("stop") --[[@as Cybersyn.TrainStop?]]
		if stop then check_per_wagon_mode(stop) end
		create_or_destroy_hidden_chest(combinator)
	end
end)

cs2.on_combinator_destroyed(
	function(combinator) create_or_destroy_hidden_chest(combinator, true) end
)

-- On train departure, clear all wagon combs.
cs2.on_train_departed(function(train, cstrain, stop)
	if not cstrain or not stop then return end
	local combs = stop:get_associated_combinators(
		function(c) return c.mode == "wagon" end
	)
	if #combs > 0 then
		for _, comb in pairs(combs) do
			-- Clear all wagon inventory signals
			local chest = comb.associated_entities
				and comb.associated_entities.proxy_chest
			if chest and chest.valid then
				chest.proxy_target_entity = nil
				strace(
					stlib.DEBUG,
					"cs2",
					"combinator",
					"message",
					"Cleared proxy target entity"
				)
			end
			comb:direct_write_outputs(empty)
		end
	end
	-- Clear wagon inventory filters
	if cstrain.is_filtered then
		cstrain.is_filtered = nil
		for _, carriage in pairs(train.cargo_wagons) do
			local inv = carriage.get_inventory(defines.inventory.cargo_wagon)
			if inv then
				for j = 1, #inv do
					inv.set_filter(j, nil)
				end
			end
		end
	end
end)

--------------------------------------------------------------------------------
-- Impl Details
-- The entire per-wagon subsystem is implemented here.
--------------------------------------------------------------------------------

---@param train Cybersyn.Train
local function compute_per_wagon_capacity(train)
	if train.per_wagon_fluid_capacity or train.per_wagon_item_slot_capacity then
		return
	end
	local carriages = train.lua_train.carriages
	local ccap = {}
	local fcap = {}
	for i = 1, #carriages do
		local carriage = carriages[i]
		if carriage.type == "fluid-wagon" then
			-- TODO: quality fluid wagons
			fcap[i] = carriage.prototype.fluid_capacity
		elseif carriage.type == "cargo-wagon" then
			local inventory = carriage.get_inventory(defines.inventory.cargo_wagon)
			ccap[i] = #inventory
		end
	end
	train.per_wagon_fluid_capacity = fcap
	train.per_wagon_item_slot_capacity = ccap
end

---@class Cybersyn.Internal.WagonManifest
---@field public type "cargo"|"fluid"
---@field public carriage LuaEntity
---@field public index integer
---@field public capacity integer
---@field public manifest Cybersyn.Manifest

---@class Cybersyn.Internal.CargoWagonManifest: Cybersyn.Internal.WagonManifest
---@field public type "cargo"
---@field public slot_filter_index uint
---@field public inv LuaInventory

---@alias Cybersyn.Internal.WagonManifests table<integer, Cybersyn.Internal.WagonManifest>

---Distribute items amongst cargo wagons, locking inventory slots along
---the way.
---@param cw_manifests Cybersyn.Internal.CargoWagonManifest[]
---@param n_slots integer
---@param item SignalKey?
---@param stack_size uint?
---@param count uint?
---@return boolean
local function lock_item_slots(cw_manifests, n_slots, item, count, stack_size)
	if n_slots == 0 then return true end
	local target_slots_per_wagon = ceil(n_slots / #cw_manifests)

	---@type ItemFilter?
	local item_filter = nil
	if item then
		local sig = key_to_signal(item)
		if sig then
			item_filter = {
				name = sig.name,
				quality = sig.quality,
				comparator = "=",
			}
		end
	end

	-- Attempt to distribute the slots evenly over all the cargo wagons,
	-- accounting for variant capacities etc.
	while n_slots > 0 do
		local distributed_some = false
		for _, cw_manifest in ipairs(cw_manifests) do
			if n_slots <= 0 then break end
			local available_slot_capacity = cw_manifest.capacity
			if available_slot_capacity > 0 then
				local slots_to_distribute =
					min(n_slots, available_slot_capacity, target_slots_per_wagon)
				cw_manifest.capacity = cw_manifest.capacity - slots_to_distribute
				n_slots = n_slots - slots_to_distribute
				if item and count and stack_size then
					local n_distributed = min(count, slots_to_distribute * stack_size)
					count = count - n_distributed
					cw_manifest.manifest[item] = (cw_manifest.manifest[item] or 0)
						+ n_distributed

					-- Set the filter for the slots we just allocated
					if item_filter then
						for i = 1, slots_to_distribute do
							cw_manifest.inv.set_filter(
								cw_manifest.slot_filter_index,
								item_filter
							)
							cw_manifest.slot_filter_index = cw_manifest.slot_filter_index + 1
						end
					end
				end
				distributed_some = true
			end
		end
		if n_slots > 0 and not distributed_some then
			strace(
				stlib.ERROR,
				"cs2",
				"wagon_control",
				"message",
				"Not enough slot capacity to distribute allocated slots."
			)
			return false
		end
	end
	return true
end

---@param fw_manifests Cybersyn.Internal.WagonManifest[]
local function distribute_fluid(fw_manifests, fluid, qty)
	local target_amount_per_wagon = ceil(qty / #fw_manifests)
	while qty > 0 do
		local distributed_some = false
		for _, fw_manifest in ipairs(fw_manifests) do
			if qty <= 0 then break end
			local available_capacity = fw_manifest.capacity
			if available_capacity > 0 then
				local qty_to_distribute =
					min(qty, available_capacity, target_amount_per_wagon)
				fw_manifest.manifest[fluid] = (fw_manifest.manifest[fluid] or 0)
					+ qty_to_distribute
				fw_manifest.capacity = fw_manifest.capacity - qty_to_distribute
				qty = qty - qty_to_distribute
				distributed_some = true
			end
		end
		if qty > 0 and not distributed_some then
			strace(
				stlib.ERROR,
				"cs2",
				"wagon_control",
				"message",
				"Not enough capacity in fluid wagons to distribute all fluid."
			)
			return false
		end
	end
	return true
end

---@param train Cybersyn.Train
---@param stop Cybersyn.TrainStop
---@param delivery Cybersyn.TrainDelivery
---@return table<int, Cybersyn.Manifest>
local function create_wagon_manifests(train, stop, delivery)
	compute_per_wagon_capacity(train)

	-- Build base carriage manifest records
	local carriages = train.lua_train.carriages
	---@type Cybersyn.Internal.CargoWagonManifest[]
	local cw_manifests = {}
	local n_cargo_wagons = 0
	---@type Cybersyn.Internal.WagonManifest[]
	local fw_manifests = {}
	for i = 1, #carriages do
		local carriage = carriages[i]
		if carriage.type == "fluid-wagon" then
			fw_manifests[#fw_manifests + 1] = {
				type = "fluid",
				index = i,
				carriage = carriage,
				capacity = train.per_wagon_fluid_capacity[i]
					- delivery.reserved_fluid_capacity,
				manifest = {},
			}
		elseif carriage.type == "cargo-wagon" then
			cw_manifests[#cw_manifests + 1] = {
				type = "cargo",
				index = i,
				carriage = carriage,
				capacity = train.per_wagon_item_slot_capacity[i]
					- delivery.reserved_slots,
				manifest = {},
				slot_filter_index = 1,
				inv = carriage.get_inventory(defines.inventory.cargo_wagon) --[[@as LuaInventory]],
			}
			n_cargo_wagons = n_cargo_wagons + 1
		end
	end

	-- Attempt to distribute each manifest item evenly over wagons, accounting
	-- for variant capacities etc.
	for item, qty in pairs(delivery.manifest) do
		if key_is_fluid(item) then
			-- Fluid case
			if #fw_manifests == 0 then
				error("Impossible fluid allocation to a nonfluid train")
			end
			distribute_fluid(fw_manifests, item, qty)
		else
			-- Item case
			if #cw_manifests == 0 then
				error("Impossible item allocation to a nonitem train")
			end
			local stack_size = key_to_stacksize(item)
			local n_slots = ceil(qty / stack_size)
			-- Spillover calc: add net spillover to qty, then spread open
			-- slots across all wagons.
			local spillover_slots = ceil(
				(qty + (delivery.spillover * n_cargo_wagons)) / stack_size
			) - n_slots
			-- Distribute item slots + set filters
			lock_item_slots(cw_manifests, n_slots, item, qty, stack_size)
			train.is_filtered = true
			-- Distribute spillover_slots
			lock_item_slots(cw_manifests, spillover_slots, nil, nil, nil)
		end
	end

	-- Generate per-car manifests from cw and fw manifests
	local per_car_manifests = {}
	for _, fw_manifest in pairs(fw_manifests) do
		per_car_manifests[fw_manifest.index] = fw_manifest.manifest
	end
	for _, cw_manifest in pairs(cw_manifests) do
		per_car_manifests[cw_manifest.index] = cw_manifest.manifest
	end

	return per_car_manifests
end

---@param carriage LuaEntity
---@return DeciderCombinatorOutput[]
local function create_carriage_signals(carriage)
	if carriage.type == "cargo-wagon" then
		local inv = carriage.get_inventory(defines.inventory.cargo_wagon)
		if inv then
			local signals = {}
			for i = 1, #inv do
				local item = inv[i]
				if item.valid_for_read then
					signals[#signals + 1] = {
						signal = {
							type = "item",
							name = item.name,
							quality = get_quality_name(item.quality) or "normal",
						},
						constant = item.count,
						copy_count_from_input = false,
					}
				end
			end
			return signals
		end
	elseif carriage.type == "fluid-wagon" then
		local inv = carriage.get_fluid_contents()
		local signals = {}
		for fluid_name, count in pairs(inv) do
			signals[#signals + 1] = {
				signal = { type = "fluid", name = fluid_name },
				constant = count,
				copy_count_from_input = false,
			}
		end
		return signals
	end
	return {}
end

---@param train Cybersyn.Train
---@param wagon LuaEntity
---@return uint?
local function get_wagon_index(train, wagon)
	for index, carriage in pairs(train.lua_train.carriages) do
		if carriage.unit_number == wagon.unit_number then return index end
	end
end

---@param comb Cybersyn.Combinator
---@param wagon LuaEntity
local function set_proxy_chest_inventory(comb, wagon)
	local chest = comb.associated_entities
		and comb.associated_entities.proxy_chest
	if chest and chest.valid then
		if wagon and wagon.type == "cargo-wagon" then
			chest.proxy_target_entity = wagon
			chest.proxy_target_inventory = defines.inventory.cargo_wagon
			strace(
				stlib.DEBUG,
				"cs2",
				"combinator",
				"message",
				"Set proxy target to wagon",
				wagon
			)
		else
			chest.proxy_target_entity = nil
			strace(
				stlib.DEBUG,
				"cs2",
				"combinator",
				"message",
				"Cleared proxy target entity"
			)
		end
	end
end

---@param cstrain Cybersyn.Train
---@param stop Cybersyn.TrainStop
---@param delivery Cybersyn.TrainDelivery
local function set_producer_wagon_combs(cstrain, stop, delivery)
	local combs = stop:get_associated_combinators(
		function(c) return c.mode == "wagon" end
	)
	if #combs == 0 then return end
	local manifests = create_wagon_manifests(cstrain, stop, delivery)
	for _, comb in pairs(combs) do
		local wagon = comb:find_connected_wagon()
		if wagon then
			local index = get_wagon_index(cstrain, wagon)
			if index and manifests[index] then
				comb:write_outputs(manifests[index], -1)
			end
			set_proxy_chest_inventory(comb, wagon)
		end
	end
end

---@param cstrain Cybersyn.Train
---@param stop Cybersyn.TrainStop
---@param delivery Cybersyn.TrainDelivery
local function set_consumer_wagon_combs(cstrain, stop, delivery)
	local combs = stop:get_associated_combinators(
		function(c) return c.mode == "wagon" end
	)
	if #combs == 0 then return end
	for _, comb in pairs(combs) do
		local wagon = comb:find_connected_wagon()
		if wagon then
			local index = get_wagon_index(cstrain, wagon)
			local carriages = cstrain.lua_train.carriages
			if index and carriages[index] then
				comb:direct_write_outputs(create_carriage_signals(carriages[index]))
			end
			set_proxy_chest_inventory(comb, wagon)
		end
	end
end

-- On train arrival, if it is a wagon-based stop, generate a per wagon
-- manifest.
cs2.on_train_arrived(function(train, cstrain, stop)
	if
		not cstrain
		or not stop
		or not stop.per_wagon_mode
		or not cstrain.delivery_id
	then
		return
	end
	local delivery = Delivery.get(cstrain.delivery_id) --[[@as Cybersyn.TrainDelivery?]]
	if not delivery then return end
	if delivery.from_id == stop.id then
		-- If this is the pickup stop for the delivery, output negative manifest
		return set_producer_wagon_combs(cstrain, stop, delivery)
	elseif delivery.to_id == stop.id then
		-- If this is the dropoff stop for the delivery, output positive manifest
		return set_consumer_wagon_combs(cstrain, stop, delivery)
	end
end)
