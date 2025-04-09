--------------------------------------------------------------------------------
-- Global constants
--------------------------------------------------------------------------------

_G.cs2.CYBERSYN_TRAIN_GROUP_NAME_PREFIX = "[virtual-signal=cybersyn2]"
_G.cs2.WINDOW_NAME = "cybersyn2-combinator-gui"
_G.cs2.COMBINATOR_CLOSE_SOUND = "entity-close/cybersyn-combinator"
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
_G.cs2.PERF_TRAIN_GROUP_MONITOR_WORKLOAD = 5
-- Base number of combinators to examine per `poll_combinators` iteration.
-- TODO: all these are set to 1 for debugging convenience, adjust later
_G.cs2.PERF_COMB_POLL_WORKLOAD = 1
-- Base number of nodes to examine per `poll_nodes` iteration
_G.cs2.PERF_NODE_POLL_WORKLOAD = 1
-- Base number of items to examine per `alloc` iteration.
_G.cs2.PERF_ALLOC_ITEM_WORKLOAD = 1
-- Base number of vehs to check per `find_vehicles` iteration.
_G.cs2.PERF_FIND_VEHICLES_WORKLOAD = 1

-- Set of virtual signals considered configuration signals; these can't
-- be used as network names.
_G.cs2.CONFIGURATION_VIRTUAL_SIGNAL_SET = {
	["cybersyn2"] = true,
	["cybersyn2-priority"] = true,
	["cybersyn2-item-threshold"] = true,
	["cybersyn2-fluid-threshold"] = true,
	["cybersyn2-item-slots"] = true,
	["cybersyn2-fluid-capacity"] = true,
}

-- Default settings for a newly placed combinator with no tags.
_G.cs2.DEFAULT_COMBINATOR_SETTINGS = {
	mode = "station",
	network = "signal-A",
	pr = 0,
	inactivity_mode = 1,
	inactivity_timeout = 5,
	station_flags = 1,
}
