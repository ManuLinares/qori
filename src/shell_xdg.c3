module qori;
import wl, wlr;
import std::core::mem;

struct Popup
{
	WlrXdgPopup* xdg_popup;
	WlListener commit;
	WlListener destroy;
	WlListener reposition;
	WlListener new_popup;
}

fn void toplevel_toggle_maximize(Toplevel* toplevel)
{
	WlrXdgToplevel* xdg = toplevel.xdg_toplevel;
	uint serial         = 0;
	if (!toplevel.is_maximized)
	{
		toplevel.floating_x = toplevel.scene_tree.node.x;
		toplevel.floating_y = toplevel.scene_tree.node.y;
		toplevel.floating_width = xdg.base.current.geometry.width ?: xdg.base.surface.current.width;
		toplevel.floating_height = xdg.base.current.geometry.height ?: xdg.base.surface.current.height;
		WlrOutput* output = g_server.active_output != null ? g_server.active_output.wlr_output : null;
		if (output != null)
		{
			WlrBox ua = g_server.usable_area;
			wlr::wlr_scene_node_set_position(&toplevel.scene_tree.node, ua.x, ua.y);
			toplevel.pending_x = ua.x;
			toplevel.pending_y = ua.y;
			toplevel.pending_width = ua.width;
			toplevel.pending_height = ua.height;
			serial = wlr::wlr_xdg_toplevel_set_size(xdg, ua.width, ua.height);
			wlr::wlr_xdg_toplevel_set_maximized(xdg, true);
			toplevel.is_maximized = true;
		}
	}
	else
	{
		wlr::wlr_scene_node_set_position(&toplevel.scene_tree.node, toplevel.floating_x, toplevel.floating_y);
		toplevel.pending_x = toplevel.floating_x;
		toplevel.pending_y = toplevel.floating_y;
		toplevel.pending_width = toplevel.floating_width;
		toplevel.pending_height = toplevel.floating_height;
		serial = wlr::wlr_xdg_toplevel_set_size(xdg, toplevel.floating_width, toplevel.floating_height);
		wlr::wlr_xdg_toplevel_set_maximized(xdg, false);
		toplevel.is_maximized = false;
	}
	if (serial > 0)
	{
		toplevel.pending_configure_serial = serial;
	}
	if (toplevel.foreign_handle != null)
	{
		wlr::wlr_foreign_toplevel_handle_v1_set_maximized(toplevel.foreign_handle, toplevel.is_maximized);
	}
}

fn void update_top_layer_visibility()
{
	bool has_fullscreen = g_server.focused_toplevel != null && g_server.focused_toplevel.is_fullscreen;
	wlr::wlr_scene_node_set_enabled(&g_server.layers.top.node, !has_fullscreen);
}

fn void toplevel_toggle_fullscreen(Toplevel* toplevel)
{
	WlrXdgToplevel* xdg = toplevel.xdg_toplevel;
	uint serial         = 0;
	if (!toplevel.is_fullscreen)
	{
		toplevel.floating_x = toplevel.scene_tree.node.x;
		toplevel.floating_y = toplevel.scene_tree.node.y;
		toplevel.floating_width = xdg.base.current.geometry.width ?: xdg.base.surface.current.width;
		toplevel.floating_height = xdg.base.current.geometry.height ?: xdg.base.surface.current.height;
		WlrOutput* output = g_server.active_output != null ? g_server.active_output.wlr_output : null;
		if (output != null)
		{
			WlrBox box;
			wlr::wlr_output_layout_get_box(g_server.output_layout, output, &box);
			wlr::wlr_scene_node_set_position(&toplevel.scene_tree.node, box.x, box.y);
			toplevel.pending_x = box.x;
			toplevel.pending_y = box.y;
			toplevel.pending_width = box.width;
			toplevel.pending_height = box.height;
			serial = wlr::wlr_xdg_toplevel_set_size(xdg, box.width, box.height);
			wlr::wlr_xdg_toplevel_set_fullscreen(xdg, true);
			toplevel.is_fullscreen = true;
		}
	}
	else
	{
		wlr::wlr_scene_node_set_position(&toplevel.scene_tree.node, toplevel.floating_x, toplevel.floating_y);
		toplevel.pending_x = toplevel.floating_x;
		toplevel.pending_y = toplevel.floating_y;
		toplevel.pending_width = toplevel.floating_width;
		toplevel.pending_height = toplevel.floating_height;
		serial = wlr::wlr_xdg_toplevel_set_size(xdg, toplevel.floating_width, toplevel.floating_height);
		wlr::wlr_xdg_toplevel_set_fullscreen(xdg, false);
		toplevel.is_fullscreen = false;
	}
	if (serial > 0)
	{
		toplevel.pending_configure_serial = serial;
	}
	update_top_layer_visibility();
}

