@abstract class_name AssetData
extends RefCounted

var id: String
var display_name: String
var source_path: String

@abstract func get_count() -> int
@abstract func get_size(index: int) -> Vector2i


static func get_id() -> String:
	var crypto = Crypto.new()
	# Generate 6 random bytes (48 bits = 281 trillion combinations)
	var bytes = crypto.generate_random_bytes(6)

	# Encode to Base64 and clean up filesystem-unsafe characters
	var short_id = Marshalls.raw_to_base64(bytes)
	short_id = short_id.replace("+", "-").replace("/", "_").replace("=", "")

	return short_id
