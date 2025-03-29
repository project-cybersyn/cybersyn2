if ... ~= "__cybersyn2__.lib.relm" then
	return require("__cybersyn2__.lib.relm")
end

local log = require("__cybersyn2__.lib.logging")

local tremove = table.remove

local lib = {}

--------------------------------------------------------------------------------
-- FACTORIO STUFF
-- If they change something in factorio look here first for what needs updated
--------------------------------------------------------------------------------

-- h/t `flib.gui` for the below code which serves much the same function here

--- A GUI element definition.
--- @class Relm.PrimitiveDefinition: LuaGuiElement.add_param.button|LuaGuiElement.add_param.camera|LuaGuiElement.add_param.checkbox|LuaGuiElement.add_param.choose_elem_button|LuaGuiElement.add_param.drop_down|LuaGuiElement.add_param.flow|LuaGuiElement.add_param.frame|LuaGuiElement.add_param.line|LuaGuiElement.add_param.list_box|LuaGuiElement.add_param.minimap|LuaGuiElement.add_param.progressbar|LuaGuiElement.add_param.radiobutton|LuaGuiElement.add_param.scroll_pane|LuaGuiElement.add_param.slider|LuaGuiElement.add_param.sprite|LuaGuiElement.add_param.sprite_button|LuaGuiElement.add_param.switch|LuaGuiElement.add_param.tab|LuaGuiElement.add_param.table|LuaGuiElement.add_param.text_box|LuaGuiElement.add_param.textfield

--- Aggregate type of all possible GUI events.
--- @alias Relm.GuiEventData EventData.on_gui_checked_state_changed|EventData.on_gui_click|EventData.on_gui_closed|EventData.on_gui_confirmed|EventData.on_gui_elem_changed|EventData.on_gui_location_changed|EventData.on_gui_opened|EventData.on_gui_selected_tab_changed|EventData.on_gui_selection_state_changed|EventData.on_gui_switch_state_changed|EventData.on_gui_text_changed|EventData.on_gui_value_changed

-- h/t flib for this code
local gui_events = {}
for name, id in pairs(defines.events) do
	if string.find(name, "on_gui_") then
		gui_events[id] = true
	end
end

-- `LuaGuiElement` keys that can safely be applied from `Primitive` props.
local APPLICABLE_KEYS = {
	caption = true,
	value = true,
	visible = true,
	text = true,
	state = true,
	sprite = true,
	resize_to_sprite = true,
	hovered_sprite = true,
	clicked_sprite = true,
	tooltip = true,
	elem_tooltip = true,
	horizontal_scroll_policy = true,
	vertical_scroll_policy = true,
	items = true,
	selected_index = true,
	number = true,
	show_percent_for_small_numbers = true,
	location = true,
	auto_center = true,
	badge_text = true,
	auto_toggle = true,
	toggled = true,
	game_controller_interaction = true,
	position = true,
	surface_index = true,
	zoom = true,
	minimap_player_index = true,
	force = true,
	elem_value = true,
	elem_filters = true,
	selectable = true,
	word_wrap = true,
	read_only = true,
	enabled = true,
	ignored_by_interaction = true,
	locked = true,
	draw_vertical_lines = true,
	draw_horizontal_lines = true,
	draw_vertical_line_after_headers = true,
	vertical_centering = true,
	slider_value = true,
	mouse_button_filter = true,
	numeric = true,
	allow_decimal = true,
	allow_negative = true,
	is_password = true,
	lose_focus_on_confirm = true,
	drag_target = true,
	selected_tab_index = true,
	entity = true,
	anchor = true,
	tags = true,
	raise_hover_events = true,
	switch_state = true,
	allow_none_state = true,
	left_label_caption = true,
	left_label_tooltip = true,
	right_label_caption = true,
	right_label_tooltip = true,
}

-- `LuaGuiElement` keys that can only be applied at creation.
local CREATE_KEYS = {
	index = true,
	type = true,
	name = true,
	direction = true,
	elem_type = true,
	column_count = true,
	style = true,
}
-- TODO: if an element props change in one of the `CREATE_KEYS` categories, recreate it in `vpaint`.

-- `Primitive` props that will be set on the `LuaStyle` rather than the
-- element itself.
local STYLE_KEYS = {
	minimal_width = true,
	maximal_width = true,
	minimal_height = true,
	maximal_height = true,
	natural_width = true,
	natural_height = true,
	top_padding = true,
	right_padding = true,
	bottom_padding = true,
	left_padding = true,
	top_margin = true,
	right_margin = true,
	bottom_margin = true,
	left_margin = true,
	horizontal_align = true,
	vertical_align = true,
	font_color = true,
	font = true,
	top_cell_padding = true,
	right_cell_padding = true,
	bottom_cell_padding = true,
	left_cell_padding = true,
	horizontally_stretchable = true,
	vertically_stretchable = true,
	horizontally_squashable = true,
	vertically_squashable = true,
	rich_text_setting = true,
	hovered_font_color = true,
	clicked_font_color = true,
	disabled_font_color = true,
	pie_progress_color = true,
	clicked_vertical_offset = true,
	selected_font_color = true,
	selected_hovered_font_color = true,
	selected_clicked_font_color = true,
	strikethrough_color = true,
	horizontal_spacing = true,
	vertical_spacing = true,
	use_header_filler = true,
	color = true,
	-- column_alignments = true,
	single_line = true,
	extra_top_padding_when_activated = true,
	extra_bottom_padding_when_activated = true,
	extra_left_padding_when_activated = true,
	extra_right_padding_when_activated = true,
	extra_top_margin_when_activated = true,
	extra_bottom_margin_when_activated = true,
	extra_left_margin_when_activated = true,
	extra_right_margin_when_activated = true,
	stretch_image_to_widget_size = true,
	badge_font = true,
	badge_horizontal_spacing = true,
	default_badge_font_color = true,
	selected_badge_font_color = true,
	disabled_badge_font_color = true,
	width = true,
	height = true,
	padding = true,
	margin = true,
}

