extends SceneTree
## Où marchent les piétons : quatre cadrages rapprochés, TOUS les créneaux
## allumés — on juge le tracé, pas la foule.
## Godot --path Godot --script res://outils/apercu_pietons.gd [-- --suffixe=avant]

const VUES := [
	["1 · Carrefour de quatre boulevards", Vector2(75.75, -304.0)],
	["2 · Trois boulevards et une rue", Vector2(-275.5, -317.5)],
	["3 · Boulevard et rue, rive droite", Vector2(243.25, 170.5)],
	["4 · Ruelle sans trottoir", 40],
]


func _initialize() -> void:
	call_deferred("filmer")


func filmer() -> void:
	var suffixe := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--suffixe="):
			suffixe = "_" + a.get_slice("=", 1)
	var jeu = load("res://maquette.tscn").instantiate()
	root.add_child(jeu)
	jeu.vitesse = 0.0
	jeu.mois = 0.0
	jeu.interface.hide()
	jeu.moniteur_performances.hide()
	var t = jeu.trafic
	var bandeau := CanvasLayer.new()
	root.add_child(bandeau)
	var legende := Label.new()
	legende.position = Vector2(24, 18)
	legende.add_theme_font_size_override("font_size", 28)
	legende.add_theme_color_override("font_shadow_color", Color.BLACK)
	legende.add_theme_constant_override("shadow_offset_x", 2)
	legende.add_theme_constant_override("shadow_offset_y", 2)
	bandeau.add_child(legende)
	var dossier := ProjectSettings.globalize_path("res://../QGIS/rendus/")
	for k in VUES.size():
		var cible = VUES[k][1]
		if cible is int:
			var axe: Array = jeu.donnees["couloirs"][str(cible)][1][0]
			var m := axe.size() / 2
			cible = Vector2(float(axe[m - m % 2]), float(axe[m - m % 2 + 1]))
		jeu.pivot.viser(cible, 42.0)
		jeu.pivot.caler(20.0, 58.0)
		await process_frame
		await process_frame
		# Tous les créneaux, quelle que soit la foule : c'est le TRACÉ qu'on juge.
		for fam in [t._pieds]:
			for i in fam.t.size():
				fam.mm.set_instance_transform(i, fam.t[i])
		legende.text = VUES[k][0]
		await RenderingServer.frame_post_draw
		await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		var chemin := dossier + "pietons_%d%s.png" % [k + 1, suffixe]
		if img.save_png(chemin) != OK:
			push_error("Capture impossible : " + chemin)
			quit(1)
			return
		print("  " + chemin)
	quit()
