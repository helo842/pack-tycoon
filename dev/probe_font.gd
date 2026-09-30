extends Node

# Vuelca las cajas de los hijos de la tarjeta de revelado, para ver que se pisa
# con que. La captura del juego sale con "NOTA PSA" y "VALOR" cortados, pero una
# Label sola con la misma fuente y la misma caja se ve bien (esto se comprobo
# antes), asi que lo que las tapa tiene que ser OTRO nodo.
#
#   DISPLAY=:1 godot --path . --display-driver x11 --rendering-driver opengl3 \
#       res://dev/ProbeFont.tscn

const REVEAL_SCENE := preload("res://scenes/RevealCard.tscn")


func _ready() -> void:
	var card := REVEAL_SCENE.instantiate() as RevealCard
	card.show_item({
		"name": "CARTA EDICION LIMITADA", "art": "loot_card_edited_psa10",
		"rarity": "epic", "grade": 10, "value": 4200,
		"condition": LootDB.condition_for_grade(10),
	})
	add_child(card)
	await get_tree().process_frame
	await get_tree().process_frame

	print("--- hijos de la tarjeta, en orden de dibujo ---")
	for c in card.get_children():
		_dump(c, 0)
	print("")
	print("--- los nietos (que es lo que se ve) ---")
	_vijos(card)
	get_tree().quit()


func _dump(c: Node, depth: int) -> void:
	var pad := "  ".repeat(depth)
	if c is Control:
		var ct := c as Control
		print("%s%-22s pos %s  size %s" % [pad, ct.get_class(), str(ct.position),
				str(ct.size)])
	else:
		print("%s%s" % [pad, c.get_class()])
	for k in c.get_children():
		_dump(k, depth + 1)


func _vijos(n: Node) -> void:
	for c in n.get_children():
		if c is Control and not (c as Control).get_children().is_empty():
			_vijos(c)
