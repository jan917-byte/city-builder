extends SceneTree
# Le contrôle imprimé du système énergie — Prototype/Énergie.md §7, étapes 1, 2 et 6.
#
# Depuis la décision 65, l'auteur ne voit plus passer le code : ce compte rendu
# en français est LE SEUL ENDROIT où une erreur peut encore se voir. Il tourne
# sur le noyau nu (ville + énergie + chantiers), sans un seul nœud, donc en
# --headless :
#
#   Godot_v4.7.1-stable_win64_console.exe --headless --path Godot ^
#       --script res://outils/essai_energie.gd
#
# ⚠️ Le recoupement avec `08_jouer.py` n'existe plus (exception assumée,
# PLAN §9 c) : ces invariants ne comparent le moteur qu'à lui-même.

const Donnees := preload("res://scripts/donnees.gd")
const Ville := preload("res://scripts/ville.gd")
const Energie := preload("res://scripts/energie.gd")
const Chantiers := preload("res://scripts/chantiers.gd")

var _echecs := 0


func _initialize() -> void:
	var d := Donnees.charger()
	if d.is_empty():
		quit(1)
		return
	var ville := Ville.new()
	ville.charger(d)

	print("")
	print("=".repeat(72))
	print("CONTRÔLE ÉNERGIE — Wehrau, noyau seul")
	print("=".repeat(72))

	_mois_zero(ville)
	_table_potentiel(ville)
	_rentabilites(ville)
	_scenario_barre(d)
	_partie_aveugle(d, "PAN", "Capital",
		"panneaux seuls : l'argent ne manque pas, la légitimité si")
	_partie_aveugle(d, "ISO", "Budget",
		"isolation seule : la légitimité monte, l'argent s'épuise")

	print("")
	if _echecs == 0:
		print("Tout est au vert.")
	else:
		print("🔴 %d contrôle(s) au rouge — voir ci-dessus." % _echecs)
	print("")
	quit(1 if _echecs > 0 else 0)


## Un contrôle nommé : vert si la condition tient, rouge sinon.
func _controle(nom: String, ok: bool) -> void:
	print("  %s  %s" % ["✅" if ok else "🔴", nom])
	if not ok:
		_echecs += 1


# --------------------------------------------------- 1. les quatre nombres

func _mois_zero(v) -> void:
	var m: Dictionary = Energie.ville_mwh(v, 0.0)
	var conso_gwh: float = m["conso"] / 1000.0
	var prod_gwh: float = m["production"] / 1000.0
	var co2: float = Energie.co2_achat_kt(v, 0.0)

	print("")
	print("Les quatre nombres, au mois 0 (PLAN §3) :")
	print("  consommation      %6.1f GWh/an   (indice 100)" % conso_gwh)
	print("  production locale %6.1f GWh/an   (%.0f %%)"
		% [prod_gwh, 100.0 * prod_gwh / conso_gwh])
	print("  achat (facture)    indice 100     — 100 % acheté, la phrase qui pique")
	print("  CO2               %6.1f kt/an" % co2)
	print("")
	_controle("consommation dans la fourchette 45–58 GWh (attendu ~51)",
		conso_gwh >= 45.0 and conso_gwh <= 58.0)
	_controle("production nulle au départ", prod_gwh == 0.0)
	_controle("CO2 ≈ 0,25 × achat (attendu ~12,8 kt)",
		absf(co2 - m["achat"] * 0.25 / 1000.0) < 0.001)


# --------------------------------------- 2. le gisement, tissu par tissu

