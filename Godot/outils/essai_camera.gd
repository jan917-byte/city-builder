extends SceneTree
## Vérifie les vrais événements : clic, glissé, orbite, zoom et panneaux.
const Camera := preload("res://scripts/camera_axo.gd")
const Selection := preload("res://scripts/selection.gd")
var pivot
var selection
var clics := 0
var echecs := 0


func _initialize() -> void:
	call_deferred("executer")


func verifier(ok: bool, message: String) -> void:
	if not ok:
		echecs += 1
		push_error(message)


func bouton(pos: Vector2, presse: bool, ctrl := false, index := MOUSE_BUTTON_LEFT) -> void:
	var e := InputEventMouseButton.new()
	e.position = pos
	e.global_position = pos
	e.button_index = index
	e.pressed = presse
	e.ctrl_pressed = ctrl
	e.factor = 1.0
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if presse and index == MOUSE_BUTTON_LEFT else 0
	root.push_input(e, true)


func mouvement(pos: Vector2, delta: Vector2, presse := true) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.relative = delta
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if presse else 0
	root.push_input(e, true)


func stabiliser() -> void:
	for i in 100:
		pivot._process(1.0 / 60.0)


func executer() -> void:
	if "--ville" in OS.get_cmdline_user_args():
		await executer_ville()
		return
	root.size = Vector2i(1600, 900)
	pivot = Camera.new()
	root.add_child(pivot)
	pivot.set_process(false)
	selection = Selection.new()
	selection.camera = pivot.camera
	root.add_child(selection)
	pivot.clic_sol.connect(selection.choisir)
	selection.choisi.connect(func(_c, _f): clics += 1)
	var corps := StaticBody3D.new()
	corps.set_meta("fid", 123)
	corps.set_meta("couche", "i")
	var collision := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = Vector3(100, 2, 100)
	collision.shape = boite
	corps.add_child(collision)
	root.add_child(corps)
	await physics_frame
	await process_frame
	var centre := Vector2(800, 450)
	bouton(centre, true)
	verifier(clics == 0, "La sélection part avant le relâchement")
	bouton(centre, false)
	verifier(clics == 1 and selection.sel_fid == 123, "Le clic bref ne sélectionne pas le bâtiment visible")
	for dimensions in [Vector2i(1600, 900), Vector2i(1100, 700)]:
		root.size = dimensions
		await process_frame
		for angle in [6.0, 32.0, 90.0]:
			pivot.caler(137.0, angle)
			pivot.viser(Vector2.ZERO, 900.0)
			var depart := Vector2(dimensions) * Vector2(0.6, 0.4)
			var fin := depart + Vector2(84, 51)
			var sol: Vector3 = pivot._sol(depart)
			bouton(depart, true)
			mouvement(fin, fin - depart)
			verifier(pivot.camera.unproject_position(sol).distance_to(fin) < 0.1, "Le sol glisse sous le curseur : %s, %s°" % [dimensions, angle])
			bouton(fin, false)
			verifier(clics == 1, "Un déplacement sélectionne un objet")
			var ancre: Vector3 = pivot._sol(depart)
			var avant: float = pivot.taille
			bouton(depart, true, false, MOUSE_BUTTON_WHEEL_UP)
			pivot._process(1.0 / 60.0)
			verifier(pivot.taille < avant and pivot.taille > avant * 0.88, "Le zoom ne progresse pas en douceur")
			stabiliser()
			verifier(pivot.camera.unproject_position(ancre).distance_to(depart) < 0.1, "Le zoom perd le point visé")
	root.size = Vector2i(1600, 900)
	await process_frame
	pivot.caler(30, 32)
	var vise := Vector2(1000, 340)
	var sol_vise: Vector3 = pivot._sol(vise)
	bouton(vise, true, true)
	mouvement(vise + Vector2(90, -35), Vector2(90, -35))
	stabiliser()
	bouton(vise + Vector2(90, -35), false, true)
	verifier(pivot.camera.unproject_position(sol_vise).distance_to(vise) < 0.1, "L'orbite perd le point visé")
	verifier(clics == 1 and pivot.hauteur > 32, "Ctrl glissé sélectionne ou n'incline pas")
	pivot.caler(725, 40)
	pivot.remettre_nord()
	stabiliser()
	verifier(is_equal_approx(pivot.lacet, 720.0), "La boussole ne prend pas le chemin court vers le nord")
	pivot.basculer_dessus()
	stabiliser()
	verifier(is_equal_approx(pivot.hauteur, 90), "La vue de dessus n'est pas verticale")
	pivot.basculer_dessus()
	stabiliser()
	verifier(is_equal_approx(pivot.hauteur, 40), "Le retour 3D perd l'inclinaison")
	var panneau := Panel.new()
	panneau.position = Vector2(1200, 200)
	panneau.size = Vector2(300, 450)
	root.add_child(panneau)
	await process_frame
	var sur_ui := Vector2(1300, 350)
	mouvement(sur_ui, Vector2.ZERO, false)
	var avant_ui: Vector3 = pivot.position
	var taille_ui: float = pivot.taille
	bouton(sur_ui, true)
	mouvement(sur_ui + Vector2(20, 0), Vector2(20, 0))
	bouton(sur_ui, false)
	bouton(sur_ui, true, false, MOUSE_BUTTON_WHEEL_UP)
	stabiliser()
	verifier(pivot.position.is_equal_approx(avant_ui) and is_equal_approx(pivot.taille, taille_ui) and clics == 1, "Le panneau laisse passer un geste vers la ville")
	mouvement(centre, Vector2.ZERO, false)
	bouton(centre, true)
	mouvement(sur_ui, sur_ui - centre)
	bouton(sur_ui, false)
	var arret: Vector3 = pivot.position
	mouvement(centre, centre - sur_ui, false)
	verifier(pivot.position.is_equal_approx(arret) and clics == 1 and not pivot._appui, "Le relâchement sur un panneau laisse la carte accrochée")
	bouton(centre, true)
	pivot._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	mouvement(centre + Vector2(80, 0), Vector2(80, 0), false)
	verifier(not pivot._appui and pivot.position.is_equal_approx(arret), "La perte de focus laisse la carte accrochée")
	for limite in [40.0, 2400.0]:
		pivot.viser(Vector2.ZERO, limite)
		bouton(centre, true, false, MOUSE_BUTTON_WHEEL_UP if limite == 40 else MOUSE_BUTTON_WHEEL_DOWN)
		stabiliser()
		verifier(is_equal_approx(pivot.taille, limite), "Le zoom dépasse une limite")
	print("CAMÉRA : clic, ancrage, zoom, orbite, nord, dessus, panneaux et focus : %d échec(s)" % echecs)
	quit(1 if echecs else 0)


