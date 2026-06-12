module qori;
import wl, wlr;

struct Keyboard
{
	WlrKeyboard* wlr_keyboard;
	WlListener key;
	WlListener modifiers;
	WlListener destroy;
}

// Keyboard handlers

fn void keyboard_handle_key(WlListener* listener, void* data)
{
	Keyboard* kb               = wl::@container_of(listener, Keyboard, key);
	WlrKeyboardKeyEvent* event = (WlrKeyboardKeyEvent*)data;

	if (event.state == PRESSED)
	{
		if (g_server.active_session_lock != null)
		{
			wlr::wlr_seat_set_keyboard(g_server.seat, kb.wlr_keyboard);
			wlr::wlr_seat_keyboard_notify_key(g_server.seat, event.time_msec, event.keycode, event.state);
			return;
		}
		uint mods        = wlr::wlr_keyboard_get_modifiers(kb.wlr_keyboard);
		uint xkb_keycode = event.keycode + 8;
		XkbKey* syms;
		wlr::xkb_state_key_get_syms(kb.wlr_keyboard.xkb_state, xkb_keycode, &syms);
		XkbKey sym = syms[0];

		if ((mods & WlrModifier.LOGO) != 0 && sym == (XkbKey)'r')
		{
			if (g_server.active_layer_surface == null)
			{
				WlEventLoop* loop = wl::wl_display_get_event_loop(g_server.display);
				launch_startup("bemenu-run", loop, false);
			}
			return;
		}

		if ((mods & WlrModifier.ALT) != 0 && sym == XkbKey.TAB)
		{
			alt_tab_cycle();
			return;
		}

		bool is_vt_switch = false;
		uint vt           = 0;
		if (sym >= XkbKey.XF86_SWITCH_VT_1 && sym <= XkbKey.XF86_SWITCH_VT_12)
		{
			is_vt_switch = true;
			vt = (uint)sym - (uint)XkbKey.XF86_SWITCH_VT_1 + 1;
		}
		else if ((mods & WlrModifier.CTRL) != 0 && (mods & WlrModifier.ALT) != 0)
		{
			if (sym >= XkbKey.F1 && sym <= XkbKey.F12)
			{
				is_vt_switch = true;
				vt = sym - XkbKey.F1 + 1;
			}
		}

		if (is_vt_switch)
		{
			if (g_server.session != null)
			{
				wlr::wlr_session_change_vt(g_server.session, vt);
				return;
			}
		}
	}

	wlr::wlr_seat_set_keyboard(g_server.seat, kb.wlr_keyboard);
	wlr::wlr_seat_keyboard_notify_key(g_server.seat, event.time_msec, event.keycode, event.state);
}

fn void keyboard_handle_modifiers(WlListener* listener, void* data)
{
	Keyboard* kb      = wl::@container_of(listener, Keyboard, modifiers);
	bool alt_was_held = g_alt_held;
	g_alt_held = (wlr::wlr_keyboard_get_modifiers(kb.wlr_keyboard) & WlrModifier.ALT) != 0;
	if (alt_was_held && !g_alt_held)
	{
		if (g_server.focused_toplevel != null)
		{
			Toplevel* tl = g_server.focused_toplevel;
			wl::wl_list_remove(&tl.link);
			wl::wl_list_insert(&g_server.toplevels, &tl.link);
			update_top_layer_visibility();
		}
	}
	wlr::wlr_seat_set_keyboard(g_server.seat, kb.wlr_keyboard);
	wlr::wlr_seat_keyboard_notify_modifiers(g_server.seat, &kb.wlr_keyboard.modifiers);
}

fn void keyboard_handle_destroy(WlListener* listener, void* data)
{
	Keyboard* kb = wl::@container_of(listener, Keyboard, destroy);
	keyboard_cleanup_listeners(kb);
	mem::free(kb);
}

fn void keyboard_init_listeners(Keyboard* kb)
{
	listener_register(&kb.key, &keyboard_handle_key, &kb.wlr_keyboard.events.key);
	listener_register(&kb.modifiers, &keyboard_handle_modifiers, &kb.wlr_keyboard.events.modifiers);
	listener_register(&kb.destroy, &keyboard_handle_destroy, &kb.wlr_keyboard.base.events.destroy);
}

fn void keyboard_cleanup_listeners(Keyboard* kb) => @cleanup_listeners(Keyboard, kb);

// Focus helpers & alt-tab

