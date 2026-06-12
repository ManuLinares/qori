module wlr;
import wl, libc;

// Type-safe opaque handles matching the C struct layout behavior
// c3fmt off
struct WlrRenderer          { void* _opaque; }
struct WlrAllocator         { void* _opaque; }
struct WlrCompositor        { void* _opaque; }
struct WlrSceneOutput       { void* _opaque; }
struct WlrOutputMode        { void* _opaque; }
struct WlrSession           { void* _opaque; }
struct WlrOutputLayout      { void* _opaque; }
struct WlrSceneOutputLayout { void* _opaque; }
struct WlrBuffer            { void* _opaque; }
struct WlrClientBuffer      { void* _opaque; }
struct WlrSwapchain         { void* _opaque; }
struct WlrOutputCursor      { void* _opaque; }
struct WlrSceneBuffer       { void* _opaque; }
struct WlrSurfaceRole       { void* _opaque; }
struct WlrKeyboardGroup     { void* _opaque; }
struct WlrImageDescription  { void* _opaque; }
struct WlrColorPrimaries    { void* _opaque; }
struct WlrOutputImpl        { void* _opaque; }
struct WlrGpuTimeline       { void* _opaque; }
struct WlrColorTransform    { void* _opaque; }
struct WlrOutputLayerState  { void* _opaque; }
struct WlrXdgOutputManagerV1 { void* _opaque; }
struct WlrXcursorManager    { void* _opaque; }
struct WlrForeignToplevelManagerV1 { void* _opaque; }
struct WlrSceneRect         { void* _opaque; }

// xkbcommon opaque handles
struct XkbContext           { void* _opaque; }
struct XkbKeymap            { void* _opaque; }
struct XkbState             { void* _opaque; }

// Private implementation details (still opaque to C3)
struct WlrBackendImpl       { void* _opaque; }
struct WlrKeyboardImpl      { void* _opaque; }
struct WlrCursorState       { void* _opaque; }
// c3fmt on

struct WlrSeatPointerButton
{
	uint button;
	usz n_pressed;
}

struct WlrSeatPointerState
{
	WlrSeat* seat;
	void* focused_client;
	WlrSurface* focused_surface;
	double sx, sy;
	void* grab;
	void* default_grab;
	bool sent_axis_source;
	uint cached_axis_source;
	WlrSeatPointerButton[16] buttons;
	usz button_count;
	uint grab_button;
	uint grab_serial;
	uint grab_time;
	struct events
	{
		WlSignal focus_change;
	}
	struct private_data
	{
		WlListener surface_destroy;
	}
}

struct WlrSeatKeyboardState
{
	WlrSeat* seat;
	WlrKeyboard* keyboard;
	void* focused_client;
	WlrSurface* focused_surface;
	void* grab;
	void* default_grab;
	struct events
	{
		WlSignal focus_change;
	}
	struct private_data
	{
		WlListener keyboard_destroy;
		WlListener keyboard_keymap;
		WlListener keyboard_repeat_info;
		WlListener surface_destroy;
	}
}

struct WlrSeatTouchState
{
	WlrSeat* seat;
	WlList touch_points;
	uint grab_serial;
	uint grab_id;
	void* grab;
	void* default_grab;
}

struct WlrSeatEvents
{
	WlSignal pointer_grab_begin;
	WlSignal pointer_grab_end;
	WlSignal keyboard_grab_begin;
	WlSignal keyboard_grab_end;
	WlSignal touch_grab_begin;
	WlSignal touch_grab_end;
	WlSignal request_set_cursor;
	WlSignal request_set_selection;
	WlSignal set_selection;
	WlSignal request_set_primary_selection;
	WlSignal set_primary_selection;
	WlSignal request_start_drag;
	WlSignal start_drag;
	WlSignal destroy;
}

struct WlrSeat
{
	void* global;
	void* display;
	WlList clients;
	char* name;
	uint capabilities;
	uint accumulated_capabilities;
	void* selection_source;
	uint selection_serial;
	WlList selection_offers;
	void* primary_selection_source;
	uint primary_selection_serial;
	void* drag;
	void* drag_source;
	uint drag_serial;
	WlList drag_offers;
	WlrSeatPointerState pointer_state;
	WlrSeatKeyboardState keyboard_state;
	WlrSeatTouchState touch_state;
	WlrSeatEvents events;
	void* data;
}

// Fixed struct layout matching the C header exactly
struct WlrCursor
{
	WlrCursorState* state;
	double x;
	double y;
	struct events
	{
		WlSignal motion;
		WlSignal motion_absolute;
		WlSignal button;
		WlSignal axis;
		WlSignal frame;
	}
}

