## CDMarchingOrder
## Encodes a single formation movement command — step, breathe, or pause
## Used by FormationDirector to execute ordered movement sequences

class_name CDMarchingOrder extends Resource

enum Type { STEP, BREATHE, PAUSE }

## --- exports ---

## type of movement command
@export var type: Type = Type.STEP

## duration of this order in seconds
@export var duration: float = 2.0

@export_group("Step")
## distance to shift the formation (positive = right, negative = left)
@export var distance: float = 16.0
## optional scaler for step interval — replaces fixed duration when assigned
@export var speed_scaler: CDScaler

@export_group("Breathe")
## amplitude of spacing expansion (1.0 = spacing doubles at peak)
@export var amplitude: float = 0.5
## time to expand (seconds)
@export var expand_time: float = 1.0
## time to hold at peak (seconds)
@export var hold_time: float = 0.5
## time to contract back (seconds)
@export var contract_time: float = 1.0