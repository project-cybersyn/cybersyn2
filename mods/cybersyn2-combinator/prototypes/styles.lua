local styles = data.raw["gui-style"].default
local constants = require "scripts.constants"

styles[constants.STYLES.SIGNAL_SPRITE] = {
  type = "image_style",
  parent = "image",
  size = 32,
  left_padding = 2,
  stretch_image_to_widget_size = true
}

styles[constants.STYLES.SIGNAL_LABEL] = {
  type = "label_style",
  parent = "caption_label",
  horizontally_stretchable = "on"
}

styles[constants.STYLES.SIGNAL_TEXT] = {
  type = "textbox_style",
  parent = "short_number_textfield",
  horizontal_align = "right",
  horizontally_stretchable = "off"
}

styles[constants.STYLES.SIGNAL_RESET] = {
  type = "button_style",
  parent = "tool_button_red",
  horizontally_stretchable = "off"
}

styles[constants.STYLES.SIGNAL_BUTTON] = {
  type = "button_style",
  parent = "flib_slot_button_default"
}

styles[constants.STYLES.SIGNAL_BUTTON_PRESSED] = {
  type = "button_style",
  parent = "flib_selected_slot_button_default"
}

-- styles["cybersyn-combinator_signal-button_disabled"] = {
--   type = "button_style",
--   parent = "flib_slot_button_default",
--   draw_grayscale_picture = true,
--   default_graphical_set = {
--     base = {
--       border = 4, position = { 0, 0 }, size = 80,
--       filename = "__cybersyn-combinator__/graphics/gui/disabled-slot-button-tileset.png"
--     },
--     shadow = offset_by_2_rounded_corners_glow(default_dirt_color)
--   },
--   hovered_graphical_set = {
--     base = {
--       border = 4, position = { 80, 0 }, size = 80,
--       filename = "__cybersyn-combinator__/graphics/gui/disabled-slot-button-tileset.png"
--     },
--     shadow = offset_by_2_rounded_corners_glow(default_dirt_color),
--     glow = offset_by_2_rounded_corners_glow(default_glow_color)
--   },
--   clicked_graphical_set = {
--     base = {
--       border = 4, position = { 160, 0 }, size = 80,
--       filename = "__cybersyn-combinator__/graphics/gui/disabled-slot-button-tileset.png"
--     },
--     shadow = offset_by_2_rounded_corners_glow(default_dirt_color)
--   }
-- }

-- styles["cybersyn-combinator_signal-button_disabled_pressed"] = {
--   type = "button_style",
--   parent = "cybersyn-combinator_signal-button_disabled",
--   default_graphical_set = styles["cybersyn-combinator_signal-button_disabled"].clicked_graphical_set
-- }

styles[constants.STYLES.SIGNAL_COMPARATOR] = {
  type = "label_style",
  parent = "label",
  font = constants.FONT_NAME,
  size = 36,
  horizontal_align = "left",
  vertical_align = "top",
  margin = 0,
  padding = 0,
  parent_hovered_font_color = { 1, 1, 1 }
}

styles[constants.STYLES.SIGNAL_COUNT] = {
  type = "label_style",
  parent = "count_label",
  size = 36,
  horizontal_align = "right",
  vertical_align = "bottom",
  right_padding = 2,
  parent_hovered_font_color = { 1, 1, 1 }
}

styles[constants.STYLES.NETWORK_LIST_INFO_SPRITE] = {
  type = "image_style",
  parent = "image",
  size = 10,
  stretch_image_to_widget_size = true,
  vertical_align = "center"
}

styles[constants.STYLES.NETWORK_MASK_TEXT_INPUT] = {
  type = "textbox_style",
  horizontal_align = "right"
}

-- Credit to FactoryPlanner for list-box/scroll-pane styles
styles[constants.STYLES.NETWORK_LIST_SCROLL_PANE] = {
  type = "scroll_pane_style",
  parent = "list_box_in_shallow_frame_scroll_pane",
  background_graphical_set = { -- rubber grid
    position = { 282, 17 },
    corner_size = 8,
    overall_tiling_vertical_size = 22,
    overall_tiling_vertical_spacing = 6,
    overall_tiling_vertical_padding = 4,
    overall_tiling_horizontal_padding = 4
  },
  vertically_stretchable = "on",
  horizontally_stretchable = "on",
  padding = 0,
  vertical_flow_style = {
    type = "vertical_flow_style",
    vertical_spacing = 0
  }
}

styles[constants.STYLES.NETWORK_LIST_ITEM] = {
  type = "button_style",
  parent = "list_box_item",
  horizontally_stretchable = "on",
  horizontally_squashable = "on"
}

styles[constants.STYLES.NETWORK_LIST_ITEM_ACTIVE] = {
  type = "button_style",
  parent = constants.STYLES.NETWORK_LIST_ITEM,
  default_graphical_set = styles.button.selected_graphical_set,
  hovered_graphical_set = styles.button.selected_hovered_graphical_set,
  clicked_graphical_set = styles.button.selected_clicked_graphical_set,
  default_font_color = styles.button.selected_font_color,
  default_vertical_offset = styles.button.selected_vertical_offset
}

styles[constants.STYLES.GROUP_LIST_SCROLL_PANE] = {
  type = "scroll_pane_style",
  parent = "list_box_in_shallow_frame_under_subheader_scroll_pane",
  padding = 0,
  vertical_flow_style = {
    type = "vertical_flow_style",
    vertical_spacing = 0
  }
}

styles[constants.STYLES.FRAME_TRANSPARENT] = {
  type = "frame_style",
  graphical_set = {
    base = {
      type = "composition",
      filename = "__cybersyn2-combinator__/graphics/frame/transparent-pixel.png",
      corner_size = 1,
      position = { 0, 0 }
    }
  }
}

styles[constants.STYLES.FRAME_SEMITRANSPARENT] = {
  type = "frame_style",
  graphical_set = {
    base = {
      type = "composition",
      filename = "__cybersyn2-combinator__/graphics/frame/semitransparent-pixel.png",
      corner_size = 1,
      position = { 0, 0 }
    }
  }
}

styles[constants.STYLES.ENCODER_BIT_BUTTON] = {
  type = "button_style",
  parent = "flib_standalone_slot_button_grey",
  size = 32,
  hovered_graphical_set = styles.flib_standalone_slot_button_grey.default_graphical_set
}

styles[constants.STYLES.ENCODER_BIT_BUTTON_PRESSED] = {
  type = "button_style",
  parent = "flib_selected_standalone_slot_button_grey",
  size = 32
}