enum WlrSceneNodeType : uint
{
	TREE,
	RECT,
	BUFFER,
}

struct WlrSceneNode
{
	WlrSceneNodeType type;
	WlrSceneTree* parent;
	WlList link;
	bool enabled;
	int x;
	int y;
	struct events
	{
		WlSignal destroy;
	}
	void* data;
}

struct WlrSceneTree
{
	WlrSceneNode node;
	WlList children;
}

struct WlrSceneSurface
{
	WlrSceneBuffer* buffer;
	WlrSurface* surface;
}

struct WlrBox
{
	int x;
	int y;
	int width;
	int height;
}

struct WlrLayerShellV1
{
	WlGlobal* global;
	struct events
	{
		WlSignal new_surface;
		WlSignal destroy;
	}
}

struct WlrSceneLayerSurfaceV1
{
	WlrSceneTree* tree;
	WlrLayerSurfaceV1* layer_surface;
}

struct WlrLayerSurfaceV1State
{
	uint committed;
	uint anchor;
	int exclusive_zone;
	struct margin
	{
		int top;
		int right;
		int bottom;
		int left;
	}
	WlrLayerSurfaceV1KeyboardInteractivity keyboard_interactive;
	uint desired_width, desired_height;
	uint layer;
	uint exclusive_edge;
	uint configure_serial;
	uint actual_width, actual_height;
}

struct WlrLayerSurfaceV1
{
	WlrSurface* surface;
	WlrOutput* output;
	WlResource* resource;
	WlrLayerShellV1* shell;
	WlList popups;
	char* ns;
	bool configured;
	WlList configure_list;
	WlrLayerSurfaceV1State current;
	WlrLayerSurfaceV1State pending;
	bool initialized;
	bool initial_commit;
	struct events
	{
		WlSignal destroy;
		WlSignal new_popup;
	}
	void* data;
}

struct WlrPointerMotionEvent
{
	WlrInputDevice* device;
	uint time_msec;
	double delta_x;
	double delta_y;
	double unaccel_dx;
	double unaccel_dy;
}

struct WlrPointerMotionAbsoluteEvent
{
	WlrInputDevice* device;
	uint time_msec;
	double x;
	double y;
}

constdef WlrButton : uint
{
	LEFT  = 0x110,
	RIGHT = 0x111,
}

struct WlrPointerButtonEvent
{
	WlrInputDevice* device;
	uint time_msec;
	WlrButton button;
	uint state;
}

struct WlrPointerAxisEvent
{
	WlrInputDevice* device;
	uint time_msec;
	uint source;
	uint orientation;
	uint relative_direction;
	double delta;
	int delta_discrete;
}

const uint WL_POINTER_BUTTON_STATE_RELEASED = 0;
const uint WL_POINTER_BUTTON_STATE_PRESSED  = 1;

// Named Constants
const int SIGCHLD                      = 17;
const int CLOCK_MONOTONIC              = 1;
const uint WL_SEAT_CAPABILITY_POINTER  = 1;
const uint WL_SEAT_CAPABILITY_KEYBOARD = 2;
const uint WL_SEAT_CAPABILITY_TOUCH    = 4;

const uint WLR_INPUT_DEVICE_KEYBOARD   = 0;
const uint WLR_INPUT_DEVICE_POINTER    = 1;
const uint WLR_INPUT_DEVICE_TOUCH      = 2;
const uint WLR_INPUT_DEVICE_TABLET     = 3;
const uint WLR_INPUT_DEVICE_TABLET_PAD = 4;
const uint WLR_INPUT_DEVICE_SWITCH     = 5;

const uint WLR_OUTPUT_STATE_MODE        = 1 << 2;
const uint WLR_OUTPUT_STATE_MODE_FIXED  = 0;
const uint WLR_OUTPUT_STATE_MODE_CUSTOM = 1;

const uint WLR_XDG_TOPLEVEL_WM_CAPABILITIES_WINDOW_MENU = 1 << 0;
const uint WLR_XDG_TOPLEVEL_WM_CAPABILITIES_MAXIMIZE    = 1 << 1;
const uint WLR_XDG_TOPLEVEL_WM_CAPABILITIES_FULLSCREEN  = 1 << 2;
const uint WLR_XDG_TOPLEVEL_WM_CAPABILITIES_MINIMIZE    = 1 << 3;

const int XKB_CONTEXT_NO_FLAGS        = 0;
const int XKB_KEYMAP_COMPILE_NO_FLAGS = 0;

