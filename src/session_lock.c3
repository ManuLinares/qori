module qori;
import wl, wlr, std;

struct SessionLockOutput
{
	WlrSceneTree* tree;
	WlrSceneRect* background;
	Output* output;
	WlrSessionLockSurfaceV1* surface;
	WlList link;
	WlListener destroy;
	WlListener commit;
	WlListener surface_destroy;
	WlListener surface_map;
}

fn void focus_lock_surface(WlrSurface* surface)
{
	if (surface != null)
	{
		WlrKeyboard* kb            = wlr::wlr_seat_get_keyboard(g_server.seat);
		WlrKeyboardModifiers* mods = kb != null ? &kb.modifiers : null;
		wlr::wlr_seat_keyboard_enter(g_server.seat, surface, null, 0, mods);
	}
	else
	{
		wlr::wlr_seat_keyboard_notify_clear_focus(g_server.seat);
	}
}

fn void refocus_lock_outputs()
{
	WlList* pos = g_server.session_lock_outputs.next;
	while (pos != &g_server.session_lock_outputs)
	{
		SessionLockOutput* lo = wl::@container_of(pos, SessionLockOutput, link);
		if (lo.surface != null && lo.surface.surface != null && lo.surface.surface.mapped)
		{
			focus_lock_surface(lo.surface.surface);
			return;
		}
		pos = pos.next;
	}
	wlr::wlr_seat_pointer_notify_clear_focus(g_server.seat);
}

fn void handle_surface_map(WlListener* listener, void* data)
{
	SessionLockOutput* lo = wl::@container_of(listener, SessionLockOutput, surface_map);
	focus_lock_surface(lo.surface.surface);
}

fn void handle_surface_destroy(WlListener* listener, void* data)
{
	SessionLockOutput* lo = wl::@container_of(listener, SessionLockOutput, surface_destroy);
	wl::wl_list_remove(&lo.surface_destroy.link);
	wl::wl_list_remove(&lo.surface_map.link);
	lo.surface = null;
	refocus_lock_outputs();
}

fn void lock_output_reconfigure(SessionLockOutput* lo)
{
	WlrBox box;
	wlr::wlr_output_layout_get_box(g_server.output_layout, lo.output.wlr_output, &box);
	wlr::wlr_scene_rect_set_size(lo.background, box.width, box.height);
	if (lo.surface != null)
	{
		wlr::wlr_session_lock_surface_v1_configure(lo.surface, (uint)box.width, (uint)box.height);
	}
}

fn SessionLockOutput* lock_output_for_output(Output* output)
{
	WlList* pos = g_server.session_lock_outputs.next;
	while (pos != &g_server.session_lock_outputs)
	{
		SessionLockOutput* lo = wl::@container_of(pos, SessionLockOutput, link);
		if (lo.output == output) return lo;
		pos = pos.next;
	}
	return null;
}

fn void handle_new_surface(WlListener* listener, void* data)
{
	WlrSessionLockSurfaceV1* lock_surface = (WlrSessionLockSurfaceV1*)data;
	Output* output                        = (Output*)lock_surface.output.data;
	SessionLockOutput* lo                 = lock_output_for_output(output);
	if (lo == null)
	{
		return;
	}

	lo.surface = lock_surface;

	WlrSceneTree* surface_tree = wlr::wlr_scene_subsurface_tree_create(lo.tree, lock_surface.surface);
	associate_scene_node(&surface_tree.node, SceneObjectType.NONE, null);

	lo.surface_destroy.notify = &handle_surface_destroy;
	wl::wl_signal_add(&lock_surface.events.destroy, &lo.surface_destroy);

	lo.surface_map.notify = &handle_surface_map;
	wl::wl_signal_add(&lock_surface.surface.events.map, &lo.surface_map);

	lock_output_reconfigure(lo);
}

fn void session_lock_output_destroy(SessionLockOutput* lo)
{
	if (lo.surface != null)
	{
		wl::wl_list_remove(&lo.surface_destroy.link);
		wl::wl_list_remove(&lo.surface_map.link);
	}
	wl::wl_list_remove(&lo.commit.link);
	wl::wl_list_remove(&lo.destroy.link);
	wl::wl_list_remove(&lo.link);
	mem::free(lo);
}

