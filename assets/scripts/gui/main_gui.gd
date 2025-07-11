extends Control

const VISUALIZER_PCK_PATH = "user://mods"
const VIS_MODULES_PATH = "res://vis_modules"
const VISUALIZER_SCENE_PATH = "res://assets/scenes/visualizers/"

@onready var visual_display = preload("res://assets/scenes/VisualDisplay.tscn")
@onready var empty_scene_entry = preload("res://assets/scenes/gui/SceneEntry.tscn")
@onready var scene_list = $"VBoxContainer/TabContainer/Scene Select/MarginContainer3/VBoxContainer/ScrollContainer/SceneList"
@onready var online = preload("res://assets/sprites/Online.tres")
@onready var offline = preload("res://assets/sprites/Offline.tres")
@onready var server_status = $HBoxContainer/StatusTexture
@onready var db_label = $"VBoxContainer/TabContainer/Settings/VBoxContainer/Server Settings/Server Settings/dB Label"
@onready var port_error = $"VBoxContainer/TabContainer/Settings/VBoxContainer/Server Settings/Server Settings/PortError"
@onready var variance_error = $"VBoxContainer/TabContainer/Settings/VBoxContainer/Visualization Settings/Visualization Settings/VarianceError"
@onready var delay_error = $"VBoxContainer/TabContainer/Settings/VBoxContainer/Visualization Settings/Visualization Settings/DelayError"

var visual_display_instance: VisualDisplay

var server_path = ProjectSettings.globalize_path("res://bin/lt_server")
var sv_path = ProjectSettings.globalize_path("res://bin/supervisor")

var server_pid: int
var platform: String

var gain = 0.0
var port = 3000
var input_mode = false
var scene_change_delay = 20.0
var scene_change_variance = 5.0
var shuffle_mode = false

var scenes = {}
var checkbox_state = {}

var dir: DirAccess = null
var last_files = null

var p_accum = 0
var scene_idx = 0

func _ready() -> void:
	ModLoader.connect("scene_entries_updated", _on_scene_entries_updated)
	
func _on_scene_entries_updated():
	var entries = ModLoader.scene_entries
	for entry in entries:
		var new_scene_entry_element: SceneEntryElement = empty_scene_entry.instantiate()
		new_scene_entry_element.get_label().text = entry.name
		new_scene_entry_element.connect("SceneEntryToggled", _on_entry_toggled)
		new_scene_entry_element.path = entry.path
		scene_list.add_child(new_scene_entry_element)

func _process(delta: float) -> void:
	
	if Input.is_action_just_pressed("toggle_menu"):
		self.visible = !self.visible
	
	#var files = dir.get_files()
	#if last_files != files:
		#_reset_scene_entries()
	#last_files = files
	
	p_accum += delta
	if p_accum >= 1:
		clean_zombie()
		p_accum = 0
		if is_server_running():
			server_status.texture = online
		else:
			restart_server()


func start() -> void:
	platform = OS.get_name()
	# TODO: Windows support
	if platform != "Linux":
		printerr("Unsupported Platform: " + platform)
		OS.kill(OS.get_process_id())
	
	if is_server_running():
		server_status.texture = online
	else:
		restart_server()
	#_reset_scene_entries()
	_on_scene_switcher_timeout()
	
	launch_sv()


func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		kill_server()
		get_tree().quit()


func is_server_running() -> bool:
	var args = ["lt_server"]
	var output = []
	
	match platform:
		"Linux":
			OS.execute("pgrep", args, output)
		"Windows":
			# TODO
			pass
			
	return str(output[0]).replace("\n", "").is_valid_int()


func kill_server():
	var output = []
	match platform:
		"Linux":
			OS.execute("killall", ["lt_server"], output)
		"Windows":
			# TODO
			pass


func launch_sv():
	var args = []
	match platform:
		"Linux":
			args = ["-p", port]
		"Windows":
			# TODO
			pass
	server_pid = OS.create_process(sv_path, args)


