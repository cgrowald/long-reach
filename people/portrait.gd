extends RefCounted
## Procedural pixel portrait (24x24), the same every time for a given seed.
## Show it scaled up with nearest filtering for crisp pixels.

const SIZE := 24

const SKIN: Array[Color] = [
	Color("f1c9a5"), Color("e0ac7e"), Color("c68863"), Color("a86b46"), Color("7c4a2d"), Color("5a3520"),
]
const HAIR: Array[Color] = [
	Color("1d1a17"), Color("3b2a1e"), Color("5e4128"), Color("8a6a3f"), Color("b98d4f"), Color("6b6b6b"),
]
const KIT: Array[Color] = [Color("4a5638"), Color("6b6046"), Color("2f3a44"), Color("3d3d3d")]
const BG := Color("1f2a33")


static func make(seed: int, grayscale: bool = false) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(BG)
	var skin: Color = SKIN[rng.randi() % SKIN.size()]
	var hair: Color = HAIR[rng.randi() % HAIR.size()]
	var kit: Color = KIT[rng.randi() % KIT.size()]
	var hair_style: int = rng.randi() % 4      # 0 buzz, 1 short, 2 bald, 3 cap
	var beard: bool = rng.randf() < 0.45
	var face_w: int = rng.randi_range(4, 5)    # half-width
	var shade: Color = skin.darkened(0.18)

	# Shoulders / plate carrier.
	for y in range(18, SIZE):
		var half: int = 6 + (y - 18)
		for x in range(12 - half, 12 + half):
			_px(img, x, y, kit)
	for y in range(19, SIZE):
		_px(img, 9, y, kit.darkened(0.3))
		_px(img, 14, y, kit.darkened(0.3))
	# Neck.
	for y in range(15, 19):
		for x in range(10, 14):
			_px(img, x, y, shade)
	# Head (rounded box).
	for y in range(5, 17):
		var inset: int = 1 if (y == 5 or y == 16) else 0
		for x in range(12 - face_w + inset, 12 + face_w + inset):
			_px(img, x, y, skin)
	# Ears.
	_px(img, 12 - face_w - 1, 10, shade)
	_px(img, 12 + face_w, 10, shade)
	# Hair / cap.
	match hair_style:
		0:
			for x in range(12 - face_w, 12 + face_w):
				_px(img, x, 5, hair)
		1:
			for y in range(4, 7):
				for x in range(12 - face_w, 12 + face_w):
					_px(img, x, y, hair)
			_px(img, 12 - face_w, 7, hair)
			_px(img, 12 + face_w - 1, 7, hair)
		3:
			for y in range(3, 7):
				for x in range(12 - face_w - 1, 12 + face_w + 1):
					_px(img, x, y, kit.darkened(0.15))
			for x in range(12 - face_w - 1, 12 + face_w + 3):
				_px(img, x, 7, kit.darkened(0.35))
	# Eyes, brows, mouth.
	var eye := Color("1a1a1a")
	_px(img, 10, 10, eye)
	_px(img, 13, 10, eye)
	_px(img, 10, 9, hair.darkened(0.2))
	_px(img, 13, 9, hair.darkened(0.2))
	_px(img, 11, 12, shade)
	for x in range(10, 14):
		_px(img, x, 14, skin.darkened(0.35))
	if beard:
		for y in range(13, 17):
			for x in range(12 - face_w + 1, 12 + face_w - 1):
				if y != 14 or x < 10 or x > 13:
					_px(img, x, y, hair)
	if grayscale:
		for y in SIZE:
			for x in SIZE:
				var c: Color = img.get_pixel(x, y)
				var g: float = c.get_luminance() * 0.8
				img.set_pixel(x, y, Color(g, g, g))
	return ImageTexture.create_from_image(img)


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < SIZE and y < SIZE:
		img.set_pixel(x, y, c)
