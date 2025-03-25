if ... ~= "__cybersyn2__.lib.relm" then
	return require("__cybersyn2__.lib.relm")
end

local log = require("__cybersyn2__.lib.logging")

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
---@field public is_listener? true `true` if this node is a primitive listening to Factorio events.

---Definition of a reusable element distinguished by its name.
---@class Relm.ElementDefinition
---@field public name string The name of this element. Must be unique across the Lua state.
---@field public render Relm.Element.RenderDefinition
---@field public factory? fun(props: Relm.Props, children?: Relm.Node[]): Relm.Children
---@field public receive? Relm.Element.ReceiveDefinition
---@field public diff? Relm.Element.DiffDefinition
---@field public state? Relm.Element.StateDefinition

---@alias Relm.Props table

---@alias Relm.State table

---@alias Relm.Children Relm.Node|Relm.Node[]|nil

---@alias Relm.Element.RenderDefinition fun(props: Relm.Props, state?: Relm.State, children?: Relm.Node[]): Relm.Children

---@alias Relm.Element.ReceiveDefinition fun(message: string, props: table, state?: table)

---@alias Relm.Element.StateDefinition fun(initial_props: Relm.Props): Relm.State

---@alias Relm.NodeFactory fun(props: Relm.Props, children?: Relm.Node[]): Relm.Node

--------------------------------------------------------------------------------
-- CONSTANTS AND GLOBALS
--------------------------------------------------------------------------------

local function noop() end

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

--------------------------------------------------------------------------------
-- CORE RENDERING ALGORITHM
--------------------------------------------------------------------------------

---Internal representation of a vtree node. This is stored in state.
---@class (exact) Relm.Internal.VNode
---@field public name? string Element name of this node. `nil` represents a node that has been pruned.
---@field public props? Relm.Props
---@field public state? Relm.State
---@field public children? Relm.Internal.VNode[] Ordered children.
---@field public elem? LuaGuiElement The Lua element this node maps to, if a real element.
---@field public is_being_pruned true? `True` if this node is being pruned.
---@field public index? uint Index in parent node
---@field public parent? Relm.Internal.VNode Parent of this node.

---@class Relm.Internal.PrimitiveTags
---@field public root int Root id this node belongs to
---@field public event_id? int Event ID of this node in the root, if it is assigned one.

local function construct_child(def, parent, index)
	def.index = index
	local elem = parent.add(def)
	def.index = nil
	return elem
end

local function destroy_child(orig_elem, parent, index)
	local elem = parent.children[index]
	if elem then
		elem.destroy()
	end
end

---Diff a node against the live tree to determine if rendering is needed.
local function vnode_diff(def, vnode, node)
	return true
end

---Prune a branch of the vtree, possibly destroying related Factorio elts.
---@param node Relm.Internal.VNode
---@param elem? LuaGuiElement
---@param destroy fun(elem: LuaGuiElement, arg1: any?, arg2: any?) Destroy the Factorio element this vnode corresponds to
---@param cd_arg1 any? General arguments for creator/destructor
---@param cd_arg2 any? General arguments for creator/destructor
local function vtree_prune(node, elem, destroy, cd_arg1, cd_arg2)
	node.is_being_pruned = true
	if elem then
		destroy(elem, cd_arg1, cd_arg2)
	end
	-- Assume destroying the factorio element destroys elts associated to
	-- all children. Simply prune vdom nodes.
	if node.children then
		for i = 1, #node.children do
			vtree_prune(node.children[i], nil, noop)
		end
		node.children = nil
	end
	-- TODO: node_was_destroyed effect
	node.props = nil
	node.state = nil
	node.name = nil
	node.is_being_pruned = nil
	node.elem = nil
	node.index = nil
	node.parent = nil
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

-- Recursive forward declared
local vtree_diff