constdef WlrModifier : inline uint
{
	SHIFT = 1 << 0,
	CAPS  = 1 << 1,
	CTRL  = 1 << 2,
	ALT   = 1 << 3,
	MOD2  = 1 << 4,
	MOD3  = 1 << 5,
	LOGO  = 1 << 6,
	MOD5  = 1 << 7,
}

constdef WlrEdge : inline uint
{
	NONE   = 0,
	TOP    = 1 << 0,
	BOTTOM = 1 << 1,
	LEFT   = 1 << 2,
	RIGHT  = 1 << 3,
}

const uint XKB_CONTROL = 0xff00;
constdef XkbKey : inline uint
{
	BACKSPACE = XKB_CONTROL | '\b',
	TAB       = XKB_CONTROL | '\t',
	RETURN    = XKB_CONTROL | '\r',
	ESCAPE    = XKB_CONTROL | '\e', // 0x1b, standard ESC hex

	F1  = 0xffbe,
	F12 = 0xffc9,

	XF86_SWITCH_VT_1  = 0x1008fe01,
	XF86_SWITCH_VT_12 = 0x1008fe0c,
}

enum WlKeyboardKeyState : uint
{
	RELEASED,
	PRESSED
}

enum WlrLayerSurfaceV1KeyboardInteractivity : uint
{
	NONE,
	EXCLUSIVE,
	ON_DEMAND
}

const uint ZWLR_LAYER_SHELL_V1_LAYER_BACKGROUND = 0;
const uint ZWLR_LAYER_SHELL_V1_LAYER_BOTTOM     = 1;
const uint ZWLR_LAYER_SHELL_V1_LAYER_TOP        = 2;
const uint ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY    = 3;

struct WlrKeyboardModifiers
{
	uint depressed;
	uint latched;
	uint locked;
	uint group;
}

struct PixmanBox32
{
	int x1;
	int y1;
	int x2;
	int y2;
}

struct PixmanRegion32Data
{
	CLong size;
	CLong num_rects;
}

struct PixmanRegion32
{
	PixmanBox32 extents;
	PixmanRegion32Data* data;
}

struct WlrKeyboardKeyEvent
{
	uint time_msec;
	uint keycode;
	bool update_state;
	WlKeyboardKeyState state;
}

struct WlrInputDevice
{
	uint type;
	char* name;
	struct events
	{
		WlSignal destroy;
	}
	void* data;
}

struct WlrKeyboard
{
	WlrInputDevice base;
	WlrKeyboardImpl* impl;
	WlrKeyboardGroup* group;
	char* keymap_string;
	usz keymap_size;
	int keymap_fd;
	XkbKeymap* keymap;
	XkbState* xkb_state;
	int[5] led_indexes;
	int[8] mod_indexes;
	uint leds;
	uint[32] keycodes;
	usz num_keycodes;
	WlrKeyboardModifiers modifiers;
	struct repeat_info
	{
		int rate;
		int delay;
	}
	struct events
	{
		WlSignal key;
		WlSignal modifiers;
		WlSignal keymap;
		WlSignal repeat_info;
	}
	void* data;
}

struct WlrSurfaceViewport
{
	bool has_src;
	bool has_dst;
	double[4] src;
	int dst_width;
	int dst_height;
}

struct WlrSurfaceState
{
	uint committed;
	uint seq;
	WlrBuffer* buffer;
	int dx;
	int dy;
	PixmanRegion32 surface_damage;
	PixmanRegion32 buffer_damage;
	PixmanRegion32 opaque;
	PixmanRegion32 input;
	uint transform;
	int scale;
	WlList frame_callback_list;
	int width;
	int height;
	int buffer_width;
	int buffer_height;
	WlList subsurfaces_below;
	WlList subsurfaces_above;
	WlrSurfaceViewport viewport;
	usz cached_state_locks;
	WlList cached_state_link;
	WlArray synced;
}

struct WlrSurface
{
	WlResource* resource;
	WlrCompositor* compositor;
	WlrClientBuffer* buffer;
	PixmanRegion32 buffer_damage;
	PixmanRegion32 opaque_region;
	PixmanRegion32 input_region;
	WlrSurfaceState current;
	WlrSurfaceState pending;
	WlList cached;
	bool mapped;
	WlrSurfaceRole* role;
	WlResource* role_resource;
	struct events
	{
		WlSignal client_commit;
		WlSignal commit;
		WlSignal map;
		WlSignal unmap;
		WlSignal new_subsurface;
		WlSignal destroy;
	}
	WlList current_outputs;
	WlList addons;
	void* data;
}

// Cleaned to match WlrBox directly
struct WlrXdgSurfaceState
{
	uint committed;
	WlrBox geometry;
	uint configure_serial;
}

