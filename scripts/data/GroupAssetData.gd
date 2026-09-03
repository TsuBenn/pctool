class_name GroupAssetData
extends AssetData

var children: Array[AssetData] = []

func _init(
	new_id: String,
	new_display_name: String,
	new_children: Array[AssetData],
) -> void:
	id = new_id
	display_name = new_display_name
	source_path = ""
	children = new_children

func get_count() -> int:
	return children.size()

func get_image(index: int) -> Image:
	return children[index].get_image(0)

func get_preview_texture(index: int) -> Texture2D:
	return children[index].get_preview_texture(0)

func flatten() -> Array[AssetData]:
	var flattened_group: Array[AssetData] = []

	for asset in children:
		if asset is GroupAssetData:
			for a in asset.flatten():
				flattened_group.append(a)
		else:
			flattened_group.append(asset)

	return flattened_group

func remove_child(index: int):
	children.remove_at(index)
	emit_changed()

static func create_from_assets(assets: Array[AssetData], name: String) -> GroupAssetData:
	if assets.size() <= 1:
		Global.notice("Cannot Group Assets", "You must select at least 2 assets for grouping!")
		return null
	var new_group: Array[AssetData] = []
	var new_id: String = AssetData.get_id()

	for asset in assets:
		if asset is GroupAssetData:
			for a in asset.flatten():
				new_group.append(a)
		else:
			new_group.append(asset)

	var asset: GroupAssetData = GroupAssetData.new(new_id, name, new_group)
	return asset
