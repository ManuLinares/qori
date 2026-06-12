module qori;
import wl, wlr, std, libc;

fn int main(String[] args)
{
	CliOptions opts;
	if (!parse_args(args, &opts))
	{
		print_usage(args[0]);
		return 1;
	}

	if (opts.exit_only)
	{
		if (handle_exit_flag()) return 0;
		return 1;
	}

	WlEventLoop* loop = null;
	if (!server_init(&loop))
	{
		server_finish();
		return 1;
	}

	ZString socket = wl::wl_display_add_socket_auto(g_server.display);
	if (!socket)
	{
		server_finish();
		return 1;
	}

	if (!wlr::wlr_backend_start(g_server.backend))
	{
		server_finish();
		return 1;
	}

	env::set_var("WAYLAND_DISPLAY", socket.str_view(), true);
	env::set_var("QORI_PID", string::tformat("%d", posix::getpid()), true);

	if (opts.startup_cmd.len > 0)
	{
		g_has_startup_cmd = true;
		launch_startup(opts.startup_cmd, loop, opts.startup_sticky);
	}

	wl::wl_display_run(g_server.display);

	server_finish();
	return 0;
}

// CLI Options and Parsing

fn void print_usage(String program_name)
{
	io::printfn("Usage: %s [options]", program_name);
	io::printfn("Options:");
	io::printfn("  -h, --help       Show this help message");
	io::printfn("  -e, --exit       Exit the running qori instance");
	io::printfn("  -s <command>     Run startup command");
	io::printfn("  -S <command>     Run startup command and terminate qori on its exit");
}

struct CliOptions
{
	bool exit_only;
	String startup_cmd;
	bool startup_sticky;
}

fn bool parse_args(String[] args, CliOptions* opts)
{
	opts.exit_only = false;
	opts.startup_cmd = "";
	opts.startup_sticky = false;

	for (int i = 1; i < (int)args.len; i++)
	{
		switch
		{
			case (args[i] == "-e" || args[i] == "--exit"):
				opts.exit_only = true;
			case (args[i] == "-s" && i + 1 < (int)args.len):
				opts.startup_cmd = args[++i];
			case (args[i] == "-S" && i + 1 < (int)args.len):
				opts.startup_cmd = args[++i];
				opts.startup_sticky = true;
			case (args[i] == "-h" || args[i] == "-?" || args[i] == "--help"):
				print_usage(args[0]);
				libc::exit(0);
			default:
				io::printfn("Unknown or malformed option: %s", args[i]);
				return false;
		}
	}
	return true;
}


//////////////////////////////////////////////////////////////////////////
// Globals

Server g_server;
bool g_alt_held;

uint g_last_button_time;
Toplevel* g_last_button_toplevel;
const uint DOUBLE_CLICK_MS = 350;
const int KEY_REPEAT_RATE  = 40;
const int KEY_REPEAT_DELAY = 200;

Pid_t g_startup_pid = -1;
bool g_startup_terminate;
bool g_has_startup_cmd;


struct Server
{
	WlDisplay* display;
	WlrBackend* backend;
	WlrSession* session;
	WlrRenderer* renderer;
	WlrAllocator* allocator;
	WlrScene* scene;
	WlrXdgShell* xdg_shell;
	WlrForeignToplevelManagerV1* foreign_toplevel_mgr;
	WlrSeat* seat;
	WlrOutputLayout* output_layout;
	WlrSceneOutputLayout* scene_layout;
	SceneLayers layers;
	Toplevel* focused_toplevel;
	Output* active_output;

	WlrCursor* cursor;
	WlrXcursorManager* cursor_mgr;
	WlList toplevels;
	WlList outputs;

	Toplevel* grabbed_toplevel;
	double grab_x;
	double grab_y;
	uint grab_edges; // 0 = move; Wlr_edge bitmask = resize
	int grab_node_x; // window origin at drag start (resize)
	int grab_node_y;
	int grab_width; // window size at drag start (resize)
	int grab_height;
	bool grab_client_initiated;

	WlrLayerShellV1* layer_shell;
	WlListener new_layer_surface;
	LayerSurface* active_layer_surface;
	WlList layer_surfaces;
	WlrBox usable_area;

	WlListener new_xdg_toplevel;
	WlListener new_output;
	WlListener new_input;
	WlListener backend_destroy;

	WlListener cursor_motion;
	WlListener cursor_motion_absolute;
	WlListener cursor_button;
	WlListener cursor_axis;
	WlListener cursor_frame;

	WlrSessionLockManagerV1* session_lock_mgr;
	WlrXdgOutputManagerV1* xdg_output_mgr;
	WlrSessionLockV1* active_session_lock;
	WlList session_lock_outputs;
	WlListener new_session_lock;
	WlListener session_lock_mgr_destroy;
	WlListener lock_new_surface;
	WlListener lock_unlock;
	WlListener lock_destroy;

