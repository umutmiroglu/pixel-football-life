class_name TownTileMapBuilder
extends Node2D

const TILESET_TEX_PATH: String = "res://assets/tilesets/town_tiles_16x16.png"
const TREE_TEX_PATH: String = "res://assets/sprites/props/tree_oak.png"

var ground_layer: TileMapLayer = null
var decor_layer: TileMapLayer = null

func _ready() -> void:
	_build_tilemaps()
	_spawn_customizable_trees()

func _build_tilemaps() -> void:
	var tex: Texture2D = load(TILESET_TEX_PATH) as Texture2D
	if tex == null:
		push_error("TownTileMapBuilder failed to load tileset texture: " + TILESET_TEX_PATH)
		return

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(16, 16)

	var atlas := TileSetAtlasSource.new()
	atlas.texture = tex
	atlas.texture_region_size = Vector2i(16, 16)
	tile_set.add_source(atlas, 0)

	for row in 4:
		for col in 8:
			atlas.create_tile(Vector2i(col, row))

	ground_layer = TileMapLayer.new()
	ground_layer.name = "GroundLayer"
	ground_layer.tile_set = tile_set
	ground_layer.z_index = -10
	add_child(ground_layer)

	decor_layer = TileMapLayer.new()
	decor_layer.name = "DecorLayer"
	decor_layer.tile_set = tile_set
	decor_layer.z_index = -4
	add_child(decor_layer)

	_paint_starter_town()

func _paint_starter_town() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 202605

	# 1. Çim tabanı (tüm kasaba + dış çerçeve)
	for y in range(-20, 20):
		for x in range(-34, 34):
			var r: float = rng.randf()
			var tile := Vector2i(0, 0)
			if r < 0.16:
				tile = Vector2i(1, 0) # Çim tutamı
			elif r < 0.22:
				tile = Vector2i(2, 0) # Çiçekli çim
			ground_layer.set_cell(Vector2i(x, y), 0, tile)

	# 2. Ana Doğu-Batı Bulvarı (y = -3..1 -> -48..+32 px)
	for x in range(-31, 31):
		ground_layer.set_cell(Vector2i(x, -3), 0, Vector2i(0, 3))
		ground_layer.set_cell(Vector2i(x, -2), 0, Vector2i(4, 0))
		ground_layer.set_cell(Vector2i(x, -1), 0, Vector2i(5, 0))
		ground_layer.set_cell(Vector2i(x, 0), 0, Vector2i(4, 0))
		ground_layer.set_cell(Vector2i(x, 1), 0, Vector2i(1, 3))

	# 3. Kuzey-Güney Bağlantı Yolları (Kapıları Ana Bulvara Bağlar!)
	var v_paths: Array[Vector2i] = [
		Vector2i(-24, -22), # Sol yol: Ev Kapısı <-> Gol Kafe Kapısı
		Vector2i(-6, -4),   # Orta-sol yol: Kulüp Evi Kapısı <-> Gece Kulübü Kapısı
		Vector2i(9, 11),    # Orta-sağ yol: Gazete Kapısı <-> Spor Mağazası Kapısı
		Vector2i(21, 23)    # Sağ yol: Otobüs Durağı <-> Köşe Kahve Kapısı
	]
	for span in v_paths:
		for y in range(-10, 10):
			for x in range(span.x, span.y + 1):
				if y >= -3 and y <= 1:
					if y == -1:
						ground_layer.set_cell(Vector2i(x, y), 0, Vector2i(2, 3)) # Yaya geçidi
				else:
					ground_layer.set_cell(Vector2i(x, y), 0, Vector2i(3, 0)) # Toprak/taş patika

	# 4. Kasaba Meydanı (Taş parke)
	for y in range(-4, 3):
		for x in range(-1, 6):
			ground_layer.set_cell(Vector2i(x, y), 0, Vector2i(6, 0))

	# 5. Otobüs Durağı Sarı Şerit Alanı (x: 20..28, y: -7..-2)
	for y in range(-7, -1):
		for x in range(20, 28):
			var bt := Vector2i(5, 3) if (y == -2 or y == -7) else Vector2i(4, 0)
			ground_layer.set_cell(Vector2i(x, y), 0, bt)

	# 6. Kafe Arka Sokağı Koyu Taşı (Sol alt)
	for y in range(10, 15):
		for x in range(-30, -26):
			ground_layer.set_cell(Vector2i(x, y), 0, Vector2i(4, 3))

	# 7. Dekor Katmanı: Meydan Çiçeklikleri, Banklar, Sokak Lambaları & Çalılar
	for fb in [Vector2i(-1, -4), Vector2i(5, -4), Vector2i(-1, 2), Vector2i(5, 2)]:
		decor_layer.set_cell(fb, 0, Vector2i(3, 3))

	for b in [Vector2i(1, -4), Vector2i(3, -4), Vector2i(2, 2)]:
		decor_layer.set_cell(b, 0, Vector2i(3, 2))

	for lp in [
		Vector2i(-17, -4), Vector2i(-8, -4), Vector2i(7, -4), Vector2i(19, -4),
		Vector2i(-17, 2), Vector2i(-8, 2), Vector2i(7, 2), Vector2i(19, 2)
	]:
		decor_layer.set_cell(lp, 0, Vector2i(2, 2))

	for bsh in [
		Vector2i(-15, -9), Vector2i(-13, -9), Vector2i(4, -9), Vector2i(5, -9),
		Vector2i(-15, 8), Vector2i(3, 8), Vector2i(16, 8), Vector2i(28, 8)
	]:
		decor_layer.set_cell(bsh, 0, Vector2i(1, 2))

func _spawn_customizable_trees() -> void:
	# Aseprite-hazır bağımsız tree_oak.png (32x48) ağaçlar — gövdesi çarpışmalı!
	var tree_tex: Texture2D = load(TREE_TEX_PATH) as Texture2D
	if tree_tex == null:
		return

	var tree_positions: Array[Vector2] = []
	# Üst ve alt orman sınırı
	for x in range(-480, 481, 44):
		tree_positions.append(Vector2(float(x), -278.0))
		tree_positions.append(Vector2(float(x), 260.0))
	# Sol ve sağ sınır
	for y in range(-220, 221, 56):
		tree_positions.append(Vector2(-492.0, float(y)))
		tree_positions.append(Vector2(492.0, float(y)))
	# Kasaba içi birkaç dekoratif ağaç
	tree_positions.append(Vector2(-225.0, -140.0))
	tree_positions.append(Vector2(62.0, -155.0))
	tree_positions.append(Vector2(-215.0, 120.0))
	tree_positions.append(Vector2(252.0, 122.0))

	var trunk_shape := RectangleShape2D.new()
	trunk_shape.size = Vector2(12.0, 10.0)

	for pos in tree_positions:
		var body := StaticBody2D.new()
		body.position = pos
		var spr := Sprite2D.new()
		spr.texture = tree_tex
		spr.offset = Vector2(0.0, -16.0)
		body.add_child(spr)

		var col := CollisionShape2D.new()
		col.shape = trunk_shape
		col.position = Vector2(0.0, 2.0)
		body.add_child(col)
		add_child(body)
