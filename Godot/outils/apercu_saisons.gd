extends SceneTree
## ❄️🍂 LES SAISONS, à juger d'un coup d'œil : une rue plantée et la vallée à
## plusieurs dates d'une même partie (graine fixe), puis une planche numérotée.
## Godot --path Godot --script res://outils/apercu_saisons.gd -- [--graine=7]

const Saison := preload("res://scripts/saison.gd")

var jeu


func _initialize() -> void:
	call_deferred("capturer")


func capturer() -> void:
	var graine := 7
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--graine="):
			graine = int(a.split("=")[1])
	root.size = Vector2i(1600, 1000)
	jeu = load("res://maquette.tscn").instantiate()
	root.add_child(jeu)
	jeu.vitesse = 0.0
	jeu.interface.hide()
	jeu.moniteur_performances.hide()
	if jeu.ouverture != null:
		jeu.ouverture.hide()
		jeu.ouverture._reperes.hide()
	jeu.set_process(false)
	jeu.paysage.mat_nuages.set_shader_parameter("horloge", 0.0)
	(jeu.flocons.material as ShaderMaterial).set_shader_parameter("horloge", 3.0)
	var s := Saison.new(graine)
	jeu.changer_saison(s)
	await process_frame
	# Les alignements tous en terre : sinon une rue sans plantation n'en montre aucun.
	for a in jeu._arbres_slots:
		a[6] = -1.0
	jeu._arbres_compte = -1

	# La neige de l'an 1, en trois temps : collines, toits, toute posée.
	var e: Array = s.neige_hiver(1)
	var arrivee := float(e[0]) + Saison.ARRIVEE_MOIS * 0.35
	var toits := float(e[0]) + Saison.ARRIVEE_MOIS * 0.6
	var neige := (float(e[0]) + Saison.ARRIVEE_MOIS + float(e[1])) * 0.5
	var janvier_1 := _janvier_sans_neige(s, 1)
	var janvier_18 := _janvier_sans_neige(s, 18)
	# [nom, mois, légende]
	var dates := [
		["1_mars", 0.0, "1er mars, an 1"],
		["2_avril", 1.35, "mi-avril"],
		["3_juillet", 4.5, "juillet"],
		["4_octobre", 7.75, "fin octobre"],
		["5_novembre", 8.85, "fin novembre"],
		["6_arrivee", arrivee, "la neige arrive"],
		["7_toits", toits, "les toits d'abord"],
		["8_neige", neige, "la neige de l'an 1"],
	]
	var vues := [
		["rue", ["i", 22], 170.0, 30.0, 38.0],
		["pavillons", ["i", 11], 130.0, 30.0, 40.0],
	]
	for v in vues:
		for d in dates:
			await _vue(v, d[1])
			await jeu._capturer("saisons_%s_%s" % [v[0], d[0]])
	for d in [["a_juillet", 4.5], ["b_janvier_an1", janvier_1], ["c_janvier_an18", janvier_18],
			["d_arrivee", arrivee], ["e_toits", toits]]:
		await _vue(["vallee", Vector2.ZERO, 1100.0, 30.0, 32.0], d[1])
		await jeu._capturer("saisons_vallee_%s" % d[0])
		# Les collines de l'ouest, les plus hautes qu'on voie avant la brume du bord.
		await _vue(["collines", Vector2(-1050.0, -450.0), 800.0, 30.0, 28.0], d[1])
		await jeu._capturer("saisons_collines_%s" % d[0])
	print("Saisons : graine %d, neige de l'an 1 du mois %.2f au mois %.2f, janviers sans neige aux mois %.2f et %.2f"
		% [graine, e[0], e[1], janvier_1, janvier_18])
	print("  ligne de neige des collines : %.0f m en janvier de l'an 1, %.0f m en janvier de l'an 18"
		% [s.ligne_collines(janvier_1), s.ligne_collines(janvier_18)])
	quit()


func _vue(v: Array, mois: float) -> void:
	jeu.mois = mois
	var cible = v[1]
	if cible is Array:
		jeu._viser_objet(cible[0], int(cible[1]), float(v[2]))
	else:
		jeu.pivot.viser(cible, float(v[2]))
	jeu.pivot.caler(float(v[3]), float(v[4]))
	jeu._dernier_peint = -1.0
	jeu._rafraichir(true)
	for f in 6:
		await process_frame
		await RenderingServer.frame_post_draw


## Le jour sans neige de l'hiver de l'an `an` le plus proche de la mi-janvier : on y lit les collines seules.
func _janvier_sans_neige(s, an: int) -> float:
	var janvier := 12.0 * an - 1.5
	for k in 60:
		for t in [janvier - k * 0.025, janvier + k * 0.025]:
			if s.avancee(t) == 0.0:
				return t
	return janvier
