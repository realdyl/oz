extends Node

## MeterService: Global resource tracking for Oz
## Tracks Brain, Heart, and Courage

signal meter_changed(type: String, value: float)

var meters = {
	"Brain": 100.0,
	"Heart": 100.0,
	"Courage": 100.0
}

var max_meters = {
	"Brain": 100.0,
	"Heart": 100.0,
	"Courage": 100.0
}

func get_meter(type: String) -> float:
	return meters.get(type, 0.0)

func spend_meter(type: String, amount: float) -> bool:
	if meters.has(type) and meters[type] >= amount:
		meters[type] -= amount
		meter_changed.emit(type, meters[type])
		return true
	return false

func regen_meter(type: String, amount: float, delta: float) -> void:
	if meters.has(type):
		meters[type] = min(meters[type] + amount * delta, max_meters[type])
		meter_changed.emit(type, meters[type])

func reset_meter(type: String) -> void:
	if meters.has(type):
		meters[type] = max_meters[type]
		meter_changed.emit(type, meters[type])
