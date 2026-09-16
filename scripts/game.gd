extends Node
## Singleton global (autoload "Game").
## Contient l'etat de la partie, l'economie de ferraille et les ameliorations
## achetees. Enregistre aussi les touches au demarrage : le jeu n'a donc pas
## besoin d'une InputMap pre-configuree dans l'editeur.

enum State { INTERMISSION, WAVE, GAME_OVER }

signal scrap_changed(total: int)
signal state_changed(new_state: State)
signal notice(text: String)

## Touches par defaut. physical_keycode = position physique de la touche,
## donc ca marche aussi bien en AZERTY qu'en QWERTY (ZQSD sur un clavier FR).
const KEY_BINDINGS := {
	"move_forward": KEY_W,
	"move_back": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"jump": KEY_SPACE,
	"sprint": KEY_SHIFT,
	"reload": KEY_R,
	"shop": KEY_TAB,
	"pause": KEY_ESCAPE,
	"restart": KEY_ENTER,
}

var scrap: int = 0
var state: State = State.INTERMISSION
var wave: int = 0

# Ameliorations permanentes achetees dans la boutique.
var damage_multiplier: float = 1.0
var bonus_magazine: int = 0
var turrets_built: int = 0

# --------------------------------------------------------------- options
## Preferences utilisateur (menu Options) : persistantes entre les parties
## et entre les lancements du jeu, contrairement au reste de cet etat.
const SETTINGS_PATH := "user://settings.cfg"
const MIN_MOUSE_SENSITIVITY := 0.2
const MAX_MOUSE_SENSITIVITY := 3.0

var mouse_sensitivity: float = 1.0
var fullscreen: bool = false

func _enter_tree() -> void:
	_register_inputs()
	_load_settings()

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	mouse_sensitivity = clampf(
		config.get_value("options", "mouse_sensitivity", 1.0),
		MIN_MOUSE_SENSITIVITY,
		MAX_MOUSE_SENSITIVITY
	)
	fullscreen = config.get_value("options", "fullscreen", false)
	_apply_fullscreen()

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("options", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("options", "fullscreen", fullscreen)
	config.save(SETTINGS_PATH)

func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, MIN_MOUSE_SENSITIVITY, MAX_MOUSE_SENSITIVITY)

func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply_fullscreen()
	save_settings()

func _apply_fullscreen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)

func _register_inputs() -> void:
	for action_name in KEY_BINDINGS:
		if InputMap.has_action(action_name):
			continue
		InputMap.add_action(action_name)
		var key_event := InputEventKey.new()
		key_event.physical_keycode = KEY_BINDINGS[action_name]
		InputMap.action_add_event(action_name, key_event)

	if not InputMap.has_action("shoot"):
		InputMap.add_action("shoot")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("shoot", click)

## Remet tout a zero pour une nouvelle partie.
func reset() -> void:
	scrap = 0
	wave = 0
	state = State.INTERMISSION
	damage_multiplier = 1.0
	bonus_magazine = 0
	turrets_built = 0

func add_scrap(amount: int) -> void:
	scrap += amount
	scrap_changed.emit(scrap)

## Tente de depenser. Renvoie false (et ne depense rien) si le compte est court.
func spend_scrap(amount: int) -> bool:
	if scrap < amount:
		notice.emit("Pas assez de ferraille")
		return false
	scrap -= amount
	scrap_changed.emit(scrap)
	return true

func set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(state)

func announce(text: String) -> void:
	notice.emit(text)
