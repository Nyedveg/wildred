extends Area3D
func _on_Ladder_body_entered(body):
	if body.name == "player":
		body.ladder_array.append(self)
		body.current_state = body.State.LADDER

func _on_Ladder_body_exited(body):
	if body.name == "player":
		body.ladder_array.erase(self)
		if body.ladder_array.size() == 0:
			body.current_state = body.State.NORMAL