---Compare rendered children against known virtual children state, imposing
---the result on the vtree as well as the Factorio UI tree starting at `elem`
---@param vparent Relm.Internal.VNode
---@param vchildren Relm.Internal.VNode[]
---@param render_children Relm.Node[]
---@param elem LuaGuiElement
local function vtree_diff_primitive_children(
	vparent,
	vchildren,
	render_children,
	elem
)
	log.trace("vtree_diff_primitive_children", vchildren, render_children)
	local echildren = elem.children
	if #render_children == 0 then
		-- Fastpath 1: no children
		for i = 1, #vchildren do
			vtree_prune(vchildren[i], echildren[i], destroy_child, elem, i)
			vchildren[i] = nil
		end
	elseif #render_children == 1 then
		local vchild = vchildren[1]
		if not vchild then
			vchildren[1] = {}
			vchild = vchildren[1]
		end
		vchild.parent = vparent
		vchild.index = 1
		-- Fastpath 2: 1 child
		vtree_diff(
			vchildren[1],
			render_children[1],
			echildren and echildren[1],
			construct_child,
			destroy_child,
			elem,
			1
		)
		for i = 2, #vchildren do
			vtree_prune(vchildren[i], echildren[i], destroy_child, elem, i)
			vchildren[i] = nil
		end
	else
		for i = 1, #render_children do
			local rchild = render_children[i]
			if not rchild.props.key then
				rchild.props.key = "__IMPLIED_KEY__" .. i
			end
			local vchild = vchildren[i]
			if not vchild then
				vchildren[i] = {}
				vchild = vchildren[i]
			end
			-- TODO: handle nil renders?
			-- find out if vtree_diff actually rendered a primitive or not...
			local echild = echildren[i]
			vtree_diff(
				vchild,
				render_children[i],
				echild,
				construct_child,
				destroy_child,
				elem,
				i
			)
		end
		-- Update children after dom op
		echildren = elem.children
		-- Prune children beyond those rendered.
		for i = #render_children + 1, #vchildren do
			vtree_prune(
				vchildren[i],
				echildren and echildren[i],
				destroy_child,
				elem,
				i
			)
			vchildren[i] = nil
		end
	end
end

local function vtree_diff_virtual_children(
	vparent,
	vchildren,
	render_children,
	elem,
	construct,
	destroy,
	cd_arg1,
	cd_arg2
)
	-- Pure virtual children handling
	for i = 1, #render_children do
		local vchild = vchildren[i]
		if not vchild then
			vchildren[i] = {}
			vchild = vchildren[i]
		end
		vchild.parent = vparent
		vchild.index = i
		vtree_diff(
			vchild,
			render_children[i],
			elem,
			construct,
			destroy,
			cd_arg1,
			cd_arg2
		)
	end
	for i = #render_children + 1, #vchildren do
		vtree_prune(vchildren[i], elem, destroy, cd_arg1, cd_arg2)
		vchildren[i] = nil
	end
end

---Core tree comparison algorithm. Compares a rendered subtree to last known
---baseline while also comparing corresponding Factorio UI elts.
---@param vnode Relm.Internal.VNode The virtual node to hydrate.
---@param node? Relm.Node The node specification to match to the root.
---@param elem? LuaGuiElement Real element corresponding to this vnode if any
---@param construct fun(def: Relm.PrimitiveDefinition, arg1: any?, arg2: any?): LuaGuiElement Create the Factorio element this vnode corresponds to.
---@param destroy fun(elem: LuaGuiElement, arg1: any?, arg2: any?) Destroy the Factorio element this vnode corresponds to
---@param cd_arg1 any? General arguments for creator/destructor
---@param cd_arg2 any? General arguments for creator/destructor
vtree_diff = function(vnode, node, elem, construct, destroy, cd_arg1, cd_arg2)
	log.trace(
		"vtree_diff",
		vnode.name,
		node and node.type,
		vnode.props,
		node and node.props
	)
	-- Vnode-vnode matching
	-- Replace with nothing...
	if not node then
		if vnode.name then
			return vtree_prune(vnode, elem, destroy, cd_arg1, cd_arg2)
		end
		return
	end
	local target_type = node.type
	local target_def = registry[target_type]
	-- If type changing, prune the old node.
	if (not target_def) or target_type ~= vnode.name then
		vtree_prune(vnode, elem, destroy, cd_arg1, cd_arg2)
		elem = nil
	end
	-- TODO: maybe error here but for now, missing node type = just prune
	if not target_def then
		return
	end
	local is_creating = not vnode.name
	-- Allow vdom diffing to elide entire subtrees.
	if not is_creating and not vnode_diff(target_def, vnode, node) then
		return
	end
	vnode.name = target_type
	vnode.props = node.props
	if is_creating then
		if target_def.state then
			vnode.state = target_def.state(node.props)
		end
		-- TODO: mount effect
	end

	-- Render
	local render_children = normalized_render(
		target_def,
		target_type,
		node.props,
		vnode.state,
		node.children
	)
	if not vnode.children then
		vnode.children = {}
	end
	local vchildren = vnode.children --[[@as Relm.Internal.VNode[] ]]

	if node.type == "Primitive" then
		-- Vnode-elem matching
		-- If different type, destroy the element
		if elem and elem.type ~= node.props.type then
			destroy(elem, cd_arg1, cd_arg2)
			elem = nil
		end
		-- If no element, create it
		if not elem then
			-- TODO: props sanitization?
			elem = construct(node.props, cd_arg1, cd_arg2)
			if not elem then
				log.error("vdiff: failed to construct primitive", node.props)
				-- TODO: error handling for failed construction?
				return
			end
			-- TODO: this is where to generate event handler keys
			vnode.elem = elem
		end
		-- Apply props
		for key, value in pairs(node.props) do
			-- TODO: `style.column_alignments`
			if STYLE_KEYS[key] then
				elem.style[key] = value
			elseif APPLICABLE_KEYS[key] then
				elem[key] = value
			end
		end
		-- Real-element child handling
		vtree_diff_primitive_children(vchildren, render_children, elem)
	else
		vtree_diff_virtual_children(
			vchildren,
			render_children,
			elem,
			construct,
			destroy,
			cd_arg1,
			cd_arg2
		)
	end
