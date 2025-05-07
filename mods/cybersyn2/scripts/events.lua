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

_G.cs2.on_init, _G.cs2.raise_init =
	event("init", "nil", "nil", "nil", "nil", "nil")

_G.cs2.on_load, _G.cs2.raise_load =
	event("load", "nil", "nil", "nil", "nil", "nil")

---Event corresponding to Factorio's `on_configuration_changed`.
_G.cs2.on_configuration_changed, _G.cs2.raise_configuration_changed = event(
	"configuration_changed",
	"ConfigurationChangedData",
	"nil",
	"nil",
	"nil",
	"nil"
)

---Event raised when runtime mod settings are changed. By the time this
---event is dispatched, the global `mod_settings` contains the new settings.
--- * Arg 1 - string|nil - The name of the setting that was changed, or `nil` if unknown. When `nil` you must assume any/all settings have changed.
_G.cs2.on_mod_settings_changed, _G.cs2.raise_mod_settings_changed =
	event("mod_settings_changed", "StringOrNil", "nil", "nil", "nil", "nil")

---Event raised immediately before wiping the global state. The `ResetData`
---object may be used to hand over information that needs to be re-copied
---into the new global state.
--- * Arg 1 - `Cybersyn.ResetData` - The reset data object. This is a table that can be used to store information that needs to be copied into the new global state.
_G.cs2.on_reset, _G.cs2.raise_reset =
	event("reset", "Cybersyn.ResetData", "nil", "nil", "nil", "nil")

---Event raised on startup or after clearing the global state.
---* Arg 1 - `Cybersyn.ResetData` - The reset data object. May contain handoff
---information if called after a reset.
_G.cs2.on_startup, _G.cs2.raise_startup =
	event("startup", "Cybersyn.ResetData", "nil", "nil", "nil", "nil")

--------------------------------------------------------------------------------
-- Factorio world events
--------------------------------------------------------------------------------

_G.cs2.on_built_train_stop, _G.cs2.raise_built_train_stop =
	event("built_train_stop", "LuaEntity", "nil", "nil", "nil", "nil")

_G.cs2.on_broken_train_stop, _G.cs2.raise_broken_train_stop =
	event("broken_train_stop", "LuaEntity", "nil", "nil", "nil", "nil")

_G.cs2.on_built_rail, _G.cs2.raise_built_rail =
	event("built_rail", "LuaEntity", "nil", "nil", "nil", "nil")

_G.cs2.on_broken_rail, _G.cs2.raise_broken_rail =
	event("broken_rail", "LuaEntity", "nil", "nil", "nil", "nil")

---@alias TagsOrNil Tags|nil

_G.cs2.on_built_combinator, _G.cs2.raise_built_combinator =
	event("built_combinator", "LuaEntity", "TagsOrNil", "nil", "nil", "nil")

_G.cs2.on_built_combinator_ghost, _G.cs2.raise_built_combinator_ghost =
	event("built_combinator_ghost", "LuaEntity", "nil", "nil", "nil", "nil")

_G.cs2.on_broken_combinator, _G.cs2.raise_broken_combinator =
	event("broken_combinator", "LuaEntity", "nil", "nil", "nil", "nil")

_G.cs2.on_broken_train_stock, _G.cs2.raise_broken_train_stock =
	event("broken_train_stock", "LuaEntity", "LuaTrain", "nil", "nil", "nil")

-- Event raised when a relevant entity changes its physical configuration.
_G.cs2.on_entity_repositioned, _G.cs2.raise_entity_repositioned =
	event("entity_repositioned", "string", "LuaEntity", "nil", "nil", "nil")

-- Event raised when a relevant entity is renamed.
_G.cs2.on_entity_renamed, _G.cs2.raise_entity_renamed =
	event("entity_renamed", "string", "LuaEntity", "string", "nil", "nil")

_G.cs2.on_surface, _G.cs2.raise_surface =
	event("surface", "int", "string", "nil", "nil", "nil")

---Event raised when equipment recognized by the layout algorithm is built.
_G.cs2.on_built_equipment, _G.cs2.raise_built_equipment =
	event("built_equipment", "LuaEntity", "nil", "nil", "nil", "nil")

-- Event raised when equipment recognized by the layout algorithm is removed.
_G.cs2.on_broken_equipment, _G.cs2.raise_broken_equipment =
	event("broken_equipment", "LuaEntity", "nil", "nil", "nil", "nil")

-- Event raised when an ephemeral combinator has its settings changed,
-- possibly en masse, by a factorio copy and paste or blueprint op.
_G.cs2.on_entity_settings_pasted, _G.cs2.raise_entity_settings_pasted = event(
	"entity_settings_pasted",
	"EventData.on_entity_settings_pasted",
	"nil",
	"nil",
	"nil",
	"nil"
)

_G.cs2.on_luatrain_created, _G.cs2.raise_luatrain_created = event(
	"luatrain_created",
	"EventData.on_train_created",
	"nil",
	"nil",
	"nil",
	"nil"
)

