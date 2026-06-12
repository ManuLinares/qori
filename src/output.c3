module qori;
import wl, wlr;
import std::os::posix;
import libc;

struct Output
{
	Server* server;
	WlrOutput* wlr_output;
	WlrSceneOutput* scene_output;
	WlListener frame;
	WlListener request_state;
	WlListener destroy;
	WlrOutputState pending;
	WlList link;
}

fn void recalculate_usable_area(WlrOutput* output)
{
	if (output == null) return;
	WlrBox full_area   = { 0, 0, output.width, output.height };
	WlrBox usable_area = full_area;

	WlList* pos = g_server.layer_surfaces.next;
	while (pos != &g_server.layer_surfaces)
	{
		LayerSurface* ls = wl::@container_of(pos, LayerSurface, link);
		if (ls.wlr_layer_surface.initialized)
		{
			wlr::wlr_scene_layer_surface_v1_configure(ls.scene_layer_surface, &full_area, &usable_area);
		}
		pos = pos.next;
	}

	g_server.usable_area = usable_area;
}

fn void server_new_output(WlListener* listener, void* data)
{
	WlrOutput* wlr_output = (WlrOutput*)data;

	wlr::wlr_output_init_render(wlr_output, g_server.allocator, g_server.renderer);

	WlrOutputState state;
	wlr::wlr_output_state_init(&state);
	defer wlr::wlr_output_state_finish(&state);

	wlr::wlr_output_state_set_enabled(&state, true);

	WlrOutputMode* mode = wlr::wlr_output_preferred_mode(wlr_output);
	if (mode != null) wlr::wlr_output_state_set_mode(&state, mode);
	wlr::wlr_output_commit_state(wlr_output, &state);

	g_server.usable_area = { 0, 0, wlr_output.width, wlr_output.height };

	Output* output = mem::new(Output);
	output.server = &g_server;
	output.wlr_output = wlr_output;
	wlr_output.data = output;

	wlr::wlr_output_state_init(&output.pending);

	wl::wl_list_insert(&g_server.outputs, &output.link);

	if (g_server.active_output == null) g_server.active_output = output;

	output_init_listeners(output);

	output.scene_output = wlr::wlr_scene_output_create(g_server.scene, wlr_output);
	void* l_output = wlr::wlr_output_layout_add_auto(g_server.output_layout, wlr_output);
	wlr::wlr_scene_output_layout_add_output(g_server.scene_layout, l_output, output.scene_output);
}

fn void output_frame(WlListener* listener, void* data)
{
	Output* output = wl::@container_of(listener, Output, frame);

	if (wlr::wlr_scene_output_needs_frame(output.scene_output))
	{
		if (wlr::wlr_scene_output_build_state(output.scene_output, &output.pending, null))
		{
			if (wlr::wlr_output_commit_state(output.wlr_output, &output.pending))
			{
				wlr::wlr_output_state_finish(&output.pending);
				wlr::wlr_output_state_init(&output.pending);
				recalculate_usable_area(output.wlr_output);
				wlr::wlr_output_schedule_done(output.wlr_output);
			}
		}
	}

	TimeSpec now;
	posix::clock_gettime(posix::CLOCK_MONOTONIC, &now);
	wlr::wlr_scene_output_send_frame_done(output.scene_output, &now);
}

fn void output_request_state(WlListener* listener, void* data)
{
	Output* output                    = wl::@container_of(listener, Output, request_state);
	WlrOutputEventRequestState* event = (WlrOutputEventRequestState*)data;

	if (event.state.committed == wlr::WLR_OUTPUT_STATE_MODE)
	{
		switch (event.state.mode_type)
		{
			case wlr::WLR_OUTPUT_STATE_MODE_FIXED:
				wlr::wlr_output_state_set_mode(&output.pending, event.state.mode);
				break;
			case wlr::WLR_OUTPUT_STATE_MODE_CUSTOM:
				wlr::wlr_output_state_set_custom_mode(&output.pending, event.state.custom_mode.width, event.state.custom_mode.height, event.state.custom_mode.refresh);
				break;
		}
		wlr::wlr_output_schedule_frame(output.wlr_output);
		return;
	}

	if (wlr::wlr_output_commit_state(output.wlr_output, event.state))
	{
		recalculate_usable_area(output.wlr_output);
		wlr::wlr_output_schedule_done(output.wlr_output);
	}
}

fn void output_destroy(WlListener* listener, void* data)
{
	Output* output = wl::@container_of(listener, Output, destroy);
	if (g_server.active_output == output) g_server.active_output = null;
	wl::wl_list_remove(&output.link);
	output_cleanup_listeners(output);
	wlr::wlr_output_state_finish(&output.pending);
	mem::free(output);
	wl::wl_display_terminate(g_server.display);
}

fn void output_init_listeners(Output* o)
{
	listener_register(&o.frame, &output_frame, &o.wlr_output.events.frame);
	listener_register(&o.request_state, &output_request_state, &o.wlr_output.events.request_state);
	listener_register(&o.destroy, &output_destroy, &o.wlr_output.events.destroy);
}
fn void output_cleanup_listeners(Output* o) => @cleanup_listeners(Output, o);
