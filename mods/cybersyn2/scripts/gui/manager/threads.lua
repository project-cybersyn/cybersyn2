local events = require("lib.core.event")
local relm = require("lib.core.relm.relm")
local ultros = require("lib.core.relm.ultros")
local relm_util = require("lib.core.relm.util")
local cmt_lib = require("lib.core.cmt")
local tlib = require("lib.core.table")

local Pr = relm.Primitive
local HF = ultros.HFlow
local VF = ultros.VFlow
local table_size = table_size
local EMPTY = tlib.EMPTY

local lib = {}

local SchedulerEntry = relm.define("Manager.SchedulerEntry", function()
	relm_util.use_timer_handler(120, function(me) relm.paint(me) end)

	local tasks = relm.use_result(function() return cmt_lib.get_tasks() end)
	local n_tasks = table_size(tasks)
	local n_sleeping = 0
	local n_running = 0
	local n_realtime = 0
	for _, task in pairs(tasks) do
		if not task._cmt_awake then n_sleeping = n_sleeping + 1 end
		if task._cmt_awake and not task._cmt_dead then n_running = n_running + 1 end
		if task._cmt_realtime then n_realtime = n_realtime + 1 end
	end
	local max_work_per_frame = cmt_lib.get_max_work_per_frame() or 0

	return Pr({
		type = "frame",
		direction = "vertical",
		style = "shallow_frame",
		horizontally_stretchable = true,
	}, {
		ultros.RtLabel("[font=default-bold]Scheduler[/font]"),
		Pr({ type = "line" }),
		Pr({ type = "table", column_count = 5, horizontally_stretchable = true }, {
			HF({ horizontally_stretchable = true }, {
				ultros.RtLabel({ "", "[font=default-bold]Threads[/font] ", n_tasks }),
			}),
			HF({ horizontally_stretchable = true }, {
				ultros.RtLabel({
					"",
					"[font=default-bold]Sleeping[/font] ",
					n_sleeping,
				}),
			}),
			HF({ horizontally_stretchable = true }, {
				ultros.RtLabel({
					"",
					"[font=default-bold]Running[/font] ",
					n_running,
				}),
			}),
			HF({ horizontally_stretchable = true }, {
				ultros.RtLabel({
					"",
					"[font=default-bold]Realtime[/font] ",
					n_realtime,
				}),
			}),
			HF({ horizontally_stretchable = true }, {
				ultros.RtLabel("[font=default-bold]Global Work Cap[/font]"),
				ultros.UncontrolledInput({
					numeric = true,
					value = max_work_per_frame,
					width = 60,
					on_change = function(_, next_wpf)
						cmt_lib.set_max_work_per_frame(next_wpf)
					end,
				}),
			}),
		}),
	})
end)

local DispatcherEntry = relm.define("Manager.DispatcherEntry", function()
	relm_util.use_timer_handler(120, function(me) relm.paint(me) end)

	local tasks = relm.use_result(function() return cmt_lib.get_tasks() end)
		or EMPTY
	local task = tlib.find(
		tasks,
		function(t) return t._cmt_name == "delivery_dispatch" end
	) or EMPTY
	---@cast task Cybersyn.Internal.DeliveryDispatchThread
	local n_dispatches = task.n_dispatches or 0
	local fpd = (task.frames_per_dispatch or EMPTY)[1] or 0

	return Pr({
		type = "frame",
		direction = "vertical",
		style = "shallow_frame",
		horizontally_stretchable = true,
	}, {
		ultros.RtLabel("[font=default-bold]Delivery Dispatch[/font]"),
		Pr({ type = "line" }),
		Pr({ type = "table", column_count = 5, horizontally_stretchable = true }, {
			HF({ horizontally_stretchable = true }, {
				ultros.RtLabel({
					"",
					"[font=default-bold]Dispatches[/font] ",
					n_dispatches,
				}),
			}),
			HF({ horizontally_stretchable = true }, {
				ultros.RtLabel({
					"",
					"[font=default-bold]Frames per Dispatch[/font] ",
					fpd,
				}),
			}),
		}),
	})
end)

local TrainMonitorEntry = relm.define("Manager.TrainMonitorEntry", function()
	relm_util.use_timer_handler(120, function(me) relm.paint(me) end)

	local tasks = relm.use_result(function() return cmt_lib.get_tasks() end)
		or EMPTY
	local task = tlib.find(
		tasks,
		function(t) return t._cmt_name == "TrainMonitor" end
	) or EMPTY
	local wpi = (task._cmt_work_per_iter or EMPTY)[1] or 0
	local work_cap = task._cmt_work_cap or 0
	local spike_cap = task._cmt_spike_cap or 0

	return Pr({
		type = "frame",
		direction = "vertical",
		style = "shallow_frame",
		horizontally_stretchable = true,
	}, {
		ultros.RtLabel("[font=default-bold]Train Monitor[/font]"),
		Pr({ type = "line" }),
		Pr({ type = "table", column_count = 5, horizontally_stretchable = true }, {
			HF({ horizontally_stretchable = true }, {
				ultros.RtLabel({
					"",
					"[font=default-bold]Work per Iteration[/font] ",
					wpi,
				}),
			}),
			HF({ horizontally_stretchable = true }, {
				ultros.RtLabel("[font=default-bold]Work Cap[/font]"),
				ultros.UncontrolledInput({
					numeric = true,
					value = work_cap,
					width = 60,
					on_change = function(_, next_work_cap)
						task._cmt_work_cap = next_work_cap
					end,
				}),
			}),
			HF({ horizontally_stretchable = true }, {
				ultros.RtLabel("[font=default-bold]Spike Cap[/font]"),
				ultros.UncontrolledInput({
					numeric = true,
					value = spike_cap,
					width = 60,
					on_change = function(_, next_spike_cap)
						task._cmt_spike_cap = next_spike_cap
					end,
				}),
			}),
		}),
	})
end)

