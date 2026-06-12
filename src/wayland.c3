module wl;

// Opaque handle types
// c3fmt off
struct WlDisplay     { void* _opaque; } 
struct WlEventLoop   { void* _opaque; }
struct WlGlobal      { void* _opaque; }
struct WlResource    { void* _opaque; }
struct WlClient      { void* _opaque; }
struct WlEventSource { void* _opaque; }
// c3fmt on

struct WlArray
{
	usz size;
	usz alloc;
	void* data;
}

struct WlList
{
	WlList* prev;
	WlList* next;
}

alias WlNotifyFunc = fn void(WlListener* listener, void* data);
alias WlEventSignalFunc = fn int(int signal_number, void* data);

struct WlListener
{
	WlList link;
	WlNotifyFunc notify;
}

struct WlSignal
{
	WlList listener_list;
}

extern fn WlDisplay* wl_display_create();
extern fn void wl_display_destroy(WlDisplay* display);
extern fn WlEventLoop* wl_display_get_event_loop(WlDisplay* display);
extern fn ZString wl_display_add_socket_auto(WlDisplay* display);
extern fn void wl_display_terminate(WlDisplay* display);
extern fn void wl_display_run(WlDisplay* display);
extern fn void wl_display_destroy_clients(WlDisplay* display);

extern fn void wl_list_init(WlList* list);
extern fn void wl_list_insert(WlList* list, WlList* elm);
extern fn void wl_list_remove(WlList* elm);
extern fn int wl_list_length(WlList* list);
extern fn bool wl_list_empty(WlList* list);
extern fn void* wl_event_loop_add_signal(WlEventLoop* loop, int signal_number, WlEventSignalFunc func, void* data);

fn void wl_signal_add(WlSignal* signal, WlListener* listener)
{
	wl_list_insert(signal.listener_list.prev, &listener.link);
}

// container_of: recover a pointer to the enclosing struct from a member pointer.
// Usage: wayland::@container_of(listener_ptr, Output, frame)
macro @container_of(ptr, $Type, #field)
{
	usz $off = 0;
	$foreach $m : $Type::members:
		$if $m.name == $stringify(#field):
			$off = $m.offset;
		$endif
	$endforeach
	return ($Type*)((char*)ptr - $off);
}
