module qori;
import wl, wlr;

enum SceneObjectType
{
	NONE,
	TOPLEVEL,
	LAYER_SURFACE,
	POPUP
}

struct SceneDescriptor
{
	SceneObjectType type;
	void* owner;
	WlListener destroy;
}

// Scene node tagging helper functions

fn void scene_node_destroy_handler(WlListener* listener, void* data)
{
	SceneDescriptor* desc = wl::@container_of(listener, SceneDescriptor, destroy);
	wl::wl_list_remove(&desc.destroy.link);
	mem::free(desc);
}

fn void associate_scene_node(WlrSceneNode* node, SceneObjectType type, void* owner)
{
	SceneDescriptor* desc = mem::new(SceneDescriptor);
	desc.type = type;
	desc.owner = owner;
	desc.destroy.notify = &scene_node_destroy_handler;
	wl::wl_signal_add(&node.events.destroy, &desc.destroy);
	node.data = desc;
}

fn SceneDescriptor* get_scene_descriptor(WlrSceneNode* node)
{
	WlrSceneNode* curr = node;
	while (curr != null)
	{
		if (curr.data != null) return (SceneDescriptor*)curr.data;
		curr = curr.parent != null ? &curr.parent.node : null;
	}
	return null;
}

fn void* get_scene_owner(WlrSceneNode* node, SceneObjectType expected)
{
	SceneDescriptor* desc = get_scene_descriptor(node);
	return (desc != null && desc.type == expected) ? desc.owner : null;
}

fn Toplevel* get_toplevel_from_node(WlrSceneNode* node) => (Toplevel*)get_scene_owner(node, TOPLEVEL);
fn LayerSurface* get_layer_surface_from_node(WlrSceneNode* node) => (LayerSurface*)get_scene_owner(node, LAYER_SURFACE);
fn Popup* get_popup_from_node(WlrSceneNode* node) => (Popup*)get_scene_owner(node, POPUP);

fn WlrSceneTree* get_surface_scene_tree(WlrSurface* surface) => (WlrSceneTree*)surface.data ?: null;
