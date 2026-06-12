module qori;
import wl;

alias WlNotifyFn = fn void(WlListener* listener, void* data);

fn void listener_register(WlListener* listener, WlNotifyFn notify, WlSignal* signal)
{
	listener.notify = notify;
	wl::wl_signal_add(signal, listener);
}

fn void listener_deregister(WlListener* listener)
{
	if (listener.notify != null)
	{
		wl::wl_list_remove(&listener.link);
		listener.notify = null;
	}
}

macro void @cleanup_listeners($Type, ptr)
{
	$foreach $m : $Type::members:
		$if $m.type == WlListener:
			listener_deregister(&(*ptr).$eval($m.name));
		$endif
	$endforeach
}
