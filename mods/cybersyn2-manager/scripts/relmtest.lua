local relm = require("__cybersyn2__.lib.relm")
local ultros = require("__cybersyn2__.lib.ultros")
local log = require("__cybersyn2__.lib.logging")
local mgr = _G.mgr

local Pr = relm.Primitive
local VF = ultros.VFlow
local HF = ultros.HFlow
local Button = ultros.Button
local SpriteButton = ultros.SpriteButton

local Widget = relm.define_element({
	name = "Widget",
	render = function(props)
		return HF({
			Pr({
				type = "label",
				caption = props.caption,
				ignored_by_interaction = true,
			}),
			SpriteButton({
				style = "frame_action_button",
				sprite = "utility/close",
				hovered_sprite = "utility/close",
				mouse_button_filter = { "left" },
				on_click = "delete_widget",
			}),
		})
	end,
})

local Widgets = relm.define_element({
	name = "Widgets",
	render = function(props, state)
		local children = {}
		for i = 1, state do
			table.insert(children, Widget({ caption = "Widget " .. i }))
		end
		table.insert(
			children,
			Button({
				caption = "Add Widget",
				on_click = "add_widget",
			})
		)
		return VF(children)
	end,
	state = function()
		return 0
	end,
	message = function(me, payload, props, state)
		if payload.key == "add_widget" then
			log.trace("Adding widget")
			relm.set_state(me, function(prev)
				return prev + 1
			end)
			return true
		elseif payload.key == "delete_widget" then
			log.trace("Deleting widget")
			relm.set_state(me, function(prev)
				if prev > 0 then
					return prev - 1
				else
					return 0
				end
			end)
			return true
		end
	end,
})

local Tabs = relm.define_element({
	name = "Tabs",
	render = function(props)
		return Pr({ type = "tabbed-pane" }, {
			Pr({
				type = "tab",
				caption = "Tab 1",
			}),
			Pr({
				type = "tab",
				caption = "Tab 2",
			}),
			Widgets(),
			Widgets(),
		})
	end,
})

relm.define_element({
	name = "Root",
	render = function(props, state)
		local n = state and state.n or 0
		relm.use_effect(n, function()
			log.trace("use_effect callback", n)
			return n + 100
		end, function(p)
			log.trace("use_effect cleanup", p)
		end)
		return ultros.WindowFrame({ caption = "Title" }, { Widgets(), Tabs() })
	end,
	message = function(me, payload, props, state)
		log.trace("Relm root got message", payload)
		if payload.key == "close" then
			relm.root_destroy(props.root_id)
			return true
		end
	end,
})

mgr.on_manager_toggle(function(idx)
	local player = game.get_player(idx)
	if not player then
		return
	end
	local screen = player.gui.screen
	if not screen["relm"] then
		log.debug("Creating relm root")
		storage.test_root_id = relm.root_create(screen, "Root", {}, "relm")
	end
	local handle = relm.root_handle(storage.test_root_id)
	if handle then
		relm.set_state(handle, function(prev)
			local n = prev and prev.n or 0
			return { n = n + 1 }
		end)
	end
end)

relm.install_event_handlers()

mgr.on_init(relm.init, true)
mgr.on_load(relm.on_load, true)
