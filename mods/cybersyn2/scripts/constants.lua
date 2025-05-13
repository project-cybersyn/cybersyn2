--------------------------------------------------------------------------------
-- Global constants
--------------------------------------------------------------------------------

_G.cs2.CYBERSYN_TRAIN_GROUP_NAME_PREFIX = "[virtual-signal=cybersyn2]"
_G.cs2.WINDOW_NAME = "cybersyn2-combinator-gui"
_G.cs2.COMBINATOR_CLOSE_SOUND = "entity-close/cybersyn2-combinator"
_G.cs2.COMBINATOR_NAME = "cybersyn2-combinator"

-- Max rails to search away from station when checking layout.
-- No idea why this is 112, the number comes from Cybersyn 1.
_G.cs2.MAX_RAILS_TO_SEARCH = 112

-- Longest reach of an inserter to account for when calculating bounding boxes
-- for train stop layouts. Ultimately determines the "fatness" of bbox around
-- rails.
-- This is a bit of a hack, but it is what it is.
_G.cs2.LONGEST_INSERTER_REACH = 2

-- Base number of trains to examine per iteration of the train group monitor.
_G.cs2.PERF_TRAIN_GROUP_MONITOR_WORKLOAD = 4
-- Base number of nodes to examine per `enum_nodes` iteration.
_G.cs2.PERF_ENUM_NODES_WORKLOAD = 10
-- Base number of combinators to examine per `poll_combinators` iteration.
_G.cs2.PERF_POLL_COMBINATORS_WORKLOAD = 6
-- Base number of nodes to examine per `poll_nodes` iteration
_G.cs2.PERF_NODE_POLL_WORKLOAD = 4
-- Base number of items to examine per `cull` iteration.
_G.cs2.PERF_CULL_WORKLOAD = 20
-- Base number of items to examine per `alloc` iteration.
_G.cs2.PERF_ALLOC_ITEM_WORKLOAD = 1
-- Number of deliveries to examine per delivery monitor iteration.
_G.cs2.PERF_DELIVERY_MONITOR_WORKLOAD = 5

-- Expiration time in ticks for a finished delivery to be deleted from storage.
-- TODO: possibly make this a setting
_G.cs2.DELIVERY_EXPIRATION_TICKS = 3600 * 15 -- 15 minutes

-- When attempting to restore a shared inventory link from blueprint tags,
-- keep the hypothetical link in storage for this many ticks. (This gives
-- bots time to build the appropriate stations.)
-- If link is not restored after this time, it will be deleted from storage.
_G.cs2.SHARED_INVENTORY_RELINK_ATTEMPT_TICKS = 3600 * 15 -- 15 minutes

-- Set of virtual signals considered configuration signals; these can't
-- be used as network names.
_G.cs2.CONFIGURATION_VIRTUAL_SIGNAL_SET = {
	["cybersyn2"] = true,
	["cybersyn2-priority"] = true,
	["cybersyn2-all-items"] = true,
	["cybersyn2-all-fluids"] = true,
}

-- Default settings for a newly placed combinator with no tags.
_G.cs2.DEFAULT_COMBINATOR_SETTINGS = {
	mode = "station",
	network = "signal-A",
	pr = 0,
	inactivity_mode = 0,
	inactivity_timeout = 1,
	station_flags = 1,
	reserved_slots = 0,
	reserved_capacity = 0,
	spillover = 0,
}

_G.cs2.CS2_ICON_SIGNAL_ID = {
	type = "virtual",
	name = "cybersyn2",
}