_G.cs2.on_luatrain_changed_state, _G.cs2.raise_luatrain_changed_state = event(
	"luatrain_changed_state",
	"EventData.on_train_changed_state",
	"nil",
	"nil",
	"nil",
	"nil"
)

---Event raised when a blueprint is pasted into the world.
_G.cs2.on_blueprint_built, _G.cs2.raise_blueprint_built = event(
	"blueprint_built",
	"BlueprintLib.BlueprintInfo",
	"nil",
	"nil",
	"nil",
	"nil"
)

_G.cs2.on_blueprint_setup, _G.cs2.raise_blueprint_setup = event(
	"blueprint_setup",
	"BlueprintLib.BlueprintInfo",
	"nil",
	"nil",
	"nil",
	"nil"
)

---Event raised when a relevant entity is "selected" as defined by
---Factorio.
_G.cs2.on_selected, _G.cs2.raise_selected =
	event("selected", "LuaEntity", "LuaEntity", "LuaPlayer", "nil", "nil")

---Event raised when a player clears his cursor.
_G.cs2.on_cursor_cleared, _G.cs2.raise_cursor_cleared =
	event("cursor_cleared", "LuaPlayer", "nil", "nil", "nil", "nil")

--------------------------------------------------------------------------------
-- Cybersyn vehicle object events
--------------------------------------------------------------------------------

_G.cs2.on_vehicle_created, _G.cs2.raise_vehicle_created =
	event("vehicle_created", "Cybersyn.Vehicle", "nil", "nil", "nil", "nil")

_G.cs2.on_vehicle_destroyed, _G.cs2.raise_vehicle_destroyed =
	event("vehicle_destroyed", "Cybersyn.Vehicle", "nil", "nil", "nil", "nil")

_G.cs2.on_train_layout_created, _G.cs2.raise_train_layout_created = event(
	"train_layout_created",
	"Cybersyn.TrainLayout",
	"nil",
	"nil",
	"nil",
	"nil"
)

---@alias Cybersyn.TrainOrNil Cybersyn.Train|nil
---@alias Cybersyn.TrainStopOrNil Cybersyn.TrainStop|nil

---Event raised when a train arrives at a stop.
_G.cs2.on_train_arrived, _G.cs2.raise_train_arrived = event(
	"train_arrived",
	"LuaTrain",
	"Cybersyn.Train",
	"Cybersyn.TrainStop",
	"nil",
	"nil"
)

---Event raised when a train departs a stop.
_G.cs2.on_train_departed, _G.cs2.raise_train_departed = event(
	"train_departed",
	"LuaTrain",
	"Cybersyn.Train",
	"Cybersyn.TrainStop",
	"nil",
	"nil"
)

--------------------------------------------------------------------------------
-- Cybersyn combinator object events
--------------------------------------------------------------------------------

_G.cs2.on_combinator_created, _G.cs2.raise_combinator_created =
	event("combinator_created", "Cybersyn.Combinator", "nil", "nil", "nil", "nil")

---Event raised when a combinator is destroyed.
---* Arg 1 - `Cybersyn.Combinator` - The combinator.
---* Arg 2 - `boolean` - `true` if this is the result of a reset, `false` if it is the result of actual combinator destruction.
_G.cs2.on_combinator_destroyed, _G.cs2.raise_combinator_destroyed = event(
	"combinator_destroyed",
	"Cybersyn.Combinator",
	"boolean",
	"nil",
	"nil",
	"nil"
)

---@alias CybersynNodeOrNil Cybersyn.Node|nil

---Event raised when a combinator is associated or disassociated with a node.
--- * Arg 1 - `Cybersyn.Combinator` - The combinator.
--- * Arg 2 - `Cybersyn.Node|nil` - The node, if any, that the combinator is now associated with.
--- * Arg 3 - `Cybersyn.Node|nil` - The node, if any, that the combinator was previously associated with.
_G.cs2.on_combinator_node_associated, _G.cs2.raise_combinator_node_associated =
	event(
		"combinator_node_associated",
		"Cybersyn.Combinator",
		"CybersynNodeOrNil",
		"CybersynNodeOrNil",
		"nil",
		"nil"
	)

---Event raised when a setting changes on a combinator OR a ghost.
--- * Arg 1 - `Cybersyn.Combinator.Ephemeral` - The combinator or ghost.
--- * Arg 2 - `string|nil` - The name of the setting that changed. If `nil`, you must assume that any or all of the settings have changed.
--- * Arg 3 - `any` - The new value of the setting, if known.
--- * Arg 4 - `any` - The old value of the setting, if known.
_G.cs2.on_combinator_or_ghost_setting_changed, _G.cs2.raise_combinator_or_ghost_setting_changed =
	event(
		"combinator_or_ghost_setting_changed",
		"Cybersyn.Combinator.Ephemeral",
		"StringOrNil",
		"any",
		"any",
		"nil"
	)

