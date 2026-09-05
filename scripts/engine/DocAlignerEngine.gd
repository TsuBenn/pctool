class_name DocAlignerEngine
extends RefCounted

var binary_path: String

func _init() -> void:
	binary_path = _get_platform_binary()

func _get_platform_binary() -> String:
	var os_name = OS.get_name()
	var path = ""

	match os_name:
		"Windows":
			path = "res://bin/detector-win.exe"
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			path = "res://bin/detector-linux"
		"macOS":
			path = "res://bin/detector-mac"
		_:
			push_error("Unsupported OS: " + os_name)
			return ""

	return ProjectSettings.globalize_path(path)

func detect_corners_from_image(img: Image) -> Array[Vector2]:
	var result_points: Array[Vector2] = []
	var image_size: Vector2 = img.get_size()

	if binary_path == "" or not FileAccess.file_exists(binary_path):
		push_error("Detector binary missing at path: " + binary_path)
		return result_points

	# Save temporarily to user://
	var temp_path = "user://temp_scan.png"
	var abs_temp_path = ProjectSettings.globalize_path(temp_path)
	img.save_png(abs_temp_path)

	# Execute process with argument
	var output = []
	var exit_code = OS.execute(binary_path, [abs_temp_path], output, true)

	# Clean up temp file immediately
	if FileAccess.file_exists(temp_path):
		DirAccess.remove_absolute(abs_temp_path)

	if exit_code == 0 and output.size() > 0:
		var json = JSON.new()
		if json.parse(output[0]) == OK:
			var data = json.get_data()
			if data.has("corners"):
				for pt in data["corners"]:
					result_points.append(Vector2(pt[0], pt[1])/image_size)

	return result_points