func _table_potentiel(v) -> void:
	var par_tissu := {}
	for fid in v.fids_batis():
		var st: String = str(v.ilots[fid].get("sous_type", ""))
		if not par_tissu.has(st):
			par_tissu[st] = {"n": 0, "logements": 0.0, "conso": 0.0,
				"equipable": 0.0, "potentiel": 0.0}
		var t: Dictionary = par_tissu[st]
		t["n"] += 1
		t["logements"] += v.base("i", fid, "logements")
		t["conso"] += Energie.conso_mwh(v, fid, 0.0)
		t["equipable"] += Energie.toit_equipable_m2(v, fid)
		t["potentiel"] += Energie.potentiel_mwh(v, fid, 0.0)

	var conso_totale: float = Energie.ville_mwh(v, 0.0)["conso"]
	var equip_total := 0.0
	var pot_total := 0.0

	print("")
	print("Le gisement solaire, tissu par tissu (PLAN §7 étape 1) :")
	print("  %-22s %5s %9s %10s %12s %8s" % ["sous_type", "îlots",
		"logements", "conso GWh", "équipable m²", "pot. GWh"])
	var tissus: Array = par_tissu.keys()
	tissus.sort()
	for st in tissus:
		var t: Dictionary = par_tissu[st]
		equip_total += t["equipable"]
		pot_total += t["potentiel"]
		print("  %-22s %5d %9.0f %10.2f %12.0f %8.2f" % [st, t["n"],
			t["logements"], t["conso"] / 1000.0, t["equipable"],
			t["potentiel"] / 1000.0])
	print("  %-22s %5s %9s %10.2f %12.0f %8.2f" % ["TOTAL", "", "",
		conso_totale / 1000.0, equip_total, pot_total / 1000.0])

	var toit_total := 0.0
	for fid in v.fids_batis():
		toit_total += v.base("i", fid, "toit_m2")
	var part: float = 100.0 * pot_total / conso_totale
	var part_max: float = 100.0 * (pot_total / maxf(equip_total, 1.0)) \
		* toit_total / conso_totale
	print("")
	print("  Le potentiel couvre %.1f %% de la consommation." % part)
	print("")
	print("  ⚠️ ARBITRAGE AUTEUR — la fourchette du PLAN §4 (25–40 %) est")
	print("  inatteignable : elle avait été calibrée sur 76,5 ha d'EMPRISE,")
	print("  mais les toits réels de Wehrau font %.1f ha. Même équiper 100 %%"
		% (toit_total / 1e4))
	print("  de chaque m² de toit plafonnerait vers %.0f %%. La leçon « Wehrau"
		% part_max)
	print("  ne devient pas autonome par ses toits » sort renforcée ; les")
	print("  ordres de grandeur du §5 changent d'échelle, pas de sens.")
	print("")
	_controle("le potentiel plafonne (< 40 % : pas d'autonomie par les toits)",
		part < 40.0)
	_controle("le gisement existe (> 5 %, sinon la table est trop timide)",
		part > 5.0)


# ---------------------------------- 3. la rentabilité, et le temps qui passe

func _rentabilites(v) -> void:
	print("")
	print("La rentabilité au mois 0, tissu par tissu (années — PLAN §4) :")
	var par_tissu := {}
	for fid in v.fids_batis():
		var r: float = Energie.rentabilite_annees(v, fid, 0.0)
		if is_inf(r):
			continue
		var st: String = str(v.ilots[fid].get("sous_type", ""))
		if not par_tissu.has(st):
			par_tissu[st] = []
		par_tissu[st].append(r)

	var tissus: Array = par_tissu.keys()
	tissus.sort()
	for st in tissus:
		var liste: Array = par_tissu[st]
		liste.sort()
		print("  %-22s %5.1f à %5.1f ans   (%d îlot%s)"
			% [st, liste[0], liste[liste.size() - 1], liste.size(),
			"s" if liste.size() > 1 else ""])

	# Le cœur ancien aux mois 0, 60 et 120 : les deux dérives composées font
	# fondre la rentabilité d'environ 7,8 % par an (PLAN §7 étape 2).
	var coeur: float = _mediane_tissu(v, "coeur_ancien", 0.0)
	var coeur60: float = _mediane_tissu(v, "coeur_ancien", 60.0)
	var coeur120: float = _mediane_tissu(v, "coeur_ancien", 120.0)
	print("")
	print("Le cœur ancien, si on décidait plus tard (attendu ~24 → 16 → 11) :")
	print("  mois 0 : %.1f ans   mois 60 : %.1f ans   mois 120 : %.1f ans"
		% [coeur, coeur60, coeur120])
	print("")
	_controle("le cœur ancien n'est jamais rentable dans la partie (> 20 ans à t0)",
		coeur > 20.0)
	_controle("la dérive le ramène vers ~11 ans au mois 120 (10 à 12)",
		coeur120 > 10.0 and coeur120 < 12.0)

	var barre: float = _mediane_tissu(v, "barre_1970", 0.0)
	var dalle: float = _mediane_tissu(v, "dalle_commerciale", 0.0)
	print("Le moment cherché (PLAN §1) : la dalle en %.1f ans, la barre en %.1f," % [dalle, barre])
	print("le cœur ancien en %.1f — la question devient « où, et est-ce que j'assume ? »" % coeur)
	print("")
	_controle("la dalle et la barre se remboursent vite (< 10 ans)",
		dalle < 10.0 and barre < 10.0)


