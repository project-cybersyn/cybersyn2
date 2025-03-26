if ... ~= "__cybersyn2__.lib.relm" then
	return require("__cybersyn2__.lib.relm")
end

local log = require("__cybersyn2__.lib.logging")

local tremove = table.remove

local lib = {}

--------------------------------------------------------------------------------
-- NOTES
--------------------------------------------------------------------------------

-- Messages - bubble, scatter/gather
-- Message barriers
-- Structured paint
-- Side effects/`dirty_vnodes` diff arg

--------------------------------------------------------------------------------
-- PUBLIC TYPES
--------------------------------------------------------------------------------

-- The below class is from `flib` and serves much the same function here.

--- A GUI element definition. This extends `LuaGuiElement.add_param` with several new attributes.
--- Children may be defined in the array portion as an alternative to the `children` subtable.
--- @class Relm.PrimitiveDefinition: LuaGuiElement.add_param.button|LuaGuiElement.add_param.camera|LuaGuiElement.add_param.checkbox|LuaGuiElement.add_param.choose_elem_button|LuaGuiElement.add_param.drop_down|LuaGuiElement.add_param.flow|LuaGuiElement.add_param.frame|LuaGuiElement.add_param.line|LuaGuiElement.add_param.list_box|LuaGuiElement.add_param.minimap|LuaGuiElement.add_param.progressbar|LuaGuiElement.add_param.radiobutton|LuaGuiElement.add_param.scroll_pane|LuaGuiElement.add_param.slider|LuaGuiElement.add_param.sprite|LuaGuiElement.add_param.sprite_button|LuaGuiElement.add_param.switch|LuaGuiElement.add_param.tab|LuaGuiElement.add_param.table|LuaGuiElement.add_param.text_box|LuaGuiElement.add_param.textfield
--- @field style_mods LuaStyle? Modifications to make to the element's style.

---The primary output of `render` functions, representing nodes in the virtual
---tree.
---@class Relm.Node
---@field public type string The type of this node.
---@field public props? Relm.Props The properties of this node.
---@field public children? Relm.Node[] The children of this node.

---Opaque references used by Relm APIs. Do not read or write fields.
---@class (exact) Relm.Handle

---Definition of a reusable element distinguished by its name.
---@class Relm.ElementDefinition
---@field public name string The name of this element. Must be unique across the Lua state.
---@field public render Relm.Element.RenderDefinition
---@field public factory? Relm.NodeFactory
---@field public message? Relm.Element.MessageDefinition
---@field public state? Relm.Element.StateDefinition

---@alias Relm.Props table<string,string|number|int|boolean|table>

---@alias Relm.State string|number|int|boolean|table|nil

---@alias Relm.Children Relm.Node|Relm.Node[]|nil

---@class Relm.MessagePayload
---@field public key string A key identifying the type of the message.

---@alias Relm.Element.RenderDefinition fun(props: Relm.Props, state?: Relm.State, children?: Relm.Node[]): Relm.Children

---@alias Relm.Element.MessageDefinition fun(me: Relm.Handle, payload: Relm.MessagePayload, props: Relm.Props, state?: Relm.State): boolean|nil

---@alias Relm.Element.StateDefinition fun(initial_props: Relm.Props): Relm.State

---@alias Relm.NodeFactory fun(props?: Relm.Props, children?: Relm.Node[]): Relm.Children

--------------------------------------------------------------------------------
-- CONSTANTS AND GLOBALS
--------------------------------------------------------------------------------

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

---Registry of all elt types defined in this Relm instance.
---@type table<string, Relm.ElementDefinition>
local registry = {}

---Internal representation of a vtree node. This is stored in state.
---@class (exact) Relm.Internal.VNode: Relm.Node
---@field public state? Relm.State
---@field public children? Relm.Internal.VNode[]
---@field public elem? LuaGuiElement The Lua element this node maps to, if a real element.
---@field public is_being_pruned true? `True` if this node is being pruned.
---@field public index? uint Index in parent node
---@field public parent? Relm.Internal.VNode Parent of this node.

---Map from "<player_index>:<element_index>" to vnodes
---@type table<string, Relm.Internal.VNode>
local evcache = setmetatable({}, { __mode = "v" })

-- Forward declarations
local vmsg

--------------------------------------------------------------------------------
-- ELT->NODE CACHE
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

	log.trace("get_vnode cache miss", elt)
	local root_id = elt.tags["__relm_root"]
	if not root_id then
		log.trace(
			"get_vnode: ive got no roots (but my home was never on the ground)"
		)
		return nil
	end
	---@type Relm.Internal.Root?
	local root = storage._relm.roots[root_id]
	if not root then
		log.trace("get_vnode: bad root id", root_id)
		return nil
	end
	vnode = find_vnode(root.vtree_root, elt)
	evcache[cache_key] = vnode
	return vnode
