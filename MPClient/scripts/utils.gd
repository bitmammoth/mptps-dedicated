extends Node

# This script is global. Here we declare some useful functions.

func align_with_normal(trans : Transform, normal : Vector3):
	trans.basis.x = Vector3.ZERO
	trans.basis.y = Vector3.ZERO
	trans.basis.z = normal.normalized()
	return trans
