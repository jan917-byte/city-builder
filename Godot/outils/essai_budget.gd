extends SceneTree
## --headless --script res://outils/essai_budget.gd
## 🗳️ Le budget voté en janvier (124) : aide fixe, prime notée sur l'an passé, règles.
const Ville := preload("res://scripts/ville.gd")
const Budget := preload("res://scripts/budget.gd")
var echecs := 0

func verifier(ok: bool, quoi: String) -> void:
	print("%s · %s" % ["OK" if ok else "ÉCHEC", quoi])
	if not ok:
		echecs += 1

func imprimer(v, an: int) -> void:
	var b := Budget.bilan(v, an)
	print("   an %d (mois %.0f) : prime %.0f k€ · logements %d (%d dehors, %d au camp) · trafic %d (%d ponts coupés, %d rues saturées) · économie %d · confiance %d (%.0f)" % [
		an, b["mois"], b["prime_ke"], b["logements"]["note"], b["logements"]["dehors"], b["logements"]["au_camp"],
		b["trafic"]["note"], b["trafic"]["coupes"].size(), b["trafic"]["saturees"].size(),
		b["economie"]["note"], b["confiance"]["note"], b["confiance"]["valeur"]])

func _initialize() -> void:
	var v := Ville.new()
	v.charger(JSON.parse_string(FileAccess.get_file_as_string("res://data/wehrau.json")))
	verifier(Budget.bilan(v, 1).is_empty(), "L'an 1 n'a pas de bilan : la caisse de départ")
	verifier(is_equal_approx(Budget.debut_an(2), 10.0), "L'an 2 commence au mois 10")
	print("Sans rien faire :")
	imprimer(v, 2)
	# Une ouverture ordinaire : deux camps, le pont provisoire le moins cher.
	var champs := []
	for fid in v.ilots:
		if v.camp_possible(fid) and v.camp_accessible(fid):
			champs.append(fid)
	v.abriter(champs[0], 0.0)
	v.abriter(champs[1], 0.0)
	var pont: int = v.ponts_coupes()[2]
	v.reparer("r", pont, 0.5, true)
	print("Deux camps, un pont provisoire :")
	imprimer(v, 2)
	imprimer(v, 3)
	var t2 := Budget.debut_an(2)
	var avant := v.caisse_ke(t2 - 0.001)
	var apres := v.caisse_ke(t2)
	verifier(absf(apres - avant - Budget.AIDE_KE_AN) < 1.0, "Le 1er janvier : +%.0f k€ d'aide fixe" % (apres - avant))
	var prime := Budget.prime_ke_an(v, 2)
	verifier(absf(Budget.prime_cumulee_ke(v, t2 + 12.0) - prime) < 0.01, "Un an de prime versée : %.0f k€" % prime)
	verifier(absf(Budget.prime_mensuelle_ke(v, t2 + 3.0) * 12.0 - prime) < 0.01, "Chaque mois : %.1f k€" % (prime / 12.0))
	# Le passé ne change pas : une décision après janvier ne refait pas la note de janvier.
	v.abriter(champs[2], t2 + 1.0) if champs.size() > 2 else null
	verifier(is_equal_approx(Budget.prime_ke_an(v, 2), prime), "Une décision de février ne refait pas la note de janvier")
	print("%d échec%s" % [echecs, "s" if echecs > 1 else ""])
	quit(1 if echecs > 0 else 0)
