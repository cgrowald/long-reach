extends RefCounted
## Procedural pixel "photos" for the laptop (no image files needed).

static var _cache: Dictionary = {}


static func make(id: String) -> ImageTexture:
	if _cache.has(id):
		return _cache[id]
	var img := Image.create(120, 80, false, Image.FORMAT_RGBA8)
	match id:
		"dog":
			_dog(img)
		"lake":
			_lake(img)
		"checkpoint":
			_checkpoint(img)
		_:
			img.fill(Color(0.3, 0.3, 0.3))
	var tex := ImageTexture.create_from_image(img)
	_cache[id] = tex
	return tex


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h).intersection(Rect2i(0, 0, img.get_width(), img.get_height())), c)


static func _disc(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() and (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r:
				img.set_pixel(x, y, c)


static func _noise(img: Image, amount: float, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var n := rng.randf_range(-amount, amount)
			img.set_pixel(x, y, Color(clampf(c.r + n, 0, 1), clampf(c.g + n, 0, 1), clampf(c.b + n, 0, 1)))


static func _dog(img: Image) -> void:
	img.fill(Color(0.55, 0.72, 0.5))                      # lawn
	_rect(img, 0, 0, 120, 34, Color(0.62, 0.78, 0.9))    # sky
	_rect(img, 0, 30, 120, 6, Color(0.36, 0.5, 0.33))    # hedge
	var fur := Color(0.72, 0.5, 0.28)
	var dark := Color(0.45, 0.3, 0.16)
	_rect(img, 38, 44, 40, 18, fur)                       # body
	_rect(img, 40, 60, 6, 12, fur)                        # legs
	_rect(img, 70, 60, 6, 12, fur)
	_rect(img, 76, 40, 6, 6, fur)                         # tail
	_disc(img, 36, 40, 11, fur)                           # head
	_rect(img, 24, 36, 6, 14, dark)                       # ears
	_rect(img, 42, 32, 6, 14, dark)
	_rect(img, 22, 44, 8, 6, Color(0.85, 0.7, 0.5))       # snout
	_rect(img, 22, 44, 3, 3, Color(0.1, 0.1, 0.1))        # nose
	_rect(img, 31, 37, 3, 3, Color(0.1, 0.1, 0.1))        # eye
	_rect(img, 33, 52, 6, 3, Color(0.8, 0.15, 0.15))      # collar
	_disc(img, 90, 70, 4, Color(0.9, 0.85, 0.2))          # ball
	_noise(img, 0.03, 1)


static func _lake(img: Image) -> void:
	img.fill(Color(0.95, 0.7, 0.45))
	for y in 40:
		_rect(img, 0, y, 120, 1, Color(0.98, 0.75 - y * 0.006, 0.5 - y * 0.005))
	_disc(img, 82, 36, 9, Color(1.0, 0.88, 0.55))         # sun
	_rect(img, 0, 30, 120, 8, Color(0.3, 0.38, 0.42))     # far hills
	_rect(img, 0, 38, 120, 26, Color(0.35, 0.5, 0.62))    # water
	for i in 8:
		_rect(img, 60 + i * 3, 40 + i * 3, 10, 1, Color(1.0, 0.85, 0.55))
	_rect(img, 0, 64, 120, 16, Color(0.3, 0.26, 0.2))     # jetty / shore
	_rect(img, 40, 46, 5, 18, Color(0.1, 0.1, 0.12))      # two silhouettes
	_disc(img, 42, 44, 3, Color(0.1, 0.1, 0.12))
	_rect(img, 48, 47, 5, 17, Color(0.1, 0.1, 0.12))
	_disc(img, 50, 45, 3, Color(0.1, 0.1, 0.12))
	_noise(img, 0.025, 2)


static func _checkpoint(img: Image) -> void:
	img.fill(Color(0.55, 0.58, 0.6))                      # grey morning sky
	_rect(img, 0, 34, 120, 46, Color(0.3, 0.31, 0.32))    # road
	_rect(img, 0, 30, 120, 4, Color(0.42, 0.44, 0.45))    # railing
	for i in 12:
		_rect(img, i * 10, 22, 2, 10, Color(0.42, 0.44, 0.45))
	_rect(img, 10, 46, 70, 3, Color(0.85, 0.2, 0.2))      # barrier
	for i in 7:
		_rect(img, 10 + i * 10, 46, 5, 3, Color(0.95, 0.95, 0.95))
	_rect(img, 84, 18, 26, 30, Color(0.4, 0.42, 0.36))    # guard booth
	_rect(img, 88, 24, 18, 8, Color(0.65, 0.75, 0.8))
	for g in [[30, 52], [52, 54]]:                        # guards
		_rect(img, g[0], g[1], 6, 16, Color(0.24, 0.3, 0.2))
		_disc(img, g[0] + 3, g[1] - 3, 3, Color(0.75, 0.6, 0.5))
		_rect(img, g[0] + 5, g[1] + 3, 7, 2, Color(0.1, 0.1, 0.1))
	_rect(img, 60, 34, 30, 14, Color(0.6, 0.62, 0.64))    # grey van
	_rect(img, 82, 36, 7, 5, Color(0.3, 0.35, 0.4))
	_rect(img, 63, 46, 5, 4, Color(0.1, 0.1, 0.1))
	_rect(img, 82, 46, 5, 4, Color(0.1, 0.1, 0.1))
	for y in 80:                                          # rain streaks
		if y % 7 == 0:
			for x in range(y % 13, 120, 17):
				_rect(img, x, y, 1, 3, Color(0.75, 0.8, 0.85))
	_noise(img, 0.05, 3)