end

--------------------------------------------------------------------------------
-- CORE RENDERING ALGORITHM
--------------------------------------------------------------------------------

---Diff a node against the live tree to determine if rendering is needed.
local function vnode_diff(def, vnode, node)
	return true
end

---Normalize calls and results of `element.render`
---@param def? Relm.ElementDefinition
---@param type? string
---@param props? Relm.Props
---@param state? Relm.State
---@param children? Relm.Children
---@return Relm.Node[]
local function normalized_render(def, type, props, state, children)
	if not def then
		def = registry[type or ""]
	end
	if not def then
		error("Element type " .. (type or "") .. " not found.")
	end
	local rendered_children = def.render(props or {}, state, children)
	-- Normalize to array
	if not rendered_children then
		rendered_children = {}
	elseif rendered_children.type then
		-- single node, promote to array
		rendered_children = { rendered_children }
	end
	return rendered_children
end

---@param node? Relm.Node
local function is_primitive(node)
	return node and node.type == "Primitive"
end

local vapply

---@param vnode Relm.Internal.VNode
local function vprune(vnode)
	if vnode.children then
		for i = 1, #vnode.children do
			vprune(vnode.children[i])
		end
		vnode.children = nil
	end
	-- TODO: unmount message

	vnode.type = nil
	vnode.elem = nil
	vnode.index = nil
	vnode.parent = nil
end

---@param vnode Relm.Internal.VNode
---@param render_children Relm.Node[]
local function vapply_children(vnode, render_children)
	if not vnode.children then
		vnode.children = {}
	end
	local vchildren = vnode.children --[[@as Relm.Internal.VNode[] ]]
	for i = 1, #render_children do
		local vchild = vchildren[i]
		if not vchild then
			---@diagnostic disable-next-line: missing-fields
			vchildren[i] = {}
			vchild = vchildren[i]
		end
		vchild.parent = vnode
		vchild.index = i
		vapply(vchild, render_children[i])
	end
	for i = #render_children + 1, #vchildren do
		vprune(vchildren[i])
		vchildren[i] = nil
	end
end

---@param vnode Relm.Internal.VNode
---@param node? Relm.Node
function vapply(vnode, node)
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
	-- Allow vdom diffing to elide entire subtrees.
	if not is_creating and not vnode_diff(target_def, vnode, node) then
		return
	end

	-- Create vnode
	vnode.type = target_type
	vnode.props = node.props
	if is_creating then
		if target_def.state then
			vnode.state = target_def.state(node.props)
		end
		vmsg(vnode, { key = "create" })
		-- TODO: queue mount effect
	end

	-- Render
	local render_children = normalized_render(
		target_def,
		target_type,
		node.props,
		vnode.state,
		node.children
	)
	return vapply_children(vnode, render_children)
end

---Force a vnode to rerender
---@param vnode Relm.Internal.VNode
local function vrender(vnode)
	local target_def = registry[vnode.type]
	local render_children =
		normalized_render(target_def, nil, vnode.props, vnode.state, vnode.children)
	return vapply_children(vnode, render_children)
end

--------------------------------------------------------------------------------
-- VNODE PAINTING
--------------------------------------------------------------------------------

local function vpaint_context_destroy(vprim, context)
	if vprim then
		local elem = vprim.elem
		if context and elem and elem.valid then
			local child = elem.children[context]
			if child then
				child.destroy()
			end
		end
	end
end

local function vpaint_context_get(vprim, context)
	if vprim then
		local elem = vprim.elem
		if elem and elem.valid then
			if context then
				return elem.children[context]
			else
				return elem
			end
		end
	else
		return nil
	end
end

---@param vprim Relm.Internal.VNode?
local function vpaint_context_create(vprim, context, props)
	if vprim then
		local elem = vprim.elem
		if context and elem and elem.valid then
			props.index = context
			local new_elem = elem.add(props)
			props.index = nil
			-- Inherit __relm_root
			local tags = new_elem.tags
			tags["__relm_root"] = elem.tags["__relm_root"]
			new_elem.tags = tags
			return new_elem
		end
	elseif type(context) == "function" then
		-- Render to context fn
		return context(props)
	end
end

