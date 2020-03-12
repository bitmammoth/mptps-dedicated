extends Node

func delta_angle(current : float, target : float):
	var delta : float = repeat((target - current), 360.0)
	if delta > 180.0:
		delta -= 360.0
	return delta

func repeat(t : float, length : float):
	return clamp(t - floor(t / length) * length, 0.0, length)