enum WlrXdgSurfaceRole : uint
{
	NONE,
	TOPLEVEL,
	POPUP,
}

struct WlrXdgSurface
{
	void* client;
	WlResource* resource;
	WlrSurface* surface;
	WlList link;
	WlrXdgSurfaceRole role;
	WlResource* role_resource;
	union
	{
		WlrXdgToplevel* toplevel;
		WlrXdgPopup* popup;
	}
	WlList popups;
	bool configured;
	WlEventSource* configure_idle;
	uint scheduled_serial;
	WlList configure_list;
	WlrXdgSurfaceState current;
	WlrXdgSurfaceState pending;
	bool initialized;
	bool initial_commit;
	int[4] geometry;
	struct events
	{
		WlSignal destroy;
		WlSignal ping_timeout;
		WlSignal new_popup;
		WlSignal configure;
		WlSignal ack_configure;
	}
	void* data;
}

struct WlrXdgToplevelState
{
	bool maximized;
	bool fullscreen;
	bool resizing;
	bool activated;
	bool suspended;
	uint tiled;
	uint constrained;
	int width;
	int height;
	int max_width;
	int max_height;
	int min_width;
	int min_height;
}

struct WlrXdgToplevelRequested
{
	bool maximized;
	bool minimized;
	bool fullscreen;
	WlrOutput* fullscreen_output;
	struct wlr_private
	{
		WlListener fullscreen_output_destroy;
	}
}

struct WlrXdgToplevelConfigure
{
	uint fields;
	bool maximized;
	bool fullscreen;
	bool resizing;
	bool activated;
	bool suspended;
	uint tiled;
	uint constrained;
	int width;
	int height;
	struct bounds
	{
		int width;
		int height;
	}
	uint wm_capabilities;
}

struct WlrXdgToplevel
{
	WlResource* resource;
	WlrXdgSurface* base;
	WlrXdgToplevel* parent;
	WlrXdgToplevelState current;
	WlrXdgToplevelState pending;
	WlrXdgToplevelConfigure scheduled;
	WlrXdgToplevelRequested requested;
	char* title;
	char* app_id;
	struct events
	{
		WlSignal destroy;
		WlSignal request_maximize;
		WlSignal request_fullscreen;
		WlSignal request_minimize;
		WlSignal request_move;
		WlSignal request_resize;
		WlSignal request_show_window_menu;
		WlSignal set_parent;
		WlSignal set_title;
		WlSignal set_app_id;
	}
}

struct WlrXdgToplevelResizeEvent
{
	WlrXdgToplevel* toplevel;
	void* seat;
	uint serial;
	uint edges;
}

struct WlrXdgPopupConfigure
{
	uint fields;
	WlrBox geometry;
	char[60] rules;
	uint reposition_token;
}

struct WlrXdgPopupState
{
	WlrBox geometry;
	bool reactive;
}

struct WlrXdgPopup
{
	WlrXdgSurface* base;
	WlList link;
	WlResource* resource;
	WlrSurface* parent;
	WlrSeat* seat;
	WlrXdgPopupConfigure scheduled;
	WlrXdgPopupState current;
	WlrXdgPopupState pending;
	struct events
	{
		WlSignal destroy;
		WlSignal reposition;
	}
}

struct WlrScene
{
	WlrSceneTree tree;
}

struct WlrXdgShell
{
	WlGlobal* global;
	uint version;
	WlList clients;
	WlList popup_grabs;
	uint ping_timeout;
	struct events
	{
		WlSignal new_surface;
		WlSignal new_toplevel;
		WlSignal new_popup;
		WlSignal destroy;
	}
}

struct WlrBackend
{
	WlrBackendImpl* impl;
	uint buffer_caps;
	struct features
	{
		bool timeline;
	}
	struct events
	{
		WlSignal destroy;
		WlSignal new_input;
		WlSignal new_output;
	}
}