local DeliveryMonitorEntry = relm.define(
	"Manager.DeliveryMonitorEntry",
	function()
		relm_util.use_timer_handler(120, function(me) relm.paint(me) end)

		local tasks = relm.use_result(function() return cmt_lib.get_tasks() end)
			or EMPTY
		local task = tlib.find(
			tasks,
			function(t) return t._cmt_name == "delivery_monitor" end
		) or EMPTY
		local wpi = (task._cmt_work_per_iter or EMPTY)[1] or 0
		local work_cap = task._cmt_work_cap or 0
		local spike_cap = task._cmt_spike_cap or 0

		return Pr({
			type = "frame",
			direction = "vertical",
			style = "shallow_frame",
			horizontally_stretchable = true,
		}, {
			ultros.RtLabel("[font=default-bold]Delivery Monitor[/font]"),
			Pr({ type = "line" }),
			Pr(
				{ type = "table", column_count = 5, horizontally_stretchable = true },
				{
					HF({ horizontally_stretchable = true }, {
						ultros.RtLabel({
							"",
							"[font=default-bold]Work per Iteration[/font] ",
							wpi,
						}),
					}),
					HF({ horizontally_stretchable = true }, {
						ultros.RtLabel("[font=default-bold]Work Cap[/font]"),
						ultros.UncontrolledInput({
							numeric = true,
							value = work_cap,
							width = 60,
							on_change = function(_, next_work_cap)
								task._cmt_work_cap = next_work_cap
							end,
						}),
					}),
					HF({ horizontally_stretchable = true }, {
						ultros.RtLabel("[font=default-bold]Spike Cap[/font]"),
						ultros.UncontrolledInput({
							numeric = true,
							value = spike_cap,
							width = 60,
							on_change = function(_, next_spike_cap)
								task._cmt_spike_cap = next_spike_cap
							end,
						}),
					}),
				}
			),
		})
	end
)

local DispatchLoop = relm.define("Manager.DispatchLoop", function(props)
	local task = props.task
	local wpi = (task._cmt_work_per_iter or EMPTY)[1] or 0
	local work_cap = task._cmt_work_cap or 0
	local spike_cap = task._cmt_spike_cap or 0

	return Pr({
		type = "frame",
		direction = "vertical",
		style = "shallow_frame",
		horizontally_stretchable = true,
	}, {
		ultros.RtLabel({
			"",
			"[font=default-bold]Logistics:[/font] ",
			task._cmt_name or "",
		}),
		Pr({ type = "line" }),
		Pr({ type = "table", column_count = 5, horizontally_stretchable = true }, {
			HF({ horizontally_stretchable = true }, {
				ultros.RtLabel({
					"",
					"[font=default-bold]Work per Iteration[/font] ",
					wpi,
				}),
			}),
			HF({ horizontally_stretchable = true }, {
				ultros.RtLabel("[font=default-bold]Work Cap[/font]"),
				ultros.UncontrolledInput({
					numeric = true,
					value = work_cap,
					width = 60,
					on_change = function(_, next_work_cap)
						task._cmt_work_cap = next_work_cap
					end,
				}),
			}),
			HF({ horizontally_stretchable = true }, {
				ultros.RtLabel("[font=default-bold]Spike Cap[/font]"),
				ultros.UncontrolledInput({
					numeric = true,
					value = spike_cap,
					width = 60,
					on_change = function(_, next_spike_cap)
						task._cmt_spike_cap = next_spike_cap
					end,
				}),
			}),
		}),
	})
end)

local DispatchLoops = relm.define("Manager.DispatchLoops", function(props)
	relm_util.use_timer_handler(120, function(me) relm.paint(me) end)

	local tasks = relm.use_result(function() return cmt_lib.get_tasks() end)
		or EMPTY
	local logistics_tasks = tlib.t_map_a(tasks, function(task)
		if string.find(task._cmt_name or "", "^logistics_") then
			return DispatchLoop({ task = task })
		end
	end)

	return VF(
		{ horizontally_stretchable = true, vertically_stretchable = true },
		logistics_tasks
	)
end)

lib.ThreadsTab = relm.define(
	"Manager.ThreadsTab",
	function()
		return Pr({
			type = "scroll-pane",
			direction = "vertical",
			horizontally_stretchable = true,
			vertically_stretchable = true,
			horizontal_scroll_policy = "never",
			vertical_scroll_policy = "always",
		}, {
			SchedulerEntry({}),
			DispatcherEntry({}),
			TrainMonitorEntry({}),
			DeliveryMonitorEntry({}),
			DispatchLoops({}),
		})
	end
)

return lib