func _mediane_tissu(v, st: String, t: float) -> float:
	var liste := []
	for fid in v.fids_batis():
		if str(v.ilots[fid].get("sous_type", "")) == st:
			var r: float = Energie.rentabilite_annees(v, fid, t)
			if not is_inf(r):
				liste.append(r)
	if liste.is_empty():
		return INF
	liste.sort()
	return liste[liste.size() / 2]


# ------------------------- 4. la barre de 1974 : panneaux, PUIS isolation

## L'étape 3 du PLAN §7 en un scénario : équiper la barre, puis isoler la
## même barre. Deux courbes, deux formes — et les invariants de l'étape 6.
func _scenario_barre(d: Dictionary) -> void:
	var v := Ville.new()
	v.charger(d)
	var ch := Chantiers.new(v)
	var barre := -1
	for fid in v.fids_batis():
		if str(v.ilots[fid].get("sous_type", "")) == "barre_1970":
			barre = fid
			break

	print("")
	print("La barre de 1974 (îlot %d) : panneaux au mois 0, isolation au mois 1." % barre)
	var pan: Dictionary = ch.engager("PAN", [barre], 0.0)
	var iso: Dictionary = ch.engager("ISO", [barre], 1.0)
	_controle("les panneaux s'engagent (%.0f pts, capital %.0f)"
		% [pan.get("cout", 0.0), pan.get("capital", 0.0)], bool(pan["ok"]))
	_controle("isoler le MÊME îlot reste possible (clé par décision)",
		bool(iso["ok"]))
	if not (bool(pan["ok"]) and bool(iso["ok"])):
		return

	print("")
	print("  mois | conso GWh | production GWh | CO2 kt (gris compris)")
	var co2_0: float = Energie.co2_achat_kt(v, 0.0)
	for m in [0.0, 6.0, 9.0, 12.0, 60.0]:
		var mm: Dictionary = Energie.ville_mwh(v, m)
		print("  %4.0f | %9.2f | %14.3f | %.2f" % [m, mm["conso"] / 1000.0,
			mm["production"] / 1000.0, Energie.co2_achat_kt(v, m) + ch.co2_gris_an(m)])

	var prod6: float = Energie.ville_mwh(v, 6.0)["production"]
	var prod12: float = Energie.ville_mwh(v, 12.0)["production"]
	var pot: float = Energie.potentiel_mwh(v, barre, 12.0)
	var conso60: float = Energie.ville_mwh(v, 60.0)["conso"]
	var conso0: float = Energie.ville_mwh(v, 0.0)["conso"]
	print("")
	_controle("rien ne se passe pendant le délai (production nulle au mois 6)",
		prod6 == 0.0)
	_controle("la production décolle puis atteint le potentiel de la barre au mois 12",
		absf(prod12 - pot) < 0.01)
	_controle("l'isolation fait TOMBER la consommation (deux courbes, deux formes)",
		conso60 < conso0 - 1500.0)
	var co2_9: float = Energie.co2_achat_kt(v, 9.0) + ch.co2_gris_an(9.0)
	var co2_60: float = Energie.co2_achat_kt(v, 60.0) + ch.co2_gris_an(60.0)
	_controle("le CO2 MONTE pendant les travaux (carbone gris), à %.2f kt" % co2_9,
		co2_9 > co2_0)
	_controle("puis redescend plus bas qu'au départ, à %.2f kt" % co2_60,
		co2_60 < co2_0)

	_invariants(v, ch)
	_remboursement(v, ch, barre, pan)