struct WlrOutput
{
	WlrOutputImpl* impl;
	WlrBackend* backend;
	WlEventLoop* event_loop;
	WlGlobal* global;
	WlList resources;
	char* name;
	char* description;
	char* make;
	char* model;
	char* serial;
	int phys_width;
	int phys_height;
	WlrColorPrimaries* default_primaries;
	WlList modes;
	WlrOutputMode* current_mode;
	int width;
	int height;
	int refresh;
	uint supported_primaries;
	uint supported_transfer_functions;
	bool enabled;
	float scale;
	uint subpixel;
	uint transform;
	uint adaptive_sync_status;
	uint render_format;
	uint color_encoding;
	uint color_range;
	WlrImageDescription* image_description;
	bool adaptive_sync_supported;
	bool needs_frame;
	bool frame_pending;
	bool non_desktop;
	uint commit_seq;
	struct events
	{
		WlSignal frame;
		WlSignal damage;
		WlSignal needs_frame;
		WlSignal precommit;
		WlSignal commit;
		WlSignal present;
		WlSignal bind;
		WlSignal description;
		WlSignal request_state;
		WlSignal destroy;
	}
	WlEventSource* idle_frame;
	WlEventSource* idle_done;
	int attach_render_locks;
	WlList cursors;
	WlrOutputCursor* hardware_cursor;
	WlrSwapchain* cursor_swapchain;
	WlrBuffer* cursor_front_buffer;
	int software_cursor_locks;
	WlList layers;
	WlrAllocator* wlr_allocator;
	WlrRenderer* wlr_renderer;
	WlrSwapchain* swapchain;
	WlList addons;
	void* data;
}

struct WlrOutputState
{
	uint committed;
	bool allow_reconfiguration;
	PixmanRegion32 damage;
	bool enabled;
	float scale;
	uint transform;
	bool adaptive_sync_enabled;
	uint render_format;
	uint subpixel;
	WlrBuffer* buffer;
	double[4] buffer_src_box;
	int[4] buffer_dst_box;
	bool tearing_page_flip;
	uint color_encoding;
	uint color_range;
	uint mode_type;
	WlrOutputMode* mode;
	struct custom_mode
	{
		int width;
		int height;
		int refresh;
	}
	WlrOutputLayerState* layers;
	usz layers_len;
	WlrGpuTimeline* wait_timeline;
	ulong wait_point;
	WlrGpuTimeline* signal_timeline;
	ulong signal_point;
	WlrColorTransform* color_transform;
	WlrImageDescription* image_description;
}

struct WlrOutputEventRequestState
{
	WlrOutput* output;
	WlrOutputState* state;
}

struct WlrForeignToplevelHandleV1
{
	void* manager;
	WlList resources;
	WlList link;
	void* parent;
	void* idle_source;
	char* title;
	char* app_id;
	WlList output_resources;
	void* data;
	struct events
	{
		WlSignal request_maximize;
		WlSignal request_minimize;
		WlSignal request_activate;
		WlSignal request_close;
		WlSignal request_fullscreen;
		WlSignal set_rectangle;
		WlSignal destroy;
	}
}

struct WlrForeignToplevelMaximizedEvent
{
	WlrForeignToplevelHandleV1* handle;
	bool maximized;
}

struct WlrForeignToplevelMinimizedEvent
{
	WlrForeignToplevelHandleV1* handle;
	bool minimized;
}

struct WlrForeignToplevelActivatedEvent
{
	WlrForeignToplevelHandleV1* handle;
	WlrSeat* seat;
}

extern fn WlrBackend* wlr_backend_autocreate(WlEventLoop* loop, WlrSession** session_ptr);
extern fn bool wlr_session_change_vt(WlrSession* session, uint vt);
extern fn bool wlr_backend_start(WlrBackend* backend);
extern fn void wlr_backend_destroy(WlrBackend* backend);

extern fn WlrRenderer* wlr_renderer_autocreate(WlrBackend* backend);
extern fn bool wlr_renderer_init_wl_display(WlrRenderer* r, WlDisplay* wl_display);
extern fn void wlr_renderer_destroy(WlrRenderer* renderer);

extern fn WlrAllocator* wlr_allocator_autocreate(WlrBackend* backend, WlrRenderer* renderer);
extern fn void wlr_allocator_destroy(WlrAllocator* alloc);

extern fn WlrCompositor* wlr_compositor_create(WlDisplay* display, uint version, WlrRenderer* renderer);
extern fn void* wlr_subcompositor_create(WlDisplay* display);
extern fn void* wlr_data_device_manager_create(WlDisplay* display);

extern fn WlrScene* wlr_scene_create();
extern fn WlrSceneOutput* wlr_scene_output_create(WlrScene* scene, WlrOutput* output);
extern fn void wlr_scene_output_destroy(WlrSceneOutput* scene_output);
extern fn bool wlr_scene_output_commit(WlrSceneOutput* scene_output, void* options);
extern fn void wlr_scene_output_send_frame_done(WlrSceneOutput* scene_output, libc::TimeSpec* now);
extern fn bool wlr_scene_output_needs_frame(WlrSceneOutput* scene_output);
extern fn bool wlr_scene_output_build_state(WlrSceneOutput* scene_output, WlrOutputState* state, void* options);

