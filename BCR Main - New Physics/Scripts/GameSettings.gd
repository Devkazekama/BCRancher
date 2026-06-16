extends Node

# This signal allows us to broadcast changes to the whole game instantly.
# Your UI slider will eventually trigger this.
signal taskbar_offset_changed(new_offset: float)

# Default offset is 40.0. 
# The setter function ensures that any time a script changes this number, 
# the signal is automatically fired off to notify the rest of the game.
var taskbar_offset: float = -0.0:
	set(value):
		taskbar_offset = value
		taskbar_offset_changed.emit(taskbar_offset)
