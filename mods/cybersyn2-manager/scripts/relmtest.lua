local relm = require("__cybersyn2__.lib.relm")
local log = require("__cybersyn2__.lib.logging")
local mgr = _G.mgr

local Primitive = relm.Primitive

local Titlebar = relm.define_element({
	name = "Titlebar",
	render = function(props)
		return Primitive({ type = "flow", direction = "horizontal" }, {
			Primitive({
				type = "label",
				caption = props.caption,
				style = "frame_title",
				ignored_by_interaction = true,
			}),
			Primitive({
				type = "empty-widget",
				style = "flib_titlebar_drag_handle",
				ignored_by_interaction = true,
			}),
			Primitive({
				type = "sprite-button",
				style = "frame_action_button",
				sprite = "utility/close",
				hovered_sprite = "utility/close",
				mouse_button_filter = { "left" },
			}),
		})
	end,
})

mgr.on_init(relm.init, true)

mgr.on_manager_toggle(function(idx)
	local player = game.get_player(idx)
	if not player then
		return
	end
	local screen = player.gui.screen
	if screen["relm"] then
		log.debug("Destroying relm root")
		relm.root_destroy(screen["relm"].tags.__relm_root)
	else
		log.debug("Creating relm root")
		relm.root_create(screen, Titlebar({ caption = "Hello from Relm!" }), "relm")
	end
end)