fn void focus_toplevel(Toplevel* toplevel)
{
	if (g_server.active_layer_surface != null || g_server.active_session_lock != null)
	{
		return;
	}
	WlList* pos = g_server.toplevels.next;
	while (pos != &g_server.toplevels)
	{
		Toplevel* t    = wl::@container_of(pos, Toplevel, link);
		bool activated = (t == toplevel);
		if (t.foreign_handle != null)
		{
			wlr::wlr_foreign_toplevel_handle_v1_set_activated(t.foreign_handle, activated);
		}
		if (t.xdg_toplevel.base.initialized)
		{
			uint serial = wlr::wlr_xdg_toplevel_set_activated(t.xdg_toplevel, activated);
			if (serial > 0) t.pending_configure_serial = serial;
		}
		pos = pos.next;
	}
	g_server.focused_toplevel = toplevel;
	if (toplevel != null)
	{
		WlrKeyboard* kb            = wlr::wlr_seat_get_keyboard(g_server.seat);
		WlrKeyboardModifiers* mods = kb != null ? &kb.modifiers : null;
		wlr::wlr_seat_keyboard_enter(g_server.seat, toplevel.xdg_toplevel.base.surface, null, 0, mods);
	}
	update_top_layer_visibility();
}

fn void alt_tab_cycle()
{
	if (wl::wl_list_empty(&g_server.toplevels)) return;

	WlList* next = g_server.focused_toplevel != null ? g_server.focused_toplevel.link.next : g_server.toplevels.next;
	if (next == &g_server.toplevels) next = g_server.toplevels.next;

	Toplevel* tl = wl::@container_of(next, Toplevel, link);
	wlr::wlr_scene_node_raise_to_top(&tl.scene_tree.node);
	focus_toplevel(tl);
}

// Cursor / pointer handlers

fn void process_cursor_motion(uint time_msec)
{
	WlrOutput* wlr_out = wlr::wlr_output_layout_output_at(g_server.output_layout, g_server.cursor.x, g_server.cursor.y);
	if (wlr_out != null && wlr_out.data != null)
	{
		g_server.active_output = (Output*)wlr_out.data;
	}

	if (g_server.drag_active)
	{
		wlr::wlr_scene_node_set_position(&g_server.drag_icons.node, (int)g_server.cursor.x, (int)g_server.cursor.y);
	}

	if (g_server.grabbed_toplevel != null)
	{
		Toplevel* gt = g_server.grabbed_toplevel;
		if (g_server.grab_edges == 0)
		{
			int nx = (int)(g_server.cursor.x - g_server.grab_x);
			int ny = (int)(g_server.cursor.y - g_server.grab_y);
			gt.pending_x = nx;
			gt.pending_y = ny;
			gt.current_x = nx;
			gt.current_y = ny;
			wlr::wlr_scene_node_set_position(&gt.scene_tree.node, nx, ny);
		}
		else
		{
			double dx  = g_server.cursor.x - g_server.grab_x;
			double dy  = g_server.cursor.y - g_server.grab_y;
			uint edges = g_server.grab_edges;
			int new_w  = g_server.grab_width;
			int new_h  = g_server.grab_height;
			int new_x  = g_server.grab_node_x;
			int new_y  = g_server.grab_node_y;
			if ((edges & wlr::WlrEdge.RIGHT) != 0) new_w = (int)(g_server.grab_width + dx);
			if ((edges & wlr::WlrEdge.BOTTOM) != 0) new_h = (int)(g_server.grab_height + dy);
			if ((edges & wlr::WlrEdge.LEFT) != 0)
			{
				new_w = (int)(g_server.grab_width - dx);
				new_x = (int)(g_server.grab_node_x + dx);
			}
			if ((edges & wlr::WlrEdge.TOP) != 0)
			{
				new_h = (int)(g_server.grab_height - dy);
				new_y = (int)(g_server.grab_node_y + dy);
			}
			if (new_w < 1) new_w = 1;
			if (new_h < 1) new_h = 1;
			gt.pending_x = new_x;
			gt.pending_y = new_y;
			gt.pending_width = new_w;
			gt.pending_height = new_h;
			uint serial = wlr::wlr_xdg_toplevel_set_size(gt.xdg_toplevel, new_w, new_h);
			if (serial > 0)
			{
				gt.pending_configure_serial = serial;
			}
		}
		return;
	}

	double sx, sy;
	WlrSceneNode* node = wlr::wlr_scene_node_at(&g_server.scene.tree.node, g_server.cursor.x, g_server.cursor.y, &sx, &sy);

	bool entered = false;
	if (node != null && node.type == WlrSceneNodeType.BUFFER)
	{
		WlrSceneSurface* scene_surface = wlr::wlr_scene_surface_try_from_buffer(node);
		if (scene_surface != null)
		{
			wlr::wlr_seat_pointer_notify_enter(g_server.seat, scene_surface.surface, sx, sy);
			wlr::wlr_seat_pointer_notify_motion(g_server.seat, time_msec, sx, sy);
			entered = true;
		}
	}
	if (!entered)
	{
		wlr::wlr_seat_pointer_notify_clear_focus(g_server.seat);
		wlr::wlr_cursor_set_xcursor(g_server.cursor, g_server.cursor_mgr, "default");
	}
}

