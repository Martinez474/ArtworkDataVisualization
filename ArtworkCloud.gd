extends Node3D

signal artwork_selected(artwork: Dictionary)

@export var json_path: String = "res://data/artwork_map.json"
@export var artworks_folder: String = "res://artworks/"

# marker cloud
@export var point_radius: float = 0.25
@export var selection_ray_threshold: float = 0.8

# nearby thumbnails
@export var thumbnails_enabled: bool = true
@export var thumbnail_distance: float = 8.0
@export var max_thumbnails: int = 10
@export var thumbnail_scale: float = .25
@export var thumbnail_height_offset: float = 0.6
@export var thumbnail_update_interval: float = 0.2

var artworks: Array = []
var multimesh_instance: MultiMeshInstance3D
var multimesh: MultiMesh

var selected_index: int = -1
var cluster_colors := {}

var active_thumbnails := {}
var white_texture: Texture2D
var thumbnail_timer: float = 0.0


func _ready():
	load_artworks()
	print_bounds()
	build_cluster_colors()
	build_multimesh()
	create_white_texture()


func _process(delta):
	thumbnail_timer += delta

	if not thumbnails_enabled:
		clear_all_thumbnails()
		return

	if thumbnail_timer >= thumbnail_update_interval:
		thumbnail_timer = 0.0
		update_nearby_thumbnails()


func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			thumbnails_enabled = not thumbnails_enabled
			print("Thumbnails enabled: ", thumbnails_enabled)

			if not thumbnails_enabled:
				clear_all_thumbnails()
			else:
				update_nearby_thumbnails()


func load_artworks():
	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_error("Could not open JSON: " + json_path)
		return

	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if parsed == null:
		push_error("Failed to parse JSON: " + json_path)
		return

	artworks = parsed
	print("Loaded artworks: ", artworks.size())


func get_artwork_color(art: Dictionary) -> Color:
	var cluster := int(art.get("cluster", -1))
	return cluster_colors.get(cluster, Color(1.0, 0.8, 0.2, 0.9))


func build_cluster_colors():
	var palette = [
		Color(0.90, 0.20, 0.20),
		Color(0.20, 0.60, 0.95),
		Color(0.20, 0.80, 0.35),
		Color(0.95, 0.75, 0.20),
		Color(0.70, 0.35, 0.90),
		Color(0.20, 0.85, 0.85),
		Color(0.95, 0.45, 0.15),
		Color(0.75, 0.75, 0.75)
	]

	var unique_clusters: Array = []
	for art in artworks:
		var c := int(art.get("cluster", -1))
		if c not in unique_clusters:
			unique_clusters.append(c)

	unique_clusters.sort()

	for i in range(unique_clusters.size()):
		cluster_colors[unique_clusters[i]] = palette[i % palette.size()]


func build_multimesh():
	multimesh_instance = MultiMeshInstance3D.new()
	multimesh = MultiMesh.new()

	var quad := QuadMesh.new()
	quad.size = Vector2(point_radius, point_radius)

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = mat

	multimesh.mesh = quad
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.instance_count = artworks.size()

	for i in range(artworks.size()):
		var art: Dictionary = artworks[i]

		var pos := Vector3(
			float(art["x"]),
			float(art["y"]),
			float(art["z"])
		)

		multimesh.set_instance_transform(i, Transform3D(Basis(), pos))
		multimesh.set_instance_color(i, get_artwork_color(art))

	multimesh_instance.multimesh = multimesh
	add_child(multimesh_instance)


func get_closest_artwork_to_ray(ray_origin: Vector3, ray_dir: Vector3, max_distance := 0.8) -> int:
	var best_index := -1
	var best_dist := INF

	for i in range(artworks.size()):
		var art: Dictionary = artworks[i]
		var p := Vector3(
			float(art["x"]),
			float(art["y"]),
			float(art["z"])
		)

		var to_point := p - ray_origin
		var projected := ray_dir * to_point.dot(ray_dir)
		var closest := ray_origin + projected
		var dist := p.distance_to(closest)

		if dist < best_dist and dist <= max_distance:
			best_dist = dist
			best_index = i

	return best_index


func select_from_mouse(camera: Camera3D, mouse_pos: Vector2):
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos).normalized()

	# First try clicking a visible thumbnail sprite
	var thumb_idx := get_closest_thumbnail_to_ray(ray_origin, ray_dir, 1.2)
	if thumb_idx != -1:
		select_index(thumb_idx)
		return

	# Fall back to the normal marker cloud selection
	var idx := get_closest_artwork_to_ray(ray_origin, ray_dir, selection_ray_threshold)
	if idx != -1:
		select_index(idx)