fn void toplevel_handle_request_fullscreen(WlListener* listener, void* data)
{
	Toplevel* toplevel = wl::@container_of(listener, Toplevel, request_fullscreen);
	if (!toplevel.xdg_toplevel.base.initialized) return;
	if (toplevel.xdg_toplevel.requested.fullscreen != toplevel.is_fullscreen)
	{
		toplevel_toggle_fullscreen(toplevel);
	}
}

fn void toplevel_handle_request_minimize(WlListener* listener, void* data)
{
	Toplevel* t = wl::@container_of(listener, Toplevel, request_minimize);
	if (!t.xdg_toplevel.base.initialized || t.is_minimized) return;
	t.is_minimized = true;
	wlr::wlr_scene_node_set_enabled(&t.scene_tree.node, false);
	if (t.foreign_handle != null)
	{
		wlr::wlr_foreign_toplevel_handle_v1_set_minimized(t.foreign_handle, true);
	}
	if (g_server.focused_toplevel == t)
	{
		Toplevel* next = null;
		WlList* pos    = g_server.toplevels.next;
		while (pos != &g_server.toplevels)
		{
			Toplevel* candidate = wl::@container_of(pos, Toplevel, link);
			if (candidate != t && !candidate.is_minimized)
			{
				next = candidate;
				break;
			}
			pos = pos.next;
		}
		focus_toplevel(next);
	}
}

fn void toplevel_handle_set_title(WlListener* listener, void* data)
{
	Toplevel* t = wl::@container_of(listener, Toplevel, set_title);
	if (t.foreign_handle != null && t.xdg_toplevel.title != null)
	{
		wlr::wlr_foreign_toplevel_handle_v1_set_title(t.foreign_handle, t.xdg_toplevel.title);
	}
}

fn void toplevel_handle_set_app_id(WlListener* listener, void* data)
{
	Toplevel* t = wl::@container_of(listener, Toplevel, set_app_id);
	if (t.foreign_handle != null && t.xdg_toplevel.app_id != null)
	{
		wlr::wlr_foreign_toplevel_handle_v1_set_app_id(t.foreign_handle, t.xdg_toplevel.app_id);
	}
}

