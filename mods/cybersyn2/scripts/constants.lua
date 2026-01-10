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

-- Bonus to provider evaluation per normalized unit of cargo available.
-- (In normalized units, 1 fluid unit = 1 normalized unit and 1 item STACK = 1250 normalized units)
_G.cs2.LOGISTICS_PROVIDER_CARGO_WEIGHT = 0.001
-- Penalty to provider evaluation per tile of distance from requester.
_G.cs2.LOGISTICS_PROVIDER_DISTANCE_WEIGHT = 0
-- Penalty to provider evaluation per train in queue.
_G.cs2.LOGISTICS_PROVIDER_BUSY_WEIGHT = -300
-- Number of ticks between deliveries of an item before a station is considered
-- "starving" for that item.
_G.cs2.LOGISTICS_STARVATION_TICKS = 3600 * 5 -- 5 minutes
-- Maximum number of passes over the provider match array to perform for a given requester.
_G.cs2.LOGISTICS_MAX_PROVIDER_PASSES = 2

-- Base logistics workload
_G.cs2.PERF_BASE_LOGISTICS_WORKLOAD = 100
-- Base workload for general threads
_G.cs2.PERF_BASE_THREAD_WORKLOAD = 50

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

-- Set of virtual signals that are invalid for network names.
_G.cs2.INVALID_NETWORK_SIGNAL_SET = {
	["signal-everything"] = true,
	["signal-anything"] = true,
	["cybersyn2-priority"] = true,
	["cybersyn2-all-items"] = true,
	["cybersyn2-all-fluids"] = true,
}

-- Default settings for a newly placed combinator with no tags.
_G.cs2.DEFAULT_COMBINATOR_SETTINGS = {
	mode = "station",
	order_primary_network = "signal-A",
	order_secondary_network = "signal-A",
	order_flags = 3,
	pr = 0,
	inactivity_mode = 0,
	inactivity_timeout = 1,
	station_flags = 64,
	reserved_slots = 0,
	reserved_capacity = 0,
	spillover = 0,
}

_G.cs2.CS2_ICON_SIGNAL_ID = {
	type = "virtual",
	name = "cybersyn2",
}

_G.cs2.ERROR_PRINT_OPTS = {
	color = { 255, 128, 0 },
	skip = defines.print_skip.never,
	sound = defines.print_sound.always,
}
