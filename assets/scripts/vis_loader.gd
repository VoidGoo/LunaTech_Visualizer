extends Node

class SceneEntry:
	var entry_name: String = ""
	var path: String = ""
	var enabled: bool = true

const VIS_USER_PATH = "user://vis"
const VIS_RES_PATH = "res://vis"

var vis_register = {} # name -> enabled
var scene_entries = {}

var vis_dir: DirAccess
var last_files = null

signal vis_list_updated
signal scene_entries_updated


func _ready() -> void:
	vis_dir = DirAccess.open("user://")
	vis_dir.make_dir("vis")
	vis_dir = DirAccess.open("res://")
	vis_dir.make_dir("vis")
	vis_dir = DirAccess.open(VIS_USER_PATH)
	refresh_vis_list()


func _process(delta: float) -> void:
	var files = vis_dir.get_files()
	if last_files != files:
		refresh_vis_list()
	last_files = files


func _reset_scene_paths() -> void:
	scene_entries = {}
	for vis_name in vis_register.keys():
		if (vis_register[vis_name]["enabled"]):
			if (vis_register[vis_name].has("scene_paths")):
				var new_entries = []
				for path in scene_entries:
					var new_entry = SceneEntry.new()
					new_entry.entry_name = str(path).get_file().get_basename()
					new_entry.path = path
					new_entry.enabled = true
				scene_entries.append_array(vis_register[vis_name]["scene_paths"])
			else:
				printerr("Mod " + vis_name + " is missing scene paths")
	emit_signal("scene_entries_updated")


func set_vis_enabled(vis_name, is_enabled):
	if vis_register.has(vis_name):
		vis_register[vis_name]["enabled"] = is_enabled
		_reset_scene_paths()
	else:
		printerr("Mod could not be found: " + vis_name)


func get_scene_entries():
	return scene_entries


func refresh_vis_list():
	vis_register = {}
	# Check downloaded viss and load them into memory
	var dir = DirAccess.open(VIS_USER_PATH)
	dir.list_dir_begin()
	while (true):
		var file = dir.get_next()
		if file == "":
			break
		elif file.get_extension() == "pck":
			if (!ProjectSettings.load_resource_pack(VIS_USER_PATH + "/" + file, false)):
				printerr("Failed to load " + file)
	
	# Go through loaded viss and process manifest data
	dir = DirAccess.get_directories_at(VIS_RES_PATH)
	for folder in dir:
		var vis_dir = DirAccess.open(folder)
		var manifest = load(VIS_RES_PATH + "/" + folder + "/manifest.gd").new()
		
		var vis_name = manifest.vis_name
		var scene_paths = manifest.scene_paths
		var author = manifest.author
		var version = manifest.version
		var desc = manifest.desc
		
		if vis_register.has(vis_name):
			printerr("Mod \"" + vis_name + "\" already loaded. Is there a vis name conflict?")
			continue
		else:
			vis_register[vis_name] = {}
			vis_register[vis_name]["scene_paths"] = scene_paths
			vis_register[vis_name]["author"] = author
			vis_register[vis_name]["version"] = version
			vis_register[vis_name]["desc"] = desc
			vis_register[vis_name]["enabled"] = true
			
	# add scene paths to scene entries (if a vis is disabled, all scene paths must be reset)
	_reset_scene_paths()
	emit_signal("vis_list_updated")