fn void toplevel_handle_commit(WlListener* listener, void* data)
{
	Toplevel* toplevel           = wl::@container_of(listener, Toplevel, commit);
	WlrXdgSurface* xdg_surface   = toplevel.xdg_toplevel.base;
	WlrXdgToplevel* toplevel_wlr = toplevel.xdg_toplevel;

	if (xdg_surface.initial_commit)
	{
		uint serial = wlr::wlr_xdg_surface_schedule_configure(xdg_surface);
		if (serial > 0)
		{
			toplevel.pending_configure_serial = serial;
		}

		uint wm_caps = wlr::WLR_XDG_TOPLEVEL_WM_CAPABILITIES_WINDOW_MENU | wlr::WLR_XDG_TOPLEVEL_WM_CAPABILITIES_MAXIMIZE | wlr::WLR_XDG_TOPLEVEL_WM_CAPABILITIES_FULLSCREEN
			| wlr::WLR_XDG_TOPLEVEL_WM_CAPABILITIES_MINIMIZE;
		wlr::wlr_xdg_toplevel_set_wm_capabilities(toplevel_wlr, wm_caps);

		if (g_server.active_output != null)
		{
			WlrOutput* wlr_out = g_server.active_output.wlr_output;
			wlr::wlr_xdg_toplevel_set_bounds(toplevel_wlr, wlr_out.width, wlr_out.height);
		}

		if (toplevel_wlr.requested.maximized)
		{
			toplevel_toggle_maximize(toplevel);
		}
		focus_toplevel(toplevel);
		return;
	}

	int size_w = xdg_surface.geometry[2];
	int size_h = xdg_surface.geometry[3];

	if (toplevel.pending_width == 0 && toplevel.pending_height == 0 && size_w > 0 && size_h > 0)
	{
		toplevel.pending_width = size_w;
		toplevel.pending_height = size_h;
		if (g_server.active_output != null)
		{
			WlrBox ua    = g_server.usable_area;
			int center_x = ua.x + (ua.width - size_w) / 2;
			int center_y = ua.y + (ua.height - size_h) / 2;
			if (center_x < ua.x) center_x = ua.x;
			if (center_y < ua.y) center_y = ua.y;
			toplevel.pending_x = center_x;
			toplevel.pending_y = center_y;
			toplevel.current_x = center_x;
			toplevel.current_y = center_y;
			wlr::wlr_scene_node_set_position(&toplevel.scene_tree.node, center_x, center_y);
		}
	}

	if (size_w != toplevel.pending_width || size_h != toplevel.pending_height)
	{
		int extent_w = xdg_surface.surface.current.width;
		int extent_h = xdg_surface.surface.current.height;
		if (extent_w == toplevel.pending_width && extent_h == toplevel.pending_height)
		{
			size_w = extent_w;
			size_h = extent_h;
		}
	}

	bool update_required = false;
	if (toplevel.current_width != size_w || toplevel.current_height != size_h)
	{
		update_required = true;
	}

	uint serial = toplevel.pending_configure_serial;
	if (serial > 0 && serial == xdg_surface.current.configure_serial)
	{
		toplevel.pending_configure_serial = 0;
		update_required = true;
	}

	if (update_required)
	{
		int next_x = toplevel.pending_x;
		int next_y = toplevel.pending_y;

		// Heuristic to anchor appropriate edges during resize
		if (toplevel.current_x != toplevel.pending_x && toplevel.current_x + toplevel.current_width == toplevel.pending_x + toplevel.pending_width)
		{
			next_x = toplevel.pending_x + toplevel.pending_width - size_w;
		}
		if (toplevel.current_y != toplevel.pending_y && toplevel.current_y + toplevel.current_height == toplevel.pending_y + toplevel.pending_height)
		{
			next_y = toplevel.pending_y + toplevel.pending_height - size_h;
		}

		toplevel.current_x = next_x;
		toplevel.current_y = next_y;
		toplevel.current_width = size_w;
		toplevel.current_height = size_h;

		wlr::wlr_scene_node_set_position(&toplevel.scene_tree.node, next_x, next_y);

		if (toplevel.pending_configure_serial == 0)
		{
			toplevel.pending_x = next_x;
			toplevel.pending_y = next_y;
			toplevel.pending_width = size_w;
			toplevel.pending_height = size_h;
			toplevel_wlr.scheduled.width = size_w;
			toplevel_wlr.scheduled.height = size_h;
		}
	}
}

fn void toplevel_handle_request_maximize(WlListener* listener, void* data)
{
	Toplevel* toplevel = wl::@container_of(listener, Toplevel, request_maximize);
	if (!toplevel.xdg_toplevel.base.initialized) return;
	if (toplevel.xdg_toplevel.requested.maximized != toplevel.is_maximized)
	{
		toplevel_toggle_maximize(toplevel);
	}
}

fn void toplevel_handle_request_move(WlListener* listener, void* data)
{
	Toplevel* toplevel = wl::@container_of(listener, Toplevel, request_move);
	if (toplevel.is_maximized) return;

	g_server.grabbed_toplevel = toplevel;
	g_server.grab_edges = 0;
	g_server.grab_x = g_server.cursor.x - toplevel.scene_tree.node.x;
	g_server.grab_y = g_server.cursor.y - toplevel.scene_tree.node.y;
	g_server.grab_client_initiated = true;
}