---@param vnode Relm.Internal.VNode? Node tree to paint
---@param vprim Relm.Internal.VNode? Parent primitive node
---@param context any Context within parent primitive node
---@param same boolean? If true, the vnode type is the same as the last paint
local function vpaint(vnode, vprim, context, same)
	local elem = nil

	-- Iterate through virtual parents
	while vnode and not is_primitive(vnode) do
		vnode = vnode.children and vnode.children[1]
	end

	if not same then
		-- Create/destroy/typematch
		if (not vnode) or not vnode.type then
			return vpaint_context_destroy(vprim, context)
		end
		elem = vpaint_context_get(vprim, context)
		-- If different type, destroy the element
		if elem and elem.type ~= vnode.props.type then
			vpaint_context_destroy(vprim, context)
			vnode.elem = nil
			elem = nil
		end
		-- If no element, create it
		if not elem then
			-- TODO: props sanitization?
			elem = vpaint_context_create(vprim, context, vnode.props)
			if not elem then
				log.error("vpaint: failed to construct primitive", vnode.props)
				-- TODO: error handling for failed construction?
				return
			end
			-- TODO: this is where to generate event handler keys
			vnode.elem = elem
		end
	else
		if not vnode or not vnode.elem then
			log.error("vpaint: repaint without painted vnode", vnode)
			return
		end
		elem = vnode.elem --[[@as LuaGuiElement]]
	end

	-- Apply props
	for key, value in pairs(vnode.props) do
		-- TODO: `style.column_alignments`
		if STYLE_KEYS[key] then
			elem.style[key] = value
		elseif APPLICABLE_KEYS[key] then
			-- TODO: further investigate this, probably is an actual
			-- mistake here.
			elem[key] = value
		end
	end

	-- Apply tags
	local tags = elem.tags
	if vnode.props["listen"] then
		tags["__relm_listen"] = true
	else
		tags["__relm_listen"] = nil
	end
	elem.tags = tags

	-- Real-element child handling
	local vchildren = vnode.children or {}
	for i = 1, #vchildren do
		vpaint(vchildren[i], vnode, i)
	end
	local echildren = elem.children
	-- Prune children beyond those rendered.
	for i = #vchildren + 1, #echildren do
		echildren[i].destroy()
	end
	-- TODO: tabs frame
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
	vpaint(vnode, vnode, nil, true)
end

---@param start Relm.Internal.VNode?
local function find_first_elem(start)
	while start and not start.elem do
		start = start.children and start.children[1]
	end
	return start and start.elem
end

--------------------------------------------------------------------------------
-- SIDE EFFECTS
--------------------------------------------------------------------------------

-- TODO: consider a more efficient deque for barrier_queue

local barrier_count = 0
local barrier_queue = {}

local function enter_side_effect_barrier()
	barrier_count = barrier_count + 1
	log.trace("enter barrier, count", barrier_count)
end

local function pop_barrier_queue()
	if barrier_count == 0 and #barrier_queue > 0 then
		local op = tremove(barrier_queue, 1)
		local vnode = tremove(barrier_queue, 1)
		local arg = tremove(barrier_queue, 1)
		log.trace("popping", vnode.type, "from barrier queue with op", op)
		op(vnode, arg)
	end
end

local function exit_side_effect_barrier()
	barrier_count = barrier_count - 1
	log.trace("exit barrier, count", barrier_count)
	return pop_barrier_queue()
end