extern fn bool wlr_output_init_render(WlrOutput* output, WlrAllocator* allocator, WlrRenderer* renderer);
extern fn WlrOutputMode* wlr_output_preferred_mode(WlrOutput* output);
extern fn void wlr_output_state_init(WlrOutputState* state);
extern fn void wlr_output_state_finish(WlrOutputState* state);
extern fn void wlr_output_state_set_enabled(WlrOutputState* state, bool enabled);
extern fn void wlr_output_state_set_mode(WlrOutputState* state, WlrOutputMode* mode);
extern fn void wlr_output_state_set_custom_mode(WlrOutputState* state, int width, int height, int refresh);
extern fn bool wlr_output_commit_state(WlrOutput* output, WlrOutputState* state);
extern fn void wlr_output_schedule_frame(WlrOutput* output);
extern fn void wlr_output_schedule_done(WlrOutput* output);

extern fn WlrXdgShell* wlr_xdg_shell_create(WlDisplay* display, uint version);
extern fn uint wlr_xdg_toplevel_set_size(WlrXdgToplevel* toplevel, int width, int height);
extern fn uint wlr_xdg_surface_schedule_configure(WlrXdgSurface* surface);
extern fn void wlr_xdg_toplevel_send_close(WlrXdgToplevel* toplevel);
extern fn uint wlr_xdg_toplevel_set_wm_capabilities(WlrXdgToplevel* toplevel, uint caps);
extern fn uint wlr_xdg_toplevel_set_bounds(WlrXdgToplevel* toplevel, int width, int height);
extern fn WlrXdgSurface* wlr_xdg_surface_try_from_wlr_surface(WlrSurface* surface);
extern fn void wlr_xdg_popup_unconstrain_from_box(WlrXdgPopup* popup, WlrBox* toplevel_sx_box);
extern fn WlrXdgOutputManagerV1* wlr_xdg_output_manager_v1_create(WlDisplay* display, WlrOutputLayout* layout);

extern fn WlrOutputLayout* wlr_output_layout_create(WlDisplay* display);
extern fn void* wlr_output_layout_add_auto(WlrOutputLayout* layout, WlrOutput* output);
extern fn WlrSceneOutputLayout* wlr_scene_attach_output_layout(WlrScene* scene, WlrOutputLayout* layout);
extern fn void wlr_scene_output_layout_add_output(WlrSceneOutputLayout* scene_layout, void* l_output, WlrSceneOutput* scene_output);
extern fn WlrSceneTree* wlr_scene_tree_create(WlrSceneTree* parent);
extern fn WlrSceneTree* wlr_scene_xdg_surface_create(WlrSceneTree* parent_tree, WlrXdgSurface* xdg_surface);

extern fn WlrSeat* wlr_seat_create(WlDisplay* display, char* name);
extern fn void wlr_seat_set_capabilities(WlrSeat* seat, uint capabilities);
extern fn void wlr_seat_set_keyboard(WlrSeat* seat, WlrKeyboard* keyboard);
extern fn WlrKeyboard* wlr_seat_get_keyboard(WlrSeat* seat);
extern fn void wlr_seat_keyboard_enter(WlrSeat* seat, WlrSurface* surface, uint* keycodes, usz num_keycodes, WlrKeyboardModifiers* modifiers);
extern fn void wlr_seat_keyboard_notify_key(WlrSeat* seat, uint time_msec, uint keycode, WlKeyboardKeyState state);
extern fn void wlr_seat_keyboard_notify_modifiers(WlrSeat* seat, WlrKeyboardModifiers* modifiers);
extern fn void wlr_seat_keyboard_notify_clear_focus(WlrSeat* seat);

extern fn XkbContext* xkb_context_new(int flags);
extern fn void xkb_context_unref(XkbContext* context);
extern fn XkbKeymap* xkb_keymap_new_from_names(XkbContext* context, void* names, int flags);
extern fn void xkb_keymap_unref(XkbKeymap* keymap);

extern fn bool wlr_keyboard_set_keymap(WlrKeyboard* keyboard, XkbKeymap* keymap);
extern fn uint wlr_keyboard_get_modifiers(WlrKeyboard* keyboard);
extern fn void wlr_keyboard_set_repeat_info(WlrKeyboard* keyboard, int rate, int delay);

extern fn int xkb_state_key_get_syms(XkbState* state, uint key, XkbKey** syms_out);

