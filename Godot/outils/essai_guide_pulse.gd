extends SceneTree
## --script res://outils/essai_guide_pulse.gd -- --ouverture
## 💫 Le guide respire au clic hors consigne et après 20 s sans progrès (auteur, 2026-10-28).
const Maquette := preload("res://scripts/maquette.gd")
var jeu
var echecs := 0


func _initialize() -> void:
	call_deferred("executer")


func verifier(ok: bool, quoi: String) -> void:
	print("%s · %s" % ["OK" if ok else "ÉCHEC", quoi])
	if not ok:
		echecs += 1
		push_error(quoi)


func respire() -> bool:
	return jeu.ouverture._pulse != null and jeu.ouverture._pulse.is_running()


func laisser_finir() -> void:
	while respire():
		await process_frame


func executer() -> void:
	root.size = Vector2i(1600, 900)
	jeu = Maquette.new()
	root.add_child(jeu)
	jeu.set_process(false)
	jeu.horloge_trafic.stop()
	jeu.moniteur_performances.hide()
	var o = jeu.ouverture
	jeu._sur_mode(false)
	jeu.recit.commencer()
	jeu.recit.terminer()
	jeu._sur_vitesse(0.0)
	o.actualiser(true)
	verifier(o.etape == "reloger" and o.parle(), "Le guide parle au relogement")

	# B : un îlot bâti ne reçoit pas de camp, le guide respire.
	var bati := -1
	for fid in jeu.ville.ilots:
		if not jeu.ville.est_champ(int(fid)) and not o.autorise("i", int(fid)):
			bati = int(fid)
			break
	jeu._sur_choix("i", bati)
	verifier(respire(), "Un îlot bâti cliqué au relogement : le guide respire")
	await laisser_finir()
	verifier(o.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(o.modulate.r, 1.0),
		"Après la respiration, le guide revient à sa taille et à sa teinte")

	# Le champ demandé ne fait rien respirer.
	jeu.interface._fermer_fiche()
	jeu._sur_choix("i", int(o._champs_accessibles()[0]))
	verifier(not respire(), "Un champ atteignable cliqué : le guide reste calme")

	# D : 20 s sans que la consigne change.
	jeu.interface._fermer_fiche()
	o.actualiser(true)
	o._consigne_ms = Time.get_ticks_msec() - o.PULSE_INACTIF_MS + 500
	o.actualiser()
	verifier(not respire(), "Avant 20 s, rien")
	o._consigne_ms = Time.get_ticks_msec() - o.PULSE_INACTIF_MS - 10
	o.actualiser()
	verifier(respire(), "20 s sans progrès : le guide respire")
	await laisser_finir()
	o.actualiser()
	verifier(not respire(), "Puis il attend 20 s de plus")

	# Réduit par « − » : c'est la tuile Guide qui respire.
	o.ouvert = false
	o.actualiser(true)
	verifier(o._cible_pulse() == jeu.interface._debut, "Guide réduit : la tuile Guide respire à sa place")
	o.pulser()
	await laisser_finir()
	verifier(jeu.interface._debut.scale.is_equal_approx(Vector2.ONE), "La tuile revient à sa taille")

	print("— %d échec(s)" % echecs)
	quit(1 if echecs > 0 else 0)
