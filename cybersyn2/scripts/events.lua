--------------------------------------------------------------------------------
-- Internal event backplane.
--------------------------------------------------------------------------------

local event = require("__cybersyn2__.lib.events").create_event

-- These type aliases are necessary due to problems in Sumneko Lua's parameter
-- system.

---@alias StringOrNil string|nil

--------------------------------------------------------------------------------
-- Factorio core control phase events
--------------------------------------------------------------------------------

---Event corresponding to Factorio's `on_init`.
on_init, raise_init = event("init", "nil", "nil", "nil", "nil", "nil")

---Event corresponding to Factorio's `on_configuration_changed`.
on_configuration_changed, raise_configuration_changed = event("configuration_changed", "ConfigurationChangedData", "nil",
	"nil", "nil", "nil")

---Event raised when runtime mod settings are changed. By the time this
---event is dispatched, the global `mod_settings` contains the new settings.
--- * Arg 1 - string|nil - The name of the setting that was changed, or `nil` if unknown. When `nil` you must assume any/all settings have changed.
on_mod_settings_changed, raise_mod_settings_changed = event("mod_settings_changed", "StringOrNil", "nil",
	"nil", "nil", "nil")

--------------------------------------------------------------------------------
-- Factorio world events
--------------------------------------------------------------------------------

on_built_train_stop, raise_built_train_stop = event("built_train_stop", "LuaEntity", "nil", "nil", "nil", "nil")

on_broken_train_stop, raise_broken_train_stop = event("broken_train_stop", "LuaEntity", "nil", "nil", "nil",
	"nil")

on_built_rail, raise_built_rail = event("built_rail", "LuaEntity", "nil", "nil", "nil", "nil")

on_broken_rail, raise_broken_rail = event("broken_rail", "LuaEntity", "nil", "nil", "nil", "nil")

---@alias TagsOrNil Tags|nil

on_built_combinator, raise_built_combinator = event("built_combinator", "LuaEntity",
	"TagsOrNil", "nil", "nil", "nil")

on_broken_combinator, raise_broken_combinator = event("broken_combinator", "LuaEntity",
	"nil", "nil", "nil", "nil")

on_built_combinator_ghost, raise_built_combinator_ghost = event("built_combinator_ghost", "LuaEntity",
	"nil", "nil", "nil", "nil")

on_built_combinator_settings_ghost, raise_built_combinator_settings_ghost = event("built_combinator_settings_ghost",
	"LuaEntity", "nil", "nil", "nil", "nil")

on_broken_combinator_ghost, raise_broken_combinator_ghost = event("broken_combinator_ghost", "LuaEntity",
	"nil", "nil", "nil", "nil")

on_broken_train_stock, raise_broken_train_stock = event("broken_train_stock", "LuaEntity",
	"LuaTrain", "nil", "nil", "nil")

-- Event raised when a relevant entity changes its physical configuration.
on_entity_repositioned, raise_entity_repositioned = event("entity_repositioned", "string", "LuaEntity",
	"nil", "nil", "nil")

-- Event raised when a relevant entity is renamed.
on_entity_renamed, raise_entity_renamed = event("entity_renamed", "string", "LuaEntity",
	"nil", "nil", "nil")

on_surface_removed, raise_surface_removed = event("surface_removed", "int",
	"nil", "nil", "nil", "nil")

---Event raised when equipment recognized by the layout algorithm is built.
on_built_equipment, raise_built_equipment = event("built_equipment", "LuaEntity",
	"nil", "nil", "nil", "nil")

-- Event raised when equipment recognized by the layout algorithm is removed.
on_broken_equipment, raise_broken_equipment = event("broken_equipment", "LuaEntity",
	"nil", "nil", "nil", "nil")

-- Event raised when an ephemeral combinator has its settings changed,
-- possibly en masse, by a factorio copy and paste or blueprint op.
on_entity_settings_pasted, raise_entity_settings_pasted = event("entity_settings_pasted",
	"EventData.on_entity_settings_pasted", "nil", "nil", "nil", "nil")

on_luatrain_created, raise_luatrain_created = event("luatrain_created", "EventData.on_train_created", "nil", "nil",
	"nil", "nil")

on_luatrain_changed_state, raise_luatrain_changed_state = event("luatrain_changed_state",
	"EventData.on_train_changed_state", "nil", "nil", "nil", "nil")

---@alias BlueprintEntityArray BlueprintEntity[]

---Event raised when a blueprint is pasted into the world.
on_built_blueprint, raise_built_blueprint = event("built_blueprint",
	"LuaPlayer", "EventData.on_pre_build", "nil", "nil", "nil")

--------------------------------------------------------------------------------
-- Cybersyn vehicle object events
--------------------------------------------------------------------------------

on_vehicle_created, raise_vehicle_created = event("vehicle_created", "Cybersyn.Vehicle", "nil", "nil", "nil", "nil")

on_vehicle_destroyed, raise_vehicle_destroyed = event("vehicle_destroyed", "Cybersyn.Vehicle", "nil", "nil", "nil",
	"nil")

---Event raised when a new Cybersyn train group is created.
on_train_group_created, raise_train_group_created = event("train_group_created", "string",
	"nil", "nil", "nil", "nil")

---Event raised when a train is added to a Cybersyn group.
on_train_group_train_added, raise_train_group_train_added = event("train_group_train_added", "Cybersyn.Train",
	"nil", "nil", "nil", "nil")

---Event raised when a train is removed from a Cybersyn group.
on_train_group_train_removed, raise_train_group_train_removed = event("train_group_train_removed", "Cybersyn.Train",
	"string", "nil", "nil", "nil")

