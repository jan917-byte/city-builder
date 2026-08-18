extends RefCounted
# Lecture et VALIDATION du JSON produit par 07_exporter_godot.py.
#
# Le geste vient du dépôt : `05_exporter_classeur.py:57-68` préfère « un
# message clair plutôt qu'un no such column de sqlite ». Ici c'est pareil —
# on échoue en nommant ce qui manque, jamais par un magenta silencieux
# quarante lignes plus loin.

const CHEMIN := "res://data/wehrau.json"

# Les comptes sont connus, donc vérifiables. S'ils changent, c'est que la
# carte a changé — et on veut le savoir tout de suite.
const N_ILOTS := 71
const N_ROUTES := 178      # source moins les deux ponts supprimés par la décision 30c


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
	for cle in ["meta", "palette", "terrain", "masses", "sols", "eau",
			"voirie", "arbres", "alignements", "couloirs", "emprises", "objets", "riverains",
			"reperes", "controles"]:
		if not d.has(cle):
			_fatal("clé absente du JSON : `%s`\n" % cle
				+ "Relancer :  python QGIS/scripts/07_exporter_godot.py")
			return {}

	var o: Dictionary = d["objets"]
	if not o.has("ilots") or not o.has("routes"):
		_fatal("`objets` doit porter `ilots` et `routes`")
		return {}
	if (o["ilots"] as Dictionary).size() != N_ILOTS:
		push_warning("objets.ilots : %d fiches pour %d îlots"
			% [(o["ilots"] as Dictionary).size(), N_ILOTS])

	var c: Dictionary = d["controles"]
	if int(c["ilots"]) != N_ILOTS or int(c["routes"]) != N_ROUTES:
		push_warning("La carte a changé : %d îlots et %d tronçons au lieu de %d et %d."
			% [int(c["ilots"]), int(c["routes"]), N_ILOTS, N_ROUTES])

	# 🔄 `terrain` était un champ d'altitude et se contrôlait à part (grille
	# nx × nz contre nombre d'altitudes). La carte étant plate, c'est un
	# maillage comme les autres — donc il passe le MÊME contrôle qu'eux.
	for nom in ["terrain", "masses", "sols", "eau", "voirie"]:
		var e: String = _valider_maillage(d[nom] as Dictionary, nom)
		if e != "":
			_fatal(e)
			return {}

	return d


static func _valider_maillage(m: Dictionary, nom: String) -> String:
	for cle in ["v", "n", "c", "i", "g"]:
		if not m.has(cle):
			return "maillage `%s` : clé `%s` absente" % [nom, cle]
	# Une plage qui déborde donnerait un « index out of bounds » quarante
	# lignes plus loin, sans dire de quel objet il s'agit.
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
	# 🪟 UV2 est facultatif — seul un maillage qui porte des murs percés
	# l'emporte. Mais s'il est là, il est COMPLET : un tableau plus court
	# décalerait le genre de façade d'un sommet à l'autre, et la ville
	# sortirait avec des vitrines au hasard.
	if m.has("uv2") and (m["uv2"] as Array).size() != nv:
		return "maillage `%s` : %d façades pour %d sommets" % [nom,
			(m["uv2"] as Array).size(), nv]
	var ni: int = (m["i"] as Array).size()
	if ni % 3 != 0:
		return "maillage `%s` : %d indices, pas un multiple de 3" % [nom, ni]
	return ""


## La teinte d'un rôle de la palette. Un rôle absent est une erreur NOMMÉE :
## le magenta silencieux fait perdre une heure, le message en fait perdre dix
## secondes.
static func teinte(d: Dictionary, role: String, defaut := Color.MAGENTA) -> Color:
	var p: Dictionary = d["palette"]
	if not p.has(role):
		push_error("palette : rôle `%s` absent — voir QGIS/scripts/palette.py" % role)
		return defaut
	return Color(p[role] as String)


static func _fatal(message: String) -> void:
	push_error("DONNÉES — " + message)
	printerr("DONNÉES — " + message)