local function barrier_wrap(op, vnode, arg)
	if not vnode or not vnode.type then
		return pop_barrier_queue()
	end
	if barrier_count > 0 then
		log.trace("adding", vnode.type, "to barrier_queue", op, barrier_count)
		barrier_queue[#barrier_queue + 1] = op
		barrier_queue[#barrier_queue + 1] = vnode
		barrier_queue[#barrier_queue + 1] = arg
	else
		enter_side_effect_barrier()
		op(vnode, arg)
		return exit_side_effect_barrier()
	end
end

local function vstate_impl(vnode, arg)
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
	local target_def = registry[vnode.type]
	if target_def and target_def.message then
		return target_def.message(
			vnode --[[@as Relm.Handle]],
			payload,
			vnode.props,
			vnode.state
		)
	end
end

---@param vnode Relm.Internal.VNode
---@param payload Relm.MessagePayload
vmsg = function(vnode, payload)
	-- TODO: a unicast message probably doesn't need a barrier_wrap
	-- but there isnt much harm.
	return barrier_wrap(vmsg_impl, vnode, payload)
end

local function vbubble_impl(vnode, arg)
	while vnode and vnode.type do
		if vmsg_impl(vnode, arg) then
			return
		end
		vnode = vnode.parent
	end
end

---@param vnode Relm.Internal.VNode
---@param	payload Relm.MessagePayload
local function vbubble(vnode, payload)
	return barrier_wrap(vbubble_impl, vnode, payload)
end

--------------------------------------------------------------------------------
-- EVENT HANDLING
--------------------------------------------------------------------------------

-- h/t flib for this code
local gui_events = {}
for name, id in pairs(defines.events) do
	if string.find(name, "on_gui_") then
		gui_events[id] = true
	end
end

local function dispatch(event)
	if event.element and event.element.tags["__relm_listen"] then
		local vnode = get_vnode(event.element)
		if vnode and vnode.type then
			vbubble(vnode, { key = "factorio_event", event = event })
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
-- API: STORAGE AND ROOTS
--------------------------------------------------------------------------------

---@class Relm.Internal.Root
---@field public root_element LuaGuiElement The rendered root element.
---@field public player_index int The player index of the owning player of the root element.
---@field public vtree_root Relm.Internal.VNode The root of the virtual tree.

---Initialize Relm's storage. Must be called in the mod's `on_init` handler or
---in a suitable migration.
function lib.init()
	-- Lint diagnostic here is ok. We can't disable it because of luals bug.
	if not storage._relm then
		storage._relm = { roots = {}, root_counter = 0 }
	end
end

---Creates a root.
---@param base_element LuaGuiElement The render result will be `.add`ed to this element. e.g. `player.gui.screen`. MUST NOT be within another Relm tree.
---@param node Relm.Children The node to render at the root. Must be a single node.
---@param name? string If given, the rendered root will have this name within the `base_element`.
---@return int? root_id ID of the newly created root.
---@return LuaGuiElement? root_element The root Factorio element.
function lib.root_create(base_element, node, name)
	if not base_element or not base_element.valid then
		error("Base element must be a valid LuaGuiElement.")
	end
	if not node then
		error("Node must be a valid Relm node.")
	end
	if not node.type then
		node = node[1]
	end
	if not node or not node.type then
		error("Node must be a valid Relm node.")
	end

	log.trace("root_create", node)

	local player_index = base_element.player_index
	local relm_state = storage._relm

	local id = storage._relm.root_counter + 1
	storage._relm.root_counter = id

	relm_state.roots[id] = {
		player_index = player_index,
		vtree_root = {},
	}
	node.props.root_id = id
	local vtree_root = relm_state.roots[id].vtree_root

	-- Render the entire tree from the root
	enter_side_effect_barrier()
	vapply(vtree_root, node)
	vpaint(vtree_root, nil, function(props)
		local old_name = props.name
		props.name = name
		local elt = base_element.add(props)
		props.name = old_name
		local tags = elt.tags
		tags["__relm_root"] = id
		elt.tags = tags
		return elt
	end)
	exit_side_effect_barrier()
	local created_elt = find_first_elem(vtree_root)

	if created_elt then
		log.trace("root_create, rendered root", created_elt)
		relm_state.roots[id].root_element = created_elt
		local tags = created_elt.tags
		tags["__relm_root"] = id
		created_elt.tags = tags
	else
		-- TODO: error handling here
		log.error("root_create: rendered nothing")
		lib.root_destroy(id)
	end

	return id, created_elt
end

---Destoys a root and all components beneath it.
---@param id int The ID of the root.
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

---@param id uint?
---@return Relm.Handle? handle A handle to the root element.
function lib.root_ref(id)
	if not id then
		return nil
	end
	local root = storage._relm.roots[id]
	if root then
		return root.vtree_root
	end
end

---Given a `LuaGuiElement`, attempt to find a Relm handle to its associated
---virtual element.
---@param element? LuaGuiElement The element to search for.
---@return Relm.Handle? handle A handle to the node associated with the element.
function lib.get_ref(element)
	return get_vnode(element) --[[@as Relm.Handle]]
end

--------------------------------------------------------------------------------
-- API: SIDE EFFECTS
--------------------------------------------------------------------------------

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

---@param handle Relm.Handle
---@param msg Relm.MessagePayload
function lib.bubble(handle, msg)
	return vbubble(handle --[[@as Relm.Internal.VNode]], msg)
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
			return {
				type = name,
				props = props or {},
				children = children,
			}
		end
	end
end

---A primitive element whose props are passed directly to Factorio GUI
---for rendering.
---@type fun(props: Relm.PrimitiveDefinition, children?: Relm.Node[]): Relm.Node
lib.Primitive = lib.define_element({
	name = "Primitive",
	render = function(_, _, children)
		return children
	end,
})

return lib
