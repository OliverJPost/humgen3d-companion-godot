@tool
extends EditorPlugin
# Human Generator 3D Companion for Godot: registers the post-import step that
# sets up characters exported from Human Generator for Blender.

var _post_import: EditorScenePostImportPlugin


func _enter_tree() -> void:
	_post_import = preload("res://addons/humgen3d_companion/post_import.gd").new()
	add_scene_post_import_plugin(_post_import)


func _exit_tree() -> void:
	remove_scene_post_import_plugin(_post_import)
	_post_import = null
