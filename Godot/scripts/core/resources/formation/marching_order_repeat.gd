## marching_order_repeat.gd
## Produces: a composite marching order that loops through sub-orders.
## Consumes: CDMarchingOrder child resources; nothing on write.
@tool
class_name MarchingOrderRepeat extends CDMarchingOrder

## total duration before the FormationDirector advances to the next top-level order
@export var duration: float = 10.0

## the sequence of sub-orders to loop through
@export var orders: Array[CDMarchingOrder] = []

## Return the total repeat duration.
func get_duration() -> float:
	return duration

## Return the absolute offset achieved at the given time.
func get_offset_at_time(time: float) -> Vector2:
	if orders.is_empty():
		return Vector2.ZERO

	## calculate the total duration and offset of ONE loop of the sub-orders
	var loop_duration := 0.0
	var loop_offset := Vector2.ZERO
	for sub_order in orders:
		loop_duration += sub_order.get_duration()
		loop_offset += sub_order.get_accumulated_offset()

	if loop_duration <= 0.0:
		return Vector2.ZERO

	## find out how many times we've looped, and how far into the current loop we are
	var loops_completed := int(time / loop_duration)
	var current_time_in_loop := fmod(time, loop_duration)

	## start with the accumulated offset from all fully completed loops
	var active_offset := loop_offset * loops_completed

	## evaluate the active sub-order in the current loop
	var elapsed_in_loop := 0.0
	for sub_order in orders:
		var sub_duration := sub_order.get_duration()
		if current_time_in_loop <= elapsed_in_loop + sub_duration:
			var time_in_sub_order := current_time_in_loop - elapsed_in_loop
			active_offset += sub_order.get_offset_at_time(time_in_sub_order)
			break
		else:
			## sub-order is fully completed in this loop, add its final offset
			active_offset += sub_order.get_accumulated_offset()
			elapsed_in_loop += sub_duration

	return active_offset

## Return the final total offset when this repeat order completes.
func get_accumulated_offset() -> Vector2:
	return get_offset_at_time(duration)

## Return breathing data from the active sub-order at the given time.
func get_breathing_values(time: float) -> Dictionary:
	if orders.is_empty():
		return { "spacing_scale": 1.0, "offset_scale": 1.0 }

	var loop_duration := 0.0
	for sub_order in orders:
		loop_duration += sub_order.get_duration()

	if loop_duration <= 0.0:
		return { "spacing_scale": 1.0, "offset_scale": 1.0 }

	var current_time_in_loop := fmod(time, loop_duration)

	var elapsed_in_loop := 0.0
	for sub_order in orders:
		var sub_duration := sub_order.get_duration()
		if current_time_in_loop <= elapsed_in_loop + sub_duration:
			var time_in_sub_order := current_time_in_loop - elapsed_in_loop
			return sub_order.get_breathing_values(time_in_sub_order)
		elapsed_in_loop += sub_duration

	return { "spacing_scale": 1.0, "offset_scale": 1.0 }