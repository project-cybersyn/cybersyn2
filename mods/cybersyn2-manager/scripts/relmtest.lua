local relm = require("__cybersyn2__.lib.relm")
local ultros = require("__cybersyn2__.lib.ultros")
local log = require("__cybersyn2__.lib.logging")
local mgr = _G.mgr

local Pr = relm.Primitive

local Titlebar = relm.define_element({
	name = "Titlebar",
	render = function(props)
		return Pr({ type = "flow", direction = "horizontal" }, {
			Pr({
				type = "label",
				caption = props.caption,
				style = "frame_title",
				ignored_by_interaction = true,
			}),
			Pr({
				type = "empty-widget",
				style = "flib_titlebar_drag_handle",
				ignored_by_interaction = true,
			}),
			Pr({
				message_handler = ultros.transform_events(
					defines.events.on_gui_click,
					"close"
				),
				type = "sprite-button",
				style = "frame_action_button",
				sprite = "utility/close",
				hovered_sprite = "utility/close",
				mouse_button_filter = { "left" },
				listen = true,
			}),
		})
	end,
})

local Window = relm.define_element({
	name = "Window",
	render = function(props)
		return Pr({ type = "frame", direction = "vertical" }, {
			Titlebar({ caption = props.caption }),
			Pr({
				type = "scroll-pane",
				style_mods = {
					vertically_stretchable = true,
					horizontally_stretchable = true,
				},
			}, props.children),
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
		return Window({ caption = "Hello from Relm! " .. n })
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
	local handle = relm.root_ref(storage.test_root_id)
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
