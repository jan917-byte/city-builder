extends RefCounted
# Lecture et VALIDATION du JSON produit par 07_exporter_godot.py.
# On échoue en NOMMANT ce qui manque, jamais par un magenta silencieux quarante
# lignes plus loin (même geste que `05_exporter_classeur.py`).

const CHEMIN := "res://data/wehrau.json"
# Les tableaux de sommets, compressés à côté du JSON : `export_godot/octets.py`.
const COMPRESSION := FileAccess.COMPRESSION_DEFLATE

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
	var e_bin := _deplier(d, chemin.get_basename() + ".bin")
	if e_bin != "":
		_fatal(e_bin + "\nRelancer :  python QGIS/scripts/07_exporter_godot.py")
		return {}
	for cle in ["meta", "palette", "terrain", "masses", "sols", "eau", "berges",
			"berges_mur", "berges_pente",
			"voirie", "repare", "repare_voirie", "ponts_ruine", "ponts_provisoires", "boue",
			"arbres", "alignements", "berges_semis", "berges_couloir",
			"couloirs", "emprises", "objets", "riverains", "camps",
			"crue", "reperes", "controles"]:
		if not d.has(cle):
			_fatal("clé absente du JSON : `%s`\n" % cle
				+ "Relancer :  python QGIS/scripts/07_exporter_godot.py")
			return {}

	var boue: Dictionary = d["boue"]
	var taille: Array = boue.get("taille", [])
	var repere: Array = boue.get("repere", [])
	if taille.size() != 2 or repere.size() != 4:
		_fatal("carte de boue : taille ou repère absent")
		return {}
	if int(taille[0]) < 2 or int(taille[1]) < 2 \
			or float(repere[2]) <= 0.0 or float(repere[3]) <= 0.0 \
			or boue.get("pixels", []).size() != int(taille[0]) * int(taille[1]) * 2:
		_fatal("carte de boue : dimensions ou pixels incohérents")
		return {}

	var o: Dictionary = d["objets"]
	if not o.has("ilots") or not o.has("routes") or not o.has("berges"):
		_fatal("`objets` doit porter `ilots`, `routes` et `berges`")
		return {}
	if (o["ilots"] as Dictionary).size() != N_ILOTS:
		push_warning("objets.ilots : %d fiches pour %d îlots"
			% [(o["ilots"] as Dictionary).size(), N_ILOTS])

	# 🏕️ Les places de camp : une par logement de containers, semées par `07`.
	# Sans elles, poser un camp ne dessinerait rien et rien ne le dirait.
	var camps: Dictionary = d["camps"]
	if (camps.get("boite", []) as Array).size() != 3 \
			or (camps.get("places", {}) as Dictionary).is_empty():
		_fatal("`camps` doit porter une boîte de 3 côtés et des places")
		return {}

	var c: Dictionary = d["controles"]
	for fid in o["routes"]:
		var route: Dictionary = o["routes"][fid]
		if route.get("etat_crue", "") == "coupe" and not route.get("morceaux_reunis") is Array:
			_fatal("Pont %s : accès absents ; relancer 07_exporter_godot.py." % fid)
			return {}
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
	for nom in ["terrain", "masses", "sols", "eau", "berges", "berges_mur",
			"berges_pente", "voirie", "repare", "repare_voirie", "ponts_ruine",
			"ponts_provisoires"]:
		var e: String = _valider_maillage(d[nom] as Dictionary, nom)
		if e != "":
			_fatal(e)
			return {}

	return d


## Chaque maillage renvoie au binaire par `octets` : {clé: [début, longueur]}
## dans le binaire décompressé, chaque morceau au format de `var_to_bytes`.
static func _deplier(d: Dictionary, chemin_bin: String) -> String:
	var b: Dictionary = (d.get("meta", {}) as Dictionary).get("binaire", {})
	if b.is_empty():
		return "export sans binaire : `meta.binaire` absent"
	# L'empreinte est écrite par 07 dans le JSON : un .bin d'un autre export est refusé.
	if FileAccess.get_md5(chemin_bin) != str(b.get("md5", "")):
		return "%s absent, ou d'un autre export que le JSON" % chemin_bin
	var brut := FileAccess.get_file_as_bytes(chemin_bin).decompress(
		int(b["taille"]), COMPRESSION)
	if brut.size() != int(b["taille"]):
		return "%s : %d octets décompressés pour %d" % [chemin_bin, brut.size(), int(b["taille"])]
	_deplier_dans(d, brut)
	return ""


static func _deplier_dans(x: Dictionary, brut: PackedByteArray) -> void:
	if x.get("octets") is Dictionary:
		var refs: Dictionary = x["octets"]
		for cle in refs:
			var r: Array = refs[cle]
			x[cle] = bytes_to_var(brut.slice(int(r[0]), int(r[0]) + int(r[1])))
		x.erase("octets")
		return
	for v in x.values():
		if v is Dictionary:
			_deplier_dans(v, brut)


static func _valider_maillage(m: Dictionary, nom: String) -> String:
	for cle in ["v", "n", "c", "i", "g"]:
		if not m.has(cle):
			return "maillage `%s` : clé `%s` absente" % [nom, cle]
	if not (m["v"] is PackedVector3Array and m["n"] is PackedVector3Array
			and m["c"] is PackedColorArray and m["i"] is PackedInt32Array):
		return "maillage `%s` : tableaux d'un ancien export" % nom
	# Sans ça, « index out of bounds » plus loin, sans dire quel objet.
	var ni_total: int = m["i"].size()
	for g in (m["g"] as Array):
		var gr: Array = g
		if int(gr[1]) + int(gr[2]) > ni_total:
			return "maillage `%s` : le groupe %d déborde (%d + %d > %d)" \
				% [nom, int(gr[0]), int(gr[1]), int(gr[2]), ni_total]
	var nv: int = m["v"].size()
	if m["n"].size() != nv:
		return "maillage `%s` : %d normales pour %d sommets" % [nom, m["n"].size(), nv]
	if m["c"].size() != nv:
		return "maillage `%s` : %d couleurs pour %d sommets" % [nom, m["c"].size(), nv]
	if m.has("uv") and m["uv"].size() != nv:
		return "maillage `%s` : %d axes de toit pour %d sommets" % [nom, m["uv"].size(), nv]
	# 🪟 UV2 est facultatif (murs percés seulement) mais, présent, il est
	# COMPLET : trop court, il décale les façades et sème des vitrines au hasard.
	if m.has("uv2") and m["uv2"].size() != nv:
		return "maillage `%s` : %d façades pour %d sommets" % [nom, m["uv2"].size(), nv]
	# 🏢 CUSTOM0 à plat, quatre flottants par sommet.
	if m.has("dense") and m["dense"].size() != 4 * nv:
		return "maillage `%s` : %d valeurs d'étage pour %d sommets" % [nom, m["dense"].size(), nv]
	var ni: int = m["i"].size()
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