--------------------------------------------------------------------------------
-- CORE PUBLIC TYPES
-- These types, along with the exports defined on `lib`, constitute the public
-- API of Relm and should not be changed.
--------------------------------------------------------------------------------

---The primary output of `render` functions, representing nodes in the virtual
---tree.
---@class (exact) Relm.Node
---@field public type string The type of this node.
---@field public props? Relm.Props The properties of this node.

---Opaque reference used to refer to a vtree node. DO NOT read or write to
---this object, only pass it to Relm APIs.
---@class (exact) Relm.Handle

---Definition of a reusable element distinguished by its name.
---@class (exact) Relm.ElementDefinition
---@field public name string The name of this element. Must be unique across the Lua state.
---@field public render Relm.Element.RenderDefinition Renders the element. Render MUST be a pure function of state, props, and authorized access to the `children` handle. It MUST NOT cause side effects!
---@field public factory? Relm.NodeFactory If given, this will replace the automatically generated factory function returned by `define_element`.
---@field public message? Relm.Element.MessageHandlerDefinition Defines the message handler for elements of this type. Message handlers may cause side effects.
---@field public state? Relm.Element.StateDefinition If given, determines the initial state from the element's initial props. (This is NOT required to use state, only if you want a non-`nil` initial state)
---@field public query? Relm.Element.QueryHandlerDefinition Defines the query handler for elements of this type. Query handlers MUST be pure functions of state, props, and other queries. They MUST NOT cause side effects!

---@alias Relm.RootId int

---@alias Relm.Value boolean|int|number|string

---@alias Relm.Props {children?: Relm.Children, [string|int]:any}

---@alias Relm.State string|number|int|boolean|table|nil

---@alias Relm.Children Relm.Node|Relm.Node[]|nil

---@alias Relm.QueryResponse string|number|int|boolean|table|nil

---@alias Relm.EffectKey Relm.Value|table<int|string, Relm.EffectKey>

---@class Relm.MessagePayload
---@field public key string A key identifying the type of the message.
---@field public propagation_mode? "bubble"|"broadcast"|"unicast" The propagation mode of the message.

---@alias Relm.Element.RenderDefinition fun(props: Relm.Props, state?: Relm.State): Relm.Children

---@alias Relm.Element.MessageHandlerDefinition fun(me: Relm.Handle, payload: Relm.MessagePayload, props: Relm.Props, state?: Relm.State): boolean|nil

---@alias Relm.Element.MessageHandlerWrapper fun(me: Relm.Handle, payload: Relm.MessagePayload, props: Relm.Props, state?: Relm.State, base_handler: Relm.Element.MessageHandlerDefinition): boolean|nil

---@alias Relm.Element.StateDefinition fun(initial_props: Relm.Props): Relm.State

---@alias Relm.NodeFactory fun(props?: Relm.Props, children?: Relm.Node[]): Relm.Children

---@alias Relm.Element.QueryHandlerDefinition fun(me: Relm.Handle, payload: Relm.MessagePayload, props: Relm.Props, state?: Relm.State): boolean, Relm.QueryResponse?

--------------------------------------------------------------------------------
-- INTERNAL TYPES AND GLOBALS
-- These can be changed as needed without breaking userspace.
--------------------------------------------------------------------------------

---Registry of all elt types defined in this Relm instance.
---@type table<string, Relm.ElementDefinition>
local registry = {}

---Internal representation of a vtree node. This is stored in state.
---@class (exact) Relm.Internal.VNode
---@field public type string The type of this node.
---@field public state? Relm.State
---@field public children? Relm.Internal.VNode[]
---@field public elem? LuaGuiElement The Lua element this node maps to, if a real element.
---@field public index? uint Index in parent node
---@field public parent? Relm.Internal.VNode Parent of this node.
---@field public hooks? table<uint, any> Hook data for this node, if it has hooks.