func select_index(idx: int):
	if idx < 0 or idx >= artworks.size():
		return

	if selected_index != -1:
		restore_instance_color(selected_index)

	selected_index = idx
	multimesh.set_instance_color(selected_index, Color.WHITE)

	var art: Dictionary = artworks[selected_index]
	artwork_selected.emit(art)


func restore_instance_color(idx: int):
	var art: Dictionary = artworks[idx]
	multimesh.set_instance_color(idx, get_artwork_color(art))


func get_artwork_texture_path(art: Dictionary) -> String:
	return artworks_folder + String(art.get("image", ""))


func create_white_texture():
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	white_texture = ImageTexture.create_from_image(image)


func update_nearby_thumbnails():
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var camera_pos = camera.global_position
	var candidates: Array = []

	for i in range(artworks.size()):
		var art: Dictionary = artworks[i]
		var pos := Vector3(
			float(art["x"]),
			float(art["y"]),
			float(art["z"])
		)

		var dist := camera_pos.distance_to(pos)
		candidates.append({
			"id": i,
			"dist": dist
		})

	candidates.sort_custom(func(a, b): return a["dist"] < b["dist"])

	if candidates.size() > max_thumbnails:
		candidates = candidates.slice(0, max_thumbnails)

	var wanted_ids := {}

	for candidate in candidates:
		var idx := int(candidate["id"])
		wanted_ids[idx] = true

		if not active_thumbnails.has(idx):
			create_thumbnail(idx)
		else:
			update_thumbnail_transform(idx)

	var ids_to_remove := []
	for idx in active_thumbnails.keys():
		if not wanted_ids.has(idx):
			ids_to_remove.append(idx)

	for idx in ids_to_remove:
		remove_thumbnail(idx)


func create_thumbnail(idx: int):
	var art: Dictionary = artworks[idx]
	var texture_path := get_artwork_texture_path(art)

	if not ResourceLoader.exists(texture_path):
		return

	var tex = load(texture_path)
	if tex == null:
		return

	var root := Node3D.new()
	root.name = "thumb_%d" % idx

	var border := Sprite3D.new()
	border.name = "BorderSprite"
	border.texture = white_texture
	border.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	border.modulate = get_artwork_color(art)
	border.pixel_size = 0.01
	border.scale = Vector3(thumbnail_scale * 1.15, thumbnail_scale * 1.15, 1.0)

	var image_sprite := Sprite3D.new()
	image_sprite.name = "ImageSprite"
	image_sprite.texture = tex
	image_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	image_sprite.pixel_size = 0.01
	image_sprite.scale = Vector3(thumbnail_scale, thumbnail_scale, 1.0)
	image_sprite.position = Vector3(0, 0, 0.01)

	root.add_child(border)
	root.add_child(image_sprite)

	add_child(root)
	active_thumbnails[idx] = root

	update_thumbnail_transform(idx)


func update_thumbnail_transform(idx: int):
	if not active_thumbnails.has(idx):
		return

	var art: Dictionary = artworks[idx]
	var root: Node3D = active_thumbnails[idx]

	root.position = Vector3(
		float(art["x"]),
		float(art["y"]) + thumbnail_height_offset,
		float(art["z"])
	)


func remove_thumbnail(idx: int):
	if active_thumbnails.has(idx):
		var node: Node3D = active_thumbnails[idx]
		node.queue_free()
		active_thumbnails.erase(idx)


func clear_all_thumbnails():
	var ids_to_remove := active_thumbnails.keys()
	for idx in ids_to_remove:
		remove_thumbnail(idx)


func print_bounds():
	if artworks.is_empty():
		return

	var min_x = INF
	var min_y = INF
	var min_z = INF
	var max_x = -INF
	var max_y = -INF
	var max_z = -INF

	for art in artworks:
		var x = float(art["x"])
		var y = float(art["y"])
		var z = float(art["z"])

		min_x = min(min_x, x)
		min_y = min(min_y, y)
		min_z = min(min_z, z)

		max_x = max(max_x, x)
		max_y = max(max_y, y)
		max_z = max(max_z, z)

	print("Bounds:")
	print("x:", min_x, "to", max_x)
	print("y:", min_y, "to", max_y)
	print("z:", min_z, "to", max_z)

func get_closest_thumbnail_to_ray(ray_origin: Vector3, ray_dir: Vector3, max_distance := 1.2) -> int:
	var best_index := -1
	var best_dist := INF

	for idx in active_thumbnails.keys():
		var node: Node3D = active_thumbnails[idx]
		var p := node.global_position

		var to_point := p - ray_origin
		var projected := ray_dir * to_point.dot(ray_dir)
		var closest := ray_origin + projected
		var dist := p.distance_to(closest)

		if dist < best_dist and dist <= max_distance:
			best_dist = dist
			best_index = int(idx)

	return best_index
