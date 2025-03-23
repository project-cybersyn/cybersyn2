--------------------------------------------------------------------------------
-- Global constants
--------------------------------------------------------------------------------

_G.cs2.CYBERSYN_TRAIN_GROUP_NAME_PREFIX = "[virtual-signal=cybersyn2-group]"

_G.cs2.WINDOW_NAME = "cybersyn-combinator-gui"
_G.cs2.COMBINATOR_CLOSE_SOUND = "entity-close/cybersyn-combinator"

-- Max rails to search away from station when checking layout.
-- No idea why this is 112, the number comes from Cybersyn 1.
_G.cs2.MAX_RAILS_TO_SEARCH = 112

-- Longest reach of an inserter to account for when calculating bounding boxes
-- for train stop layouts. Ultimately determines the "fatness" of bbox around
-- rails.
-- This is a bit of a hack, but it is what it is.
_G.cs2.LONGEST_INSERTER_REACH = 2

-- Base number of trains to examine per iteration of the train group monitor.
_G.cs2.PERF_TRAIN_GROUP_MONITOR_WORKLOAD = 10
-- Base number of inventories to examine per `poll_inventories` iteration.
_G.cs2.PERF_INVENTORY_POLL_WORKLOAD = 5
-- Base number of nodes to examine per `poll_nodes` iteration
_G.cs2.PERF_NODE_POLL_WORKLOAD = 5

-- Set of virtual signals considered configuration signals; these can't
-- be used as network names.
_G.cs2.CONFIGURATION_VIRTUAL_SIGNAL_SET = {
	["cybersyn2-group"] = true,
	["cybersyn2-priority"] = true,
	["cybersyn2-item-threshold"] = true,
	["cybersyn2-fluid-threshold"] = true,
	["cybersyn2-item-slots"] = true,
	["cybersyn2-fluid-capacity"] = true,
}