end

local function vprune(vnode) end

local function vapply(vnode, node)
	if not node then
		if vnode.name then
			return vprune(vnode)
		end
		return
	end
	local target_type = node.type
	local target_def = registry[target_type]
	-- If type changing, prune the old node.
	if (not target_def) or target_type ~= vnode.name then
		vprune(vnode)
	end
	if not target_def then
		log.warn(
			"vapply: pruning subtree because no def for element type",
			target_type
		)
		return
	end
	local is_creating = not vnode.name
	-- Allow vdom diffing to elide entire subtrees.
	if not is_creating and not vnode_diff(target_def, vnode, node) then
		return
	end

	-- Create vnode
	vnode.name = target_type
	vnode.props = node.props
	if is_creating then
		if target_def.state then
			vnode.state = target_def.state(node.props)
		end
		-- TODO: mount effect
	end

	-- Render
	local render_children = normalized_render(
		target_def,
		target_type,
		node.props,
		vnode.state,
		node.children
	)

	-- Apply rendered children to vtree
	if not vnode.children then
		vnode.children = {}
	end
	local vchildren = vnode.children --[[@as Relm.Internal.VNode[] ]]
	for i = 1, #render_children do
		local vchild = vchildren[i]
		if not vchild then
			vchildren[i] = {}
			vchild = vchildren[i]
		end
		vapply(vchild, render_children[i])
	end
	for i = #render_children + 1, #vchildren do
		vprune(vchildren[i])
		vchildren[i] = nil
	end
end

--------------------------------------------------------------------------------
-- STORAGE AND ROOT RENDERING
--------------------------------------------------------------------------------

---@class Relm.Internal.Root
---@field public root_element LuaGuiElement The rendered root element.
---@field public player_index int The player index of the owning player of the root element.
---@field public vtree_root Relm.Internal.VNode The root of the virtual tree.

---Initialize Relm's storage. Must be called in the mod's `on_init` handler.
function lib.init()
	if not storage._relm then
		storage._relm = { roots = {}, root_counter = 0 }
	end
end

---Creates a root.
---@param base_element LuaGuiElement The render result will be `.add`ed to this element. e.g. `player.gui.screen`. MUST NOT be within another Relm tree.
---@param node Relm.Node The node to render at the root.
---@param name? string If given, the rendered root will have this name within the `base_element`.
---@return int? root_id ID of the newly created root.
---@return LuaGuiElement? root_element The root Factorio element.
function lib.root_create(base_element, node, name)
	if not base_element or not base_element.valid then
		error("Base element must be a valid LuaGuiElement.")
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

	-- Render the entire tree from the root
	local created_elt = nil
	vtree_diff(relm_state.roots[id].vtree_root, node, nil, function(def)
		if name then
			def.name = name
		end
		created_elt = base_element.add(def)
		def.name = nil
		return created_elt
	end, noop)

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
	vtree_prune(root.vtree_root, root.root_element, function(elt)
		elt.destroy()
	end)
	relm_state.roots[id] = nil
	return true
end

--------------------------------------------------------------------------------
-- ELEMENTS
--------------------------------------------------------------------------------

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

	local function factory(props, children)
		return {
			type = name,
			props = props,
			children = children,
		}
	end

	return factory
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
