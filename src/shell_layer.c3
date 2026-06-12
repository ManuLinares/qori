module qori;
import wl;
import wlr;

struct SceneLayers
{
	WlrSceneTree* background;
	WlrSceneTree* bottom;
	WlrSceneTree* toplevel;
	WlrSceneTree* top;
	WlrSceneTree* overlay;
	WlrSceneTree* session_lock;
}

fn void layer_surface_commit(WlListener* listener, void* data)
{
	LayerSurface* surface          = wl::@container_of(listener, LayerSurface, commit);
	WlrLayerSurfaceV1* wlr_surface = surface.wlr_layer_surface;

	if (!wlr_surface.initialized) return;

	WlrOutput* output = wlr_surface.output;
	if (output == null)
	{
		output = g_server.active_output != null ? g_server.active_output.wlr_output : null;
		wlr_surface.output = output;
	}

	bool mapped = wlr_surface.surface.mapped;
	if (wlr_surface.current.committed != 0 || surface.mapped != mapped)
	{
		surface.mapped = mapped;
		if (output != null) recalculate_usable_area(output);
	}

	if (wlr_surface.current.keyboard_interactive == EXCLUSIVE)
	{
		g_server.active_layer_surface = surface;
		WlrKeyboard* kb            = wlr::wlr_seat_get_keyboard(g_server.seat);
		WlrKeyboardModifiers* mods = kb != null ? &kb.modifiers : null;
		wlr::wlr_seat_keyboard_enter(g_server.seat, wlr_surface.surface, null, 0, mods);
	}
}

fn void layer_surface_destroy(WlListener* listener, void* data)
{
	LayerSurface* surface = wl::@container_of(listener, LayerSurface, destroy);
	if (g_server.active_layer_surface == surface)
	{
		g_server.active_layer_surface = null;
		if (g_server.focused_toplevel != null)
		{
			focus_toplevel(g_server.focused_toplevel);
		}
	}
	wl::wl_list_remove(&surface.link);
	layer_surface_cleanup_listeners(surface);

	WlrOutput* output = g_server.active_output != null ? g_server.active_output.wlr_output : null;
	recalculate_usable_area(output);
	mem::free(surface);
}

fn WlrSceneTree* get_layer_tree(uint layer)
{
	switch (layer)
	{
		case wlr::ZWLR_LAYER_SHELL_V1_LAYER_BACKGROUND: return g_server.layers.background;
		case wlr::ZWLR_LAYER_SHELL_V1_LAYER_BOTTOM: return g_server.layers.bottom;
		case wlr::ZWLR_LAYER_SHELL_V1_LAYER_TOP: return g_server.layers.top;
		case wlr::ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY: return g_server.layers.overlay;
		default: return g_server.layers.top;
	}
}

fn void server_new_layer_surface(WlListener* listener, void* data)
{
	WlrLayerSurfaceV1* wlr_layer_surface = (WlrLayerSurfaceV1*)data;

	WlrSceneTree* parent_tree                   = get_layer_tree(wlr_layer_surface.current.layer);
	WlrSceneLayerSurfaceV1* scene_layer_surface = wlr::wlr_scene_layer_surface_v1_create(parent_tree, wlr_layer_surface);

	LayerSurface* surface = mem::new(LayerSurface);
	surface.wlr_layer_surface = wlr_layer_surface;
	surface.scene_layer_surface = scene_layer_surface;
	surface.mapped = false;
	wlr_layer_surface.surface.data = scene_layer_surface.tree;

	associate_scene_node(&scene_layer_surface.tree.node, SceneObjectType.LAYER_SURFACE, surface);

	wl::wl_list_insert(&g_server.layer_surfaces, &surface.link);

	layer_surface_init_listeners(surface);
}

fn void layer_surface_init_listeners(LayerSurface* ls)
{
	listener_register(&ls.commit, &layer_surface_commit, &ls.wlr_layer_surface.surface.events.commit);
	listener_register(&ls.destroy, &layer_surface_destroy, &ls.wlr_layer_surface.events.destroy);
	listener_register(&ls.new_popup, &popup_handle_new_popup, &ls.wlr_layer_surface.events.new_popup);
}

fn void layer_surface_cleanup_listeners(LayerSurface* ls) => @cleanup_listeners(LayerSurface, ls);
