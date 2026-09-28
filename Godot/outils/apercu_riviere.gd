extends SceneTree
## La couleur de l'Ilse au même cadrage : la décantation au fil des mois (89),
## puis l'état limpide, qui n'a pas encore de déclencheur dans le jeu.
## Temps arrêté, aucun chantier : d'un mois à l'autre, seule l'eau change.
## Godot --path Godot --script res://outils/apercu_riviere.gd

const Ville := preload("res://scripts/ville.gd")

const CIBLE := Vector2(274.46, -167.0)
const TAILLE := 190.0
const LACET := 20.0
const HAUTEUR := 40.0

## [nom, légende, mois de l'eau] — -1 : l'état limpide, posé à la main.
const ETATS := [
	["1_crue", "1 · Mois 0, chargée de la crue", 0.0],
	["2_mi_chemin", "2 · Mois 2, elle se décante", 2.0],
	["3_normale", "3 · Mois 4, l'eau normale", 4.0],
	["4_limpide", "4 · Limpide, on voit le fond (pas encore dans le jeu)", -1.0],
]


func _initialize() -> void:
	call_deferred("filmer")


func _eaux(n: Node, acc: Array) -> Array:
	if n is MeshInstance3D and n.material_override is ShaderMaterial \
			and n.material_override.shader.resource_path.ends_with("eau.gdshader"):
		acc.append(n.material_override)
	for c in n.get_children():
		_eaux(c, acc)
	return acc


func filmer() -> void:
	var jeu = load("res://maquette.tscn").instantiate()
	root.add_child(jeu)
	jeu.vitesse = 0.0
	jeu.mois = 0.0
	jeu.interface.hide()
	jeu.moniteur_performances.hide()
	var couche := CanvasLayer.new()
	root.add_child(couche)
	var label := Label.new()
	label.position = Vector2(28, 24)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color("213d36"))
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color("f5f5ec")
	fond.set_content_margin_all(10)
	label.add_theme_stylebox_override("normal", fond)
	couche.add_child(label)
	var eaux := _eaux(jeu.monde, [])
	if eaux.is_empty():
		push_error("aucune eau trouvée")
		quit(1)
		return
	var palette: Dictionary = jeu.donnees["palette"]
	jeu.pivot.viser(CIBLE, TAILLE)
	jeu.pivot.caler(LACET, HAUTEUR)
	for e in ETATS:
		# Par le mois du jeu, pas en posant le limon : une repeinture (pulsation
		# du trafic) le reposerait d'après `mois` entre deux captures.
		jeu.mois = e[2] if e[2] >= 0.0 else Ville.EAU_DECANTATION_MOIS
		if e[2] < 0.0:
			for m: ShaderMaterial in eaux:
				m.set_shader_parameter("trouble_bord", Color(palette["_eau_limpide_bord"]))
				m.set_shader_parameter("trouble_milieu", Color(palette["_eau_limpide_milieu"]))
				m.set_shader_parameter("limpidite", 1.0)
		jeu._rafraichir(true)
		print("  %s : mois %.0f, limon %.2f" % [e[0], jeu.mois, Ville.limon_eau(jeu.mois)])
		label.text = e[1]
		for i in 4:
			await process_frame
			await RenderingServer.frame_post_draw
		await jeu._capturer("riviere_" + e[0])
	quit()
