@tool
extends EditorPlugin
## `icones/` porte un `.gdignore` (SVG lus en brut par `interface.gd`) : l'export le saute,
## même nommé dans `include_filter`. On y glisse les SVG à la main ; « _ » n'est pas lu.

var _export := ExportIcones.new()


func _enter_tree() -> void:
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)


class ExportIcones extends EditorExportPlugin:
	func _get_name() -> String:
		return "icones_export"

	func _export_begin(_features: PackedStringArray, _debug: bool, _path: String, _flags: int) -> void:
		for nom in DirAccess.get_files_at("res://icones"):
			if nom.ends_with(".svg") and not nom.begins_with("_"):
				var chemin := "res://icones/" + nom
				add_file(chemin, FileAccess.get_file_as_bytes(chemin), false)
