extends SceneTree
## ❄️ La météo tirée : même graine, mêmes hivers ; la neige varie d'un hiver à
## l'autre et baisse au fil des ans. Imprime la neige de chaque hiver d'une partie.
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

	print("\nLa partie de graine %d : la neige de chaque hiver, et la ligne des montagnes en janvier" % graine)
	print("  hiver   épisodes   semaines   janvier   ligne")
	for an in range(1, 21):
		var janvier := 12.0 * an - 2.0 + 0.5
		print("  an %2d   %8d   %8.1f   %5.1f °C   %4.0f m" % [an, s.episodes_hiver(an).size(),
			_semaines(s, an), s.temperature(janvier), s.ligne_de_neige(janvier)])

	# Sur beaucoup de parties : la neige baisse avec les années.
	var debut := 0.0
	var fin := 0.0
	var sans := [0, 0]
	for g in PARTIES:
		var p := Saison.new(1000 + g)
		for an in range(1, 6):
			var n := _semaines(p, an)
			debut += n
			if n == 0.0:
				sans[0] += 1
		for an in range(16, 21):
			var n := _semaines(p, an)
			fin += n
			if n == 0.0:
				sans[1] += 1
	debut /= PARTIES * 5.0
	fin /= PARTIES * 5.0
	print("\nSur %d parties : %.1f semaines de neige par hiver des ans 1 à 5, %.1f des ans 16 à 20"
		% [PARTIES, debut, fin])
	print("  hivers sans neige : %d %% au début, %d %% à la fin" % [
		roundi(100.0 * sans[0] / (PARTIES * 5.0)), roundi(100.0 * sans[1] / (PARTIES * 5.0))])
	if fin >= debut * 0.7:
		echecs += 1
		push_error("la neige ne baisse pas assez avec les années")
	print("\n%s" % ("ESSAI SAISON : 0 échec" if echecs == 0 else "ESSAI SAISON : %d échec(s)" % echecs))
	quit(1 if echecs > 0 else 0)


## Les semaines où la vallée est blanche, fonte à moitié comptée.
func _semaines(s, an: int) -> float:
	var jours := 0.0
	for x in s.episodes_hiver(an):
		jours += (float(x[1]) - float(x[0]) + Saison.FONTE_MOIS * 0.5) * 30.0
	return jours / 7.0