	WlListener request_set_selection;
	WlListener request_set_primary_selection;
	WlListener request_set_cursor;

	WlrSceneTree* drag_icons;
	bool drag_active;
	WlListener request_start_drag;
	WlListener start_drag;
	WlListener drag_destroy;
}

struct Toplevel
{
	WlrXdgToplevel* xdg_toplevel;
	WlrSceneTree* scene_tree;
	WlList link;
	WlListener commit;
	WlListener destroy;
	WlListener request_maximize;
	WlListener request_minimize;
	WlListener request_fullscreen;
	WlListener request_move;
	WlListener request_resize;
	WlListener new_popup;
	WlListener set_title;
	WlListener set_app_id;

	WlrForeignToplevelHandleV1* foreign_handle;
	WlListener foreign_activate;
	WlListener foreign_close;
	WlListener foreign_minimize;
	WlListener foreign_maximize;

	bool is_maximized;
	bool is_minimized;
	bool is_fullscreen;
	int floating_x;
	int floating_y;
	int floating_width;
	int floating_height;

	uint pending_configure_serial;
	int pending_x;
	int pending_y;
	int pending_width;
	int pending_height;

	int current_x;
	int current_y;
	int current_width;
	int current_height;
}

struct LayerSurface
{
	WlrLayerSurfaceV1* wlr_layer_surface;
	WlrSceneLayerSurfaceV1* scene_layer_surface;
	WlList link;
	WlListener commit;
	WlListener destroy;
	WlListener new_popup;
	bool mapped;
}

// Startup / SIGCHLD

fn int handle_sigchld(int sig, void* data)
{
	if (g_startup_pid <= 0) return 0;
	CInt status;
	Pid_t pid = posix::waitpid(g_startup_pid, &status, posix::WNOHANG);
	if (pid == g_startup_pid)
	{
		g_startup_pid = -1;
		if (g_startup_terminate)
		{
			wl::wl_display_terminate(g_server.display);
		}
	}
	return 0;
}

fn bool handle_exit_flag()
{
	String qori_pid_str = env::get_var(tmem, "QORI_PID") ?? "";
	if (qori_pid_str.len == 0)
	{
		io::printfn("QORI_PID not set (are you running this command inside qori?)");
		return false;
	}

	Pid_t pid = qori_pid_str.to_int() ?? 0;
	if (pid <= 0)
	{
		io::printfn("Invalid QORI_PID: '%s'", qori_pid_str);
		return false;
	}

	io::printfn("Sending SIGTERM to compositor process %d...", pid);
	posix::kill(pid, libc::SIGTERM);
	return true;
}

fn int handle_terminate_signal(int sig, void* data)
{
	wl::wl_display_terminate(g_server.display);
	return 0;
}

fn void launch_startup(String cmd, WlEventLoop* loop, bool terminate_on_exit)
{
	Process proc = process::spawn({ "sh", "-c", cmd }, INHERIT_ENV | INHERIT_STDIO, { })!!;
	g_startup_pid = proc.child;
	g_startup_terminate = terminate_on_exit;
	if (terminate_on_exit)
	{
		wl::wl_event_loop_add_signal(loop, wlr::SIGCHLD, &handle_sigchld, null);
	}
}

// Backend

fn void server_backend_destroy(WlListener* listener, void* data) => wl::wl_display_terminate(g_server.display);

// Setup and Teardown

