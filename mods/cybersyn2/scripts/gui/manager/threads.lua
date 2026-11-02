local events = require("lib.core.event")
local relm = require("lib.core.relm.relm")
local ultros = require("lib.core.relm.ultros")
local relm_util = require("lib.core.relm.util")
local cmt_lib = require("lib.core.cmt")
local tlib = require("lib.core.table")
local nlib = require("lib.core.math.numeric")

local Pr = relm.Primitive
local HF = ultros.HFlow
local VF = ultros.VFlow
local table_size = table_size
local clamp = nlib.clamp
local EMPTY = tlib.EMPTY
local strformat = string.format

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
		ultros.RtLabel({ "cybersyn2-manager.threads-scheduler" }),
		Pr({ type = "line" }),
		Pr({ type = "table", column_count = 5, horizontally_stretchable = true }, {
			HF({ horizontally_stretchable = true }, {
				ultros.RtLabel({ "cybersyn2-manager.threads-threads", n_tasks }),
			}),
			HF({ horizontally_stretchable = true }, {
				ultros.RtLabel({ "cybersyn2-manager.threads-sleeping", n_sleeping }),
			}),
			HF({ horizontally_stretchable = true }, {
				ultros.RtLabel({ "cybersyn2-manager.threads-running", n_running }),
			}),
			HF({ horizontally_stretchable = true }, {
				ultros.RtLabel({ "cybersyn2-manager.threads-realtime", n_realtime }),
			}),
			HF({ horizontally_stretchable = true }, {
				ultros.RtLabel({ "cybersyn2-manager.threads-global-work-cap" }),
				ultros.UncontrolledInput({
					numeric = true,
					value = max_work_per_frame,
					width = 60,
					on_change = function(_, next_wpf)
						cmt_lib.set_max_work_per_frame(clamp(next_wpf, 0, 1000000, 100))
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
		ultros.RtLabel({ "cybersyn2-manager.threads-delivery-dispatch" }),
		Pr({ type = "line" }),
		Pr({ type = "table", column_count = 5, horizontally_stretchable = true }, {
			HF({ horizontally_stretchable = true }, {
				ultros.RtLabel({ "cybersyn2-manager.threads-dispatches", n_dispatches }),
			}),
			HF({ horizontally_stretchable = true }, {
				ultros.RtLabel({
					"cybersyn2-manager.threads-frames-per-dispatch",
					strformat("%.2f", fpd),
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
	---@cast task Cybersyn.Internal.TrainMonitor
	local loop_length_era = (task.loop_length_era or EMPTY)[1] or 0
	local n_luatrains = task.n_luatrains or 0
	local n_cstrains = task.n_cstrains or 0
	local wpi = (task._cmt_work_per_iter or EMPTY)[1] or 0
	local work_cap = task._cmt_work_cap or 0

	return Pr({
		type = "frame",
		direction = "vertical",
		style = "shallow_frame",
		horizontally_stretchable = true,
	}, {
		ultros.RtLabel({ "cybersyn2-manager.threads-train-monitor" }),
		Pr({ type = "line" }),
		Pr({ type = "table", column_count = 5, horizontally_stretchable = true }, {
			HF({ horizontally_stretchable = true }, {
				ultros.RtLabel({
					"cybersyn2-manager.threads-work-per-iteration",
					strformat("%.2f", wpi),
				}),
			}),
			HF({ horizontally_stretchable = true }, {
				ultros.RtLabel({
					"cybersyn2-manager.threads-loop-length",
					strformat("%.2f", loop_length_era),
				}),
			}),
			HF({ horizontally_stretchable = true }, {
				ultros.RtLabel({ "cybersyn2-manager.threads-luatrains", n_luatrains }),
			}),
			HF({ horizontally_stretchable = true }, {
				ultros.RtLabel({ "cybersyn2-manager.threads-cstrains", n_cstrains }),
			}),
			HF({ horizontally_stretchable = true }, {
				ultros.RtLabel({ "cybersyn2-manager.threads-work-cap" }),
				ultros.UncontrolledInput({
					numeric = true,
					value = work_cap,
					width = 60,
					on_change = function(_, next_work_cap)
						task._cmt_work_cap = clamp(next_work_cap, 0, 1000000, 100)
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
		---@cast task Cybersyn.Internal.DeliveryMonitor
		local wpi = (task._cmt_work_per_iter or EMPTY)[1] or 0
		local work_cap = task._cmt_work_cap or 0
		local n_deliveries = task.n_deliveries or 0
		local n_active = task.n_active or 0
		local n_finalized = task.n_finalized or 0
		local loop_length_era = (task.loop_length_era or EMPTY)[1] or 0

		return Pr({
			type = "frame",
			direction = "vertical",
			style = "shallow_frame",
			horizontally_stretchable = true,
		}, {
			ultros.RtLabel({ "cybersyn2-manager.threads-delivery-monitor" }),
			Pr({ type = "line" }),
			Pr(
				{ type = "table", column_count = 5, horizontally_stretchable = true },
				{
					HF({ horizontally_stretchable = true }, {
						ultros.RtLabel({
							"cybersyn2-manager.threads-work-per-iteration",
							strformat("%.2f", wpi),
						}),
					}),
					HF({ horizontally_stretchable = true }, {
						ultros.RtLabel({
							"cybersyn2-manager.threads-loop-length",
							strformat("%.2f", loop_length_era),
						}),
					}),
					HF({ horizontally_stretchable = true }, {
						ultros.RtLabel({
							"cybersyn2-manager.threads-deliveries",
							n_deliveries,
						}),
					}),
					HF({ horizontally_stretchable = true }, {
						ultros.RtLabel({ "cybersyn2-manager.threads-active", n_active }),
					}),
					HF({ horizontally_stretchable = true }, {
						ultros.RtLabel({
							"cybersyn2-manager.threads-finalized",
							n_finalized,
						}),
					}),
					HF({ horizontally_stretchable = true }, {
						ultros.RtLabel({ "cybersyn2-manager.threads-work-cap" }),
						ultros.UncontrolledInput({
							numeric = true,
							value = work_cap,
							width = 60,
							on_change = function(_, next_work_cap)
								task._cmt_work_cap = clamp(next_work_cap, 0, 1000000, 100)
							end,
						}),
					}),
				}
			),
		})
	end
)

local DispatchLoop = relm.define(
	"Manager.DispatchLoop",
	---@param props {task: Cybersyn.LogisticsThread}
	function(props)
		local task = props.task
		local wpi = (task._cmt_work_per_iter or EMPTY)[1] or 0
		local work_cap = task._cmt_work_cap or 0
		local n_nodes = task.n_nodes or 0
		local n_providers = task.n_providers or 0
		local requesters_era = (task.requesters_era or EMPTY)[1] or 0
		local loop_length_era = (task.loop_length_era or EMPTY)[1] or 0
		local poll_nodes_era = (task.poll_nodes_era or EMPTY)[1] or 0
		local logistics_era = (task.logistics_era or EMPTY)[1] or 0
		local deliveries_era = (task.deliveries_era or EMPTY)[1] or 0
		local deliveries_frame_era = (task.deliveries_frame_era or EMPTY)[1] or 0
		local deliveries_per_min = deliveries_frame_era * 3600
		local skipped_clean_era = (task.skipped_clean_era or EMPTY)[1] or 0

		return Pr({
			type = "frame",
			direction = "vertical",
			style = "shallow_frame",
			horizontally_stretchable = true,
		}, {
			ultros.RtLabel({
				"cybersyn2-manager.threads-logistics-title",
				task._cmt_name or "",
			}),
			Pr({ type = "line" }),
			Pr(
				{ type = "table", column_count = 5, horizontally_stretchable = true },
				{
					HF({ horizontally_stretchable = true }, {
						ultros.RtLabel({
							"cybersyn2-manager.threads-work-per-iteration",
							strformat("%.2f", wpi),
						}),
					}),
					HF({ horizontally_stretchable = true }, {
						ultros.RtLabel({
							"cybersyn2-manager.threads-loop-length-title-case",
							strformat("%.2f", loop_length_era),
						}),
					}),
					HF({ horizontally_stretchable = true }, {
						ultros.RtLabel({
							"cybersyn2-manager.threads-poll-nodes",
							strformat("%.2f", poll_nodes_era),
						}),
					}),
					HF({ horizontally_stretchable = true }, {
						ultros.RtLabel({ "cybersyn2-manager.threads-nodes", n_nodes }),
					}),
					HF({ horizontally_stretchable = true }, {
						ultros.RtLabel({
							"cybersyn2-manager.threads-skipped-clean",
							strformat("%.2f", skipped_clean_era),
						}),
					}),
					HF({ horizontally_stretchable = true }, {
						ultros.RtLabel({
							"cybersyn2-manager.threads-logistics",
							strformat("%.2f", logistics_era),
						}),
					}),
					HF({ horizontally_stretchable = true }, {
						ultros.RtLabel({
							"cybersyn2-manager.threads-unfulfilled-per-loop",
							strformat("%.2f", requesters_era),
						}),
					}),
					HF({ horizontally_stretchable = true }, {
						ultros.RtLabel({
							"cybersyn2-manager.threads-providers",
							n_providers,
						}),
					}),
					HF({ horizontally_stretchable = true }, {
						ultros.RtLabel({
							"cybersyn2-manager.threads-deliveries-per-loop",
							strformat("%.2f", deliveries_era),
						}),
					}),
					HF({ horizontally_stretchable = true }, {
						ultros.RtLabel({
							"cybersyn2-manager.threads-deliveries-per-min",
							strformat("%.2f", deliveries_per_min),
						}),
					}),
					HF({ horizontally_stretchable = true }, {
						ultros.RtLabel({ "cybersyn2-manager.threads-work-cap" }),
						ultros.UncontrolledInput({
							numeric = true,
							value = work_cap,
							width = 60,
							on_change = function(_, next_work_cap)
								task._cmt_work_cap = clamp(next_work_cap, 0, 1000000, 100)
							end,
						}),
					}),
				}
			),
		})
	end
)

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
			style = "relm_table_scroll_pane",
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
