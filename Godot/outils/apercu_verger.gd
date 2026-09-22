extends SceneTree
## 🌳 LE VERGER, trois états au même cadrage — la règle du 2026-09-17 se juge
## ici : personne ne roule dans la boue, et un quartier déblayé à moitié ne
## retrouve pas son trafic.
## Godot --path Godot --script res://outils/apercu_verger.gd

var jeu
var _verger: Array[int] = []


func _initialize() -> void:
	call_deferred("capturer")


func _compter() -> Array:
	var roulantes := 0
	var rues := 0
	for fid in _verger:
		var n: int = jeu.trafic.voitures_visibles_sur(fid)[0]
		roulantes += n
		if n > 0:
			rues += 1
	return [roulantes, rues]


func _poser(nom: String, legende: String) -> void:
	jeu.trafic._maj_roulantes(jeu.mois, true)
	for f in 6:
		await process_frame
		await RenderingServer.frame_post_draw
	var c := _compter()
	var presentes := 0
	for k in jeu.trafic._roulantes.size():
		var e: int = (jeu.trafic._roulantes[k] as Dictionary)["arc"]
		if _verger.has(jeu.trafic._arc_fid[e]):
			presentes += 1
	print("  %s : %d voitures vues sur %d dans le quartier, %d des %d rues"
		% [legende, c[0], presentes, c[1], _verger.size()])
	await jeu._capturer(nom)


func capturer() -> void:
	root.size = Vector2i(1500, 1000)
	jeu = load("res://maquette.tscn").instantiate()
	root.add_child(jeu)
	jeu.vitesse = 0.0
	jeu.interface.hide()
	jeu.moniteur_performances.hide()
	if jeu.ouverture != null:
		jeu.ouverture.hide()
		jeu.ouverture._reperes.hide()
	jeu.set_process(false)
	jeu.horloge_trafic.stop()
	jeu.paysage.mat_nuages.set_shader_parameter("horloge", 0.0)
	for fid in jeu.ville.routes:
		if jeu.ville.au_verger(fid):
			_verger.append(int(fid))
	_verger.sort()
	# Le faubourg vu du sud-est, assez haut pour tenir le quartier entier.
	var centre: Array = jeu.donnees.meta.centre
	jeu.pivot.viser(Vector2(500640 - centre[0], centre[1] - 5600530), 330.0)
	jeu.pivot.caler(25.0, 62.0)

	print("LE VERGER — %d tronçons portent du limon" % _verger.size())
	print("  fiche de la rue %d : %s" % [_verger[0], _etat_fiche(_verger[0])])
	jeu.interface.hide()
	await _poser("verger_01_sous_la_boue", "1 · sous la boue")

	# 🛠️ Mode auteur : le déblaiement est livré au clic, sinon juger demanderait
	# d'attendre les mois de chantier.
	jeu.ville.livraison_immediate = true
	# La plus longue du quartier : sur une rue courte, un cinquième de rien
	# ne se verrait pas.
	var longue: int = _verger[0]
	for fid in _verger:
		if jeu.ville.base("r", fid, "longueur_m") \
				> jeu.ville.base("r", longue, "longueur_m"):
			longue = fid
	jeu.ville.reparer("r", longue, 0.0)
	await _poser("verger_02_une_rue", "2 · une rue déblayée, le verger non")
	for fid in _verger:
		jeu.ville.reparer("r", fid, 0.0)
	print("  fiche de la rue %d : %s" % [_verger[0], _etat_fiche(_verger[0])])
	jeu.interface.hide()
	jeu.trafic.avancer(0.0)
	await _poser("verger_03_deblaye", "3 · verger déblayé")
	quit()


func _etat_fiche(fid: int) -> String:
	jeu.interface.montrer("r", fid, false)
	return str((jeu.interface._rue_valeurs["etat"] as Label).text) + " · trafic " 		+ str((jeu.interface._rue_valeurs["charge"] as Label).text)
