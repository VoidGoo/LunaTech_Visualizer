extends Node

class SceneEntry:
	var entry_name: String = ""
	var path: String = ""
	var enabled: bool = true

const MOD_USER_PATH = "user://mods"
const MOD_RES_PATH = "res://mods"

var mod_register = {} # name -> enabled
var scene_entries = {}

var mod_dir: DirAccess
var last_files = null

signal mod_list_updated
signal scene_entries_updated


func _ready() -> void:
	mod_dir = DirAccess.open(MOD_USER_PATH)
	refresh_mod_list()


func _process(delta: float) -> void:
	var files = mod_dir.get_files()
	if last_files != files:
		refresh_mod_list()
	last_files = files


func _reset_scene_paths() -> void:
	scene_entries = {}
	for mod_name in mod_register.keys():
		if (mod_register[mod_name]["enabled"]):
			if (mod_register[mod_name].has("scene_paths")):
				var new_entries = []
				for path in scene_entries:
					var new_entry = SceneEntry.new()
					new_entry.entry_name = str(path).get_file().get_basename()
					new_entry.path = path
					new_entry.enabled = true
				scene_entries.append_array(mod_register[mod_name]["scene_paths"])
			else:
				printerr("Mod " + mod_name + " is missing scene paths")
	emit_signal("scene_entries_updated")


func set_mod_enabled(mod_name, is_enabled):
	if mod_register.has(mod_name):
		mod_register[mod_name]["enabled"] = is_enabled
		_reset_scene_paths()
	else:
		printerr("Mod could not be found: " + mod_name)


func get_scene_entries():
	return scene_entries


func refresh_mod_list():
	mod_register = {}
	# Check downloaded mods and load them into memory
	var dir = DirAccess.open(MOD_USER_PATH)
	dir.list_dir_begin()
	while (true):
		var file = dir.get_next()
		if file == "":
			break
		elif file.get_extension() == "pck":
			if (!ProjectSettings.load_resource_pack(MOD_USER_PATH + "/" + file, false)):
				printerr("Failed to load " + file)
	
	# Go through loaded mods and process manifest data
	dir = DirAccess.get_directories_at(MOD_RES_PATH)
	for folder in dir:
		var mod_dir = DirAccess.open(folder)
		var manifest = load(MOD_RES_PATH + "/" + folder + "/manifest.gd").new()
		
		var mod_name = manifest.mod_name
		var scene_paths = manifest.scene_paths
		var author = manifest.author
		var version = manifest.version
		var desc = manifest.desc
		
		if mod_register.has(mod_name):
			printerr("Mod \"" + mod_name + "\" already loaded. Is there a mod name conflict?")
			continue
		else:
			mod_register[mod_name] = {}
			mod_register[mod_name]["scene_paths"] = scene_paths
			mod_register[mod_name]["author"] = author
			mod_register[mod_name]["version"] = version
			mod_register[mod_name]["desc"] = desc
			mod_register[mod_name]["enabled"] = true
			
	# add scene paths to scene entries (if a mod is disabled, all scene paths must be reset)
	_reset_scene_paths()
	emit_signal("mod_list_updated")
