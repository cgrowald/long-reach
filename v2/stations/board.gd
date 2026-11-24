extends "res://v2/stations/station.gd"
## The TONIGHT board on the wall by the roller door (docs/CONNECTED_LOOP.md): the same cards as the corner board,
## big. Click a card: you step back and the view turns to that station, which glows until you use it.
## B3 puts the cards on the 3D board itself.

const TonightBoard := preload("res://v2/ui/tonight_board.gd")

var big: Control


func build() -> void:
	big = TonightBoard.new()
	big.game = game
	add_child(big)
	big.refresh()
	var k := minf(2.2, (size.y - 60.0) / maxf(big.size.y, 1.0))
	big.scale = Vector2(k, k)
	big.position = ((size - big.size * k) * 0.5).floor()
	big.go.connect(_on_go)
	var back_b := Kit.button("Back", close, game)
	add_child(back_b)
	back_b.position = Vector2(size.x - 52, size.y - 26)


func _on_go(id: String) -> void:
	garage.close_station()
	garage.guide(id)
