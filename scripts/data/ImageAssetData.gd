class_name ImageAssetData
extends AssetData

@export var pixel_dimensions: Vector2i
@export var original_image: Image

@export var raw_file_buffer: PackedByteArray = PackedByteArray()
@export var file_extension: String = "png"


func _init(
	new_id: String = "",
	file_name: String = "",
	path: String = "",
	dim: Vector2i = Vector2i.ZERO,
	buffer: PackedByteArray = PackedByteArray(),
	ext: String = "png"
) -> void:
	id = new_id
	display_name = file_name
	source_path = path
	pixel_dimensions = dim
	raw_file_buffer = buffer
	file_extension = ext


func get_count() -> int:
	return 1

func get_size(_index: int) -> Vector2i:
	return pixel_dimensions

func get_bytes() -> PackedByteArray:
	return raw_file_buffer

func get_image(_index: int, _size: Vector2i = Vector2i.ZERO) -> Image:
	var img: Image = Image.new()
	var err: Error = FAILED

	var type: ImageType = get_image_type(raw_file_buffer)

	match type:
		ImageType.JPEG:
			err = img.load_jpg_from_buffer(raw_file_buffer)
		ImageType.PNG:
			err = img.load_png_from_buffer(raw_file_buffer)
		ImageType.WEBP:
			err = img.load_webp_from_buffer(raw_file_buffer)
		ImageType.UNKNOWN:
			err = Error.ERR_FILE_UNRECOGNIZED

	if err != OK:
		Global.notice(
			"Cannot load file", 'File from path "%s" is unsupported or corrupted' % source_path
		)
		push_error('ImageAssetData: Image from path "%s" is unsupported or corrupted' % source_path)
		return null

	return img

func clean() -> void:
	raw_file_buffer.clear()


static func create_from_file(path: String) -> ImageAssetData:
	var img_buffer: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if img_buffer.is_empty():
		Global.notice("Cannot load file", 'File from path "%s" is empty!' % path)
		push_error('ImageAssetData: File from path "%s" is empty!' % path)
		return null

	var asset: ImageAssetData = create_from_buffer(img_buffer, path)

	return asset


static func create_from_buffer(
	buffer: PackedByteArray, path: String = ""
) -> ImageAssetData:
	var img: Image = Image.new()
	var err: Error = FAILED

	var ext: String = "png"

	var type: ImageType = get_image_type(buffer)

	# img = Image.load_from_file(path)
	# err = OK if img else ERR_CANT_OPEN

	match type:
		ImageType.JPEG:
			err = img.load_jpg_from_buffer(buffer)
			ext = "jpg"
		ImageType.PNG:
			err = img.load_png_from_buffer(buffer)
			ext = "png"
			match img.detect_alpha():
				Image.ALPHA_NONE:
					buffer = img.save_jpg_to_buffer(0.5)
				_:
					buffer = img.save_webp_to_buffer(false, 0.5)
			# buffer = img.save_webp_to_buffer(true, 1)
		ImageType.WEBP:
			err = img.load_webp_from_buffer(buffer)
			ext = "webp"
		ImageType.UNKNOWN:
			err = Error.ERR_FILE_UNRECOGNIZED

	if err != OK:
		Global.notice("Cannot load file", 'File from path "%s" is unsupported or corrupted' % path)
		push_error('ImageAssetData: Image from path "%s" is unsupported or corrupted' % path)
		return null

	var dim = get_dimensions(buffer)
	var file_name = path.get_file()
	var new_id = AssetData.get_id()

	# match get_image_type(buffer):
	# 	ImageType.JPEG:
	# 		print("jpeg")
	# 	ImageType.PNG:
	# 		print("png")
	# 	ImageType.WEBP:
	# 		print("webp")

	var asset: ImageAssetData = ImageAssetData.new(
		new_id, file_name, path, dim, buffer, ext
	)

	return asset


enum ImageType { UNKNOWN, PNG, JPEG, WEBP }


static func get_dimensions(buffer: PackedByteArray) -> Vector2i:
	var type: ImageType = get_image_type(buffer)

	match type:
		ImageType.PNG:
			return _parse_png_dimensions(buffer)
		ImageType.JPEG:
			return _parse_jpeg_dimensions(buffer)
		ImageType.WEBP:
			return _parse_webp_dimensions(buffer)
		_:
			return Vector2i.ZERO


