extends Node3D

@onready var artwork_cloud = $ArtworkCloud
@onready var camera = $Camera3D
@onready var info_panel = $CanvasLayer/InfoPanel

@onready var thumbnail_count_label = $CanvasLayer/InfoPanel/VBoxContainer/ThumbnailCountLabel
@onready var thumbnail_slider = $CanvasLayer/InfoPanel/VBoxContainer/ThumbnailSlider

func _ready():
	artwork_cloud.artwork_selected.connect(_on_artwork_selected)

	thumbnail_slider.min_value = 0
	thumbnail_slider.max_value = 100
	thumbnail_slider.step = 1
	thumbnail_slider.value = artwork_cloud.max_thumbnails
	thumbnail_slider.value_changed.connect(_on_thumbnail_slider_changed)

	update_thumbnail_label()

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		artwork_cloud.select_from_mouse(camera, event.position)

func _on_artwork_selected(art: Dictionary):
	var texture_path = artwork_cloud.get_artwork_texture_path(art)
	info_panel.show_artwork(art, texture_path)

func _on_thumbnail_slider_changed(value: float):
	artwork_cloud.max_thumbnails = int(value)
	update_thumbnail_label()

	if artwork_cloud.thumbnails_enabled:
		artwork_cloud.update_nearby_thumbnails()

func update_thumbnail_label():
	thumbnail_count_label.text = "Max thumbnails: %d" % artwork_cloud.max_thumbnails
