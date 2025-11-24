local strace_lib = require("__cybersyn2__.lib.core.strace")
local relm = require("__cybersyn2__.lib.core.relm.relm")
local relm_helpers = require("__cybersyn2__.lib.core.relm.util")
local ultros = require("__cybersyn2__.lib.core.relm.ultros")
local tlib = require("__cybersyn2__.lib.core.table")
local siglib = require("__cybersyn2__.lib.signal")
local mgr = _G.mgr

local strace = strace_lib.strace
local Pr = relm.Primitive
local VF = ultros.VFlow
local HF = ultros.HFlow
local empty = tlib.empty

_G.mgr.SignalCountsButtons = relm.define_element({
	name = "Cybersyn.Manager.SignalCountsButtons",
	render = function(props)
		local signal_counts = props.signal_counts or empty
		return tlib.t_map_a(signal_counts, function(qty, item)
			-- Support sets
			if qty == true then qty = 1 end
			local item_signal = siglib.key_to_signal(item)
			return Pr({
				type = "choose-elem-button",
				elem_type = "signal",
				elem_value = item_signal,
				enabled = false,
				style = props.button_style or "flib_slot_button_green",
			}, {
				Pr({
					type = "label",
					style = "cs2_label_signal_count_inventory",
					ignored_by_interaction = true,
					caption = siglib.format_signal_count(qty),
				}),
			})
		end)
	end,
})

---@param handle Relm.Handle
local function view_effect(handle, filter)
	local view_id = remote.call("cybersyn2", "create_view", filter.type, filter)
	if not view_id then return 0 end
	local snapshot = remote.call("cybersyn2", "read_view", view_id) or empty
	relm.set_state(handle, function(current_state)
		---@cast current_state table
		local x = tlib.assign(current_state, { view_id = view_id })
		tlib.assign(x, snapshot)
		return x
	end)
	return view_id
end

---@param view_id Id
local function view_cleanup(view_id)
	if view_id then remote.call("cybersyn2", "destroy_view", view_id) end
end

_G.mgr.ViewWrapper = relm.define_element({
	name = "Cybersyn.Manager.ViewWrapper",
	render = function(props, state)
		---@cast state table
		relm.use_effect(props.filter or 0, view_effect, view_cleanup)
		relm_helpers.use_event("mgr.on_view_updated")
		local child = props.child
		local next_props = tlib.assign({}, child.props)
		tlib.assign(next_props, state)
		child.props = next_props
		return child
	end,
	state = function() return {} end,
	message = function(me, payload, props, state)
		---@cast state table
		if payload.key == "mgr.on_view_updated" then
			local updated_view_id = payload[1]
			local view_id = state.view_id
			if updated_view_id == view_id then
				local snapshot = remote.call("cybersyn2", "read_view", view_id) or empty
				relm.set_state(me, function(current_state)
					---@cast current_state table
					return tlib.assign(current_state, snapshot)
				end)
			end
			return true
		else
			return false
		end
	end,
})