---Map from `"<player_index>:<element_index>"` to vnodes
---(We can't use weak `LuaGuiElement` keys here)
---@type table<string, Relm.Internal.VNode>
local evcache = setmetatable({}, { __mode = "v" })

---Map from vnodes to last rendered props
---@type table<Relm.Internal.VNode, Relm.Props>
local vprops = setmetatable({}, { __mode = "k" })

---Map from vnodes to hook transient data
---@type table<Relm.Internal.VNode, table<uint, table>>
local vhooks_transient = setmetatable({}, { __mode = "k" })

local function noop() end
local immutable_mt = { __newindex = noop }

---Unique key for tables resulting from query gather ops.
local WAS_GATHERED = setmetatable({}, immutable_mt)

---Unique per-mod key for event listening
local LISTEN_KEY = "__relm_listen_" .. script.mod_name

-- Forward declarations for mutually recursive functions.
local vmsg
local vapply

--------------------------------------------------------------------------------
-- VNODES
--------------------------------------------------------------------------------

---Tree search from root to find vnode with given elt.
---@param root Relm.Internal.VNode
---@param elem LuaGuiElement
local function find_vnode(root, elem)
	if not root then
		return nil
	end

	if root.elem and (root.elem.index == elem.index) then
		return root
	end

	if root.children then
		for i = 1, #root.children do
			local child = root.children[i]
			local result = find_vnode(child, elem)
			if result then
				return result
			end
		end
	end

	return nil
end

---Find vnode with given element, using cache if possible.
---@param elt? LuaGuiElement
local function get_vnode(elt)
	if not elt or not elt.valid then
		return nil
	end
	local cache_key = elt.player_index .. ":" .. elt.index
	---@type Relm.Internal.VNode?
	local vnode = evcache[cache_key]
	if vnode then
		return vnode
	end

	local root_id = elt.tags["__relm_root"]
	if not root_id then
		log.error(
			"get_vnode: ive got no roots (but my home was never on the ground)"
		)
		return nil
	end
	---@type Relm.Internal.Root?
	local root = storage._relm.roots[root_id]
	if not root then
		log.error("get_vnode: bad root id", root_id)
		return nil
	end
	vnode = find_vnode(root.vtree_root, elt)
	evcache[cache_key] = vnode
	return vnode
end

---@param node? Relm.Node|Relm.Internal.VNode
local function is_primitive(node)
	return node and node.type == "Primitive"
end

--------------------------------------------------------------------------------
-- VTREE RENDERING
--------------------------------------------------------------------------------

-- Hook renderstate implementation vars.
---Currently hooking node.
---@type Relm.Internal.VNode?
local hook_node = nil
---Current hook number within the node's rendering
local hook_num = 0
---Whether we are in a hydrating render.
local render_is_hydrating = false
---Removed keys on primitive nodes. We must set these to `nil` when
---painting if we reuse the node.
local removed_keys = setmetatable({}, { __mode = "k" })

---Normalize calls and results of `element.render`
---@param def? Relm.ElementDefinition
---@param type? string
---@param props? Relm.Props
---@param state? Relm.State
---@param hook_node_? Relm.Internal.VNode
---@param is_hydrating_? boolean
---@return Relm.Node[]
local function normalized_render(
	def,
	type,
	props,
	state,
	hook_node_,
	is_hydrating_
)
	if not def then
		def = registry[type or ""]
	end
	if not def then
		error("Element type " .. (type or "") .. " not found.")
	end
	hook_num = 0
	hook_node = hook_node_
	render_is_hydrating = not not is_hydrating_
	local rendered_children = def.render(props or {}, state)
	hook_node = nil
	render_is_hydrating = false
	-- Normalize to array
	if not rendered_children then
		rendered_children = {}
	elseif rendered_children.type then
		-- single node, promote to array
		rendered_children = { rendered_children }
	end
	return rendered_children
end

---@param vnode Relm.Internal.VNode
local function vprune(vnode)
	if vnode.children then
		for i = 1, #vnode.children do
			vprune(vnode.children[i])
		end
		vnode.children = nil
	end

	-- Cleanup effects
	local transients = vhooks_transient[vnode]
	if transients then
		for index, transient in pairs(transients) do
			local cleanup = transient.cleanup
			if cleanup then
				local hook_state = vnode.hooks and vnode.hooks[index]
				if hook_state then
					transient.cleanup(hook_state.callback_return)
				end
			end
		end
	end

	-- Cleanup node data.
	-- NOTE: we may not clear `parent` here because this node may be
	-- reused at the same place in the vtree.
	vprops[vnode] = nil
	vhooks_transient[vnode] = nil
	vnode.type = nil
	vnode.elem = nil
	vnode.index = nil
	vnode.state = nil
end

---@param vnode Relm.Internal.VNode
---@param render_children Relm.Node[]
local function vapply_children(vnode, render_children)
	if not vnode.children then
		vnode.children = {}
	end
	local vchildren = vnode.children --[[@as Relm.Internal.VNode[] ]]
	local vindex = 1
	for i = 1, #render_children do
		local rchild = render_children[i]
		if rchild and rchild.type then
			local vchild = vchildren[vindex]
			if not vchild then
				---@diagnostic disable-next-line: missing-fields
				vchildren[vindex] = {}
				vchild = vchildren[vindex]
			end
			vchild.parent = vnode
			vchild.index = vindex
			vapply(vchild, rchild)
			vindex = vindex + 1
		end
	end
	for i = vindex, #vchildren do
		vprune(vchildren[i])
		vchildren[i] = nil
	end
end

---@param vnode Relm.Internal.VNode
---@param node? Relm.Node
vapply = function(vnode, node)
	if not node then
		if vnode.type then
			return vprune(vnode)
		end
		return
	end
	local target_type = node.type
	local target_def = registry[target_type]
	-- If type changing, prune the old node.
	if (not target_def) or target_type ~= vnode.type then
		vprune(vnode)
	end
	if not target_def then
		log.warn(
			"vapply: pruning subtree because no def for element type",
			target_type
		)
		return
	end
	local is_creating = not vnode.type

	-- Compute props and state
	vnode.type = target_type
	local prev_props = vprops[vnode]
	local next_props = node.props
	-- Special handling for primitives
	if prev_props and is_primitive(vnode) then
		local rk = removed_keys[vnode]
		-- We need to know what fields were set to `nil` since last render so
		-- we can poke the factorio fields as well.
		for key, _ in pairs(prev_props) do
			if (not next_props) or (next_props[key] == nil) then
				if not rk then
					removed_keys[vnode] = {}
					rk = removed_keys[vnode]
				end
				rk[#rk + 1] = key
			end
		end
		-- There are issues with modifying string `style`. If attempt to do so
		-- we will pessimize and just rebuild. As a hack, we flag this as if
		-- the `style` was removed.
		if (not next_props) or prev_props.style ~= next_props.style then
			if not rk then
				removed_keys[vnode] = {}
				rk = removed_keys[vnode]
			end
			rk[#rk + 1] = "style"
		end
	else
		removed_keys[vnode] = nil
	end
	vprops[vnode] = next_props
	if is_creating then
		if target_def.state then
			vnode.state = target_def.state(next_props or {})
		end
	end

	-- Render
	local render_children = normalized_render(
		target_def,
		target_type,
		node.props,
		vnode.state,
		vnode,
		false
	)

	-- Render children
	return vapply_children(vnode, render_children)
end

---Force a vnode to rerender
---@param vnode Relm.Internal.VNode
local function vrender(vnode)
	local props = vprops[vnode]
	if not props then
		log.error("vrender: no props cached for vnode", vnode)
	end
	local target_def = registry[vnode.type]
	local render_children =
		normalized_render(target_def, nil, props, vnode.state, vnode, false)

	return vapply_children(vnode, render_children)
end

---Special rendering mode that only hydrates prop cache.
---@param vnode Relm.Internal.VNode
---@param node? Relm.Node
local function vhydrate(vnode, node)
	-- TODO: any of these conditions will break all relm guis after a save/rl
	-- how to best notify user?
	if not node or not vnode then
		log.error("vhydrate: existence mismatch", node, vnode)
		return
	end
	if node.type ~= vnode.type then
		log.error("vhydrate: type mismatch", node.type, vnode.type)
		return
	end
	local def = registry[vnode.type]
	if not def then
		log.error("vhydrate: no definition for type", node.type)
		return
	end
	if not node.props then
		log.error("vhydrate: no props in node", node)
		return
	end
	vprops[vnode] = node.props
	local render_children =
		normalized_render(def, nil, node.props, vnode.state, vnode, true)
	local vchildren = vnode.children --[[@as Relm.Internal.VNode[] ]]
	if #vchildren ~= #render_children then
		log.error(
			"vhydrate: child count mismatch",
			node.type,
			#vchildren,
			#render_children
		)
	end
	local vindex = 1
	for i = 1, #render_children do
		local rchild = render_children[i]
		local vchild = vchildren[vindex]
		if rchild and next(rchild) and vchild then
			vhydrate(vchild, render_children[i])
			vindex = vindex + 1
		end
	end
end

--------------------------------------------------------------------------------
-- PAINTING
--------------------------------------------------------------------------------

---@class Relm.Internal.PaintContext
---@field index uint Current real child being examined
---@field elem LuaGuiElement Gui element we're rendering into
---@field is_root boolean? `true` if we're rendering a root.
---@field structure_changed boolean? `true` if something was create or destroyed in this context during the paint op.
---@field constructor? fun(props: Relm.Props): LuaGuiElement Constructor function to use instead of `add` when creating a new element.

---@param context Relm.Internal.PaintContext
local function vpaint_context_destroy(context)
	local elem = context.elem
	if elem and elem.valid then
		local child = elem.children[context.index]
		if child then
			child.destroy()
			context.structure_changed = true
		end
	end
end

---@param context Relm.Internal.PaintContext
---@param props Relm.Props
local function vpaint_context_create(context, props)
	local elem = context.elem
	if elem and elem.valid then
		local addable_props = {}
		for k, v in pairs(props) do
			if APPLICABLE_KEYS[k] or CREATE_KEYS[k] then
				addable_props[k] = v
			end
		end
		if not context.is_root then
			addable_props.index = context.index
		end
		-- Special handling for textboxes; treat them like React "uncontrolled"
		-- components and allow initial text to be specified but then let
		-- Factorio do the rest.
		if
			props["initial_text"]
			and (
				addable_props.type == "text-box" or addable_props.type == "textfield"
			)
		then
			addable_props.text = props["initial_text"]
		end
		local new_elem
		if context.constructor then
			new_elem = context.constructor(addable_props)
		else
			new_elem = elem.add(addable_props)
			-- Inherit __relm_root
			local tags = new_elem.tags
			tags["__relm_root"] = elem.tags["__relm_root"]
			new_elem.tags = tags
		end
		context.structure_changed = true
		if not context.is_root then
			context.index = context.index + 1
		end
		return new_elem
	end
end

---@param context Relm.Internal.PaintContext
---@param props Relm.Props
---@param vnode Relm.Internal.VNode
local function vpaint_context_diff(context, props, vnode)
	local elem
	if context.is_root then
		elem = context.elem
	else
		elem = context.elem.children[context.index]
	end
	if not elem then
		if props and props.type then
			return vpaint_context_create(context, props), true
		end
		return nil, false
	end
	if not props or not vnode or not props.type then
		return vpaint_context_destroy(context), true
	end

	-- Rebuild node if needed.
	local needs_rebuild = false
	if elem.type ~= props.type then
		needs_rebuild = true
	end
	-- Factorio doesn't support deleting style keys; if any style key
	-- was deleted, just rebuild
	local rk = removed_keys[vnode]
	if rk then
		for i = 1, #rk do
			local key = rk[i]
			if (key == "style") or STYLE_KEYS[key] then
				needs_rebuild = true
				break
			end
		end
	end
	if needs_rebuild then
		vpaint_context_destroy(context)
		return vpaint_context_create(context, props), true
	end

	-- No diff needed, increment context index
	context.index = context.index + 1
	return elem, false
end

---@param elem LuaGuiElement
local function vpaint_fix_tabs(elem)
	-- Tabbed panes, or T-PAINs as I call them, are extremely annoying.
	-- Algorithm here is to collect the first `n` children who are tabs
	-- and match them in order with the first `m` non-tab children.
	-- `min(m,n)` tabs will be created and the rest of the children
	-- will be left alone.
	local children = elem.children
	local tabs = {}
	local non_tabs = {}
	for i = 1, #children do
		local child = children[i]
		if child.type == "tab" then
			tabs[#tabs + 1] = child
		else
			non_tabs[#non_tabs + 1] = child
		end
	end
	elem.remove_tab()
	local ntabs = math.min(#tabs, #non_tabs)
	for i = 1, ntabs do
		elem.add_tab(tabs[i], non_tabs[i])
	end
end

---@param vnode Relm.Internal.VNode? Node tree to paint
---@param context Relm.Internal.PaintContext Context within parent primitive node
---@param same boolean? If true, the vnode type is known to be the same as the last paint. Used in repainting.
local function vpaint(vnode, context, same)
	-- Iterate through virtual parents
	while vnode and not is_primitive(vnode) do
		local vchildren = vnode.children
		local nvchildren = #vchildren
		if not vchildren or nvchildren == 0 then
			break
		elseif nvchildren == 1 then
			vnode = vchildren[1]
		else
			-- Use tail recursion
			for i = 1, nvchildren - 1 do
				vpaint(vchildren[i], context)
			end
			return vpaint(vchildren[nvchildren], context)
		end
	end
	-- If we haven't reached a primitive node, don't paint.
	if not is_primitive(vnode) then
		return
	end

	local props
	local elem_changed = false

	if not same then
		if (not vnode) or not vnode.type then
			-- No renderable nodes in this branch of vtree.
			return
		end
		props = vprops[vnode]
		if not props then
			log.error("vpaint: no props cached for vnode", vnode)
			return
		end
		vnode.elem, elem_changed = vpaint_context_diff(context, props, vnode)
	else
		if not vnode then
			log.error("vpaint: repainting a missing node")
			return
		end
		props = vprops[vnode]
		if not vnode.elem then
			log.error("vpaint: repainting an unpainted vnode", vnode.type, props.type)
			return
		end
	end
	local elem = vnode.elem --[[@as LuaGuiElement]]
	if not elem then
		-- elem destroyed by diff
		return
	end

	-- Apply props
	for key, value in pairs(props) do
		-- TODO: `style.column_alignments`
		if STYLE_KEYS[key] then
			elem.style[key] = value
		elseif APPLICABLE_KEYS[key] then
			elem[key] = value
		end
	end
	-- Remove nil'd keys if the elem didn't change
	local rk = removed_keys[vnode]
	if rk then
		if not elem_changed then
			for i = 1, #rk do
				local key = rk[i]
				if APPLICABLE_KEYS[key] then
					elem[key] = nil
				end
			end
		end
		removed_keys[vnode] = nil
	end

	-- Apply tags
	local tags = elem.tags
	if props.listen then
		tags[LISTEN_KEY] = true
	else
		tags[LISTEN_KEY] = nil
	end
	elem.tags = tags

	-- Handle `ref`s
	if type(props.ref) == "function" and elem_changed then
		props.ref(vnode.elem, vnode)
	end

	-- Handle children
	local vchildren = vnode.children or {}
	if #vchildren > 0 then
		local child_context = {
			elem = elem,
			index = 1,
		}
		for i = 1, #vchildren do
			vpaint(vchildren[i], child_context)
		end
		-- Prune children beyond those rendered.
		local echildren = elem.children
		for i = child_context.index, #echildren do
			echildren[i].destroy()
		end
		if
			elem.type == "tabbed-pane"
			and child_context
			and child_context.structure_changed
		then
			vpaint_fix_tabs(elem)
		end
	else
		local echildren = elem.children
		for i = 1, #echildren do
			echildren[i].destroy()
		end
		if elem.type == "tabbed-pane" then
			elem.remove_tab()
		end
	end
end

---Repaint a node. Type of `vnode` MUST be the same as its previous paint.
---This does not apply to its children.
---@param vnode Relm.Internal.VNode
local function vrepaint(vnode)
	vrender(vnode)
	-- Must paint from primitive ancestor
	while vnode and vnode.parent and not is_primitive(vnode) do
		vnode = vnode.parent
	end
	if vnode then
		vpaint(
			vnode,
			{ elem = vnode.elem, index = 1, is_root = not vnode.parent },
			true
		)
	else
		log.error("relm.vrepaint: no vnode to paint")
	end
end

--------------------------------------------------------------------------------
-- SIDE EFFECTS
--------------------------------------------------------------------------------

-- TODO: consider a more efficient deque for barrier_queue

local barrier_count = 0
local barrier_queue = {}

local function enter_side_effect_barrier()
	barrier_count = barrier_count + 1
	if barrier_count > 1 then
		log.warn(
			"relm.enter_side_effect_barrier: unexpected barrier_count:",
			barrier_count,
			" probably indicates a bug"
		)
	end
end

local function empty_barrier_queue()
	while barrier_count == 0 and #barrier_queue > 0 do
		local entry = tremove(barrier_queue, 1)
		local op = entry[1]
		local vnode = entry[2]
		local arg1 = entry[3]
		local arg2 = entry[4]
		op(vnode, arg1, arg2)
	end
end

local function exit_side_effect_barrier()
	barrier_count = barrier_count - 1
	return empty_barrier_queue()
end

local function barrier_wrap(op, vnode, arg1, arg2)
	if not vnode or not vnode.type then
		return
	end
	if barrier_count > 0 then
		barrier_queue[#barrier_queue + 1] = { op or noop, vnode, arg1, arg2 }
	else
		enter_side_effect_barrier()
		op(vnode, arg1, arg2)
		return exit_side_effect_barrier()
	end
end

local function vstate_impl(vnode, arg)
	-- Already in an effect barrier
	vnode.state = arg
	vrepaint(vnode)
end

---@param vnode Relm.Internal.VNode
---@param state Relm.State?
local function vstate(vnode, state)
	return barrier_wrap(vstate_impl, vnode, state)
end

---@param vnode Relm.Internal.VNode
---@param payload any
local function vmsg_impl(vnode, payload)
	local target_def = registry[vnode.type or {}]
	local base_handler = target_def and target_def.message
	local wrapper = vprops[vnode] and vprops[vnode].message_handler
	if wrapper then
		return wrapper(
			vnode --[[@as Relm.Handle]],
			payload,
			vprops[vnode],
			vnode.state,
			base_handler
		)
	elseif base_handler then
		return base_handler(
			vnode --[[@as Relm.Handle]],
			payload,
			vprops[vnode],
			vnode.state
		)
	end
end

---@param vnode Relm.Internal.VNode
---@param payload Relm.MessagePayload
vmsg = function(vnode, payload)
	payload.propagation_mode = "unicast"
	return barrier_wrap(vmsg_impl, vnode, payload)
end

local function vmsg_bubble_impl(vnode, payload, resent)
	if resent == true then
		vnode = vnode.parent
	end
	while vnode and vnode.type do
		if vmsg_impl(vnode, payload) then
			return
		end
		vnode = vnode.parent
	end
end

---@param vnode Relm.Internal.VNode
---@param	payload Relm.MessagePayload
---@param resent boolean?
local function vmsg_bubble(vnode, payload, resent)
	payload.propagation_mode = "bubble"
	return barrier_wrap(vmsg_bubble_impl, vnode, payload, resent)
end

local function vmsg_broadcast_impl(vnode, payload, resent)
	if vnode and vnode.type then
		if not resent then
			if vmsg_impl(vnode, payload) then
				return
			end
		end
		local children = vnode.children
		if children then
			for i = 1, #children do
				vmsg_broadcast_impl(children[i], payload)
			end
		end
	end
end

---@param vnode Relm.Internal.VNode
---@param payload Relm.MessagePayload
---@param resent boolean?
local function vmsg_broadcast(vnode, payload, resent)
	payload.propagation_mode = "broadcast"
	return barrier_wrap(vmsg_broadcast_impl, vnode, payload, resent)
end

--------------------------------------------------------------------------------
-- QUERIES
--------------------------------------------------------------------------------

local function vquery(node, payload)
	if not node or not node.type then
		return false, nil
	end
	local target_def = registry[node.type]
	if target_def and target_def.query then
		return target_def.query(
			node --[[@as Relm.Handle]],
			payload,
			vprops[node],
			node.state
		)
	end
	return false, nil
end

local function vquery_bubble(node, payload)
	while node and node.type do
		local handled, result = vquery(node, payload)
		if handled then
			return handled, result
		end
		node = node.parent
	end
	return false, nil
end

local function vquery_broadcast(node, payload)
	local handled, result = vquery(node, payload)
	if handled then
		return handled, result
	end
	local children = node.children
	if not children or #children == 0 then
		return false, nil
	end
	if #children == 1 then
		return vquery_broadcast(children[1], payload)
	else
		-- Scatter/gather over children
		---@type table<int|string, Relm.QueryResponse>
		local results = { [WAS_GATHERED] = true }
		local overall_handled = false
		for i = 1, #children do
			local child = children[i]
			handled, result = vquery_broadcast(child, payload)
			overall_handled = overall_handled or handled
			if handled then
				if result and type(result) == "table" and result.query_tag then
					results[result.query_tag] = result
				else
					results[i] = result
				end
			else
				results[i] = nil
			end
		end
		return overall_handled, results
	end
end

--------------------------------------------------------------------------------
-- API: EVENT HANDLING
--------------------------------------------------------------------------------

---@class (exact) Relm.MessagePayload.FactorioEvent: Relm.MessagePayload
---@field public key "factorio_event"
---@field public event Relm.GuiEventData The Factorio event data. This is the same as the event data passed to `script.on_event` handlers.
---@field public name defines.events The name of the Factorio event.

---@param event Relm.GuiEventData
local function dispatch(event)
	if event.element and event.element.tags[LISTEN_KEY] then
		local vnode = get_vnode(event.element)
		if vnode and vnode.type then
			vmsg_bubble(
				vnode,
				{ key = "factorio_event", event = event, name = event.name }
			)
		end
	end
end

---Install Relm's GUI event handlers. Your mod must call this if you want
---events in your Relm GUIs. You may override and delegate individual handlers
---AFTER calling this function if need be.
function lib.install_event_handlers()
	for id in pairs(gui_events) do
		if not script.get_event_handler(id) then
			script.on_event(id, dispatch)
		end
	end
end

---Delegate an event to Relm. If you need to override a Relm default GUI handler
---with a custom one, you may call this to enable Relm to process the event
---if your code doesn't.
function lib.delegate_event(event)
	return dispatch(event)
end

--------------------------------------------------------------------------------
-- API: STORAGE
--------------------------------------------------------------------------------

---@class Relm.Internal.Root
---@field public root_element LuaGuiElement The rendered root element.
---@field public player_index int The player index of the owning player of the root element.
---@field public vtree_root Relm.Internal.VNode The root of the virtual tree.
---@field public root_element_name string Relm element name used to render the root
---@field public root_props Relm.Props The properties used to render the root

---Initialize Relm's storage. Must be called in the mod's `on_init` handler or
---in a migration.
function lib.init()
	-- Lint diagnostic here is ok. We can't disable it because of luals bug.
	if not storage._relm then
		storage._relm = { roots = {}, root_counter = 0 }
	end
end

---This function MUST BE CALLED in `on_load` handler in order to re-sync
---Relm state with the save file. Failure to do so WILL CAUSE CRASHES after
---loading saves.
function lib.on_load()
	---@type table<int,Relm.Internal.Root>
	local roots = storage._relm.roots
	for _, root in pairs(roots) do
		vhydrate(
			root.vtree_root,
			{ type = root.root_element_name, props = root.root_props }
		)
	end
end

--------------------------------------------------------------------------------
-- API: ROOTS
--------------------------------------------------------------------------------

---@param start Relm.Internal.VNode?
local function find_first_elem(start)
	while start and not start.elem do
		start = start.children and start.children[1]
	end
	return start and start.elem
end

---Renders a new Relm root element by adding it to the given base element. The
---element will be rendered with the given props, along with an additional
---`root_id` prop reflecting the ID of the newly created Relm root.
---
---@param base_element LuaGuiElement The render result will be `.add`ed to this element. e.g. `player.gui.screen`. MUST NOT be within another Relm tree.
---@param type string Type of Relm element to render at the root. Must have previously been defined with `relm.define_element`.
---@param props Relm.Props Props to pass to the newly created root. Unlike other props in Relm, these MUST be serializable (no functions!) and may not contain `children`.
---@param name? string If given, the rendered root will have this name within the `base_element`.
---@return Relm.RootId? root_id ID of the newly created root.
---@return LuaGuiElement? root_element The root Factorio element.
function lib.root_create(base_element, type, props, name)
	if not base_element or not base_element.valid then
		error("relm.root_create: Base element must be a valid LuaGuiElement.")
	end
	if not type or not registry[type] then
		error("relm.root_create: Element type " .. (type or "") .. " not found.")
	end
	if props.children then
		error("relm.root_create: Root props may not contain children.")
	end

	local player_index = base_element.player_index
	local relm_state = storage._relm

	local id = storage._relm.root_counter + 1
	storage._relm.root_counter = id
	props.root_id = id

	relm_state.roots[id] = {
		player_index = player_index,
		vtree_root = {},
		root_element_name = type,
		root_props = props,
	}
	local vtree_root = relm_state.roots[id].vtree_root

	-- Render the entire tree from the root
	enter_side_effect_barrier()
	vapply(vtree_root, { type = type, props = props })
	vpaint(vtree_root, {
		elem = base_element,
		index = 1,
		is_root = true,
		constructor = function(painted_props)
			local old_name = painted_props.name
			painted_props.name = name
			local elt = base_element.add(painted_props)
			painted_props.name = old_name
			local tags = elt.tags
			tags["__relm_root"] = id
			elt.tags = tags
			return elt
		end,
	})
	exit_side_effect_barrier()
	local created_elt = find_first_elem(vtree_root)

	if created_elt then
		relm_state.roots[id].root_element = created_elt
	else
		log.error("root_create: rendered nothing")
		lib.root_destroy(id)
		return nil
	end

	return id, created_elt
end

---Destoys a root and all associated child elements.
---@param id Relm.RootId The ID of the root.
function lib.root_destroy(id)
	local relm_state = storage._relm
	local root = relm_state.roots[id]
	if not root then
		return
	end
	enter_side_effect_barrier()
	vprune(root.vtree_root)
	exit_side_effect_barrier()
	local root_element = root.root_element
	if root_element and root_element.valid then
		root_element.destroy()
	end
	relm_state.roots[id] = nil
	return true
end

---Returns a handle to the root element with the given ID.
---@param id Relm.RootId?
---@return Relm.Handle? handle A handle to the root element.
function lib.root_handle(id)
	if not id then
		return nil
	end
	local root = storage._relm.roots[id]
	if root then
		return root.vtree_root
	end
end

---Given a `LuaGuiElement`, attempt to find a Relm handle to its associated
---Relm element.
---@param element? LuaGuiElement The element to search for.
---@return Relm.Handle? handle A handle to the node associated with the element.
function lib.get_handle(element)
	return get_vnode(element) --[[@as Relm.Handle]]
end

---@class Relm.PublicRootInfo
---@field public id Relm.RootId The ID of the root.
---@field public player_index int The player index of the root.
---@field public handle Relm.Handle The handle to the root element.
---@field public gui_element LuaGuiElement The root element.

---Enumerate all global Relm roots. This should only be used when necessary
---to find a global root. Note that **all** players' roots will be returned.
---@return Relm.PublicRootInfo[] roots A list of all global Relm roots.
function lib.roots()
	local roots = {}
	for id, root in pairs(storage._relm.roots) do
		if root.root_element and root.root_element.valid then
			roots[#roots + 1] = {
				id = id,
				player_index = root.player_index,
				handle = root.vtree_root,
				gui_element = root.root_element,
			}
		end
	end
	return roots
end

--------------------------------------------------------------------------------
-- API: SIDE EFFECTS
--------------------------------------------------------------------------------

---Repaint the Relm element with the given `handle`.
---@param handle Relm.Handle
function lib.paint(handle)
	barrier_wrap(vrepaint, handle --[[@as Relm.Internal.VNode]])
end

---Change the state of the Relm element with the given `handle`.
---@param handle Relm.Handle
---@param state? table|number|string|int|boolean|fun(current_state: Relm.State): Relm.State The new state, or an update function of the current state.
---@return nil
function lib.set_state(handle, state)
	---@diagnostic disable-next-line: cast-type-mismatch
	---@cast handle Relm.Internal.VNode
	if handle and handle.type then
		if type(state) == "function" then
			state = state(handle.state)
		end
		return vstate(handle, state)
	end
end

---Send a message directly to the Relm element with the given `handle`.
---If the target element does not handle the message, it will not propagate.
---@param handle Relm.Handle
---@param msg Relm.MessagePayload
function lib.msg(handle, msg)
	return vmsg(handle --[[@as Relm.Internal.VNode]], msg)
end

---Send a message to the Relm element with the given `handle`, which if not
---handled will bubble up the vtree to the root.
---@param handle Relm.Handle
---@param msg Relm.MessagePayload
---@param resent boolean? If `true`, resends ignoring the current node. Useful for nodes that transform messages going through them.
function lib.msg_bubble(handle, msg, resent)
	return vmsg_bubble(handle --[[@as Relm.Internal.VNode]], msg, resent)
end

---Send a message to the Relm element with the given `handle`, which if not
---handled will be broadcast to all children.
---@param handle Relm.Handle
---@param msg Relm.MessagePayload
---@param resent boolean? If `true`, resends ignoring the current node. Useful for nodes that transform messages going through them.
function lib.msg_broadcast(handle, msg, resent)
	return vmsg_broadcast(handle --[[@as Relm.Internal.VNode]], msg, resent)
end

---Shallowly compare two values for equality. If tables, they are compared
---by key shallowly with `==`.
---@param lhs any
---@param rhs any
---@return boolean
local function shallow_eq(lhs, rhs)
	if type(lhs) ~= "table" or type(rhs) ~= "table" then
		return lhs == rhs
	end

	for key, value in pairs(lhs) do
		if rhs[key] ~= value then
			return false
		end
	end

	for key in pairs(rhs) do
		if lhs[key] == nil then
			return false
		end
	end

	return true
end

local function setup_hook(wants_state, wants_transient)
	hook_num = hook_num + 1
	local node = hook_node --[[@as Relm.Internal.VNode]]
	local state, transient
	if wants_state then
		local hooks = node.hooks or {}
		if not node.hooks then
			node.hooks = hooks
		end
		state = hooks[hook_num] or {}
		if not hooks[hook_num] then
			hooks[hook_num] = state
		end
	end
	if wants_transient then
		if not vhooks_transient[node] then
			vhooks_transient[node] = {}
		end
		local hooks = vhooks_transient[node]
		transient = hooks[hook_num] or {}
		if not hooks[hook_num] then
			hooks[hook_num] = transient
		end
	end
	return state, transient
end

---Isolate a side effect from the rendering algorithm. Similar to React's
---`useEffect` hook, this will run the given `callback` and `cleanup` functions
---in the following way:
---
---  - When the element is first created, `callback` will be called with `nil`
---    as the previous effect key, and `cleanup` will be stored.
---  - When the effect key changes as defined by shallow comparison, the
---    previous `cleanup` will be run, `callback` will be run with the previous
---    effect key provided, and the new `cleanup` will be stored.
---  - When the element is destroyed, the last stored `cleanup` will be run.
---
---This function may **only** be called during `render` and **may not** be
---called conditionally.
---@param effect_key Relm.EffectKey The effect key, compared shallowly against the previous to determine if the effect should run. `nil` is NOT a valid effect key.
---@param callback fun(me: Relm.Handle, current_key: Relm.EffectKey, previous_key: Relm.EffectKey?): any Callback that runs on creation or whenever the effect key changes as defined by shallow comparison. Return value will be passed to the next `cleanup` when it runs.
---@param cleanup? fun(previous_callback_return: any) Cleanup that runs on destruction; the previous cleanup will be run when the effect key changes as well.
function lib.use_effect(effect_key, callback, cleanup)
	if not hook_node then
		error("relm.use_effect: must be called during `render` of a Relm element.")
	end
	if effect_key == nil then
		error("relm.use_effect: effect key may not be `nil`")
	end
	local state, transient = setup_hook(true, true)
	local last_effect_key = state.effect_key
	local last_callback_return = state.callback_return
	local last_cleanup = transient.cleanup
	if render_is_hydrating then
		-- Hydrating render, restore cleanup function but do nothing else
		transient.cleanup = cleanup
		return
	else
		if not shallow_eq(effect_key, last_effect_key) then
			state.effect_key = effect_key
			if last_cleanup then
				last_cleanup(last_callback_return)
			end
			transient.cleanup = cleanup
			state.callback_return =
				callback(hook_node --[[@as Relm.Handle]], effect_key, last_effect_key)
		end
	end
end

--------------------------------------------------------------------------------
-- API: QUERIES
--------------------------------------------------------------------------------

---Send a query to the Relm element with the given `handle`, which if not
---handled, will not propagate.
---@param handle Relm.Handle
---@param payload Relm.MessagePayload
---@return boolean handled Whether the query was handled.
---@return Relm.QueryResponse? result The result of the query, if handled.
function lib.query(handle, payload)
	return vquery(handle --[[@as Relm.Internal.VNode]], payload)
end

---Send a query to the Relm element with the given `handle`, which will
---propagate upward to parents if not handled.
---@param handle Relm.Handle
---@param payload Relm.MessagePayload
---@return boolean handled Whether the query was handled.
---@return Relm.QueryResponse? result The result of the query, if handled.
function lib.query_bubble(handle, payload)
	return vquery_bubble(handle --[[@as Relm.Internal.VNode]], payload)
end

---Send a query to the Relm element with the given `handle`, which will
---propagate to all children if not handled. Responses from children past
---a split in the vtree will be gathered into a table indexed by either
---child number or `query_tag` if present. `handled` will be true if *any*
---child reached by the propagation reported that it handled the query.
---@param handle Relm.Handle
---@param payload Relm.MessagePayload
---@return boolean handled Whether the query was handled.
---@return Relm.QueryResponse? result The result of the query, if handled.
function lib.query_broadcast(handle, payload)
	return vquery_broadcast(handle --[[@as Relm.Internal.VNode]], payload)
end

---Distinguish between a query result that was gathered from children and one ---that is a single `table`-valued result.
---@param result? Relm.QueryResponse
---@return boolean
function lib.query_was_gathered(result)
	if result and type(result) == "table" then
		return result[WAS_GATHERED]
	else
		return false
	end
end

------------------------------------------------------------------------------
-- API: ELEMENTS
--------------------------------------------------------------------------------

---Define a new re-usable Relm element type.
---@param definition Relm.ElementDefinition
---@return Relm.NodeFactory #A factory function that creates a node of this type.
function lib.define_element(definition)
	if not definition.name then
		error("Element definition must have a name.")
	end
	if registry[definition.name] then
		error("Element " .. definition.name .. " already defined.")
	end
	if not definition.render then
		error("Element " .. definition.name .. " must have a render function.")
	end

	registry[definition.name] = definition
	local name = definition.name
	if definition.factory then
		-- If a factory is provided, use it.
		return definition.factory
	else
		return function(props, children)
			props = props or {}
			props.children = children
			return {
				type = name,
				props = props,
			}
		end
	end
end

---Generate a node for an element of the given named type with the given
---props. Returns `nil` if the type was invalid.
---@param type string The type of element to create.
---@param props Relm.Props The properties to pass to the element.
---@return Relm.Node? node The generated node, or `nil` if the type was invalid.
function lib.element(type, props)
	if not type or not registry[type] then
		return nil
	end
	props = props or {}
	return {
		type = type,
		props = props,
	}
end

---A primitive element whose props are passed directly to Factorio GUI
---for rendering.
---@type fun(props: Relm.PrimitiveDefinition, children?: Relm.Node[]): Relm.Node
lib.Primitive = lib.define_element({
	name = "Primitive",
	render = function(props)
		return props.children
	end,
})

return lib