static func get_image_type_from_file(file_path: String) -> ImageType:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return ImageType.UNKNOWN

	var buffer = file.get_buffer(12)
	if buffer.size() < 12:
		return ImageType.UNKNOWN

	# 1. PNG Magic Bytes (0x89 'P' 'N' 'G')
	if buffer[0] == 0x89 and buffer[1] == 0x50 and buffer[2] == 0x4E and buffer[3] == 0x47:
		return ImageType.PNG

	# 2. JPEG Magic Bytes (0xFF 0xD8)
	if buffer[0] == 0xFF and buffer[1] == 0xD8:
		return ImageType.JPEG

	# 3. WebP Magic Bytes ('R' 'I' 'F' 'F' ... 'W' 'E' 'B' 'P')
	if (
		buffer[0] == 0x52
		and buffer[1] == 0x49
		and buffer[2] == 0x46
		and buffer[3] == 0x46
		and buffer[8] == 0x57
		and buffer[9] == 0x45
		and buffer[10] == 0x42
		and buffer[11] == 0x50
	):
		return ImageType.WEBP

	return ImageType.UNKNOWN


static func get_image_type(buffer: PackedByteArray) -> ImageType:
	if buffer.size() < 12:
		return ImageType.UNKNOWN

	# 1. PNG Magic Bytes (0x89 'P' 'N' 'G')
	if buffer[0] == 0x89 and buffer[1] == 0x50 and buffer[2] == 0x4E and buffer[3] == 0x47:
		return ImageType.PNG

	# 2. JPEG Magic Bytes (0xFF 0xD8)
	if buffer[0] == 0xFF and buffer[1] == 0xD8:
		return ImageType.JPEG

	# 3. WebP Magic Bytes ('R' 'I' 'F' 'F' ... 'W' 'E' 'B' 'P')
	if (
		buffer[0] == 0x52
		and buffer[1] == 0x49
		and buffer[2] == 0x46
		and buffer[3] == 0x46
		and buffer[8] == 0x57
		and buffer[9] == 0x45
		and buffer[10] == 0x42
		and buffer[11] == 0x50
	):
		return ImageType.WEBP

	return ImageType.UNKNOWN


static func _parse_png_dimensions(buffer: PackedByteArray) -> Vector2i:
	if buffer.size() < 24:
		return Vector2i.ZERO
	var width: int = (buffer[16] << 24) | (buffer[17] << 16) | (buffer[18] << 8) | buffer[19]
	var height: int = (buffer[20] << 24) | (buffer[21] << 16) | (buffer[22] << 8) | buffer[23]
	return Vector2i(width, height)


static func _parse_jpeg_dimensions(buffer: PackedByteArray) -> Vector2i:
	var offset: int = 2
	var size: int = buffer.size()

	while offset < size - 8:
		if buffer[offset] != 0xFF:
			offset += 1
			continue

		var marker: int = buffer[offset + 1]

		if marker == 0xC0 or marker == 0xC2:
			var height: int = (buffer[offset + 5] << 8) | buffer[offset + 6]
			var width: int = (buffer[offset + 7] << 8) | buffer[offset + 8]
			return Vector2i(width, height)

		var block_length: int = (buffer[offset + 2] << 8) | buffer[offset + 3]
		offset += 2 + block_length

	return Vector2i.ZERO


static func _parse_webp_dimensions(buffer: PackedByteArray) -> Vector2i:
	if buffer.size() < 16:
		return Vector2i.ZERO

	var format_chunk: String = buffer.slice(12, 16).get_string_from_ascii()

	match format_chunk:
		"VP8 ":
			if buffer.size() < 30:
				return Vector2i.ZERO
			var width: int = (buffer[26] | (buffer[27] << 8)) & 0x3FFF
			var height: int = (buffer[28] | (buffer[29] << 8)) & 0x3FFF
			return Vector2i(width, height)

		"VP8L":
			if buffer.size() < 25:
				return Vector2i.ZERO
			var b0: int = buffer[21]
			var b1: int = buffer[22]
			var b2: int = buffer[23]
			var b3: int = buffer[24]

			var width: int = 1 + (((b1 & 0x3F) << 8) | b0)
			var height: int = 1 + (((b3 & 0xF) << 10) | (b2 << 2) | ((b1 & 0xC0) >> 6))
			return Vector2i(width, height)

		"VP8X":
			if buffer.size() < 30:
				return Vector2i.ZERO
			var width: int = 1 + (buffer[24] | (buffer[25] << 8) | (buffer[26] << 16))
			var height: int = 1 + (buffer[27] | (buffer[28] << 8) | (buffer[29] << 16))
			return Vector2i(width, height)

	return Vector2i.ZERO