func executer_ville() -> void:
	var jeu = load("res://maquette.tscn").instantiate()
	root.add_child(jeu)
	current_scene = jeu
	jeu.vitesse = 0.0
	jeu.moniteur_performances.hide()
	pivot = jeu.pivot
	selection = jeu.selection
	pivot.set_process(false)
	selection.choisi.connect(func(_c, _f): clics += 1)
	jeu._viser_objet("i", 49, 200.0)
	await physics_frame
	await process_frame
	var cible := Vector2.ZERO
	for y in range(280, 600, 20):
		for x in range(550, 1100, 20):
			if selection.sonder(Vector2(x, y)) == ["i", 49]:
				cible = Vector2(x, y)
				break
		if cible != Vector2.ZERO:
			break
	verifier(cible != Vector2.ZERO, "Aucun point cliquable sur l'îlot 49")
	mouvement(cible, Vector2.ZERO, false)
	bouton(cible, true)
	bouton(cible, false)
	await process_frame
	verifier(clics == 1 and jeu.interface._fiche_fid == 49, "Le clic n'ouvre pas la bonne fiche dans la ville")
	bouton(cible, true)
	mouvement(cible + Vector2(100, 70), Vector2(100, 70))
	bouton(cible + Vector2(100, 70), false)
	verifier(clics == 1 and jeu.interface._fiche_fid == 49, "Un glissé change la fiche dans la ville")
	var ui = jeu.interface
	for b in [ui._camera_nord, ui._camera_dessus, ui._camera_dessus]:
		var p: Vector2 = b.get_global_rect().get_center()
		mouvement(p, Vector2.ZERO, false)
		bouton(p, true)
		bouton(p, false)
		stabiliser()
		await process_frame
	verifier(absf(wrapf(pivot.lacet, -180, 180)) < 0.01 and pivot.hauteur < 90 and clics == 1,
		"Les boutons de navigation ne répondent pas ou sélectionnent la ville")
	var legende := Label.new()
	legende.text = "① Attraper le sol     ② Ctrl : tourner     ③ Molette : zoom"
	legende.position = Vector2(455, 20)
	legende.add_theme_font_size_override("font_size", 20)
	legende.add_theme_color_override("font_color", Color(0.08, 0.18, 0.13))
	legende.add_theme_color_override("font_outline_color", Color(1, 1, 1))
	legende.add_theme_constant_override("outline_size", 5)
	legende.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(legende)
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	await jeu._capturer("camera_navigation")
	print("CAMÉRA DANS LA VILLE : sélection, glissé et boutons : %d échec(s)" % echecs)
	quit(1 if echecs else 0)