func launch_bin():
	#var output = []
	var args = []
	match platform:
		"Linux":
			args = ["-p", port, "-H", "-g", gain]
			if input_mode:
				args.append("-I")
		"Windows":
			# TODO
			pass
	server_pid = OS.create_process(server_path, args)


func restart_server():
	kill_server()
	clean_zombie()
	launch_bin()


func clean_zombie():
	var output = []
	OS.execute("pgrep", ["lt_server"], output)
	var pids = str(output[0]).split("\n")
	for pid in pids:
		OS.is_process_running(pid.to_int())


func _on_entry_toggled(scene, toggled_on):
	checkbox_state[scene] = toggled_on
	if not toggled_on:
		scenes.erase(scene)
	else:
		# check hashmap for scene
		if scenes.has(scene):
			pass
		else:
			var new_scene = load(VISUALIZER_SCENE_PATH + scene.get_basename() + ".tscn")
			scenes[scene] = new_scene

#
#func _reset_scene_entries():
	#for scene_entry in scene_list.get_children():
		#scene_entry.queue_free()
	#dir = DirAccess.open(VISUALIZER_PCK_PATH)
	#dir.list_dir_begin()
	#while (true):
		#var file = dir.get_next()
		#if file == "":
			#break
		#elif file.get_extension() == "pck":
			#var success = ProjectSettings.load_resource_pack(VISUALIZER_PCK_PATH + "/" + file)
			#
			#var new_scene_entry: SceneEntry = empty_scene_entry.instantiate()
			#new_scene_entry.get_label().text = file
			#new_scene_entry.connect("SceneEntryToggled", _on_entry_toggled)
			#scene_list.add_child(new_scene_entry)
			#
			#if checkbox_state.has(file):
				#new_scene_entry.checkbox.button_pressed = checkbox_state[file]
			#else:
				#checkbox_state[file] = true
				#new_scene_entry.checkbox.button_pressed = checkbox_state[file]
			#
			## check hashmap for scene
			#if scenes.has(file):
				#pass
			#else:
				#var new_scene = load(VISUALIZER_SCENE_PATH + file.get_basename() + ".tscn")
				#scenes[file] = new_scene

func _fullscreen_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _shuffle_mode_toggled(toggled_on: bool) -> void:
	shuffle_mode = toggled_on


func _on_scene_change_delay_text_changed(new_text: String) -> void:
	if new_text.is_valid_float():
		delay_error.text = ""
		scene_change_delay = new_text.to_float()
	else:
		delay_error.text = "INVALID"


func _on_scene_change_var_text_changed(new_text: String) -> void:
	if new_text.is_valid_float():
		variance_error.text = ""
		scene_change_variance = new_text.to_float()
	else:
		variance_error.text = "INVALID"


func _on_port_text_changed(new_text: String) -> void:
	if new_text.is_valid_int():
		port_error.text = ""
		port = new_text.to_int()
		restart_server()
		OscClient.update_port(port)
	else:
		port_error.text = "INVALID"


func _input_mode_toggled(toggled_on: bool) -> void:
	input_mode = toggled_on
	restart_server()

func _on_gain_slider_value_changed(value: float) -> void:
	db_label.text = str(value) + " dB"
	gain = value
	restart_server()

func _on_scene_switcher_timeout() -> void:
	if visual_display_instance != null:
		var new_time =  scene_change_delay + randf_range(-scene_change_variance, scene_change_variance)
		new_time = 0.01 if new_time <= 0 else new_time
		$SceneSwitcher.wait_time = new_time
		$SceneSwitcher.start()
		
		var scene_keys = scenes.keys()
		if len(scene_keys) <= 0:
			return
			
		
		for child in visual_display_instance.scene_layer.get_children():
			child.queue_free()
		
		if shuffle_mode:
			scene_idx = randi() % len(scene_keys)
		else:
			scene_idx = 0 if scene_idx >= len(scene_keys) - 1 else scene_idx + 1
		
		var new_scene = scenes[scene_keys[scene_idx]].instantiate()
		visual_display_instance.scene_layer.add_child(new_scene)