---Event raised when a real combinator's settings change, including when it
---is first built.
--- * Arg 1 - `Cybersyn.Combinator` - The combinator.
--- * Arg 2 - `string|nil` - The name of the setting that changed. If `nil`, you must assume that any or all of the settings have changed.
--- * Arg 3 - `any` - The new value of the setting, if known.
--- * Arg 4 - `any` - The old value of the setting, if known.
_G.cs2.on_combinator_setting_changed, _G.cs2.raise_combinator_setting_changed =
	event(
		"combinator_setting_changed",
		"Cybersyn.Combinator",
		"StringOrNil",
		"any",
		"any",
		"nil"
	)

--------------------------------------------------------------------------------
-- Cybersyn node object events
--------------------------------------------------------------------------------

---Event fired when the collection of topologies changes.
_G.cs2.on_topologies, _G.cs2.raise_topologies =
	event("topologies", "Cybersyn.Topology", "string", "nil", "nil", "nil")

---Event raised when the set of combinators associated with a node changes.
_G.cs2.on_node_combinator_set_changed, _G.cs2.raise_node_combinator_set_changed =
	event(
		"node_combinator_set_changed",
		"Cybersyn.Node",
		"nil",
		"nil",
		"nil",
		"nil"
	)

_G.cs2.on_node_created, _G.cs2.raise_node_created =
	event("node_created", "Cybersyn.Node", "nil", "nil", "nil", "nil")

_G.cs2.on_node_destroyed, _G.cs2.raise_node_destroyed =
	event("node_destroyed", "Cybersyn.Node", "nil", "nil", "nil", "nil")

---Event raised when internal data of a node (such as a train stop's allow list)
---changes.
_G.cs2.on_node_data_changed, _G.cs2.raise_node_data_changed =
	event("node_data_changed", "Cybersyn.Node", "nil", "nil", "nil", "nil")

_G.cs2.on_train_stop_layout_changed, _G.cs2.raise_train_stop_layout_changed =
	event(
		"train_stop_layout_changed",
		"Cybersyn.TrainStop",
		"Cybersyn.TrainStopLayout",
		"nil",
		"nil",
		"nil"
	)

_G.cs2.on_train_stop_equipment_changed, _G.cs2.raise_train_stop_equipment_changed =
	event(
		"train_stop_equipment_changed",
		"Cybersyn.TrainStop",
		"Cybersyn.TrainStopLayout",
		"nil",
		"nil",
		"nil"
	)

---Event raised when the automatically-inferred pattern of equipment at
---the given stop changes. More coarse-grained than `train_stop_equipment_changed`.
_G.cs2.on_train_stop_pattern_changed, _G.cs2.raise_train_stop_pattern_changed =
	event(
		"train_stop_pattern_changed",
		"Cybersyn.TrainStop",
		"Cybersyn.TrainStopLayout",
		"nil",
		"nil",
		"nil"
	)

_G.cs2.on_train_stop_shared_inventory_changed, _G.cs2.raise_train_stop_shared_inventory_changed =
	event(
		"train_stop_shared_inventory_changed",
		"Cybersyn.TrainStop",
		"nil",
		"nil",
		"nil",
		"nil"
	)

--------------------------------------------------------------------------------
-- Inventories and deliveries.
--------------------------------------------------------------------------------

---Event raised only when the dispatch loop is paused and then stepped
---manually by the user.
_G.cs2.on_debug_loop, _G.cs2.raise_debug_loop =
	event("debug_loop", "string", "Cybersyn.LogisticsThread", "nil", "nil", "nil")

_G.cs2.on_inventory_created, _G.cs2.raise_inventory_created =
	event("inventory_created", "Cybersyn.Inventory", "nil", "nil", "nil", "nil")

_G.cs2.on_inventory_destroyed, _G.cs2.raise_inventory_destroyed =
	event("inventory_destroyed", "Cybersyn.Inventory", "nil", "nil", "nil", "nil")

_G.cs2.on_delivery_created, _G.cs2.raise_delivery_created =
	event("delivery_created", "Cybersyn.Delivery", "nil", "nil", "nil", "nil")

_G.cs2.on_delivery_destroyed, _G.cs2.raise_delivery_destroyed =
	event("delivery_destroyed", "Cybersyn.Delivery", "nil", "nil", "nil", "nil")

---Event raised when a delivery's state changes. Not raised at the initial
---creation of the delivery.
--- * Arg 1 - `Cybersyn.Delivery` - The delivery.
--- * Arg 2 - `Cybersyn.Delivery.State` - The new state of the delivery.
--- * Arg 3 - `Cybersyn.Delivery.State` - The previous state of the delivery.
_G.cs2.on_delivery_state_changed, _G.cs2.raise_delivery_state_changed = event(
	"delivery_state_changed",
	"Cybersyn.Delivery",
	"string",
	"StringOrNil",
	"nil",
	"nil"
)