extern fn WlrCursor* wlr_cursor_create();
extern fn void wlr_cursor_destroy(WlrCursor* cur);
extern fn void wlr_cursor_attach_output_layout(WlrCursor* cur, WlrOutputLayout* layout);
extern fn void wlr_cursor_attach_input_device(WlrCursor* cur, WlrInputDevice* dev);
extern fn void wlr_cursor_move(WlrCursor* cur, WlrInputDevice* dev, double delta_x, double delta_y);
extern fn void wlr_cursor_warp_absolute(WlrCursor* cur, WlrInputDevice* dev, double x, double y);
extern fn void wlr_cursor_set_xcursor(WlrCursor* cur, WlrXcursorManager* manager, char* name);

extern fn WlrXcursorManager* wlr_xcursor_manager_create(char* name, uint size);
extern fn void wlr_xcursor_manager_destroy(WlrXcursorManager* manager);
extern fn bool wlr_xcursor_manager_load(WlrXcursorManager* manager, float scale);

extern fn WlrSceneNode* wlr_scene_node_at(WlrSceneNode* node, double lx, double ly, double* nx, double* ny);
extern fn WlrSceneSurface* wlr_scene_surface_try_from_buffer(WlrSceneNode* node);
extern fn void wlr_scene_node_raise_to_top(WlrSceneNode* node);
extern fn void wlr_scene_node_set_position(WlrSceneNode* node, int x, int y);
extern fn void wlr_scene_node_set_enabled(WlrSceneNode* node, bool enabled);
extern fn void wlr_scene_node_reparent(WlrSceneNode* node, WlrSceneTree* new_parent);

extern fn void wlr_seat_pointer_notify_enter(WlrSeat* seat, WlrSurface* surface, double sx, double sy);
extern fn void wlr_seat_pointer_notify_clear_focus(WlrSeat* seat);
extern fn void wlr_seat_pointer_notify_motion(WlrSeat* seat, uint time_msec, double sx, double sy);
extern fn uint wlr_seat_pointer_notify_button(WlrSeat* seat, uint time_msec, WlrButton button, uint state);
extern fn void wlr_seat_pointer_notify_axis(WlrSeat* seat, uint time_msec, uint orientation, double value, int value_discrete, uint source, uint relative_direction);
extern fn void wlr_seat_pointer_notify_frame(WlrSeat* seat);

extern fn uint wlr_xdg_toplevel_set_maximized(WlrXdgToplevel* toplevel, bool maximized);
extern fn uint wlr_xdg_toplevel_set_activated(WlrXdgToplevel* toplevel, bool activated);
extern fn uint wlr_xdg_toplevel_set_fullscreen(WlrXdgToplevel* toplevel, bool fullscreen);
extern fn WlrOutput* wlr_output_layout_output_at(WlrOutputLayout* layout, double x, double y);
extern fn void wlr_output_layout_get_box(WlrOutputLayout* layout, WlrOutput* reference, WlrBox* dest_box);

extern fn WlrLayerShellV1* wlr_layer_shell_v1_create(WlDisplay* display, uint version);
extern fn WlrSceneLayerSurfaceV1* wlr_scene_layer_surface_v1_create(WlrSceneTree* parent, WlrLayerSurfaceV1* layer_surface);
extern fn void wlr_scene_layer_surface_v1_configure(WlrSceneLayerSurfaceV1* scene_layer_surface, WlrBox* full_area, WlrBox* usable_area);
extern fn void wlr_layer_surface_v1_destroy(WlrLayerSurfaceV1* surface);

extern fn WlrForeignToplevelManagerV1* wlr_foreign_toplevel_manager_v1_create(WlDisplay* display);
extern fn WlrForeignToplevelHandleV1* wlr_foreign_toplevel_handle_v1_create(WlrForeignToplevelManagerV1* manager);
extern fn void wlr_foreign_toplevel_handle_v1_set_title(WlrForeignToplevelHandleV1* handle, char* title);
extern fn void wlr_foreign_toplevel_handle_v1_set_app_id(WlrForeignToplevelHandleV1* handle, char* app_id);
extern fn void wlr_foreign_toplevel_handle_v1_set_activated(WlrForeignToplevelHandleV1* handle, bool activated);
extern fn void wlr_foreign_toplevel_handle_v1_set_minimized(WlrForeignToplevelHandleV1* handle, bool minimized);
extern fn void wlr_foreign_toplevel_handle_v1_set_maximized(WlrForeignToplevelHandleV1* handle, bool maximized);
extern fn void wlr_foreign_toplevel_handle_v1_output_enter(WlrForeignToplevelHandleV1* handle, WlrOutput* output);
extern fn void wlr_foreign_toplevel_handle_v1_output_leave(WlrForeignToplevelHandleV1* handle, WlrOutput* output);
extern fn void wlr_foreign_toplevel_handle_v1_done(WlrForeignToplevelHandleV1* handle);
extern fn void wlr_foreign_toplevel_handle_v1_destroy(WlrForeignToplevelHandleV1* handle);