fn void server_cursor_motion(WlListener* listener, void* data)
{
	WlrPointerMotionEvent* event = (WlrPointerMotionEvent*)data;
	wlr::wlr_cursor_move(g_server.cursor, event.device, event.delta_x, event.delta_y);
	process_cursor_motion(event.time_msec);
}

fn void server_cursor_motion_absolute(WlListener* listener, void* data)
{
	WlrPointerMotionAbsoluteEvent* event = (WlrPointerMotionAbsoluteEvent*)data;
	wlr::wlr_cursor_warp_absolute(g_server.cursor, event.device, event.x, event.y);
	process_cursor_motion(event.time_msec);
}

fn void server_cursor_button(WlListener* listener, void* data)
{
	WlrPointerButtonEvent* event = (WlrPointerButtonEvent*)data;

	if (g_server.active_layer_surface != null || g_server.active_session_lock != null)
	{
		// Exclusive layer surface or lock screen is active, ignore clicks outside of it
		wlr::wlr_seat_pointer_notify_button(g_server.seat, event.time_msec, event.button, event.state);
		return;
	}

	if (event.state == wlr::WL_POINTER_BUTTON_STATE_PRESSED)
	{
		double sx, sy;
		WlrSceneNode* node = wlr::wlr_scene_node_at(&g_server.scene.tree.node, g_server.cursor.x, g_server.cursor.y, &sx, &sy);
		Toplevel* found    = node != null ? get_toplevel_from_node(node) : null;

		if (found != null && g_alt_held)
		{
			wlr::wlr_scene_node_raise_to_top(&found.scene_tree.node);
			wl::wl_list_remove(&found.link);
			wl::wl_list_insert(&g_server.toplevels, &found.link);
			focus_toplevel(found);

			if (event.button == LEFT)
			{
				uint dt = event.time_msec - g_last_button_time;
				if (found == g_last_button_toplevel && dt <= DOUBLE_CLICK_MS)
				{
					toplevel_toggle_maximize(found);
					g_last_button_toplevel = null;
					g_last_button_time = 0;
					return;
				}
				g_last_button_toplevel = found;
				g_last_button_time = event.time_msec;
				if (!found.is_maximized)
				{
					g_server.grabbed_toplevel = found;
					g_server.grab_edges = 0;
					g_server.grab_x = g_server.cursor.x - found.scene_tree.node.x;
					g_server.grab_y = g_server.cursor.y - found.scene_tree.node.y;
					g_server.grab_client_initiated = false;
				}
			}
			else if (event.button == RIGHT && !found.is_maximized)
			{
				int win_x  = found.scene_tree.node.x;
				int win_y  = found.scene_tree.node.y;
				int win_w  = found.current_width;
				int win_h  = found.current_height;
				uint edges = 0;
				if ((int)g_server.cursor.x < win_x + win_w / 2)
				{
					edges |= wlr::WlrEdge.LEFT;
				}
				else
				{
					edges |= wlr::WlrEdge.RIGHT;
				}
				if ((int)g_server.cursor.y < win_y + win_h / 2)
				{
					edges |= wlr::WlrEdge.TOP;
				}
				else
				{
					edges |= wlr::WlrEdge.BOTTOM;
				}
				g_server.grabbed_toplevel = found;
				g_server.grab_edges = edges;
				g_server.grab_x = g_server.cursor.x;
				g_server.grab_y = g_server.cursor.y;
				g_server.grab_node_x = win_x;
				g_server.grab_node_y = win_y;
				g_server.grab_width = win_w;
				g_server.grab_height = win_h;
				g_server.grab_client_initiated = false;
			}
			return;
		}

		wlr::wlr_seat_pointer_notify_button(g_server.seat, event.time_msec, event.button, event.state);

		if (found != null)
		{
			wlr::wlr_scene_node_raise_to_top(&found.scene_tree.node);
			wl::wl_list_remove(&found.link);
			wl::wl_list_insert(&g_server.toplevels, &found.link);
			focus_toplevel(found);
			g_last_button_toplevel = null;
			g_last_button_time = 0;
		}
		else if (node != null)
		{
			LayerSurface* ls = get_layer_surface_from_node(node);
			if (ls != null && ls.wlr_layer_surface.current.keyboard_interactive == ON_DEMAND)
			{
				g_server.focused_toplevel = null;
				WlrKeyboard* kb            = wlr::wlr_seat_get_keyboard(g_server.seat);
				WlrKeyboardModifiers* mods = kb != null ? &kb.modifiers : null;
				wlr::wlr_seat_keyboard_enter(g_server.seat, ls.wlr_layer_surface.surface, null, 0, mods);
			}
		}
	}
	else if (event.state == wlr::WL_POINTER_BUTTON_STATE_RELEASED)
	{
		if (g_server.grabbed_toplevel != null)
		{
			if (g_server.grab_client_initiated)
			{
				wlr::wlr_seat_pointer_notify_button(g_server.seat, event.time_msec, event.button, event.state);
			}
			g_server.grabbed_toplevel = null;
			g_server.grab_edges = 0;
			g_server.grab_client_initiated = false;
		}
		else
		{
			wlr::wlr_seat_pointer_notify_button(g_server.seat, event.time_msec, event.button, event.state);
		}
	}
}

