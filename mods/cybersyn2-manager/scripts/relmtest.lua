local relm = require("__cybersyn2__.lib.relm")
local log = require("__cybersyn2__.lib.logging")
local mgr = _G.mgr

local Pr = relm.Primitive

local EventMap = relm.define_element({
	name = "EventMap",
	render = function(_, _, children)
		return children
	end,
	message = function(me, payload, props)
		if payload.key == "factorio_event" then
			local mapped = props[payload.event.name]
			if mapped then
				relm.bubble(me, {
					key = mapped --[[@as string]],
					event = payload.event,
				})
				return true
			end
		end
	end,
})

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
			EventMap(
				{ [defines.events.on_gui_click] = "close" },
				Pr({
					type = "sprite-button",
					style = "frame_action_button",
					sprite = "utility/close",
					hovered_sprite = "utility/close",
					mouse_button_filter = { "left" },
					listen = true,
				})
			),
		})
	end,
})

local Root = relm.define_element({
	name = "Root",
	render = function(props, state)
		local n = state and state.n or 0
		return Titlebar({ caption = "Hello from Relm! " .. n })
	end,
	message = function(me, payload, props, state)
		log.trace("Relm root got message", payload)
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