fn void toplevel_handle_request_resize(WlListener* listener, void* data)
{
	Toplevel* toplevel                    = wl::@container_of(listener, Toplevel, request_resize);
	wlr::WlrXdgToplevelResizeEvent* event = (wlr::WlrXdgToplevelResizeEvent*)data;
	if (toplevel.is_maximized) return;

	g_server.grabbed_toplevel = toplevel;
	g_server.grab_edges = event.edges;
	g_server.grab_x = g_server.cursor.x;
	g_server.grab_y = g_server.cursor.y;
	g_server.grab_node_x = toplevel.scene_tree.node.x;
	g_server.grab_node_y = toplevel.scene_tree.node.y;
	g_server.grab_width = toplevel.current_width;
	g_server.grab_height = toplevel.current_height;
	g_server.grab_client_initiated = true;
}

fn void toplevel_handle_destroy(WlListener* listener, void* data)
{
	Toplevel* toplevel                 = wl::@container_of(listener, Toplevel, destroy);
	bool was_focused                   = g_server.focused_toplevel == toplevel;
	WlrForeignToplevelHandleV1* handle = toplevel.foreign_handle;
	if (g_server.grabbed_toplevel == toplevel)
	{
		g_server.grabbed_toplevel = null;
		g_server.grab_edges = 0;
	}
	wl::wl_list_remove(&toplevel.link);
	toplevel_cleanup_listeners(toplevel);
	if (handle != null) wlr::wlr_foreign_toplevel_handle_v1_destroy(handle);
	mem::free(toplevel);
	if (!g_has_startup_cmd && wl::wl_list_empty(&g_server.toplevels))
	{
		wl::wl_display_terminate(g_server.display);
		return;
	}
	if (was_focused)
	{
		Toplevel* next = null;
		WlList* pos    = g_server.toplevels.next;
		while (pos != &g_server.toplevels)
		{
			Toplevel* candidate = wl::@container_of(pos, Toplevel, link);
			if (!candidate.is_minimized)
			{
				next = candidate;
				break;
			}
			pos = pos.next;
		}
		if (next != null)
		{
			wlr::wlr_scene_node_raise_to_top(&next.scene_tree.node);
			focus_toplevel(next);
		}
		else
		{
			g_server.focused_toplevel = null;
		}
	}
}

fn void xdg_shell_handle_new_toplevel(WlListener* listener, void* data)
{
	WlrXdgToplevel* xdg_toplevel = (WlrXdgToplevel*)data;
	WlrXdgSurface* xdg_surface   = xdg_toplevel.base;

	Toplevel* toplevel = mem::new(Toplevel);
	toplevel.xdg_toplevel = xdg_toplevel;
	toplevel.scene_tree = wlr::wlr_scene_xdg_surface_create(g_server.layers.toplevel, xdg_surface);
	xdg_surface.data = toplevel.scene_tree;
	xdg_surface.surface.data = toplevel.scene_tree;

	associate_scene_node(&toplevel.scene_tree.node, SceneObjectType.TOPLEVEL, toplevel);

	wlr::wlr_scene_node_set_position(&toplevel.scene_tree.node, 0, 0);

	wl::wl_list_insert(&g_server.toplevels, &toplevel.link);

	toplevel_init_listeners(toplevel);

	if (g_server.foreign_toplevel_mgr != null)
	{
		WlrForeignToplevelHandleV1* h = wlr::wlr_foreign_toplevel_handle_v1_create(g_server.foreign_toplevel_mgr);
		toplevel.foreign_handle = h;
		if (xdg_toplevel.title != null) wlr::wlr_foreign_toplevel_handle_v1_set_title(h, xdg_toplevel.title);
		if (xdg_toplevel.app_id != null) wlr::wlr_foreign_toplevel_handle_v1_set_app_id(h, xdg_toplevel.app_id);
		if (g_server.active_output != null) wlr::wlr_foreign_toplevel_handle_v1_output_enter(h, g_server.active_output.wlr_output);
		toplevel_init_foreign_listeners(toplevel);
	}
}

