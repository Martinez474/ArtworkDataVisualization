extends Node3D

@onready var artwork_cloud = $ArtworkCloud
@onready var camera = $Camera3D
@onready var info_panel = $CanvasLayer/InfoPanel

@onready var thumbnail_radius_label = $CanvasLayer/InfoPanel/VBoxContainer/ThumbnailRadiusLabel
@onready var thumbnail_slider = $CanvasLayer/InfoPanel/VBoxContainer/ThumbnailSlider

func _ready():
	artwork_cloud.artwork_selected.connect(_on_artwork_selected)

	thumbnail_slider.min_value = 1
	thumbnail_slider.max_value = 20
	thumbnail_slider.step = 0.5
	thumbnail_slider.value = artwork_cloud.thumbnail_distance
	thumbnail_slider.value_changed.connect(_on_thumbnail_slider_changed)

	update_thumbnail_label()

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		artwork_cloud.select_from_mouse(camera, event.position)

func _on_artwork_selected(art: Dictionary):
	var texture_path = artwork_cloud.get_artwork_texture_path(art)
	info_panel.show_artwork(art, texture_path)

func _on_thumbnail_slider_changed(value: float):
	artwork_cloud.thumbnail_distance = value
	update_thumbnail_label()

	if artwork_cloud.thumbnails_enabled:
		artwork_cloud.update_nearby_thumbnails()

func update_thumbnail_label():
	thumbnail_radius_label.text = "Thumbnail radius: %.1f" % artwork_cloud.thumbnail_distance
