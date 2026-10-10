extends SceneTree
## ❄️ La météo tirée : même graine, mêmes hivers ; une neige par hiver, plus ou
## moins longue, qui raccourcit au fil des ans. Imprime chaque hiver d'une partie.
## Godot --headless --path Godot --script res://outils/essai_saison.gd -- [--graine=7]

const Saison := preload("res://scripts/saison.gd")
const PARTIES := 400


func _initialize() -> void:
	var graine := 7
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--graine="):
			graine = int(a.split("=")[1])
	var echecs := 0
	var s := Saison.new(graine)
	var b := Saison.new(graine)
	for k in 2000:
		var t := k * 0.12
		if s.neige(t) != b.neige(t) or s.temperature(t) != b.temperature(t):
			echecs += 1
			push_error("même graine, autre météo au mois %.2f" % t)
			break
		if s.neige(t) < 0.0 or s.neige(t) > 1.0:
			echecs += 1
			push_error("manteau hors de 0..1 au mois %.2f" % t)
			break
	for k in 40:
		if s.neige(k * 0.025) > 0.0:
			echecs += 1
			push_error("de la neige au premier mois, sur la crue")
			break
	for an in range(1, 21):
		if _chutes(s, an) != 1:
			echecs += 1
			push_error("l'hiver de l'an %d a %d neiges au lieu d'une" % [an, _chutes(s, an)])
			break
		var e: Array = s.neige_hiver(an)
		if s.flocons(float(e[1])) > 0.0 or s.flocons(float(e[0]) - 0.1) > 0.0:
			echecs += 1
			push_error("des flocons hors de la chute, an %d" % an)
			break

	print("\nLa partie de graine %d : la neige de chaque hiver, et la ligne des collines en janvier" % graine)
	print("  hiver   tombe le      semaines   hiver    ligne")
	for an in range(1, 21):
		var janvier := 12.0 * an - 2.0 + 0.5
		var e: Array = s.neige_hiver(an)
		print("  an %2d   %-12s  %8.1f   %5.1f °C   %4.0f m" % [an, _date(float(e[0])),
			_semaines(s, an), s.temperature(janvier), s.ligne_collines(janvier)])

	# Sur beaucoup de parties : la neige baisse avec les années.
	var debut := 0.0
	var fin := 0.0
	var court := [99.0, 99.0]
	for g in PARTIES:
		var p := Saison.new(1000 + g)
		for an in range(1, 6):
			var n := _semaines(p, an)
			debut += n
			court[0] = minf(court[0], n)
		for an in range(16, 21):
			var n := _semaines(p, an)
			fin += n
			court[1] = minf(court[1], n)
	debut /= PARTIES * 5.0
	fin /= PARTIES * 5.0
	print("\nSur %d parties : %.1f semaines de neige par hiver des ans 1 à 5, %.1f des ans 16 à 20"
		% [PARTIES, debut, fin])
	print("  l'hiver le plus court : %.1f semaine au début, %.1f à la fin" % court)
	if fin >= debut * 0.7:
		echecs += 1
		push_error("la neige ne baisse pas assez avec les années")
	print("\n%s" % ("ESSAI SAISON : 0 échec" if echecs == 0 else "ESSAI SAISON : %d échec(s)" % echecs))
	quit(1 if echecs > 0 else 0)


## Les semaines où la vallée est blanche : le manteau intégré, de novembre à avril.
func _semaines(s, an: int) -> float:
	var debut := 12.0 * an - 4.0
	var jours := 0.0
	for k in 500:
		jours += s.neige(debut + k * 0.01) * 0.3
	return jours / 7.0


## Combien de fois la vallée se couvre dans l'hiver de l'an `an`.
func _chutes(s, an: int) -> int:
	var debut := 12.0 * an - 4.0
	var n := 0
	var avant := false
	for k in 500:
		var blanche: bool = s.avancee(debut + k * 0.01) > 0.0
		if blanche and not avant:
			n += 1
		avant = blanche
	return n


func _date(t: float) -> String:
	const Calendrier := preload("res://scripts/calendrier.gd")
	var mo := posmod(Calendrier.MOIS_DEPART + int(floor(t)), 12)
	return "%d %s" % [1 + int((t - floor(t)) * 30.0), Calendrier.NOMS[mo]]
