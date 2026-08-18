class_name HCPad
extends RefCounted
## Cross-platform controller mapping for HighCraft.
## Uses Godot's SDL Game Controller database so the SAME semantic actions work on:
##   Xbox  ·  PlayStation  ·  Nintendo Switch  ·  generic USB pads
##
## Face-button layout (SDL standard — physical labels differ per brand):
##   A = bottom (Xbox A / PS Cross / Switch B)
##   B = right  (Xbox B / PS Circle / Switch A)
##   X = left   (Xbox X / PS Square / Switch Y)
##   Y = top    (Xbox Y / PS Triangle / Switch X)
##
## Gameplay actions (Minecraft-style):
##   attack / mine  → RT (trigger) + X + LMB
##   use / place    → LT (trigger) + RB + RMB
##   inventory      → Y
##   pause          → Start
##   accept         → A
##   cancel         → B

# ---- axes ----
const AXIS_MOVE_X := JOY_AXIS_LEFT_X
const AXIS_MOVE_Y := JOY_AXIS_LEFT_Y
const AXIS_LOOK_X := JOY_AXIS_RIGHT_X
const AXIS_LOOK_Y := JOY_AXIS_RIGHT_Y
const AXIS_LT := JOY_AXIS_TRIGGER_LEFT
const AXIS_RT := JOY_AXIS_TRIGGER_RIGHT

# ---- face / system ----
const BTN_ACCEPT := JOY_BUTTON_A          # confirm / jump
const BTN_CANCEL := JOY_BUTTON_B          # back / close
const BTN_ATTACK_ALT := JOY_BUTTON_X      # secondary attack
const BTN_INVENTORY := JOY_BUTTON_Y       # open inventory
const BTN_PAUSE := JOY_BUTTON_START
const BTN_SELECT := JOY_BUTTON_BACK       # chat / select
const BTN_LB := JOY_BUTTON_LEFT_SHOULDER  # hotbar prev / mine alt
const BTN_RB := JOY_BUTTON_RIGHT_SHOULDER # use / place / hotbar next
const BTN_L3 := JOY_BUTTON_LEFT_STICK     # sprint
const BTN_R3 := JOY_BUTTON_RIGHT_STICK    # perspective
const BTN_DPAD_UP := JOY_BUTTON_DPAD_UP
const BTN_DPAD_DOWN := JOY_BUTTON_DPAD_DOWN
const BTN_DPAD_LEFT := JOY_BUTTON_DPAD_LEFT
const BTN_DPAD_RIGHT := JOY_BUTTON_DPAD_RIGHT

const TRIGGER_THRESHOLD := 0.4
const STICK_DEADZONE := 0.2


static func device_ok(device: int) -> bool:
	return device >= 0


static func axis(device: int, axis: int) -> float:
	if device < 0:
		return 0.0
	return Input.get_joy_axis(device, axis)


static func pressed(device: int, button: int) -> bool:
	if device < 0:
		return false
	return Input.is_joy_button_pressed(device, button)


static func rt(device: int) -> float:
	return axis(device, AXIS_RT)


static func lt(device: int) -> float:
	return axis(device, AXIS_LT)


static func rt_held(device: int) -> bool:
	return rt(device) > TRIGGER_THRESHOLD


static func lt_held(device: int) -> bool:
	return lt(device) > TRIGGER_THRESHOLD


## Attack: RT edge or X (left face). Caller tracks previous RT/X for edges.
static func is_attack_button(button: int) -> bool:
	return button == BTN_ATTACK_ALT


## Use / interact / place: RB or (caller handles LT via axis).
static func is_use_button(button: int) -> bool:
	return button == BTN_RB


static func is_accept(button: int) -> bool:
	return button == BTN_ACCEPT


static func is_cancel(button: int) -> bool:
	return button == BTN_CANCEL


static func is_inventory(button: int) -> bool:
	return button == BTN_INVENTORY


static func is_pause(button: int) -> bool:
	return button == BTN_PAUSE


static func is_select(button: int) -> bool:
	return button == BTN_SELECT


static func is_lb(button: int) -> bool:
	return button == BTN_LB


static func is_rb(button: int) -> bool:
	return button == BTN_RB


static func is_dpad_up(button: int) -> bool:
	return button == BTN_DPAD_UP


static func is_dpad_down(button: int) -> bool:
	return button == BTN_DPAD_DOWN


static func is_dpad_left(button: int) -> bool:
	return button == BTN_DPAD_LEFT


static func is_dpad_right(button: int) -> bool:
	return button == BTN_DPAD_RIGHT


static func is_nav_axis_x(axis: int) -> bool:
	return axis == AXIS_MOVE_X


static func is_nav_axis_y(axis: int) -> bool:
	return axis == AXIS_MOVE_Y


## Stick vector with deadzone applied (length scaled).
static func stick(device: int, x_axis: int, y_axis: int, deadzone: float = STICK_DEADZONE) -> Vector2:
	var v = Vector2(axis(device, x_axis), axis(device, y_axis))
	if v.length() < deadzone:
		return Vector2.ZERO
	return v


static func move_stick(device: int, deadzone: float = STICK_DEADZONE) -> Vector2:
	return stick(device, AXIS_MOVE_X, AXIS_MOVE_Y, deadzone)


static func look_stick(device: int, deadzone: float = STICK_DEADZONE) -> Vector2:
	return stick(device, AXIS_LOOK_X, AXIS_LOOK_Y, deadzone)