fn void toplevel_init_listeners(Toplevel* t)
{
	listener_register(&t.commit, &toplevel_handle_commit, &t.xdg_toplevel.base.surface.events.commit);
	listener_register(&t.destroy, &toplevel_handle_destroy, &t.xdg_toplevel.events.destroy);
	listener_register(&t.request_maximize, &toplevel_handle_request_maximize, &t.xdg_toplevel.events.request_maximize);
	listener_register(&t.request_minimize, &toplevel_handle_request_minimize, &t.xdg_toplevel.events.request_minimize);
	listener_register(&t.request_fullscreen, &toplevel_handle_request_fullscreen, &t.xdg_toplevel.events.request_fullscreen);
	listener_register(&t.request_move, &toplevel_handle_request_move, &t.xdg_toplevel.events.request_move);
	listener_register(&t.request_resize, &toplevel_handle_request_resize, &t.xdg_toplevel.events.request_resize);
	listener_register(&t.new_popup, &popup_handle_new_popup, &t.xdg_toplevel.base.events.new_popup);
	listener_register(&t.set_title, &toplevel_handle_set_title, &t.xdg_toplevel.events.set_title);
	listener_register(&t.set_app_id, &toplevel_handle_set_app_id, &t.xdg_toplevel.events.set_app_id);
}

fn void toplevel_cleanup_listeners(Toplevel* t) => @cleanup_listeners(Toplevel, t);

// XDG popup handlers

fn void popup_unconstrain(Popup* p)
{
	WlrXdgPopup* popup       = p.xdg_popup;
	WlrSurface* root_surface = popup.parent;
	while (root_surface != null)
	{
		WlrXdgSurface* xdg_surf = wlr::wlr_xdg_surface_try_from_wlr_surface(root_surface);
		if (xdg_surf == null) break;
		if (xdg_surf.role != WlrXdgSurfaceRole.POPUP) break;
		WlrXdgPopup* parent_popup = xdg_surf.popup;
		if (parent_popup == null || parent_popup.parent == null) break;
		root_surface = parent_popup.parent;
	}

	WlrSceneTree* root_tree = get_surface_scene_tree(root_surface);
	if (root_tree == null) return;

	WlrOutput* output = g_server.active_output != null ? g_server.active_output.wlr_output : null;
	if (output == null) return;

	WlrBox output_box;
	wlr::wlr_output_layout_get_box(g_server.output_layout, output, &output_box);

	WlrBox usable_area = g_server.usable_area;
	usable_area.x += output_box.x;
	usable_area.y += output_box.y;

	WlrBox box = { usable_area.x - root_tree.node.x, usable_area.y - root_tree.node.y, usable_area.width, usable_area.height };
	wlr::wlr_xdg_popup_unconstrain_from_box(popup, &box);
}

fn void popup_handle_commit(WlListener* listener, void* data)
{
	Popup* p           = wl::@container_of(listener, Popup, commit);
	WlrXdgPopup* popup = p.xdg_popup;

	if (popup.base.initial_commit)
	{
		WlrSceneTree* popup_tree = (WlrSceneTree*)popup.base.data;
		if (popup_tree != null)
		{
			popup_unconstrain(p);
		}
		else
		{
			wlr::wlr_xdg_surface_schedule_configure(popup.base);
		}
	}
}

fn void popup_handle_reposition(WlListener* listener, void* data)
{
	Popup* p = wl::@container_of(listener, Popup, reposition);
	popup_unconstrain(p);
}

fn void popup_handle_destroy(WlListener* listener, void* data)
{
	Popup* p = wl::@container_of(listener, Popup, destroy);
	popup_cleanup_listeners(p);
	mem::free(p);
}

fn void popup_handle_new_popup(WlListener* listener, void* data)
{
	WlrXdgPopup* popup = (WlrXdgPopup*)data;
	if (popup.parent == null || popup.base.data != null) return;

	WlrSceneTree* parent_tree = get_surface_scene_tree(popup.parent) ?: g_server.layers.overlay;
	WlrSceneTree* popup_tree  = wlr::wlr_scene_xdg_surface_create(parent_tree, popup.base);
	popup.base.data = popup_tree;
	popup.base.surface.data = popup_tree;

	Popup* p = mem::new(Popup);
	p.xdg_popup = popup;

	associate_scene_node(&popup_tree.node, SceneObjectType.POPUP, p);

	popup_init_listeners(p);
}

