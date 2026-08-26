extends RefCounted
# Lecture et VALIDATION du JSON produit par 07_exporter_godot.py.
# On échoue en NOMMANT ce qui manque, jamais par un magenta silencieux quarante
# lignes plus loin (même geste que `05_exporter_classeur.py`).

const CHEMIN := "res://data/wehrau.json"

# Comptes connus, donc vérifiables : s'ils bougent, la carte a changé.
const N_ILOTS := 71
const N_ROUTES := 178      # source moins les deux ponts supprimés par la décision 30c
const N_BERGES := 8        # 3 franchissements coupent chaque rive en 4 (07)


static func charger(chemin: String = CHEMIN) -> Dictionary:
	var f := FileAccess.open(chemin, FileAccess.READ)
	if f == null:
		_fatal("Fichier introuvable : %s (erreur %d)\n"
			% [chemin, FileAccess.get_open_error()]
			+ "Lancer d'abord :  python QGIS/scripts/07_exporter_godot.py")
		return {}
	var txt := f.get_as_text()
	f.close()

	var brut: Variant = JSON.parse_string(txt)
	if brut == null:
		_fatal("JSON illisible : %s" % chemin)
		return {}
	if typeof(brut) != TYPE_DICTIONARY:
		_fatal("JSON de type inattendu : %d" % typeof(brut))
		return {}

	var d: Dictionary = brut
	for cle in ["meta", "palette", "terrain", "masses", "sols", "eau", "berges",
			"voirie", "repare", "repare_voirie",
			"arbres", "alignements", "couloirs", "emprises", "objets", "riverains",
			"crue", "reperes", "controles"]:
		if not d.has(cle):
			_fatal("clé absente du JSON : `%s`\n" % cle
				+ "Relancer :  python QGIS/scripts/07_exporter_godot.py")
			return {}

	var o: Dictionary = d["objets"]
	if not o.has("ilots") or not o.has("routes") or not o.has("berges"):
		_fatal("`objets` doit porter `ilots`, `routes` et `berges`")
		return {}
	if (o["ilots"] as Dictionary).size() != N_ILOTS:
		push_warning("objets.ilots : %d fiches pour %d îlots"
			% [(o["ilots"] as Dictionary).size(), N_ILOTS])

	var c: Dictionary = d["controles"]
	# 🌊 Les berges ne sont pas dans la source : elles sont DÉCOUPÉES par 07 aux
	# franchissements. Leur nombre est donc le contrôle de cette découpe.
	if int(c.get("berges", 0)) != N_BERGES:
		push_warning("berges : %d objets au lieu de %d — voir la coupe aux"
			% [int(c.get("berges", 0)), N_BERGES]
			+ " franchissements dans 07_exporter_godot.py")
	if int(c["ilots"]) != N_ILOTS or int(c["routes"]) != N_ROUTES:
		push_warning("La carte a changé : %d îlots et %d tronçons au lieu de %d et %d."
			% [int(c["ilots"]), int(c["routes"]), N_ILOTS, N_ROUTES])

	# 🔄 `terrain` se contrôlait à part quand c'était un champ d'altitude ;
	# la carte étant plate, c'est un maillage comme les autres.
	for nom in ["terrain", "masses", "sols", "eau", "berges", "voirie",
			"repare", "repare_voirie"]:
		var e: String = _valider_maillage(d[nom] as Dictionary, nom)
		if e != "":
			_fatal(e)
			return {}

	return d


static func _valider_maillage(m: Dictionary, nom: String) -> String:
	for cle in ["v", "n", "c", "i", "g"]:
		if not m.has(cle):
			return "maillage `%s` : clé `%s` absente" % [nom, cle]
	# Sans ça, « index out of bounds » plus loin, sans dire quel objet.
	var ni_total: int = (m["i"] as Array).size()
	for g in (m["g"] as Array):
		var gr: Array = g
		if int(gr[1]) + int(gr[2]) > ni_total:
			return "maillage `%s` : le groupe %d déborde (%d + %d > %d)" \
				% [nom, int(gr[0]), int(gr[1]), int(gr[2]), ni_total]
	var nv: int = (m["v"] as Array).size()
	if (m["n"] as Array).size() != nv:
		return "maillage `%s` : %d normales pour %d sommets" % [nom,
			(m["n"] as Array).size(), nv]
	if (m["c"] as Array).size() != nv:
		return "maillage `%s` : %d couleurs pour %d sommets" % [nom,
			(m["c"] as Array).size(), nv]
	if m.has("uv") and (m["uv"] as Array).size() != nv:
		return "maillage `%s` : %d axes de toit pour %d sommets" % [nom,
			(m["uv"] as Array).size(), nv]
	# 🪟 UV2 est facultatif (murs percés seulement) mais, présent, il est
	# COMPLET : trop court, il décale les façades et sème des vitrines au hasard.
	if m.has("uv2") and (m["uv2"] as Array).size() != nv:
		return "maillage `%s` : %d façades pour %d sommets" % [nom,
			(m["uv2"] as Array).size(), nv]
	var ni: int = (m["i"] as Array).size()
	if ni % 3 != 0:
		return "maillage `%s` : %d indices, pas un multiple de 3" % [nom, ni]
	return ""


## Un rôle absent est une erreur NOMMÉE : le magenta silencieux coûte une heure.
static func teinte(d: Dictionary, role: String, defaut := Color.MAGENTA) -> Color:
	var p: Dictionary = d["palette"]
	if not p.has(role):
		push_error("palette : rôle `%s` absent — voir QGIS/scripts/palette.py" % role)
		return defaut
	return Color(p[role] as String)


static func _fatal(message: String) -> void:
	push_error("DONNÉES — " + message)
	printerr("DONNÉES — " + message)