## Les trois invariants de l'étape 6, aux cinq dates.
func _invariants(v, ch) -> void:
	print("")
	print("Les invariants, aux mois 0, 12, 60, 120 et 240 :")
	var ok_somme := true
	var ok_plafond := true
	for m in [0.0, 12.0, 60.0, 120.0, 240.0]:
		var mm: Dictionary = Energie.ville_mwh(v, m)
		if absf(mm["achat"] + mm["production"] - mm["conso"]) > 0.01:
			ok_somme = false
		var pot_total := 0.0
		for fid in v.fids_batis():
			pot_total += Energie.potentiel_mwh(v, fid, m)
		if mm["production"] > pot_total + 0.01:
			ok_plafond = false
		print("  mois %3.0f : achat %8.1f + production %7.1f = conso %8.1f MWh · solde %6.0f pts · capital %4.0f"
			% [m, mm["achat"], mm["production"], mm["conso"], ch.solde(m), ch.capital(m)])
	_controle("achat + production = consommation, à chaque date", ok_somme)
	_controle("la production ne dépasse jamais le potentiel", ok_plafond)


## Le remboursement : décidé au mois 0, un chantier rembourse son coût au mois
## délai + travaux + 12 × rentabilité, à 2 % près. Exact par construction
## (tarif ET coût figés au mois de la décision) — s'il dérive, c'est que
## quelqu'un a débranché le gel du tarif.
func _remboursement(v, ch, fid: int, pan: Dictionary) -> void:
	var attendu: float = 6.0 + 6.0 + 12.0 * Energie.rentabilite_annees(v, fid, 0.0)
	var cout: float = pan["cout"]
	var m := 0.0
	while m <= 240.0:
		var recu := 0.0
		for c in ch.journal:
			if c["id"] == "PAN":
				recu = c["retour_mensuel"] * maxf(0.0, m - c["fin_travaux"] + 1.0)
		if recu >= cout:
			break
		m += 1.0
	print("")
	print("Remboursement de la barre : coût %.1f pts, remboursé au mois %.0f (attendu ~%.0f)."
		% [cout, m, attendu])
	_controle("le remboursement tombe à 2 % près du mois attendu",
		absf(m - attendu) <= maxf(0.02 * attendu, 1.0))


# ------------------------------------ 5. les deux parties, en aveugle

## LE contrôle le plus important de la session (PLAN §8, 2 bis) : chaque mois,
## on engage tout ce qu'on peut, une seule décision autorisée. La partie
## « panneaux seuls » doit finir bloquée sur le CAPITAL, la partie « isolation
## seule » sur le BUDGET. Si les deux vont au bout, la paire ne tient pas —
## deux décisions indépendantes sont décoratives l'une pour l'autre.
func _partie_aveugle(d: Dictionary, id: String, attendu: String, titre: String) -> void:
	var v := Ville.new()
	v.charger(d)
	var ch := Chantiers.new(v)
	var engages := 0
	for m in range(0, 241):
		var elig: Array = ch.eligibles(id, 0.0, float(m))
		for fid in elig:
			var r: Dictionary = ch.engager(id, [fid], float(m))
			if not bool(r["ok"]):
				break   # ce mois-ci c'est non — on repassera
			engages += 1

	var restants: Array = ch.eligibles(id, 0.0, 240.0)
	var dernier := ""
	if not restants.is_empty():
		dernier = ch.refus(id, [restants[0]], 240.0)

	print("")
	print("Partie en aveugle, %s :" % titre)
	print("  %d chantiers engagés, %d îlots jamais atteints · solde final %.0f pts · capital final %.0f"
		% [engages, restants.size(), ch.solde(240.0), ch.capital(240.0)])
	if dernier != "":
		print("  le refus qui reste : « %s »" % dernier)
	_controle("des îlots restent hors de portée (sinon la décision est gratuite)",
		not restants.is_empty())
	_controle("et le blocage est bien : %s" % attendu,
		dernier.begins_with(attendu))
	if id == "ISO":
		_controle("le capital n'a fait que monter (l'isolation en rend)",
			ch.capital(240.0) > Ville.CAPITAL_DEPART)
	else:
		_controle("le budget n'est pas la cause : le solde final reste confortable",
			ch.solde(240.0) > 100.0)