---Event raised when a train group is destroyed.
on_train_group_destroyed, raise_train_group_destroyed = event("train_group_destroyed", "string",
	"nil", "nil", "nil", "nil")

on_train_layout_created, raise_train_layout_created = event("train_layout_created", "Cybersyn.TrainLayout",
	"nil", "nil", "nil", "nil")

--------------------------------------------------------------------------------
-- Cybersyn combinator object events
--------------------------------------------------------------------------------

on_combinator_created, raise_combinator_created = event("combinator_created", "Cybersyn.Combinator.Internal",
	"nil", "nil", "nil", "nil")

on_combinator_destroyed, raise_combinator_destroyed = event("combinator_destroyed", "Cybersyn.Combinator.Internal",
	"nil", "nil", "nil", "nil")

---@alias CybersynNodeOrNil Cybersyn.Node|nil

---Event raised when a combinator is associated or disassociated with a node.
--- * Arg 1 - `Cybersyn.Combinator.Internal` - The combinator.
--- * Arg 2 - `Cybersyn.Node|nil` - The node, if any, that the combinator is now associated with.
--- * Arg 3 - `Cybersyn.Node|nil` - The node, if any, that the combinator was previously associated with.
on_combinator_node_associated, raise_combinator_node_associated = event("combinator_node_associated",
	"Cybersyn.Combinator.Internal", "CybersynNodeOrNil", "CybersynNodeOrNil", "nil", "nil")

---Event raised when a setting changes on a combinator OR a ghost.
--- * Arg 1 - `Cybersyn.Combinator.Ephemeral` - The combinator or ghost.
--- * Arg 2 - `string|nil` - The name of the setting that changed. If `nil`, you must assume that any or all of the settings have changed.
--- * Arg 3 - `any` - The new value of the setting, if known.
--- * Arg 4 - `any` - The old value of the setting, if known.
on_combinator_or_ghost_setting_changed, raise_combinator_or_ghost_setting_changed = event(
	"combinator_or_ghost_setting_changed",
	"Cybersyn.Combinator.Ephemeral", "StringOrNil", "any", "any", "nil")

---Event raised when a real combinator's settings change, including when it
---is first built.
--- * Arg 1 - `Cybersyn.Combinator.Internal` - The combinator.
--- * Arg 2 - `string|nil` - The name of the setting that changed. If `nil`, you must assume that any or all of the settings have changed.
--- * Arg 3 - `any` - The new value of the setting, if known.
--- * Arg 4 - `any` - The old value of the setting, if known.
on_combinator_setting_changed, raise_combinator_setting_changed = event("combinator_setting_changed",
	"Cybersyn.Combinator.Internal", "StringOrNil", "any", "any", "nil")

--------------------------------------------------------------------------------
-- Cybersyn node object events
--------------------------------------------------------------------------------

---Event raised when the set of combinators associated with a node changes.
on_node_combinator_set_changed, raise_node_combinator_set_changed = event("node_combinator_set_changed",
	"Cybersyn.Node", "nil", "nil", "nil", "nil")

on_node_created, raise_node_created = event("node_created", "Cybersyn.Node", "nil", "nil", "nil", "nil")

on_node_destroyed, raise_node_destroyed = event("node_destroyed", "Cybersyn.Node", "nil", "nil", "nil", "nil")

---Event raised when internal data of a node (such as a train stop's allow list)
---changes.
on_node_data_changed, raise_node_data_changed = event("node_data_changed", "Cybersyn.Node", "nil", "nil", "nil", "nil")

on_train_stop_layout_changed, raise_train_stop_layout_changed = event("train_stop_layout_changed",
	"Cybersyn.TrainStop", "Cybersyn.TrainStopLayout", "nil", "nil", "nil")

on_train_stop_equipment_changed, raise_train_stop_equipment_changed = event("train_stop_equipment_changed",
	"Cybersyn.TrainStop", "Cybersyn.TrainStopLayout", "nil", "nil", "nil")

---Event raised when the automatically-inferred pattern of equipment at
---the given stop changes. More coarse-grained than `train_stop_equipment_changed`.
on_train_stop_pattern_changed, raise_train_stop_pattern_changed = event("train_stop_pattern_changed",
	"Cybersyn.TrainStop", "Cybersyn.TrainStopLayout", "nil", "nil", "nil")

--------------------------------------------------------------------------------
-- Inventories and deliveries.
--------------------------------------------------------------------------------

on_inventory_created, raise_inventory_created = event("inventory_created", "Cybersyn.Inventory", "nil", "nil", "nil",
	"nil")

on_inventory_destroyed, raise_inventory_destroyed = event("inventory_destroyed", "Cybersyn.Inventory", "nil", "nil",
	"nil", "nil")

on_delivery_created, raise_delivery_created = event("delivery_created", "Cybersyn.Delivery", "nil", "nil", "nil",
	"nil")

on_delivery_destroyed, raise_delivery_destroyed = event("delivery_destroyed", "Cybersyn.Delivery", "nil", "nil",
	"nil", "nil")

---Event raised when a delivery's state changes. Not raised at the initial
---creation of the delivery.
--- * Arg 1 - `Cybersyn.Delivery` - The delivery.
--- * Arg 2 - `Cybersyn.Delivery.State` - The new state of the delivery.
--- * Arg 3 - `Cybersyn.Delivery.State` - The previous state of the delivery.
on_delivery_state_changed, raise_delivery_state_changed = event("delivery_state_changed", "Cybersyn.Delivery",
	"Cybersyn.Delivery.State", "Cybersyn.Delivery.State", "nil", "nil")