fn bool server_init(WlEventLoop** out_loop)
{
	g_server.display = wl::wl_display_create();
	if (g_server.display == null) return false;

	WlEventLoop* loop = wl::wl_display_get_event_loop(g_server.display);
	*out_loop = loop;
	wl::wl_event_loop_add_signal(loop, libc::SIGTERM, &handle_terminate_signal, null);
	wl::wl_event_loop_add_signal(loop, libc::SIGINT, &handle_terminate_signal, null);

	g_server.backend = wlr::wlr_backend_autocreate(loop, &g_server.session);
	if (g_server.backend == null) return false;

	listener_register(&g_server.backend_destroy, &server_backend_destroy, &g_server.backend.events.destroy);

	g_server.renderer = wlr::wlr_renderer_autocreate(g_server.backend);
	if (g_server.renderer == null) return false;

	wlr::wlr_renderer_init_wl_display(g_server.renderer, g_server.display);

	g_server.allocator = wlr::wlr_allocator_autocreate(g_server.backend, g_server.renderer);
	if (g_server.allocator == null) return false;

	wlr::wlr_compositor_create(g_server.display, 5, g_server.renderer);
	wlr::wlr_subcompositor_create(g_server.display);
	wlr::wlr_data_device_manager_create(g_server.display);
	wlr::wlr_primary_selection_v1_device_manager_create(g_server.display);
	wlr::wlr_data_control_manager_v1_create(g_server.display);
	g_server.xdg_shell = wlr::wlr_xdg_shell_create(g_server.display, 6);
	g_server.layer_shell = wlr::wlr_layer_shell_v1_create(g_server.display, 4);
	g_server.foreign_toplevel_mgr = wlr::wlr_foreign_toplevel_manager_v1_create(g_server.display);
	wlr::wlr_viewporter_create(g_server.display);
	g_server.seat = wlr::wlr_seat_create(g_server.display, "seat0");
	wlr::wlr_seat_set_capabilities(g_server.seat, wlr::WL_SEAT_CAPABILITY_POINTER | wlr::WL_SEAT_CAPABILITY_KEYBOARD);

	listener_register(&g_server.request_set_selection, &seat_handle_request_set_selection, &g_server.seat.events.request_set_selection);
	listener_register(&g_server.request_set_primary_selection, &seat_handle_request_set_primary_selection, &g_server.seat.events.request_set_primary_selection);
	listener_register(&g_server.request_start_drag, &seat_handle_request_start_drag, &g_server.seat.events.request_start_drag);
	listener_register(&g_server.start_drag, &seat_handle_start_drag, &g_server.seat.events.start_drag);
	listener_register(&g_server.request_set_cursor, &seat_handle_request_set_cursor, &g_server.seat.events.request_set_cursor);

	g_server.output_layout = wlr::wlr_output_layout_create(g_server.display);
	g_server.xdg_output_mgr = wlr::wlr_xdg_output_manager_v1_create(g_server.display, g_server.output_layout);

	g_server.scene = wlr::wlr_scene_create();
	g_server.scene_layout = wlr::wlr_scene_attach_output_layout(g_server.scene, g_server.output_layout);

	g_server.layers.background = wlr::wlr_scene_tree_create(&g_server.scene.tree);
	g_server.layers.bottom = wlr::wlr_scene_tree_create(&g_server.scene.tree);
	g_server.layers.toplevel = wlr::wlr_scene_tree_create(&g_server.scene.tree);
	g_server.layers.top = wlr::wlr_scene_tree_create(&g_server.scene.tree);
	g_server.layers.overlay = wlr::wlr_scene_tree_create(&g_server.scene.tree);
	g_server.layers.session_lock = wlr::wlr_scene_tree_create(&g_server.scene.tree);

	g_server.drag_icons = wlr::wlr_scene_tree_create(g_server.layers.overlay);
	wlr::wlr_scene_node_set_enabled(&g_server.drag_icons.node, false);

	wl::wl_list_init(&g_server.toplevels);
	wl::wl_list_init(&g_server.outputs);
	wl::wl_list_init(&g_server.layer_surfaces);

	g_server.cursor = wlr::wlr_cursor_create();
	wlr::wlr_cursor_attach_output_layout(g_server.cursor, g_server.output_layout);

	g_server.cursor_mgr = wlr::wlr_xcursor_manager_create(null, 24);
	wlr::wlr_xcursor_manager_load(g_server.cursor_mgr, 1.0);

	listener_register(&g_server.cursor_motion, &server_cursor_motion, &g_server.cursor.events.motion);
	listener_register(&g_server.cursor_motion_absolute, &server_cursor_motion_absolute, &g_server.cursor.events.motion_absolute);
	listener_register(&g_server.cursor_button, &server_cursor_button, &g_server.cursor.events.button);
	listener_register(&g_server.cursor_axis, &server_cursor_axis, &g_server.cursor.events.axis);
	listener_register(&g_server.cursor_frame, &server_cursor_frame, &g_server.cursor.events.frame);

	listener_register(&g_server.new_xdg_toplevel, &xdg_shell_handle_new_toplevel, &g_server.xdg_shell.events.new_toplevel);
	listener_register(&g_server.new_output, &server_new_output, &g_server.backend.events.new_output);
	listener_register(&g_server.new_input, &server_new_input, &g_server.backend.events.new_input);
	listener_register(&g_server.new_layer_surface, &server_new_layer_surface, &g_server.layer_shell.events.new_surface);

	g_server.session_lock_mgr = wlr::wlr_session_lock_manager_v1_create(g_server.display);
	wl::wl_list_init(&g_server.session_lock_outputs);
	listener_register(&g_server.new_session_lock, &server_handle_new_session_lock, &g_server.session_lock_mgr.events.new_lock);
	listener_register(&g_server.session_lock_mgr_destroy, &server_handle_session_lock_mgr_destroy, &g_server.session_lock_mgr.events.destroy);

	return true;
}

fn void server_finish()
{
	wl::wl_display_destroy_clients(g_server.display);

	@cleanup_listeners(Server, &g_server);

	wlr::wlr_cursor_destroy(g_server.cursor);
	wlr::wlr_xcursor_manager_destroy(g_server.cursor_mgr);

	wlr::wlr_backend_destroy(g_server.backend);
	wl::wl_display_destroy(g_server.display);
}
