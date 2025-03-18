--------------------------------------------------------------------------------
-- Global constants
--------------------------------------------------------------------------------

CYBERSYN_TRAIN_GROUP_NAME_PREFIX = "[virtual-signal=cybersyn2-group]"

WINDOW_NAME = "cybersyn-combinator-gui"
COMBINATOR_CLOSE_SOUND = "entity-close/cybersyn-combinator"

-- Max rails to search away from station when checking layout.
-- No idea why this is 112, the number comes from Cybersyn 1.
MAX_RAILS_TO_SEARCH = 112

-- Longest reach of an inserter to account for when calculating bounding boxes
-- for train stop layouts. Ultimately determines the "fatness" of bbox around
-- rails.
-- This is a bit of a hack, but it is what it is.
LONGEST_INSERTER_REACH = 2

-- Base number of trains to examine per iteration of the train group monitor.
PERF_TRAIN_GROUP_MONITOR_WORKLOAD = 10
