local mod_name = "cybersyn2-combinator"
local constants = {
  INT32_MAX = 2147483647,
  INT32_MIN = -2147483648,
  MOD_NAME = mod_name,
  MOD_TITLE = "Cybersyn 2 Combinator",
  SETTINGS = {
    LOG_LEVEL = mod_name .. "-loglevel",
    CHAT_LOG_LEVEL = mod_name .. "-loglevel-chat",
    SLOT_ROWS = mod_name .. "-slotrows",
    SLOT_COUNT_WAGON = mod_name .. "-slotcount-wagon",
    UPGRADEABLE = mod_name .. "-upgradeable",
    USE_STACKS = mod_name .. "-use-stacks",
    ENABLE_EXPRESSIONS = mod_name .. "-expressions-enable",
    DISABLE_BUILT = mod_name .. "-disable-built",
    DISABLE_NONPLAYER_BUILT = mod_name .. "-disable-built-nonplayer",
    NEGATIVE_SIGNALS = mod_name .. "-negative-signals",
    NETWORK_MASK_PARSE_MODE = mod_name .. "-network-mask-parse-mode",
    NETWORK_MASK_DISPLAY_MODE = mod_name .. "-network-mask-display-mode",
    NETWORK_MASK_DISPLAY_PREFIX = mod_name .. "-network-mask-display-prefix",
    NETWORK_MASK_USE_CS_DEFAULT = mod_name .. "-network-mask-use-cs-default",
    ENCODER_ZERO_INDEX = mod_name .. "-encoder-zero-index",
    -- Project Cybersyn 2 settings
    CS_DEFAULT_PRIORITY = 0,
    CS_PRIORITY_NAME = "cybersyn2-priority",
    CS_PRIORITY_OLD = mod_name .. "-cs-old-default-priority",
    CS_DEFAULT_NETWORK_FLAG = 1,
  },
  ENTITY_NAME = "cybersyn2-constant-combinator",
  CANNOT_BUILD_SOUND = "utility/cannot_build",
  FONT_NAME = mod_name .. "-signal-comparator-font",
  STYLES = {
    SIGNAL_RESET = mod_name .. "-cs-signal-reset",
    SIGNAL_SPRITE = mod_name .. "-cs-signal-sprite",
    SIGNAL_LABEL = mod_name .. "-cs-signal-label",
    SIGNAL_TEXT = mod_name .. "-cs-signal-text",
    ENCODER_BIT_BUTTON = mod_name .. "-encoder_bit-button",
    ENCODER_BIT_BUTTON_PRESSED = mod_name .. "-encoder_bit-button_pressed",
    FRAME_SEMITRANSPARENT = mod_name .. "-frame_semitransparent",
    FRAME_TRANSPARENT = mod_name .. "-frame_transparent",
    GROUP_LIST_SCROLL_PANE = mod_name .. "-group-list_scroll-pane",
    NETWORK_LIST_INFO_SPRITE = mod_name .. "-network-list_info-sprite",
    NETWORK_LIST_ITEM = mod_name .. "-network-list_item",
    NETWORK_LIST_ITEM_ACTIVE = mod_name .. "-network-list_item-active",
    NETWORK_LIST_SCROLL_PANE = mod_name .. "-network-list_scroll-pane",
    NETWORK_MASK_TEXT_INPUT = mod_name .. "-network-mask-text-input",
    SIGNAL_BUTTON = mod_name .. "-signal-button",
    SIGNAL_BUTTON_PRESSED = mod_name .. "-signal-button_pressed",
    SIGNAL_COMPARATOR = mod_name .. "-signal-comparator",
    SIGNAL_COUNT = mod_name .. "-signal-count",
  }
}

--- @type string
constants.ENTITY_CLOSE_SOUND = "entity-close/" .. constants.ENTITY_NAME

return constants
