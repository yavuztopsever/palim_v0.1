extends Node3D

@export var cutaway_mode: int = 1  # 0 = walls up, 1 = cutaway, 2 = walls down

var walls_parent: Node3D
var north_wall: CSGBox3D
var south_wall: CSGBox3D
var east_wall: CSGBox3D
var west_wall: CSGBox3D

func _ready():
	# Wait for scene to be ready
	await get_tree().process_frame

	# Find walls using relative paths from this node's parent
	var main = get_parent()
	if main:
		walls_parent = main.get_node_or_null("Walls")
		if walls_parent:
			north_wall = walls_parent.get_node_or_null("NorthWall")
			south_wall = walls_parent.get_node_or_null("SouthWall")
			east_wall = walls_parent.get_node_or_null("EastWall")
			west_wall = walls_parent.get_node_or_null("WestWall")

			print("Walls found: North=", north_wall != null, " South=", south_wall != null,
				  " East=", east_wall != null, " West=", west_wall != null)

			# Apply initial mode
			apply_cutaway_mode()
		else:
			print("ERROR: Walls node not found!")
	else:
		print("ERROR: Parent node not found!")

func _input(event):
	if event.is_action_pressed("toggle_walls"):
		cycle_cutaway_mode()

func cycle_cutaway_mode():
	cutaway_mode = (cutaway_mode + 1) % 3
	apply_cutaway_mode()

	match cutaway_mode:
		0:
			print("Wall mode: Walls Up (all visible)")
		1:
			print("Wall mode: Cutaway (south/east hidden)")
		2:
			print("Wall mode: Walls Down (all hidden)")

func apply_cutaway_mode():
	if not walls_parent:
		return

	match cutaway_mode:
		0:  # Walls up - all visible
			set_wall_visibility(north_wall, true)
			set_wall_visibility(south_wall, true)
			set_wall_visibility(east_wall, true)
			set_wall_visibility(west_wall, true)
		1:  # Cutaway - hide south and east
			set_wall_visibility(north_wall, true)
			set_wall_visibility(south_wall, false)
			set_wall_visibility(east_wall, false)
			set_wall_visibility(west_wall, true)
		2:  # Walls down - all hidden
			set_wall_visibility(north_wall, false)
			set_wall_visibility(south_wall, false)
			set_wall_visibility(east_wall, false)
			set_wall_visibility(west_wall, false)

func set_wall_visibility(wall: CSGBox3D, visible: bool):
	if wall:
		wall.visible = visible