extern fn void* wlr_viewporter_create(WlDisplay* display);

extern fn void wlr_scene_node_destroy(WlrSceneNode* node);

extern fn WlrSceneRect* wlr_scene_rect_create(WlrSceneTree* parent, int width, int height, float* color);
extern fn void wlr_scene_rect_set_size(WlrSceneRect* rect, int width, int height);
extern fn void wlr_scene_rect_set_color(WlrSceneRect* rect, float* color);
extern fn WlrSceneTree* wlr_scene_subsurface_tree_create(WlrSceneTree* parent, WlrSurface* surface);

struct WlrSessionLockManagerV1
{
	void* global;
	struct events
	{
		WlSignal new_lock;
		WlSignal destroy;
	}
	void* data;
}

struct WlrSessionLockV1
{
	void* resource;
	WlList surfaces;
	struct events
	{
		WlSignal new_surface;
		WlSignal unlock;
		WlSignal destroy;
	}
	void* data;
}

struct WlrSessionLockSurfaceV1State
{
	uint width;
	uint height;
	uint configure_serial;
}

struct WlrSessionLockSurfaceV1
{
	void* resource;
	WlList link;
	WlrOutput* output;
	WlrSurface* surface;
	bool configured;
	WlList configure_list;
	WlrSessionLockSurfaceV1State current;
	WlrSessionLockSurfaceV1State pending;
	struct events
	{
		WlSignal destroy;
	}
	void* data;
}

extern fn WlrSessionLockManagerV1* wlr_session_lock_manager_v1_create(WlDisplay* display);
extern fn void wlr_session_lock_v1_send_locked(WlrSessionLockV1* lock);
extern fn void wlr_session_lock_v1_destroy(WlrSessionLockV1* lock);
extern fn void wlr_session_lock_surface_v1_configure(WlrSessionLockSurfaceV1* surface, uint width, uint height);

extern fn void* wlr_primary_selection_v1_device_manager_create(WlDisplay* display);
extern fn void* wlr_data_control_manager_v1_create(WlDisplay* display);

struct WlrSeatRequestSetSelectionEvent
{
	void* source;
	uint serial;
}

struct WlrSeatRequestSetPrimarySelectionEvent
{
	void* source;
	uint serial;
}

extern fn void wlr_seat_set_selection(WlrSeat* seat, void* source, uint serial);
extern fn void wlr_seat_set_primary_selection(WlrSeat* seat, void* source, uint serial);

struct WlrDragIcon
{
	WlrDrag* drag;
	WlrSurface* surface;
	struct events
	{
		WlSignal destroy;
	}
	void* data;
}

struct WlrDrag
{
	uint grab_type;
	struct keyboard_grab
	{
		void* iface;
		WlrSeat* seat;
		void* data;
	}
	struct pointer_grab
	{
		void* iface;
		WlrSeat* seat;
		void* data;
	}
	struct touch_grab
	{
		void* iface;
		WlrSeat* seat;
		void* data;
	}
	WlrSeat* seat;
	void* seat_client;
	void* focus_client;
	WlrDragIcon* icon;
	WlrSurface* focus;
	void* source;
	bool started;
	bool dropped;
	bool cancelling;
	int grab_touch_id;
	int touch_id;
	// events
	struct events
	{
		WlSignal focus;
		WlSignal motion;
		WlSignal drop;
		WlSignal destroy;
	}
	void* data;
}

struct WlrSeatRequestStartDragEvent
{
	WlrDrag* drag;
	WlrSurface* origin;
	uint serial;
}

extern fn bool wlr_seat_validate_pointer_grab_serial(WlrSeat* seat, WlrSurface* origin, uint serial);
extern fn void wlr_seat_start_pointer_drag(WlrSeat* seat, WlrDrag* drag, uint serial);
extern fn void wlr_data_source_destroy(void* source);
extern fn WlrSceneTree* wlr_scene_drag_icon_create(WlrSceneTree* parent, WlrDragIcon* icon);

struct WlrSeatPointerRequestSetCursorEvent
{
	void* seat_client;
	WlrSurface* surface;
	uint serial;
	int hotspot_x;
	int hotspot_y;
}

extern fn void wlr_cursor_set_surface(WlrCursor* cursor, WlrSurface* surface, int hotspot_x, int hotspot_y);
extern fn void wlr_cursor_unset_image(WlrCursor* cursor);