fn void server_cursor_axis(WlListener* listener, void* data)
{
	WlrPointerAxisEvent* event = (WlrPointerAxisEvent*)data;
	wlr::wlr_seat_pointer_notify_axis(g_server.seat, event.time_msec, event.orientation, event.delta, event.delta_discrete, event.source, event.relative_direction);
}

fn void server_cursor_frame(WlListener* listener, void* data) => wlr::wlr_seat_pointer_notify_frame(g_server.seat);

// Input device setup

fn void server_new_input(WlListener* listener, void* data)
{
	WlrInputDevice* device = (WlrInputDevice*)data;
	if (device.type == wlr::WLR_INPUT_DEVICE_KEYBOARD)
	{
		WlrKeyboard* wlr_keyboard = (WlrKeyboard*)data;

		void* context = wlr::xkb_context_new(wlr::XKB_CONTEXT_NO_FLAGS);
		defer wlr::xkb_context_unref(context);
		void* keymap = wlr::xkb_keymap_new_from_names(context, null, wlr::XKB_KEYMAP_COMPILE_NO_FLAGS);
		defer wlr::xkb_keymap_unref(keymap);

		wlr::wlr_keyboard_set_keymap(wlr_keyboard, keymap);
		wlr::wlr_keyboard_set_repeat_info(wlr_keyboard, KEY_REPEAT_RATE, KEY_REPEAT_DELAY);

		Keyboard* kb = mem::new(Keyboard);
		kb.wlr_keyboard = wlr_keyboard;

		keyboard_init_listeners(kb);

		wlr::wlr_seat_set_keyboard(g_server.seat, wlr_keyboard);
	}
	else if (device.type == wlr::WLR_INPUT_DEVICE_POINTER)
	{
		wlr::wlr_cursor_attach_input_device(g_server.cursor, device);
	}
}

fn void seat_handle_request_set_selection(WlListener* listener, void* data)
{
	WlrSeatRequestSetSelectionEvent* event = (WlrSeatRequestSetSelectionEvent*)data;
	wlr::wlr_seat_set_selection(g_server.seat, event.source, event.serial);
}

fn void seat_handle_request_set_primary_selection(WlListener* listener, void* data)
{
	WlrSeatRequestSetPrimarySelectionEvent* event = (WlrSeatRequestSetPrimarySelectionEvent*)data;
	wlr::wlr_seat_set_primary_selection(g_server.seat, event.source, event.serial);
}

fn void seat_handle_request_start_drag(WlListener* listener, void* data)
{
	WlrSeatRequestStartDragEvent* event = (WlrSeatRequestStartDragEvent*)data;
	if (wlr::wlr_seat_validate_pointer_grab_serial(g_server.seat, event.origin, event.serial))
	{
		wlr::wlr_seat_start_pointer_drag(g_server.seat, event.drag, event.serial);
	}
	else
	{
		wlr::wlr_data_source_destroy(event.drag.source);
	}
}

fn void seat_handle_start_drag(WlListener* listener, void* data)
{
	WlrDrag* drag = (WlrDrag*)data;
	g_server.drag_active = true;
	if (drag.icon != null)
	{
		wlr::wlr_scene_drag_icon_create(g_server.drag_icons, drag.icon);
		wlr::wlr_scene_node_raise_to_top(&g_server.drag_icons.node);
		wlr::wlr_scene_node_set_enabled(&g_server.drag_icons.node, true);
	}
	listener_register(&g_server.drag_destroy, &seat_handle_drag_destroy, &drag.events.destroy);
}

fn void seat_handle_drag_destroy(WlListener* listener, void* data)
{
	g_server.drag_active = false;
	listener_deregister(&g_server.drag_destroy);
	wlr::wlr_scene_node_set_enabled(&g_server.drag_icons.node, false);
}

fn void seat_handle_request_set_cursor(WlListener* listener, void* data)
{
	WlrSeatPointerRequestSetCursorEvent* event = (WlrSeatPointerRequestSetCursorEvent*)data;
	if (g_server.seat.pointer_state.focused_client == event.seat_client)
	{
		wlr::wlr_cursor_set_surface(g_server.cursor, event.surface, event.hotspot_x, event.hotspot_y);
	}
}