fn void popup_init_listeners(Popup* p)
{
	listener_register(&p.commit, &popup_handle_commit, &p.xdg_popup.base.surface.events.commit);
	listener_register(&p.destroy, &popup_handle_destroy, &p.xdg_popup.events.destroy);
	listener_register(&p.reposition, &popup_handle_reposition, &p.xdg_popup.events.reposition);
	listener_register(&p.new_popup, &popup_handle_new_popup, &p.xdg_popup.base.events.new_popup);
}

fn void popup_cleanup_listeners(Popup* p) => @cleanup_listeners(Popup, p);

// Foreign toplevel management integration

fn void toplevel_handle_foreign_activate(WlListener* listener, void* data)
{
	Toplevel* t = wl::@container_of(listener, Toplevel, foreign_activate);
	if (t.is_minimized)
	{
		t.is_minimized = false;
		wlr::wlr_scene_node_set_enabled(&t.scene_tree.node, true);
		if (t.foreign_handle != null)
		{
			wlr::wlr_foreign_toplevel_handle_v1_set_minimized(t.foreign_handle, false);
		}
	}
	wlr::wlr_scene_node_raise_to_top(&t.scene_tree.node);
	wl::wl_list_remove(&t.link);
	wl::wl_list_insert(&g_server.toplevels, &t.link);
	focus_toplevel(t);
}

fn void toplevel_handle_foreign_close(WlListener* listener, void* data)
{
	Toplevel* t = wl::@container_of(listener, Toplevel, foreign_close);
	wlr::wlr_xdg_toplevel_send_close(t.xdg_toplevel);
}

fn void toplevel_handle_foreign_minimize(WlListener* listener, void* data)
{
	WlrForeignToplevelMinimizedEvent* event = (WlrForeignToplevelMinimizedEvent*)data;
	Toplevel* t                             = wl::@container_of(listener, Toplevel, foreign_minimize);
	if (event.minimized == t.is_minimized) return;
	if (event.minimized)
	{
		t.is_minimized = true;
		wlr::wlr_scene_node_set_enabled(&t.scene_tree.node, false);
		if (t.foreign_handle != null)
		{
			wlr::wlr_foreign_toplevel_handle_v1_set_minimized(t.foreign_handle, true);
		}
		if (g_server.focused_toplevel == t) focus_toplevel(null);
	}
	else
	{
		t.is_minimized = false;
		wlr::wlr_scene_node_set_enabled(&t.scene_tree.node, true);
		if (t.foreign_handle != null)
		{
			wlr::wlr_foreign_toplevel_handle_v1_set_minimized(t.foreign_handle, false);
		}
		wlr::wlr_scene_node_raise_to_top(&t.scene_tree.node);
		focus_toplevel(t);
	}
}

fn void toplevel_handle_foreign_maximize(WlListener* listener, void* data)
{
	WlrForeignToplevelMaximizedEvent* event = (WlrForeignToplevelMaximizedEvent*)data;
	Toplevel* t                             = wl::@container_of(listener, Toplevel, foreign_maximize);
	if (event.maximized != t.is_maximized) toplevel_toggle_maximize(t);
}

fn void toplevel_init_foreign_listeners(Toplevel* t)
{
	WlrForeignToplevelHandleV1* h = t.foreign_handle;
	listener_register(&t.foreign_activate, &toplevel_handle_foreign_activate, &h.events.request_activate);
	listener_register(&t.foreign_close, &toplevel_handle_foreign_close, &h.events.request_close);
	listener_register(&t.foreign_minimize, &toplevel_handle_foreign_minimize, &h.events.request_minimize);
	listener_register(&t.foreign_maximize, &toplevel_handle_foreign_maximize, &h.events.request_maximize);
}
