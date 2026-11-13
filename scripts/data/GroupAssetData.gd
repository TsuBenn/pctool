class_name GroupAssetData
extends AssetData

# Array[[AssetData, Index]]
var children: Array[Array] = []
var assets: Array[AssetData] = []

func _init(
	new_id: String,
	new_display_name: String,
	new_children: Array[Array],
) -> void:
	id = new_id
	display_name = new_display_name
	source_path = ""
	children = new_children
	for child in children:
		var asset = child[0]
		var index = child[1]
		if index == 0:
			assets.append(asset)
			asset.changed.connect(update_children)

func get_count() -> int:
	return children.size()

func get_size(index: int) -> Vector2i:
	var entry = children[index]
	return entry[0].get_size(entry[1])

func get_child(index: int) -> Array:
	return children.get(index)

func clean() -> void:
	for child in children:
		child[0].clean()

	children.clear()


func flatten() -> Array[Array]:
	var flattened_group: Array[Array] = []

	for child in children:
		var asset = child[0]
		var index = child[1]
		if asset is GroupAssetData:
			for a in asset.flatten():
				flattened_group.append(a)
		else:
			flattened_group.append([asset, index])

	return flattened_group


func remove_asset(asset: AssetData):
	children.filter(func(entry): return entry[0] != asset)

func update_children():
	var new_group: Array[Array] = []

	for asset in assets:
		if asset is PdfAssetData:
			for i in range(asset.page_count):
				new_group.append([asset, i])
		elif asset is PdfAssetSlice:
			for i in range(asset.get_count()):
				new_group.append([asset, i])
		else:
			new_group.append([asset, 0])

	children = new_group
	emit_changed()

static func create_from_assets(_assets: Array[AssetData], name: String) -> GroupAssetData:
	if _assets.size() <= 1:
		Global.notice("Cannot Group Assets", "You must select at least 2 assets for grouping!")
		return null
	var new_group: Array[Array] = []
	var new_id: String = AssetData.get_id()

	for asset in _assets:
		if asset is GroupAssetData:
			for a in asset.flatten():
				new_group.append(a)
		elif asset is PdfAssetData:
			for i in range(asset.page_count):
				new_group.append([asset, i])
		elif asset is PdfAssetSlice:
			for i in range(asset.get_count()):
				new_group.append([asset, i])
		else:
			new_group.append([asset, 0])

	var asset: GroupAssetData = GroupAssetData.new(new_id, name, new_group)
	return asset
