extends PanelContainer

@onready var preview_image: TextureRect = $VBoxContainer/PreviewImage
@onready var info_label: Label = $VBoxContainer/InfoLabel

func show_artwork(art: Dictionary, texture_path: String):
	info_label.text = "File: %s\nCluster: %s\nPosition: (%.2f, %.2f, %.2f)" % [
		String(art.get("filename", "")),
		str(art.get("cluster", -1)),
		float(art.get("x", 0.0)),
		float(art.get("y", 0.0)),
		float(art.get("z", 0.0))
	]

	print("Trying to load:", texture_path)
	print("Exists:", ResourceLoader.exists(texture_path))

	var tex = load(texture_path)
	print("Loaded texture object:", tex)

	if tex:
		preview_image.texture = tex
	else:
		preview_image.texture = null
