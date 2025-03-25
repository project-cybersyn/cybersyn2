if ... ~= "__cybersyn2__.lib.relm" then
	return require("__cybersyn2__.lib.relm")
end

local counters = require("__cybersyn2__.lib.counters")

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
---@field public is_primitive? true `true` if primitive.
---@field public is_listener? true `true` if this node is a primitive listening to Factorio events.

---Definition of a reusable element distinguished by its name.
---@class Relm.ElementDefinition
---@field public name string The name of this element. Must be unique across the Lua state.
---@field public render Relm.Element.RenderDefinition
---@field public receive? Relm.Element.ReceiveDefinition
---@field public diff? Relm.Element.DiffDefinition
---@field public state? Relm.Element.StateDefinition

---@alias Relm.Props table

---@alias Relm.State table

---@alias Relm.Renderable Relm.Node|Relm.Node[]|nil

---@alias Relm.Element.RenderDefinition fun(props: Relm.Props, state?: Relm.State, children?: Relm.Node[]): Relm.Renderable

---@alias Relm.Element.ReceiveDefinition fun(message: string, props: table, state?: table)

---@alias Relm.Element.StateDefinition fun(initial_props: Relm.Props): Relm.State

---@alias Relm.NodeFactory fun(props: Relm.Props, children?: Relm.Node[]): Relm.Node

--------------------------------------------------------------------------------
-- CONSTANTS AND GLOBALS
--------------------------------------------------------------------------------

function noop() end

