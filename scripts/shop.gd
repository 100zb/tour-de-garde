extends Control
class_name Shop
## Boutique d'ameliorations (touche Tab). Elle affiche les articles et signale
## l'achat ; c'est main.gd qui applique reellement l'effet.
## Le jeu ne se met PAS en pause : ouvrir la boutique pendant une vague est
## risque, pendant l'entracte c'est tranquille.

signal purchase_requested(id: String)

const ITEMS := [
	{
		"id": "turret",
		"name": "Tourelle automatique",
		"description": "Se pose sur un socle libre autour du relais. Tire toute seule.",
		"cost": 150,
		"scaling": 1.55,
	},
	{
		"id": "damage",
		"name": "Degats +20%",
		"description": "Ameliore ton arme. Cumulable.",
		"cost": 120,
		"scaling": 1.5,
	},
	{
		"id": "repair",
		"name": "Reparer le relais",
		"description": "Rend 200 points de structure au relais.",
		"cost": 90,
		"scaling": 1.2,
	},
	{
		"id": "magazine",
		"name": "Chargeur +10",
		"description": "Dix balles de plus avant de recharger. Cumulable.",
		"cost": 80,
		"scaling": 1.4,
	},
	{
		"id": "medkit",
		"name": "Trousse de soin",
		"description": "Remet ta sante au maximum immediatement.",
		"cost": 60,
		"scaling": 1.1,
	},
]

var purchase_counts := {}

var _scrap_label: Label
var _buttons := {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build()
	Game.scrap_changed.connect(func(_total: int) -> void: refresh())

func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.03, 0.03, 0.05, 0.75)
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# CenterContainer : le panneau reste centre a toutes les resolutions.
	var centerer := CenterContainer.new()
	add_child(centerer)
	centerer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(660, 0)
	panel.add_theme_stylebox_override("panel", _panel_style())
	centerer.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var title := Label.new()
	title.text = "ATELIER"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
	column.add_child(title)

	_scrap_label = Label.new()
	_scrap_label.add_theme_font_size_override("font_size", 17)
	column.add_child(_scrap_label)

	column.add_child(HSeparator.new())

	for item in ITEMS:
		column.add_child(_build_row(item))

	column.add_child(HSeparator.new())

	var hint := Label.new()
	hint.text = "Tab : fermer    Entree : lancer la vague suivante tout de suite"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	column.add_child(hint)

func _build_row(item: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.add_theme_constant_override("separation", 0)

	var name_label := Label.new()
	name_label.text = item["name"]
	name_label.add_theme_font_size_override("font_size", 18)
	text_column.add_child(name_label)

	var description := Label.new()
	description.text = item["description"]
	description.add_theme_font_size_override("font_size", 13)
	description.add_theme_color_override("font_color", Color(0.62, 0.62, 0.68))
	text_column.add_child(description)

	row.add_child(text_column)

	var button := Button.new()
	button.custom_minimum_size = Vector2(150, 44)
	var item_id: String = item["id"]
	button.pressed.connect(func() -> void: purchase_requested.emit(item_id))
	_buttons[item_id] = button
	row.add_child(button)

	return row

func cost_of(id: String) -> int:
	for item in ITEMS:
		if item["id"] == id:
			var bought: int = purchase_counts.get(id, 0)
			return int(round(float(item["cost"]) * pow(item["scaling"], bought)))
	return 0

func register_purchase(id: String) -> void:
	purchase_counts[id] = int(purchase_counts.get(id, 0)) + 1
	refresh()

func refresh() -> void:
	if _scrap_label == null:
		return
	_scrap_label.text = "Ferraille disponible : %d" % Game.scrap
	for id in _buttons:
		var price := cost_of(id)
		var button: Button = _buttons[id]
		button.text = "%d ferraille" % price
		button.disabled = Game.scrap < price

func open() -> void:
	visible = true
	refresh()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close() -> void:
	visible = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.09, 0.12, 0.97)
	style.border_color = Color(1.0, 0.72, 0.3, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(24)
	return style