fn void handle_output_destroy(WlListener* listener, void* data)
{
	SessionLockOutput* lo = wl::@container_of(listener, SessionLockOutput, destroy);
	session_lock_output_destroy(lo);
}

fn void handle_output_commit(WlListener* listener, void* data)
{
	SessionLockOutput* lo = wl::@container_of(listener, SessionLockOutput, commit);
	lock_output_reconfigure(lo);
}

fn void align_session_lock_tree(Output* output, SessionLockOutput* lo)
{
	WlrBox box;
	wlr::wlr_output_layout_get_box(g_server.output_layout, output.wlr_output, &box);
	wlr::wlr_scene_node_set_position(&lo.tree.node, box.x, box.y);
}

fn void session_lock_output_create(Output* output)
{
	if (lock_output_for_output(output) != null) return;

	SessionLockOutput* lo = mem::new(SessionLockOutput);
	lo.output = output;
	lo.tree = wlr::wlr_scene_tree_create(g_server.layers.session_lock);

	float[4] black = { 0.0, 0.0, 0.0, 1.0 };
	lo.background = wlr::wlr_scene_rect_create(lo.tree, 0, 0, &black[0]);

	align_session_lock_tree(output, lo);

	lo.destroy.notify = &handle_output_destroy;
	wl::wl_signal_add(&lo.tree.node.events.destroy, &lo.destroy);

	lo.commit.notify = &handle_output_commit;
	wl::wl_signal_add(&output.wlr_output.events.commit, &lo.commit);

	lock_output_reconfigure(lo);

	wl::wl_list_insert(&g_server.session_lock_outputs, &lo.link);
}

fn void session_lock_destroy()
{
	while (!wl::wl_list_empty(&g_server.session_lock_outputs))
	{
		SessionLockOutput* lo = wl::@container_of(g_server.session_lock_outputs.next, SessionLockOutput, link);
		wlr::wlr_scene_node_destroy(&lo.tree.node);
	}
	if (g_server.active_session_lock != null)
	{
		listener_deregister(&g_server.lock_new_surface);
		listener_deregister(&g_server.lock_unlock);
		listener_deregister(&g_server.lock_destroy);
	}
	g_server.active_session_lock = null;
}

fn void handle_lock_unlock(WlListener* listener, void* data)
{
	session_lock_destroy();
	if (!wl::wl_list_empty(&g_server.toplevels))
	{
		Toplevel* tl = wl::@container_of(g_server.toplevels.next, Toplevel, link);
		focus_toplevel(tl);
	}
}

fn void handle_lock_destroy(WlListener* listener, void* data)
{
	session_lock_destroy();
}

fn void server_handle_new_session_lock(WlListener* listener, void* data)
{
	WlrSessionLockV1* lock = (WlrSessionLockV1*)data;
	if (g_server.active_session_lock != null)
	{
		wlr::wlr_session_lock_v1_destroy(lock);
		return;
	}

	g_server.active_session_lock = lock;

	wlr::wlr_seat_pointer_notify_clear_focus(g_server.seat);
	if (g_server.focused_toplevel != null)
	{
		wlr::wlr_seat_keyboard_notify_clear_focus(g_server.seat);
		g_server.focused_toplevel = null;
	}

	WlList* pos = g_server.outputs.next;
	while (pos != &g_server.outputs)
	{
		Output* output = wl::@container_of(pos, Output, link);
		session_lock_output_create(output);
		pos = pos.next;
	}

	listener_register(&g_server.lock_new_surface, &handle_new_surface, &lock.events.new_surface);
	listener_register(&g_server.lock_unlock, &handle_lock_unlock, &lock.events.unlock);
	listener_register(&g_server.lock_destroy, &handle_lock_destroy, &lock.events.destroy);

	wlr::wlr_session_lock_v1_send_locked(lock);
}

fn void server_handle_session_lock_mgr_destroy(WlListener* listener, void* data)
{
	session_lock_destroy();
}