local RO_KEYS = {
	column_count = true,
	elem_type = true,
	type = true,
	player_index = true,
	children_names = true,
	direction = true,
	name = true,
	parent = true,
	gui = true,
	index = true,
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
	-- column_alignments = {read_only = true},
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

---Initialize Relm's storage. Must be called in the mod's `on_init` handler.
---BEFORE any counters are utilized.
function lib.init()
	if not storage._relm then
		storage._relm = { players = {} }
	end
end

---@class Relm.PlayerState
---@field public player_index uint
---@field public roots table<int, Relm.Root> The roots the player has open.

---@class Relm.Root
---@field public real_root LuaGuiElement The rendered root element.
---@field public vtree_root Relm.Internal.VNode The root of the virtual tree.

---Internal representation of a vtree node. This is stored in state.
---@class (exact) Relm.Internal.VNode
---@field public name? string Element name of this node. `nil` represents a node that has been pruned.
---@field public state? table
---@field public is_primitive? true `True` if this maps onto a factorio gui element.
---@field public children? Relm.Internal.VNode[] Ordered children.
---@field public elem? LuaGuiElement The Lua element this node maps to, if a real element.
---@field public is_being_pruned true? `True` if this node is being pruned.

---@class Relm.Internal.PrimitiveTags
---@field public root int Root id this node belongs to
---@field public event_id? int Event ID of this node in the root, if it is assigned one.

---@alias Relm.Internal.DiffState table<Relm.Internal.VNode, boolean> A map of vnodes that have been elided in the vdiffing process.

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

---@param elem LuaGuiElement? The element being compared against.
---@param vnode Relm.Internal.VNode? The vtree to apply.
---@param diff_state Relm.Internal.DiffState Helper state in diffing.
---@param constructor fun(def: Relm.PrimitiveDefinition, arg1: any?, arg2: any?): LuaGuiElement Create an element in the appropriate slot of the parent.
---@param destructor fun(elem: LuaGuiElement, arg1: any?, arg2: any?) Destroy the `elem` passed to this function.
---@param cd_arg1 any? General arguments for creator/destructor
---@param cd_arg2 any? General arguments for creator/destructor
local function adiff(
	elem,
	vnode,
	diff_state,
	constructor,
	destructor,
	cd_arg1,
	cd_arg2
)
	-- Find renderable vnode. Early out if vdom diff is nil.
	while vnode and not vnode.is_primitive do
		if vnode and diff_state[vnode] then
			return
		elseif vnode.children then
			vnode = vnode.children[1]
		else
			vnode = nil
		end
	end
	if vnode and diff_state[vnode] then
		return
	end
	-- If nothing, destroy the element
	if not vnode then
		if elem then
			return destructor(elem, cd_arg1, cd_arg2)
		end
		return
	end
	-- If different type, destroy the element
	if elem and elem.type ~= vnode.props.type then
		destructor(elem, cd_arg1, cd_arg2)
		elem = nil
	end
	-- If no element, create it
	if not elem then
		-- TODO: props sanitization?
		elem = constructor(vnode.props, cd_arg1, cd_arg2)
		if not elem then
			-- TODO: error handling for failed construction?
			return
		end
		-- TODO: this is where to generate event handler keys
		vnode.elem = elem
	end
	-- Apply props
	for key, value in pairs(vnode.props) do
		-- TODO: `style.column_alignments`
		if STYLE_KEYS[key] then
			elem.style[key] = value
		elseif not RO_KEYS[key] then
			elem[key] = value
		end
	end
	-- Apply children
	local elem_children = elem.children
	local n_vchildren = vnode.children and #vnode.children or 0
	for i = 1, n_vchildren do
		local vchild = vnode.children[i]
		local echild = elem_children and elem_children[i]
		adiff(echild, vchild, diff_state, construct_child, destruct_child, elem, i)
	end
	if elem_children then
		for i = n_vchildren + 1, #elem_children do
			elem_children[i].destroy()
		end
	end
end

---Diff two vnodes to determine if painting is needed at all.
local function vnode_diff(def, vnode, node)
	return true
end

---@param node Relm.Internal.VNode
---@param elem? LuaGuiElement
---@param destroy fun(elem: LuaGuiElement, arg1: any?, arg2: any?) Destroy the Factorio element this vnode corresponds to
---@param cd_arg1 any? General arguments for creator/destructor
---@param cd_arg2 any? General arguments for creator/destructor
local function vtree_prune(node, elem, destroy, cd_arg1, cd_arg2)
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
	node.state = nil
	node.name = nil
end

---@param def? Relm.ElementDefinition
---@param type? string
---@param props? Relm.Props
---@param state? Relm.State
---@param children? Relm.Renderable
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

---@param vnode Relm.Internal.VNode The virtual node to hydrate.
---@param node? Relm.Node The node specification to match to the root.
---@param elem? LuaGuiElement Real element corresponding to this vnode if any
---@param construct fun(def: Relm.PrimitiveDefinition, arg1: any?, arg2: any?): LuaGuiElement Create the Factorio element this vnode corresponds to.
---@param destroy fun(elem: LuaGuiElement, arg1: any?, arg2: any?) Destroy the Factorio element this vnode corresponds to
---@param cd_arg1 any? General arguments for creator/destructor
---@param cd_arg2 any? General arguments for creator/destructor
local function vtree_diff(
	vnode,
	node,
	elem,
	construct,
	destroy,
	cd_arg1,
	cd_arg2
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
	local n_render_children = #render_children
	if not vnode.children then
		vnode.children = {}
	end
	local vchildren = vnode.children --[[@as Relm.Internal.VNode[] ]]

	if node.is_primitive then
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
			elseif not RO_KEYS[key] then
				elem[key] = value
			end
		end
		-- Real-element child handling
		-- TODO: factor to function.
		local elem_children = elem.children
		for i = 1, n_render_children do
			local vchild = vchildren[i]
			if not vchild then
				vchildren[i] = {}
				vchild = vchildren[i]
			end
			-- TODO: handle nil renders
			-- find out if vtree_diff actually rendered a primitive or not...
			local echild = elem_children and elem_children[i]
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
		-- Prune children beyond those rendered.
		for i = n_render_children + 1, #vchildren do
			vtree_prune(
				vchildren[i],
				elem_children and elem_children[i],
				destroy_child,
				elem,
				i
			)
		end
	else
		-- Pure virtual children handling
		for i = 1, n_render_children do
			local vchild = vchildren[i]
			if not vchild then
				vchildren[i] = {}
				vchild = vchildren[i]
			end
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
		for i = n_render_children + 1, #vchildren do
			vtree_prune(vchildren[i], elem, destroy, cd_arg1, cd_arg2)
			vchildren[i] = nil
		end
	end
end

local function get_or_create_player_state(player_index)
	local pstate = storage._relm.players[player_index]
	if not pstate then
		storage._relm.players[player_index] = {
			player_index = player_index,
			roots = {},
		}
		pstate = storage._relm.players[player_index]
	end
	return pstate
end

---Creates a root.
function lib.create_root() end

---Destroys a root and all components beneath it.
function lib.destroy_root() end

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

---@param props Relm.PrimitiveDefinition
---@param children? Relm.Node[]
---@return Relm.Node
function lib.Primitive(props, children)
	return {
		type = props.type,
		props = props,
		children = children,
		is_primitive = true,
	}
end

lib.define_element({
	name = "Terst",
	render = function(props, state)
		return Frame({
			prop1 = "val1",
		}, {
			Frame({
				prop2 = "val2",
			}, {
				Label({
					caption = "Hello, world!",
				}),
			}),
			Button({
				caption = "Click me!",
				on_click = function()
					print("Button clicked!")
				end,
			}),
		})
	end,
	receive = function(message, props, state) end,
})
