extends RefCounted
# L'état de Wehrau, et ce qu'il devient quand le temps passe.
# Que des nombres : aucun nœud, aucune couleur, aucun signal.
#
# La rampe vient de `Classeur/README.md`, déjà éprouvée dans `08_jouer.py`.
# ⚠️ Les deux moteurs doivent donner le même chiffre — contrôle de recoupement
# décrit dans le README de Godot.

const Energie := preload("res://scripts/energie.gd")
const Recherche := preload("res://scripts/recherche.gd")
const Politiques := preload("res://scripts/politiques.gd")

const HORIZON_MOIS := 240                  # 20 ans. Le classeur s'arrête à 60.

# ⏸️ Budget en POINTS de l'ancien prototype, hors boucle jouable depuis le
# 2026-08-17 ; seul `chantiers.gd` les lit encore.
const BUDGET_MENSUEL := 100.0 / 12.0       # 100 pts par an — Classeur §2
const CAPITAL_DEPART := 50.0               # décision 16b

# ==========================================================================
# LA CAISSE — deux nombres, et ils décrivent une mairie (2026-08-17)
# ==========================================================================
# 🎚️ LEVEL DESIGN, pas physique : à eux seuls ils décident si le jeu est « dur
# mais possible ». Trop haut, on équipe sans choisir ; trop bas, on regarde le
# temps passer. Repère imprimé par `-- --essai`.
const CAISSE_DEPART_KE := 800.0            # de quoi équiper deux ou trois bons toits
const DOTATION_KE_MOIS := 30.0             # 360 k€/an votés pour la transition

var ilots := {}            # fid:int -> {champ: float|String}
var routes := {}
var berges := {}           # 8 objets : une par rive et par bief (07)
var crue := {}             # le contrat de `04e` : niveau annoncé, paliers, bande
var riverains := {}        # fid tronçon -> [fid îlot]
var _rampes := {"i": {}, "r": {}}   # couche -> fid -> [rampe]
var _solaire := {}         # fid -> {debut, duree, cible, cout_ke}
var _vert := {}            # fid -> idem, pour les toits verts
var _stationnement_supprime := {}  # fid -> mois d'engagement
var _dense := {}           # fid -> {debut, duree, etages, logements, cout_ke}
## 🎓 Sujet de recherche -> mois d'engagement. Un sujet engagé ne s'arrête plus.
var _recherche := {}
## 🏛️ Politique -> [[début, fin], …] ; fin = -1 tant qu'elle est en vigueur.
var _politiques := {}
var _depense_ke := 0.0     # tout ce qui a été engagé en poses depuis le mois 0
## 🧪 OUTIL D'ESSAI, PAS UNE RÈGLE DU JEU : de l'argent tombé du ciel, pour
## atteindre en un clic un état que vingt ans de dotation mettraient à payer.
## Le jour où la boucle se juge pour de bon, ce champ et son bouton sautent.
var _credit_essai_ke := 0.0
var _repare := {}          # "i:66" -> le mois où la réparation a été engagée
var _berge := {}           # fid -> {cible, debut, depuis, cout_ke}
var _toit_avant := {}      # fid -> `toit_m2` d'avant la reconstruction
var _plantation := {}      # fid tronçon -> {debut, duree, cible, cout_ke, arbres}
## Les seuils de canopée des emplacements d'alignement, triés, un tableau par
## tronçon. C'est `07` qui les pose ; ici on ne fait que les compter.
var _seuils := {}          # fid tronçon -> [seuil]
var _adaptation_total_ke := 0.0
var _co2_depart_kt := 0.0

# 🔄 Un `_base_avant` figeait en base la part posée pour permettre de réviser
# une cible en cours de chantier. Retiré avec la caisse : réécrire la base
# efface l'HISTOIRE de la pose, dont la recette encaissée est l'intégrale — le
# toit aurait semblé équipé depuis le mois 0. Désormais les rampes s'ADDITIONNENT
# et un chantier engagé ne se révise plus.

# Une pose complète dure au plus UN mois, une hausse partielle au prorata.
# 🔄 C'était 3 jusqu'au 2026-08-17 : trois minutes de montre, trop long pour
# juger le geste. La plupart des poses tombant sous le mois, `interface._duree`
# les annonce EN JOURS.
const SOLAIRE_MOIS_POUR_100 := 1.0

# ==========================================================================
# LE TOIT VERT — le second usage du même toit (2026-08-31)
# ==========================================================================
# 🌿 LES DEUX DÉCISIONS SE PARTAGENT UN SEUL 100 % : un TOIT porte des panneaux
# OU du substrat, jamais les deux — la règle est au bâtiment, et c'est 07 qui
# range les volumes pour que la maquette la tienne. Le vert est en plus borné
# par la part PLATE du toit — `Energie.part_plate`, mesurée volume par volume.
# 🌿 CE QU'IL FAIT, et rien d'autre : il retient la pluie, donc il abaisse la
# prochaine crue — DANS TOUTE LA VILLE, pas dans un bief. C'est ce qui le
# distingue de la berge, qui ne soulage que la section qu'elle élargit.
# 🎚️ LEVEL DESIGN, et c'est LE nombre du jeu : verdir les 1,58 ha plats et
# équipables de Wehrau rachète 0,40 m de crue pour ~1 800 k€. Les deux repères
# qui le tiennent — renaturer les huit berges coûte 8 166 k€ pour ~0,84 m par
# bief, et sous 0,75 m PAS UN bâtiment du faubourg ne sort de la ruine. Le toit
# vert est donc le mètre le moins cher, et le seul qui ne se voie pas d'en bas.
const TOIT_VERT_MOIS_POUR_100 := 2.0        # étanchéité reprise, puis substrat
const TOIT_VERT_BAISSE_M_PAR_HA := 0.25     # de crue en moins, par hectare verdi

# Ce qui change dans le temps ; tout le reste est figé volontairement.
# ⚠️ `canopee` reste ici bien que son indicateur soit retiré : c'est elle qui
# fait l'OMBRAGE des toits. Une donnée n'est pas un indicateur.
# 🪜 `part_rendue` est le JUMEAU de `part_toit_equipe` : l'une est la surface
# couverte — ce que le shader peint —, l'autre le rendement obtenu, qui n'est
# pas droit (`Energie.courbe_rendue`). Deux rampes plutôt qu'une courbe lue au
# vol, pour que la recette encaissée reste une intégrale exacte.
# 🏢 `part_dense` est la part des bâtiments montables déjà montés : le curseur
# de la densification, et l'avancement que le shader compare aux rangs de 07.
const CHAMPS_MOBILES := {
	"i": ["canopee", "impermeabilise", "riverain", "logements",
		"part_toit_equipe", "part_rendue", "part_toit_vert", "part_isolee",
		"part_dense"],
	"r": ["canopee", "emprise_libre_m", "stationnement", "charge"],
}


# ==========================================================================
# LA CRUE — trois réparations, un seul mécanisme (04e · décision 23b)
# ==========================================================================
# 🔴 LE NOYAU NE SAIT RIEN DE LA CRUE. Chaque objet porte SON prix, calculé par
# `04e_crue.py` et posé dans sa fiche : un îlot à reconstruire, une rue à
# déblayer, un tablier à rebâtir. Ici on compare un nombre à la caisse, et on
# note ce qui est engagé. Le jour où le level design change les prix, pas une
# ligne de GDScript ne bouge.
#
# 🎚️ LES TROIS DURÉES, elles, sont d'ici — ce sont des durées de JEU, pas des
# chiffres de la carte. Repère : la pose solaire d'un îlot tient en un mois.
const RECONSTRUCTION_MOIS := 12.0    # un îlot relevé : un an de chantier
const DEBLAIEMENT_MOIS := 1.0        # la vase enlevée d'une rue
const PONT_MOIS := 18.0              # un franchissement rebâti


# ==========================================================================
# LA BERGE — trois états francs (2026-08-26)
# ==========================================================================
# 🎚️ LEVEL DESIGN, les cinq nombres : ce sont EUX qui disent si rendre l'Ilse à
# la ville tient dans un mandat ou dans vingt ans. Le prix est CUMULÉ depuis
# l'asphalte, donc passer par le quai apaisé ne coûte pas plus cher que d'aller
# droit à la berge renaturée — sinon le jeu punirait la prudence.
# 🌊 CE QU'ELLE CHANGE (question 24, tranchée le 2026-08-26) : la RÉSILIENCE À
# LA PROCHAINE CRUE, et rien d'autre pour l'instant. Rendre une rive au fleuve
# élargit la section : le niveau de la crue annoncée baisse sur toute la
# traversée du bief, LES DEUX RIVES — donc l'aléa des îlots, et la part que la
# prochaine reprendrait. Le trafic de la voie de berge, la canopée et
# l'imperméabilisation restent à trancher.
# 🎚️ LE SIXIÈME NOMBRE, et c'est le plus lourd : combien de crue un mètre de
# rive rendue rachète. Repère mesuré par `04e` — sous 0,75 m de baisse, PAS UN
# bâtiment du faubourg ne sort de la ruine ; à 2,00 m, 56 des 135 en sortent.
const BERGE_ASPHALTE := 0
const BERGE_APAISEE := 1
const BERGE_RENATUREE := 2
const BERGE_NOMS := ["asphalte", "quai apaisé", "berge renaturée"]
const BERGE_PRIX_KE_M := [0.0, 1.2, 3.4]     # k€ par mètre de rive, cumulés
const BERGE_MOIS := [0.0, 6.0, 18.0]         # depuis l'asphalte, cumulés aussi
const BERGE_BAISSE_M_PAR_M := 0.12          # de crue en moins par mètre de rive rendue


# ==========================================================================
# PLANTER UNE RUE — quatre nombres (2026-08-31)
# ==========================================================================
# 🌳 OÙ, ET POURQUOI PAS AILLEURS : un îlot bâti porte 8,78 ha de canopée que
# la maquette de masses ne peut pas montrer — le pâté est plein, il n'y a pas
# de sol dessous. La rue, si : `07` tient 821 emplacements en réserve, chacun
# avec son seuil, et sait déjà n'en révéler aucun dans l'Ilse ni sur la
# chaussée. La décision est donc SUR LA RUE, et elle se voit.
# 🎚️ LEVEL DESIGN, les quatre : ce sont eux qui disent si planter vaut mieux
# que poser des panneaux avec le même argent.
## Planté de bout en bout, un arbre tous les 12 m. 🔴 LE MÊME NOMBRE que
## `CANOPEE_ALIGNEMENT_MAX` dans `07_exporter_godot.py` — écrit deux fois,
## contrôlé au chargement. Aucun tronçon de Wehrau ne dépasse 0,20 aujourd'hui.
const PLANTATION_CANOPEE_MAX := 0.40
## Un arbre de rue, fosse et reprise comprises. À discuter avec quelqu'un qui
## en a fait planter, comme les 260 €/m² du panneau.
const PLANTATION_PRIX_KE_ARBRE := 1.5
## Planter est rapide, l'ombre ne l'est pas. 🔄 La montée de D07 est de 60 mois
## dans le classeur : trop long pour qu'on voie la concurrence se jouer dans une
## partie, c'est une dette nommée du prototype.
const PLANTATION_MOIS := 24.0
## 🎚️ CE QU'UN ARBRE ÉPARGNE, et c'est le nombre qui décide si la plantation est
## une décision ou une décoration : l'ombre portée sur les façades qu'il borde,
## en MWh/an de moins à consommer. Repère : les 821 emplacements de Wehrau tous
## occupés font 821 fois ce nombre, à comparer aux ~51 GWh de la ville.
const PLANTATION_MWH_ARBRE_AN := 0.25


func charger(d: Dictionary) -> void:
	var o: Dictionary = d["objets"]
	crue = d.get("crue", {})
	for cle in (o.get("berges", {}) as Dictionary):
		berges[int(cle)] = (o["berges"] as Dictionary)[cle]
	for cle in (o["ilots"] as Dictionary):
		ilots[int(cle)] = (o["ilots"] as Dictionary)[cle]
	for cle in (o["routes"] as Dictionary):
		routes[int(cle)] = (o["routes"] as Dictionary)[cle]
	for cle in (d["riverains"] as Dictionary):
		var liste := []
		for f in (d["riverains"] as Dictionary)[cle]:
			liste.append(int(f))
		riverains[int(cle)] = liste

	# 🌳 Les emplacements d'alignement, réduits à leur seuil : c'est tout ce que
	# le noyau a besoin de savoir pour compter des arbres et les faire payer.
	for cle in (d.get("alignements", {}) as Dictionary):
		var s := PackedFloat32Array()
		for a in ((d["alignements"] as Dictionary)[cle] as Array):
			s.append(float(a[5]))
		s.sort()
		_seuils[int(cle)] = s
		# 🔴 CONTRÔLE NOMMÉ : le plafond d'ici et `CANOPEE_ALIGNEMENT_MAX` de
		# `07` sont le MÊME nombre écrit deux fois. S'ils divergent, le curseur
		# promet des arbres qui n'existent pas dans l'export.
		if s.size() > 0 and s[s.size() - 1] > PLANTATION_CANOPEE_MAX + 0.001:
			push_error("plantation : le tronçon %d a un seuil à %.2f, au-dessus du plafond %.2f — voir CANOPEE_ALIGNEMENT_MAX dans 07_exporter_godot.py"
				% [int(cle), s[s.size() - 1], PLANTATION_CANOPEE_MAX])

	# La jauge d'adaptation porte l'urgence vitale : logements à relever et
	# franchissements à rétablir. Le déblaiement des rues reste visible dans le
	# diagnostic, mais ne retient pas indéfiniment l'ouverture de la réduction.
	for fid in ilots:
		if base("i", fid, "logements_sinistres") > 0.0:
			_adaptation_total_ke += base("i", fid, "cout_reparation_ke")
	for fid in routes:
		if str(routes[fid].get("etat_crue", "")) == "coupe":
			_adaptation_total_ke += base("r", fid, "cout_reparation_ke")
	var m := Energie.ville_mwh(self, 0.0)
	_co2_depart_kt = float(m["achat"]) * Energie.CO2_KG_KWH / 1000.0


func objets(couche: String) -> Dictionary:
	match couche:
		"i": return ilots
		"b": return berges
	return routes


## 🌊 L'état de DÉPART se mesure, il ne se choisit pas : une berge que nul mur
## ne tient ne porte pas d'asphalte — elle est déjà rendue au fleuve.
func berge_depart(fid: int) -> int:
	return BERGE_ASPHALTE if base("b", fid, "mur_m") > 1.0 else BERGE_RENATUREE


## L'état VU : la cible une fois le chantier livré, l'état d'avant tant qu'il
## dure. Une berge qui verdirait à l'engagement dirait qu'on plante en un jour.
func berge_etat(fid: int, t: float) -> int:
	if not _berge.has(fid):
		return berge_depart(fid)
	var c: Dictionary = _berge[fid]
	return int(c["cible"]) if t >= float(c["debut"]) + float(c["duree"]) 		else int(c["depuis"])


func berge_cible(fid: int) -> int:
	return int(_berge[fid]["cible"]) if _berge.has(fid) else berge_depart(fid)


func berge_reste_mois(fid: int, t: float) -> float:
	if not _berge.has(fid):
		return 0.0
	var c: Dictionary = _berge[fid]
	return maxf(0.0, float(c["debut"]) + float(c["duree"]) - t)


func berge_en_cours(fid: int, t: float) -> bool:
	return berge_reste_mois(fid, t) > 0.0


## En k€. La différence des deux prix cumulés, sur la longueur de la rive.
func cout_berge_ke(fid: int, cible: int, t: float) -> float:
	var de := berge_etat(fid, t)
	if cible <= de:
		return 0.0
	return (BERGE_PRIX_KE_M[cible] - BERGE_PRIX_KE_M[de]) 		* base("b", fid, "longueur_m")


## `false` si rien à faire, si un chantier court déjà, ou si la caisse ne suit
## pas. Même partage que `lancer_solaire` : l'interface explique, ici le verrou.
## 🔴 UNE BERGE NE REVIENT PAS EN ARRIÈRE. Rendre l'asphalte au fleuve démolit
## un mur ; le refaire serait une autre décision, et elle n'existe pas.
func transformer_berge(fid: int, cible: int, t: float) -> bool:
	if not berges.has(fid) or berge_en_cours(fid, t):
		return false
	var de := berge_etat(fid, t)
	if cible <= de or cible > BERGE_RENATUREE:
		return false
	var cout := cout_berge_ke(fid, cible, t)
	if cout > caisse_ke(t):
		return false
	_berge[fid] = {"cible": cible, "depuis": de, "debut": t,
		"duree": BERGE_MOIS[cible] - BERGE_MOIS[de], "cout_ke": cout}
	_depense_ke += cout
	return true


## 🌊 CE QU'UNE BERGE REND AU FLEUVE, en mètres de largeur : l'asphalte posé
## au-dessus de l'Ilse dès le quai apaisé, la bande de rive en plus une fois
## renaturée. Les deux sont MESURÉS sur la carte — aucun n'est un réglage, et
## c'est ce qui fait qu'une berge large rachète plus qu'une berge étroite.
func berge_largeur_rendue_m(fid: int, etat: int) -> float:
	if etat <= BERGE_ASPHALTE:
		return 0.0
	var lg := base("b", fid, "longueur_m")
	var l := (base("b", fid, "debord_m2") / lg) if lg > 0.0 else 0.0
	if etat >= BERGE_RENATUREE:
		l += float(crue.get("berge_bande_m", 0.0))
	return l


## En mètres de crue annoncée en moins, une fois le chantier LIVRÉ : `berge_etat`
## ne bascule qu'à la livraison, donc la protection non plus.
## 🔴 DEPUIS L'ÉTAT DE DÉPART, jamais depuis l'asphalte. Les berges 4 et 8 n'ont
## pas de mur : elles partent renaturées, et l'`alea` exporté par `04e` les
## compte déjà. Les créditer au mois 0 protègerait la ville d'une crue qui a
## déjà eu lieu.
func berge_baisse_m(fid: int, t: float) -> float:
	return (berge_largeur_rendue_m(fid, berge_etat(fid, t))
		- berge_largeur_rendue_m(fid, berge_depart(fid))) * BERGE_BAISSE_M_PAR_M


## Ce que les berges livrées retirent à la crue annoncée SUR CET ÎLOT. Une berge
## ne soulage que le bief qu'elle borde — mais sur les DEUX rives, car c'est la
## même section qui s'élargit. Les deux berges d'un bief s'additionnent : finir
## un bief vaut mieux qu'effleurer les quatre.
func baisse_crue_m(fid: int, t: float) -> float:
	var fil := base("i", fid, "position_fil_eau")
	# 🌿 Les toits verts entrent ICI, et pour toute la ville : ce qui n'est pas
	# tombé dans les gouttières n'arrive pas dans l'Ilse, où que soit le toit.
	var v := baisse_crue_toits_m(t)
	for b in berges:
		if fil >= base("b", b, "fil_amont") - 0.001 \
				and fil <= base("b", b, "fil_aval") + 0.001:
			v += berge_baisse_m(b, t)
	return v


## Les îlots qu'une berge soulage, du plus exposé au moins. La fiche en a besoin
## AVANT de décider : sans eux, 763 k€ s'engagent sans contrepartie lisible.
func ilots_du_bief(fid_berge: int) -> Array:
	var a0 := base("b", fid_berge, "fil_amont") - 0.001
	var a1 := base("b", fid_berge, "fil_aval") + 0.001
	var out := []
	for f in ilots:
		var fil := base("i", f, "position_fil_eau")
		if fil >= a0 and fil <= a1 and base("i", f, "part_ruinee_apres") > 0.0:
			out.append(f)
	out.sort_custom(func(x, y): return base("i", x, "alea") > base("i", y, "alea"))
	return out


## 🌊 LES TROIS CHAMPS QUE LA BERGE DÉPLACE. La hauteur d'eau annoncée perd les
## mètres rachetés, `alea` la suit, et `part_ruinee_apres` se lit sur la courbe
## que `04e` a mesurée bâtiment par bâtiment — le profil de terrain n'existe pas
## ici, on ne le réinvente pas.
func _crue_apres_berges(fid: int, champ: String, t: float) -> float:
	var baisse := baisse_crue_m(fid, t)
	if champ == "part_ruinee_apres":
		return _sur_la_courbe(fid, baisse)
	var h := maxf(0.0, base("i", fid, "hauteur_eau_annonce") - baisse)
	if champ == "hauteur_eau_annonce":
		return h
	var niveau := float(crue.get("niveau_annonce_m", 0.0))
	return 0.0 if niveau <= 0.0 else clampf(h / niveau, 0.0, 1.0)


## Les 11 paliers de `04e`, interpolés. Au-delà du dernier on garde le dernier :
## une baisse plus forte que tout ce qui a été mesuré ne doit pas sortir un
## nombre inventé.
func _sur_la_courbe(fid: int, baisse: float) -> float:
	var c: Array = ilots.get(fid, {}).get("ruine_apres_baisse", [])
	var paliers: Array = crue.get("baisses_m", [])
	if c.is_empty() or paliers.size() != c.size():
		return base("i", fid, "part_ruinee_apres")
	if baisse <= float(paliers[0]):
		return float(c[0])
	for k in range(1, c.size()):
		var p0 := float(paliers[k - 1])
		var p1 := float(paliers[k])
		if baisse <= p1:
			return lerpf(float(c[k - 1]), float(c[k]),
				0.0 if p1 <= p0 else (baisse - p0) / (p1 - p0))
	return float(c[c.size() - 1])


func base(couche: String, fid: int, champ: String) -> float:
	var o: Dictionary = objets(couche).get(fid, {})
	var v: Variant = o.get(champ)
	return 0.0 if v == null else float(v)


## La base plus les rampes en cours. Un champ préfixé `_` se CALCULE, côté
## énergie ; fiche, calques et ciblage passent tous par ici, donc voient les
## mêmes nombres sans savoir qui les fabrique (décision 41).
##
## Les bornes ne sont pas cosmétiques : sans elles une canopée dépasse 1 et
## l'indicateur ment. Les champs calculés, eux, échappent à `_borner` — une
## friche peut EXPORTER.
func valeur(couche: String, fid: int, champ: String, t: float) -> float:
	if champ.begins_with("_"):
		return Energie.derive(self, fid, champ, t) if couche == "i" else 0.0
	# 🌊 La berge passe AVANT les rampes : ces trois champs n'en portent aucune,
	# et c'est ici que la seule contrepartie non monétaire du jeu entre.
	if couche == "i" and champ in ["alea", "part_ruinee_apres",
			"hauteur_eau_annonce"]:
		return _crue_apres_berges(fid, champ, t)
	var v := base(couche, fid, champ)
	for r in _rampes[couche].get(fid, []):
		if r["champ"] == champ:
			v += float(r["ecart"]) * avancement(t, r["d"], r["L"], r["M"])
	return _borner(champ, v)


static func _borner(champ: String, v: float) -> float:
	match champ:
		"canopee", "impermeabilise", "riverain", "alea", "charge", "desserte_tc", \
		"part_toit_equipe", "part_rendue", "part_toit_vert", "part_isolee", \
		"part_dense":
			return clampf(v, 0.0, 1.0)
		"emprise_libre_m", "stationnement", "logements", "emplois":
			return maxf(v, 0.0)
	return v


## La rampe du Classeur §4 : délai, montée, plein effet. En continu, le temps
## ne sautant pas de mois en mois ici.
static func avancement(t: float, d: float, L: float, M: float) -> float:
	if t < d + L:
		return 0.0
	if M <= 0.0:
		return 1.0
	return clampf((t - d - L) / M, 0.0, 1.0)


func ajouter_rampe(couche: String, fid: int, champ: String, ecart: float,
		d: float, L: float, M: float) -> void:
	_vert_ha_mois = INF
	if not _rampes[couche].has(fid):
		_rampes[couche][fid] = []
	_rampes[couche][fid].append({
		"champ": champ, "ecart": ecart, "d": d, "L": L, "M": M,
	})


func vider_rampes() -> void:
	_vert_ha_mois = INF
	_rampes = {"i": {}, "r": {}}


## Le temps qu'on met à enlever des places : deux mois de peinture et de
## panneaux. C'est la barre de la fiche qui le lit aussi (`chantier`).
const STATIONNEMENT_MOIS := 2.0


func supprimer_stationnement(fid: int, t: float) -> bool:
	if _stationnement_supprime.has(fid):
		return false
	var actuel := valeur("r", fid, "stationnement", t)
	if actuel <= 0.0:
		return false
	_stationnement_supprime[fid] = t
	ajouter_rampe("r", fid, "stationnement", -actuel, t, 0.0, STATIONNEMENT_MOIS)
	return true


func stationnement_en_suppression(fid: int) -> bool:
	return _stationnement_supprime.has(fid)


# ------------------------------------------------------------ planter une rue

## Combien d'arbres sont en terre à cette canopée-là. Un COMPTE, pas une part :
## c'est ce qu'on paie, et c'est exactement ce qu'on voit à l'écran — les mêmes
## seuils servent au prix, à l'économie d'énergie et au rendu.
func arbres_a(fid: int, canopee: float) -> int:
	var n := 0
	for seuil in _seuils.get(fid, PackedFloat32Array()):
		if seuil <= canopee:
			n += 1
	return n


## Ce que la rue porterait plantée de bout en bout. 0 = pas la place d'un arbre
## entre la chaussée et la limite d'emprise ; `07` l'a déjà tranché.
func arbres_plantables(fid: int) -> int:
	return arbres_a(fid, PLANTATION_CANOPEE_MAX)


func cout_plantation_ke(fid: int, cible: float, t: float) -> float:
	var neufs := arbres_a(fid, cible) - arbres_a(fid, valeur("r", fid, "canopee", t))
	return maxf(neufs, 0) * PLANTATION_PRIX_KE_ARBRE


## `false` si la rue n'est pas plantable, si un chantier y court déjà, si la
## cible ne dépasse pas l'existant ou si la caisse ne suit pas. Même partage que
## `lancer_solaire` : l'interface pré-vérifie et explique, ici le verrou seul.
func planter(fid: int, cible: float, t: float) -> bool:
	if not routes.has(fid) or _plantation.has(fid):
		return false
	var actuelle := valeur("r", fid, "canopee", t)
	var c := clampf(cible, 0.0, PLANTATION_CANOPEE_MAX)
	var neufs := arbres_a(fid, c) - arbres_a(fid, actuelle)
	if neufs <= 0:
		return false
	var cout := float(neufs) * PLANTATION_PRIX_KE_ARBRE
	if cout > caisse_ke(t) + 0.001:
		return false
	ajouter_rampe("r", fid, "canopee", c - actuelle, t, 0.0, PLANTATION_MOIS)
	_plantation[fid] = {"debut": t, "duree": PLANTATION_MOIS, "cible": c,
		"cout_ke": cout, "arbres": neufs}
	_depense_ke += cout
	return true


func plantation_reste_mois(fid: int, t: float) -> float:
	if not _plantation.has(fid):
		return 0.0
	return maxf(float(_plantation[fid]["debut"])
		+ float(_plantation[fid]["duree"]) - t, 0.0)


func plantation_en_cours(fid: int, t: float) -> bool:
	return plantation_reste_mois(fid, t) > 0.0


## 🌳 CE QUE LES ARBRES ÉPARGNENT À LA VILLE, en MWh/an, DEPUIS LE MOIS 0 — pas
## en absolu : la canopée de départ est déjà dans la consommation de base, et la
## compter deux fois ferait bouger le t0 sans qu'on ait rien décidé.
## ⚠️ Un ESCALIER, pas une courbe : on compte les arbres réellement en terre à
## la canopée du moment. C'est ce qui fait que le chiffre et l'image disent la
## même chose — un arbre de plus à l'écran, un arbre de plus au compteur.
func economie_plantation_mwh(t: float) -> float:
	var n := 0
	for fid in _plantation:
		n += arbres_a(fid, valeur("r", fid, "canopee", t)) \
			- arbres_a(fid, base("r", fid, "canopee"))
	return float(n) * PLANTATION_MWH_ARBRE_AN


## Une rue envasée ou un tablier emporté ne redevient praticable qu'à la fin
## de son chantier. Le prix exporté est le seul marqueur commun aux deux cas.
func route_praticable(fid: int, t: float) -> bool:
	return base("r", fid, "cout_reparation_ke") <= 0.0 \
		or reparation_finie("r", fid, t)


## Retour au mois 0. Rien n'ayant été écrit en base, il n'y a rien d'autre à
## défaire — et ni géométrie ni caméra ne sont concernées.
func reinitialiser() -> void:
	_solaire.clear()
	_recherche.clear()
	_politiques.clear()
	_vert.clear()
	_stationnement_supprime.clear()
	_dense.clear()
	_plantation.clear()
	_berge.clear()
	_depense_ke = 0.0
	_credit_essai_ke = 0.0
	# Les toits reconstruits redeviennent des ruines : `toit_m2` est la seule
	# donnée que `reparer` écrit en base, donc la seule à défaire.
	for fid in _toit_avant:
		ilots[fid]["toit_m2"] = _toit_avant[fid]
	_toit_avant.clear()
	_repare.clear()
	vider_rampes()


## En k€, depuis la part atteinte au mois `t`. Annoncé par la fiche avant
## validation.
func cout_solaire_ke(fid: int, part: float, t: float) -> float:
	if not ilots.has(fid):
		return 0.0
	return Energie.cout_pose_ke(self, fid,
		valeur("i", fid, "part_toit_equipe", t), clampf(part, 0.0, 1.0), t)


## `false` si rien n'est lancé (cible trop basse, chantier en cours, caisse
## insuffisante). L'interface pré-vérifie et explique ; ici, le verrou seul.
##
## 🔴 La rampe s'AJOUTE. Réécrire l'histoire de la pose fausserait la recette
## encaissée, qui en est l'intégrale — d'où le prix payé : une pose engagée ne
## se révise plus.
## 🔄 RETOUR EN ARRIÈRE SIGNALÉ (2026-08-31) : la décision 72 verrouillait TOUTE
## décision de réduction tant que les logements sinistrés et les trois ponts
## n'étaient pas relevés. Mesuré : 14 445 k€ de seuil pour 8 000 k€ de caisse en
## vingt ans — le solaire n'existait plus dans la partie. Réparer et équiper se
## disputent maintenant la même caisse dès le mois 0, et c'est ça, l'arbitrage.
func lancer_solaire(fid: int, part: float, t: float) -> bool:
	if not ilots.has(fid) or etat_solaire(fid, t)["en_cours"]:
		return false
	if Energie.toit_equipable_m2(self, fid) <= 0.0:
		return false
	var actuelle := valeur("i", fid, "part_toit_equipe", t)
	var cible := clampf(minf(part, part_solaire_max(fid, t)), 0.0, 1.0)
	if cible <= actuelle + 0.0001:
		return false

	# ⚠️ Le coût se lit AVANT la rampe : `caisse_ke` intègre les rampes
	# existantes, et la nouvelle n'a encore rien rapporté.
	var cout := Energie.cout_pose_ke(self, fid, actuelle, cible, t)
	if cout > caisse_ke(t) + 0.001:
		return false

	var duree := duree_solaire_mois(actuelle, cible)
	ajouter_rampe("i", fid, "part_toit_equipe", cible - actuelle, t, 0.0, duree)
	# 🪜 LA SECONDE RAMPE, ET ELLE EST LE RENDEMENT. Ce chantier-ci gagne un
	# écart FIXE de production ; posé comme une rampe droite, il s'intègre
	# exactement, alors qu'une courbe relue chaque image ne s'intégrerait pas.
	ajouter_rampe("i", fid, "part_rendue",
		Energie.courbe_rendue(cible) - Energie.courbe_rendue(actuelle),
		t, 0.0, duree)
	_solaire[fid] = {"debut": t, "duree": duree, "cible": cible, "cout_ke": cout}
	_depense_ke += cout
	return true


func duree_solaire_mois(depart: float, cible: float) -> float:
	return maxf(cible - depart, 0.0) * SOLAIRE_MOIS_POUR_100


## De quoi distinguer la cible du réalisé.
func etat_solaire(fid: int, t: float) -> Dictionary:
	var actuel := valeur("i", fid, "part_toit_equipe", t)
	var c: Dictionary = _solaire.get(fid, {})
	var cible: float = maxf(actuel, float(c.get("cible", actuel)))
	var fin: float = float(c.get("debut", t)) + float(c.get("duree", 0.0))
	return {
		"actuel": actuel,
		"cible": cible,
		"reste_mois": maxf(fin - t, 0.0),
		"en_cours": cible > actuel + 0.0001 and t < fin,
		"a_commence": not c.is_empty(),
		"cout_ke": float(c.get("cout_ke", 0.0)),   # celui du DERNIER chantier
	}


# ------------------------------------------------------------- le toit vert

## 🌿 LE PARTAGE DU TOIT, écrit UNE FOIS et lu par les deux curseurs. Ce que
## l'autre décision a posé ou vise est retiré du plafond : le 100 % est celui du
## TOIT, pas celui d'un curseur.
func part_solaire_max(fid: int, t: float) -> float:
	return clampf(1.0 - etat_vert(fid, t)["cible"], 0.0, 1.0)


## Ce que la pente laisse, moins ce que les panneaux prennent. Un îlot tout en
## versants rend 0, et la fiche n'affiche alors pas le bloc.
func part_vert_max(fid: int, t: float) -> float:
	return clampf(minf(Energie.part_plate(self, fid),
		1.0 - etat_solaire(fid, t)["cible"]), 0.0, 1.0)


## En k€, depuis la part atteinte au mois `t`.
func cout_vert_ke(fid: int, part: float, t: float) -> float:
	if not ilots.has(fid):
		return 0.0
	return Energie.cout_vert_ke(self, fid,
		valeur("i", fid, "part_toit_vert", t), clampf(part, 0.0, 1.0), t)


## Même partage que `lancer_solaire` : l'interface pré-vérifie et explique, ici
## le verrou seul — et la rampe s'AJOUTE, pour la même raison.
func lancer_vert(fid: int, part: float, t: float) -> bool:
	if not ilots.has(fid) or etat_vert(fid, t)["en_cours"]:
		return false
	if Energie.toit_plat_equipable_m2(self, fid) <= 0.0:
		return false
	var actuelle := valeur("i", fid, "part_toit_vert", t)
	var cible := clampf(minf(part, part_vert_max(fid, t)), 0.0, 1.0)
	if cible <= actuelle + 0.0001:
		return false
	var cout := Energie.cout_vert_ke(self, fid, actuelle, cible, t)
	if cout > caisse_ke(t) + 0.001:
		return false
	var duree := duree_vert_mois(actuelle, cible)
	ajouter_rampe("i", fid, "part_toit_vert", cible - actuelle, t, 0.0, duree)
	_vert[fid] = {"debut": t, "duree": duree, "cible": cible, "cout_ke": cout}
	_vert_ha_mois = INF
	_depense_ke += cout
	return true


func duree_vert_mois(depart: float, cible: float) -> float:
	return maxf(cible - depart, 0.0) * TOIT_VERT_MOIS_POUR_100


func etat_vert(fid: int, t: float) -> Dictionary:
	var actuel := valeur("i", fid, "part_toit_vert", t)
	var c: Dictionary = _vert.get(fid, {})
	var cible: float = maxf(actuel, float(c.get("cible", actuel)))
	var fin: float = float(c.get("debut", t)) + float(c.get("duree", 0.0))
	return {
		"actuel": actuel,
		"cible": cible,
		"reste_mois": maxf(fin - t, 0.0),
		"en_cours": cible > actuel + 0.0001 and t < fin,
		"a_commence": not c.is_empty(),
		"cout_ke": float(c.get("cout_ke", 0.0)),
	}


## La somme de ville du dernier mois demandé. `degats()` la redemandait une fois
## PAR ÎLOT — 71 × 71 passages par image, 5,2 ms. La clé est le mois AU BIT PRÈS
## et non « à peu près » : dans une image tous les appels partagent le même mois,
## d'une image à l'autre il change, et toute décision qui verdit remet INF.
var _vert_ha_mois := INF
var _vert_ha := 0.0


## 🌿 EN HECTARES VERDIS DANS TOUTE LA VILLE — le seul terme de la crue qui ne
## vienne pas du fleuve. La pluie retenue sur un toit du plateau soulage l'Ilse
## autant que celle d'un toit de berge : ici, aucun bief.
func toit_vert_ha(t: float) -> float:
	if t == _vert_ha_mois:
		return _vert_ha
	var m2 := 0.0
	for fid in fids_batis():
		m2 += Energie.toit_vert_m2(self, fid, t)
	_vert_ha_mois = t
	_vert_ha = m2 / 10000.0
	return _vert_ha


## En mètres de crue annoncée en moins, partout. Sur ce qui est LIVRÉ :
## `part_toit_vert` monte en rampe, donc la protection aussi.
func baisse_crue_toits_m(t: float) -> float:
	return toit_vert_ha(t) * TOIT_VERT_BAISSE_M_PAR_HA


# ============================================== densifier (auteur, 2026-09-03)

# 🏢 UN ÉTAGE OU DEUX, DU BÂTIMENT LE PLUS BAS AU PLUS HAUT. Ces cinq nombres
# sont du LEVEL DESIGN. Repère : la dotation est de 30 k€/mois, la caisse de
# 800 k€, et 07 dit combien de logements un étage ajoute par îlot.
# ⚠️ Le patrimoine ne monte pas, et c'est 07 qui le sait (DENSE_INTERDIT) : ici,
# un îlot qui ne peut pas monter annonce simplement zéro bâtiment.
const DENSE_ETAGES_MAX := 2
const DENSE_ETAGE_M := 2.7                # le même étage que 07 (ETAGE_M)
const DENSE_PRIX_KE_LOGEMENT := 95.0      # poser un logement sur de l'existant
const DENSE_MOIS_PAR_ETAGE := 18.0        # les bâtiments montent l'un après l'autre
# 🔴 LE CONTRÔLE NOMMÉ DE LA DETTE 59 — une densification pure ne doit pas
# s'autofinancer. Loyer net moins entretien laisse 0,25 k€ par logement et par
# mois : 380 mois pour rembourser une pose, contre 240 de partie.
const DENSE_LOYER_KE_MOIS_LOGEMENT := 0.42
const DENSE_CHARGE_KE_MOIS_LOGEMENT := 0.17


## Combien de bâtiments de cet îlot ont le droit de monter. 0 = pas de menu,
## et c'est aussi le NOMBRE DE CRANS du curseur : un cran, un bâtiment.
func dense_batiments(fid: int) -> int:
	return int(base("i", fid, "dense_n"))


## Les logements qu'UN étage ajoute sur TOUS les bâtiments montables — mesuré
## par 07 sur les emprises qui montent, au même m² brut par logement que le
## plancher de 04d.
func dense_logements_etage(fid: int) -> int:
	return int(base("i", fid, "dense_logements_etage"))


## 🪜 LE PROFIL DES PALIERS, posé par 07 : `[k]` = la part de l'emprise qui
## monte atteinte aux k+1 premiers bâtiments. Un export d'avant le 2026-09-03
## n'en a pas ; on retombe alors sur des bâtiments de poids égal.
func dense_cumul(fid: int) -> Array:
	var v: Variant = ilots.get(fid, {}).get("dense_cumul")
	return v as Array if v is Array else []


## La part des LOGEMENTS atteinte quand la part `part` des BÂTIMENTS est montée.
## Les deux ne vont pas au même rythme : monter le plus petit bâtiment ne loge
## pas autant que monter le plus grand.
func dense_part_logements(fid: int, part: float) -> float:
	var n := dense_batiments(fid)
	if n <= 0:
		return 0.0
	var c := dense_cumul(fid)
	var x := clampf(part, 0.0, 1.0) * float(n)
	if c.size() != n:
		return x / float(n)
	var k := int(floor(x))
	if k >= n:
		return 1.0
	return lerpf(0.0 if k == 0 else float(c[k - 1]), float(c[k]), x - float(k))


## Le cran le plus proche : le curseur ne s'arrête qu'entre deux bâtiments.
func dense_cran(fid: int, part: float) -> float:
	var n := dense_batiments(fid)
	if n <= 0:
		return 0.0
	return clampf(roundf(clampf(part, 0.0, 1.0) * float(n)) / float(n), 0.0, 1.0)


## Les étages arrêtés pour cet îlot, 0 si rien n'est encore engagé. 🔴 Ils se
## choisissent UNE FOIS : le shader n'a qu'une hauteur pour tout l'îlot, donc
## deux bâtiments ne peuvent pas monter de deux nombres d'étages différents.
func dense_etages(fid: int) -> int:
	return int((_dense.get(fid, {}) as Dictionary).get("etages", 0))


func dense_engage(fid: int) -> bool:
	return _dense.has(fid)


## En k€, de la part `de` à la part `vers` des bâtiments.
## 🪜 Progressif comme les panneaux, et pour la même raison : 07 range les
## bâtiments DU PLUS BAS AU PLUS HAUT, donc les premiers montés sont les moins
## chers. Monter l'îlot ENTIER coûte le même prix qu'avant — seul l'ordre change.
func cout_dense_ke(fid: int, de: float, vers: float, etages: int) -> float:
	var e := mini(etages, DENSE_ETAGES_MAX)
	if e <= 0:
		return 0.0
	return float(dense_logements_etage(fid)) * float(e) \
		* maxf(Energie.courbe_payee(dense_part_logements(fid, vers))
			- Energie.courbe_payee(dense_part_logements(fid, de)), 0.0) \
		* DENSE_PRIX_KE_LOGEMENT


## Les bâtiments montent l'un après l'autre : n'en monter que la moitié prend
## la moitié du temps.
func duree_dense_mois(etages: int, de: float, vers: float) -> float:
	return DENSE_MOIS_PAR_ETAGE * float(mini(etages, DENSE_ETAGES_MAX)) \
		* maxf(vers - de, 0.0)


## Les logements ajoutés par la tranche, étages compris.
func dense_logements_tranche(fid: int, de: float, vers: float, etages: int) -> float:
	return (dense_part_logements(fid, vers) - dense_part_logements(fid, de)) \
		* float(dense_logements_etage(fid)) * float(mini(etages, DENSE_ETAGES_MAX))


## Engage une TRANCHE de bâtiments, et c'est définitif : un étage ne se
## démolit pas. Le curseur repart ensuite du cran atteint — même partage que
## `lancer_solaire` : l'interface pré-vérifie et explique, ici le verrou seul.
## 🔴 `logements` monte en RAMPE, donc tout ce qui le lit suit la montée des
## bâtiments et non l'engagement — la fiche, l'écart au mois 0, et la
## consommation d'énergie, qui est proportionnelle aux logements. Densifier
## est donc aussi ce qui fait remonter la facture de la ville.
func densifier(fid: int, part: float, etages: int, t: float) -> bool:
	if dense_batiments(fid) <= 0 or dense_logements_etage(fid) <= 0:
		return false
	var etat := etat_dense(fid, t)
	if etat["en_cours"]:
		return false
	var e: int = int(etat["etages"]) if int(etat["etages"]) > 0 \
		else mini(etages, DENSE_ETAGES_MAX)
	if e <= 0:
		return false
	var de: float = float(etat["cible"])
	var vers := clampf(dense_cran(fid, part), de, 1.0)
	if vers <= de + 0.0001:
		return false
	var cout := cout_dense_ke(fid, de, vers, e)
	if cout > caisse_ke(t) + 0.001:
		return false
	var duree := duree_dense_mois(e, de, vers)
	var neufs := dense_logements_tranche(fid, de, vers, e)
	var lots: Array = (_dense.get(fid, {}) as Dictionary).get("lots", []) as Array
	lots.append({"debut": t, "duree": duree, "logements": neufs})
	_dense[fid] = {"debut": t, "duree": duree, "etages": e, "cible": vers,
		"cout_ke": cout, "lots": lots}
	_depense_ke += cout
	ajouter_rampe("i", fid, "part_dense", vers - de, t, 0.0, duree)
	ajouter_rampe("i", fid, "logements", neufs, t, 0.0, duree)
	return true


## Ce que le shader a besoin de savoir — l'avancement, la part d'UN bâtiment et
## les mètres gagnés — et ce que la fiche annonce.
## 🪜 `avancement` est désormais la part LIVRÉE (`part_dense`), pas une rampe
## reconstruite : un îlot densifié en trois fois a trois chantiers derrière lui,
## et le shader n'en voit qu'un seul nombre.
func etat_dense(fid: int, t: float) -> Dictionary:
	var c: Dictionary = _dense.get(fid, {})
	var n := dense_batiments(fid)
	var etages := int(c.get("etages", 0))
	var actuel := valeur("i", fid, "part_dense", t)
	var cible: float = maxf(actuel, float(c.get("cible", actuel)))
	var fin: float = float(c.get("debut", t)) + float(c.get("duree", 0.0))
	return {
		"etages": etages,
		"batiments": n,
		"actuel": actuel,
		"cible": cible,
		"montes": int(roundf(actuel * float(n))),
		"vises": int(roundf(cible * float(n))),
		"logements": dense_logements_tranche(fid, 0.0, actuel, etages),
		"logements_vises": dense_logements_tranche(fid, 0.0, cible, etages),
		"cout_ke": float(c.get("cout_ke", 0.0)),   # celui du DERNIER chantier
		"avancement": actuel,
		"pas": 1.0 / maxf(float(n), 1.0),
		"metres": float(etages) * DENSE_ETAGE_M,
		"reste_mois": maxf(fin - t, 0.0),
		"en_cours": cible > actuel + 0.0001 and t < fin,
		"a_commence": not c.is_empty(),
	}


## En k€ depuis le mois 0, sur ce qui est LIVRÉ : l'intégrale des rampes, donc
## un logement ne paie qu'à partir du mois où il est habitable.
func solde_dense_ke(t: float) -> float:
	var s := 0.0
	for fid in _dense:
		for lot in ((_dense[fid] as Dictionary)["lots"] as Array):
			s += float(lot["logements"]) * _integrale_avancement(
				t, float(lot["debut"]), 0.0, float(lot["duree"]))
	return s * (DENSE_LOYER_KE_MOIS_LOGEMENT - DENSE_CHARGE_KE_MOIS_LOGEMENT)


# ================================== l'université et la mairie (décisions 79 · 80)

## Le coefficient d'un prix ou d'un rendement : les paliers acquis ET les
## politiques en vigueur, multipliés. Le seul point d'entrée — `energie.gd` ne
## sait pas d'où vient le coefficient.
func facteur(effet: String, t: float) -> float:
	return Recherche.facteur(self, effet, t) * Politiques.facteur(self, effet, t)


## `false` si le sujet est déjà financé, ou si la caisse ne tient pas le premier
## mois. Une fois engagé, il court jusqu'au palier : c'est un chantier.
func financer_recherche(cle: String, t: float) -> bool:
	if not Recherche.SUJETS.has(cle) or _recherche.has(cle):
		return false
	if caisse_ke(t) < float(Recherche.SUJETS[cle]["ke_mois"]):
		return false
	_recherche[cle] = t
	return true


## Signer, ou retirer. 🔴 Retirer arrête la dépense et ne rembourse rien ;
## re-signer ouvre une nouvelle période.
func basculer_politique(cle: String, t: float) -> bool:
	if not Politiques.POLITIQUES.has(cle):
		return false
	if not _politiques.has(cle):
		_politiques[cle] = []
	var p: Array = _politiques[cle]
	if Politiques.active(self, cle):
		p[-1][1] = t
	else:
		p.append([t, -1.0])
	return true


func recherche_engagee(cle: String) -> bool:
	return _recherche.has(cle)


## Ce que l'université et la mairie prélèvent CE mois-ci, en k€.
func charge_mensuelle_ke(t: float) -> float:
	var ke := 0.0
	for cle in _recherche:
		if not Recherche.acquis(self, cle, t):
			ke += float(Recherche.SUJETS[cle]["ke_mois"])
	for cle in _politiques:
		if Politiques.active(self, cle):
			ke += float(Politiques.POLITIQUES[cle]["ke_mois"])
	return ke


# ==================================================================== la caisse

## ∫ `part_rendue` de 0 à `t`, en « part × mois » : combien de temps chaque
## panneau a produit. 🪜 `part_rendue` et non `part_toit_equipe` — c'est le
## rendement qu'on encaisse, pas la surface.
## 🔴 Exacte, et c'est l'intérêt : le solde doit être le même à 5 ou 500 images
## par seconde, et l'essai saute 1,5 mois d'un coup.
func _integrale_part(fid: int, t: float) -> float:
	var s := base("i", fid, "part_rendue") * t
	for r in _rampes["i"].get(fid, []):
		if r["champ"] == "part_rendue":
			s += float(r["ecart"]) * _integrale_avancement(t, r["d"], r["L"], r["M"])
	return s


## ∫ `avancement` de 0 à t : la primitive de la rampe du Classeur §4.
static func _integrale_avancement(t: float, d: float, L: float, M: float) -> float:
	var u := t - d - L
	if u <= 0.0:
		return 0.0
	if M <= 0.0:
		return u
	if u < M:
		return u * u / (2.0 * M)
	return M * 0.5 + (u - M)


## En k€ depuis le mois 0.
## ⚠️ Le potentiel est sorti de l'intégrale : c'est la canopée de L'ÎLOT qui
## ombre ses toits, et aucune décision ne la fait bouger. 🔄 Planter, depuis le
## 2026-08-31, monte `routes.canopee` — une autre couche, sans effet ici. À
## reprendre le jour où une décision plantera DANS un îlot.
func recette_cumulee_ke(t: float) -> float:
	var ke := 0.0
	for fid in fids_batis():
		var pot := Energie.potentiel_mwh(self, fid, t)
		if pot > 0.0:
			ke += pot * _integrale_part_rendue(fid, t) / 12.0 \
				* Energie.PRIX_ENERGIE_EUR_MWH / 1000.0
	return ke


## ∫ `part` × le rendement du moment. 🔴 C'est ici que le palier de 79 est
## RÉTROACTIF sans être un cadeau : il vaut pour tout ce qui est déjà posé, à
## partir du mois où il tombe — jamais pour les MWh vendus avant lui.
func _integrale_part_rendue(fid: int, t: float) -> float:
	var m := Recherche.marches(self, "rendement_x")
	if m.size() == 1:
		return _integrale_part(fid, t)
	var s := 0.0
	for i in m.size():
		var bas: float = minf(float(m[i][0]), t)
		var haut: float = minf(float(m[i + 1][0]), t) if i + 1 < m.size() else t
		if haut > bas:
			s += float(m[i][1]) * (_integrale_part(fid, haut) - _integrale_part(fid, bas))
	return s


## En k€. Fonction PURE du temps et des chantiers engagés : « Recommencer »
## n'a rien à rembobiner, et deux parties jouées pareil donnent le même solde.
func caisse_ke(t: float) -> float:
	return CAISSE_DEPART_KE + DOTATION_KE_MOIS * t \
		+ recette_cumulee_ke(t) + solde_dense_ke(t) + _credit_essai_ke \
		- _depense_ke \
		- Recherche.depense_ke(self, t) - Politiques.depense_ke(self, t)


## 🧪 Le bouton d'essai. Rendu à zéro par « Recommencer », comme tout le reste.
func crediter_essai_ke(montant: float) -> void:
	_credit_essai_ke += maxf(montant, 0.0)


func fids_batis() -> Array:
	var out := []
	for fid in ilots:
		if ilots[fid].get("fonction") != "riviere":
			out.append(fid)
	return out


## Les quatre nombres de l'énergie (PLAN §3). Des SOMMES, pas des moyennes
## (décision 63). En MWh : c'est là que l'invariant achat + production = conso
## se vérifie.
##
## 🔄 Une `facture` montant de 2 %/an vivait ici ; partie avec la caisse, car
## deux monnaies — une qu'on paie, une qu'on ne paie pas — se contredisaient.
## Toujours calculable via `Energie.facture_ke`, mais plus affichée.
##
## ⚠️ CO2 de l'énergie ACHETÉE seulement ; l'interface et l'essai y ajoutent
## `chantiers.co2_gris_an(t)`.
func indicateurs(t: float) -> Dictionary:
	var m := Energie.ville_mwh(self, t)
	var co2 := float(m["achat"]) * Energie.CO2_KG_KWH / 1000.0
	var out := {
		"conso_mwh": m["conso"],
		"production_mwh": m["production"],
		"achat_mwh": m["achat"],
		"co2_kt": co2,
		# La petite économie : ce que les panneaux posés rapportent chaque année,
		# et ce qui reste en caisse après les avoir payés.
		"recette_ke_an": m["production"] * Energie.PRIX_ENERGIE_EUR_MWH / 1000.0,
		"caisse_ke": caisse_ke(t),
	}
	out.merge(durabilite(t, co2))
	return out


# --------------------------------------------------- réparer après la crue

## Ce que `04e` a chiffré pour cet objet, 0 s'il n'y a rien à réparer ou si
## c'est déjà payé.
func cout_reparation_ke(couche: String, fid: int) -> float:
	if est_repare(couche, fid):
		return 0.0
	return base(couche, fid, "cout_reparation_ke")


func est_repare(couche: String, fid: int) -> bool:
	return _repare.has(couche + ":" + str(fid))


## Combien de mois dure CE chantier-là. Un pont n'est pas une rue.
func duree_reparation_mois(couche: String, fid: int) -> float:
	if couche == "i":
		return RECONSTRUCTION_MOIS
	var coupe := str(objets("r").get(fid, {}).get("etat_crue", "")) == "coupe"
	return PONT_MOIS if coupe else DEBLAIEMENT_MOIS


## Ce qui reste avant que la géométrie neuve n'apparaisse. 0 = c'est fini.
func reste_reparation_mois(couche: String, fid: int, t: float) -> float:
	var cle := couche + ":" + str(fid)
	if not _repare.has(cle):
		return 0.0
	return maxf(float(_repare[cle]) + duree_reparation_mois(couche, fid) - t, 0.0)


## `true` quand le chantier est terminé : c'est CE test que la maquette
## interroge pour montrer le maillage neuf. Une géométrie qui apparaîtrait à
## l'engagement dirait qu'un pont se rebâtit en une image.
func reparation_finie(couche: String, fid: int, t: float) -> bool:
	return est_repare(couche, fid) and reste_reparation_mois(couche, fid, t) <= 0.0


## Les deux jauges de durabilité. L'adaptation avance au rythme réel des
## chantiers essentiels ; la réduction mesure le CO₂ évité depuis t0.
## 🔄 Elles avancent ENSEMBLE depuis le 2026-08-31 : la réduction n'attend plus
## la fin de l'urgence (voir `lancer_solaire`).
func durabilite(t: float, co2_kt: float) -> Dictionary:
	var reste_ke := 0.0
	var logements := 0.0
	var ponts := 0
	for fid in ilots:
		var perdus := base("i", fid, "logements_sinistres")
		if perdus <= 0.0:
			continue
		var part := 1.0
		if est_repare("i", fid):
			part = clampf(reste_reparation_mois("i", fid, t) \
				/ RECONSTRUCTION_MOIS, 0.0, 1.0)
		reste_ke += base("i", fid, "cout_reparation_ke") * part
		logements += perdus * part
	for fid in routes:
		if str(routes[fid].get("etat_crue", "")) != "coupe":
			continue
		var part := 1.0
		if est_repare("r", fid):
			part = clampf(reste_reparation_mois("r", fid, t) / PONT_MOIS, 0.0, 1.0)
		reste_ke += base("r", fid, "cout_reparation_ke") * part
		ponts += int(part > 0.0)
	var adaptation := 1.0 if _adaptation_total_ke <= 0.0 else \
		clampf(1.0 - reste_ke / _adaptation_total_ke, 0.0, 1.0)
	var reduction := 0.0 if _co2_depart_kt <= 0.0 else \
		clampf(1.0 - co2_kt / _co2_depart_kt, 0.0, 1.0)
	return {
		"adaptation_part": adaptation,
		"reduction_part": reduction,
		"reduction_ecart_kt": _co2_depart_kt - co2_kt,
		"adaptation_logements": logements,
		"adaptation_ponts": ponts,
	}


## `false` si rien à réparer, si c'est déjà engagé, ou si la caisse ne suit pas.
## L'interface pré-vérifie et explique ; ici, le verrou seul — même partage que
## `lancer_solaire`.
func reparer(couche: String, fid: int, t: float) -> bool:
	var cout := cout_reparation_ke(couche, fid)
	if cout <= 0.0 or cout > caisse_ke(t) + 0.001:
		return false
	_repare[couche + ":" + str(fid)] = t
	_depense_ke += cout
	if couche == "i":
		# 🔗 CE QUE LA RECONSTRUCTION REND, et c'est tout : les logements que
		# `04e` avait retirés du parc, et le toit qu'il avait emporté. Les deux
		# étaient déjà dans la fiche — on ne fabrique aucun nombre ici.
		# ⚠️ Le budget de la ville ne dépend pas encore de `logements` (dette
		# nommée du prototype) : reconstruire ne rapporte donc rien d'autre que
		# des toits équipables. C'est un manque, pas un choix.
		var perdus := base("i", fid, "logements_sinistres")
		if perdus > 0.0:
			ajouter_rampe("i", fid, "logements", perdus, t, 0.0,
				RECONSTRUCTION_MOIS)
		var neuf := base("i", fid, "toit_m2_neuf")
		if neuf > 0.0:
			_toit_avant[fid] = ilots[fid].get("toit_m2", 0.0)
			ilots[fid]["toit_m2"] = neuf
			_vert_ha_mois = INF
	return true


## Ce que la crue a pris à la ville, et ce qu'il en reste à cet instant. Deux
## nombres seulement : sans eux, réparer un îlot ne change rien de VISIBLE au
## bandeau de gauche et la décision n'a pas de contrepartie lisible.
func degats(t: float) -> Dictionary:
	var perdus := 0.0
	var a_reparer := 0.0
	var coupes := 0
	# 🌊 LE NOMBRE QUE LA BERGE FAIT BOUGER, et le seul indicateur de ville qui
	# ne soit pas de l'argent : la crue annoncée sur l'îlot le plus enfoncé. Un
	# MAXIMUM, pas une moyenne — une moyenne de ville dilue le faubourg dans les
	# 58 îlots que l'eau n'atteint pas, et ne bougerait pas de 5 cm.
	# ⚠️ Sur les îlots BÂTIS que la prochaine ruinerait, pas sur toute la ville :
	# les quatre champs riverains prennent 5 m d'eau et c'est leur rôle — ils
	# tenaient le maximum à eux seuls, et rien ne l'aurait fait bouger.
	var eau_prochaine := 0.0
	for fid in ilots:
		if base("i", fid, "part_ruinee_apres") > 0.0:
			eau_prochaine = maxf(eau_prochaine,
				valeur("i", fid, "hauteur_eau_annonce", t))
		if est_repare("i", fid):
			continue
		perdus += base("i", fid, "logements_sinistres")
		a_reparer += base("i", fid, "cout_reparation_ke")
	for fid in routes:
		if est_repare("r", fid):
			continue
		a_reparer += base("r", fid, "cout_reparation_ke")
		if str(routes[fid].get("etat_crue", "")) == "coupe":
			coupes += 1
	return {
		"logements_perdus": perdus,
		"a_reparer_ke": a_reparer,
		"franchissements_coupes": coupes,
		"eau_prochaine_m": eau_prochaine,
		"caisse_ke": caisse_ke(t),
	}


# ==========================================================================
# LA COMMANDE — on règle, puis on met en place (2026-08-31)
# ==========================================================================
# 🔴 UN OBJET, UNE COMMANDE, UN CHANTIER. La fiche laisse poser plusieurs
# réglages sur le même objet ; ils partent ENSEMBLE, sur une seule caisse
# vérifiée une seule fois. Sans ça, cinq boutons faisaient cinq fois « il
# manque 214 k€ » et le joueur ne savait jamais ce qu'il pouvait s'offrir.
#
# 🔧 CE QUE LA COMMANDE NE FAIT PAS : fermer une rue aux voitures. Le report de
# trafic vit dans `trafic.gd`, qui touche des nœuds — le noyau n'en sait rien et
# le renvoie à l'appelant dans `axe`.
#
# Les réglages reconnus, tous facultatifs :
#   solaire  float  la part de toit visée          (îlot)
#   vert     float  la part de toit verdie visée   (îlot)
#   reparer  true   relever, déblayer ou rebâtir   (îlot, rue)
#   arbres   float  la canopée visée               (rue)
#   places   true   retirer le stationnement       (rue)
#   axe      true   fermer aux voitures            (rue) — rendu à l'appelant
#   berge    int    l'état visé                    (berge)
#   dense    dict   {part, etages} : la part des bâtiments visée et la
#                   hauteur — 🪜 un cran du curseur = un bâtiment  (îlot)


## Le prix de l'ensemble, annoncé AVANT d'engager quoi que ce soit. C'est lui
## que la fiche compare à la caisse, et c'est le seul endroit où le total se
## calcule : deux additions dans deux fichiers finissent par diverger.
func cout_commande_ke(couche: String, fid: int, r: Dictionary, t: float) -> float:
	var ke := 0.0
	if r.has("solaire"):
		ke += cout_solaire_ke(fid, float(r["solaire"]), t)
	if r.has("vert"):
		ke += cout_vert_ke(fid, float(r["vert"]), t)
	if r.has("arbres"):
		ke += cout_plantation_ke(fid, float(r["arbres"]), t)
	if r.has("berge"):
		ke += cout_berge_ke(fid, int(r["berge"]), t)
	if r.has("dense"):
		ke += cout_dense_ke(fid, etat_dense(fid, t)["cible"],
			float(r["dense"]["part"]), int(r["dense"]["etages"]))
	if r.has("reparer"):
		ke += cout_reparation_ke(couche, fid)
	return ke


## La durée de l'ensemble : LA PLUS LONGUE. L'objet reste en travaux jusqu'à ce
## que le dernier corps de métier ait fini — même règle que `chantier()`.
func duree_commande_mois(couche: String, fid: int, r: Dictionary, t: float) -> float:
	var m := 0.0
	if r.has("solaire"):
		m = maxf(m, duree_solaire_mois(valeur("i", fid, "part_toit_equipe", t),
			float(r["solaire"])))
	if r.has("vert"):
		m = maxf(m, duree_vert_mois(valeur("i", fid, "part_toit_vert", t),
			float(r["vert"])))
	if r.has("arbres"):
		m = maxf(m, PLANTATION_MOIS)
	if r.has("places"):
		m = maxf(m, STATIONNEMENT_MOIS)
	if r.has("dense"):
		m = maxf(m, duree_dense_mois(int(r["dense"]["etages"]),
			etat_dense(fid, t)["cible"], float(r["dense"]["part"])))
	if r.has("berge"):
		m = maxf(m, BERGE_MOIS[int(r["berge"])] - BERGE_MOIS[berge_etat(fid, t)])
	if r.has("reparer"):
		m = maxf(m, duree_reparation_mois(couche, fid))
	return m


## Engage tout, ou rien. Rend ce qui s'est passé — `manque` non nul est le seul
## refus du jeu, et la fiche l'écrit en toutes lettres.
##
## 🔴 L'ORDRE N'EST PAS LIBRE : réparer EN DERNIER, parce qu'il remplace
## `toit_m2` par le toit d'un îlot relevé. Placé avant, la pose solaire aurait
## coûté plus cher que le prix annoncé quelques lignes plus haut.
## ⚠️ Le total étant déjà couvert par la caisse, chaque verrou individuel passe
## forcément : ce qui reste après une dépense couvre toujours le reste à payer.
func commander(couche: String, fid: int, r: Dictionary, t: float) -> Dictionary:
	var cout := cout_commande_ke(couche, fid, r, t)
	var caisse := caisse_ke(t)
	if cout > caisse + 0.001:
		return {"ok": false, "manque": cout - caisse, "cout_ke": cout,
			"faits": [], "axe": false}
	var faits := []
	if r.has("solaire") and lancer_solaire(fid, float(r["solaire"]), t):
		faits.append("solaire")
	if r.has("vert") and lancer_vert(fid, float(r["vert"]), t):
		faits.append("toit vert")
	if r.has("arbres") and planter(fid, float(r["arbres"]), t):
		faits.append("plantation")
	if r.has("places") and supprimer_stationnement(fid, t):
		faits.append("stationnement")
	if r.has("dense") and densifier(fid, float(r["dense"]["part"]),
			int(r["dense"]["etages"]), t):
		faits.append("densification")
	if r.has("berge") and transformer_berge(fid, int(r["berge"]), t):
		faits.append("berge")
	if r.has("reparer") and reparer(couche, fid, t):
		faits.append("reparation")
	return {"ok": not faits.is_empty() or r.has("axe"), "manque": 0.0,
		"cout_ke": cout, "faits": faits, "axe": r.has("axe")}


# ------------------------------------------------- la ville en travaux

# 🔧 LA VUE CHANTIERS (touche X) lit ces deux fonctions et rien d'autre. Un
# objet est CASSÉ, EN CHANTIER ou FAIT — jamais deux à la fois, sinon la
# couleur ment. Le solaire en est : « tous les chantiers » n'en exclut aucun.
# ⚠️ Rien à voir avec `chantiers.gd`, l'ancien prototype à deux décisions.
const CHANTIER_INTACT := 0
const CHANTIER_CASSE := 1
const CHANTIER_EN_COURS := 2
const CHANTIER_FAIT := 3


func etat_chantier(couche: String, fid: int, t: float) -> int:
	# La pose passe devant : sur un îlot déjà relevé, c'est elle le chantier.
	if couche == "i" and ((_solaire.has(fid) and etat_solaire(fid, t)["en_cours"])
			or (_vert.has(fid) and etat_vert(fid, t)["en_cours"])
			or (_dense.has(fid) and etat_dense(fid, t)["en_cours"])):
		return CHANTIER_EN_COURS
	if base(couche, fid, "cout_reparation_ke") <= 0.0:
		return CHANTIER_INTACT
	if reparation_finie(couche, fid, t):
		return CHANTIER_FAIT
	return CHANTIER_EN_COURS if est_repare(couche, fid) else CHANTIER_CASSE


## 🔧 OÙ EN EST LE CHANTIER DE CET OBJET-LÀ — ce que la barre de la fiche
## montre. Quand deux courent ensemble, celui qui finit le DERNIER : l'objet
## reste en travaux jusque-là. Mêmes mots que `chantiers()`, l'interface traduit.
func chantier(couche: String, fid: int, t: float) -> Dictionary:
	var out := {"actif": false, "part": 0.0, "reste_mois": 0.0, "quoi": ""}
	if fid < 0:
		return out
	var lot := []   # [quoi, durée totale, ce qui reste]
	if est_repare(couche, fid) and not reparation_finie(couche, fid, t):
		lot.append([_genre_chantier(couche, fid),
			duree_reparation_mois(couche, fid),
			reste_reparation_mois(couche, fid, t)])
	if couche == "i" and _solaire.has(fid) and etat_solaire(fid, t)["en_cours"]:
		lot.append(["solaire", float(_solaire[fid]["duree"]),
			float(etat_solaire(fid, t)["reste_mois"])])
	if couche == "i" and _vert.has(fid) and etat_vert(fid, t)["en_cours"]:
		lot.append(["toit vert", float(_vert[fid]["duree"]),
			float(etat_vert(fid, t)["reste_mois"])])
	if couche == "i" and _dense.has(fid) and etat_dense(fid, t)["en_cours"]:
		lot.append(["densification", float(_dense[fid]["duree"]),
			float(etat_dense(fid, t)["reste_mois"])])
	if couche == "b" and berge_en_cours(fid, t):
		lot.append(["berge", float(_berge[fid]["duree"]),
			berge_reste_mois(fid, t)])
	if couche == "r" and plantation_en_cours(fid, t):
		lot.append(["plantation", float(_plantation[fid]["duree"]),
			plantation_reste_mois(fid, t)])
	if couche == "r" and _stationnement_supprime.has(fid):
		var reste: float = maxf(0.0,
			float(_stationnement_supprime[fid]) + STATIONNEMENT_MOIS - t)
		if reste > 0.0:
			lot.append(["stationnement", STATIONNEMENT_MOIS, reste])
	for c in lot:
		if float(c[2]) <= float(out["reste_mois"]):
			continue
		out = {"actif": true, "quoi": str(c[0]), "reste_mois": float(c[2]),
			"part": clampf(1.0 - float(c[2]) / maxf(float(c[1]), 0.001), 0.0, 1.0)}
	return out


## Ce qui est cassé, ce qui se répare, ce qui est fait — à cet instant.
## Les genres sont des mots, pas des couleurs : l'interface les traduit.
##
## ⚠️ Les chantiers EN COURS se listent, le cassé se COMPTE : au mois 0 le
## cassé se compte en centaines d'objets, et c'est la couleur au sol qui dit où
## ils sont. Appelée à chaque image tant que le panneau est ouvert — d'où
## l'absence d'une liste qu'il faudrait allouer puis trier pour rien.
func chantiers(t: float) -> Dictionary:
	var en_cours := []
	var faits := 0
	var casses := 0
	var reste_ke := 0.0
	var casses_par_genre := {"reconstruction": 0, "pont": 0, "deblaiement": 0}
	for couche in ["i", "r"]:
		for fid in objets(couche):
			var prix := base(couche, fid, "cout_reparation_ke")
			if prix <= 0.0:
				continue
			var genre := _genre_chantier(couche, fid)
			if not est_repare(couche, fid):
				casses += 1
				casses_par_genre[genre] += 1
				reste_ke += prix
			elif reparation_finie(couche, fid, t):
				faits += 1
			else:
				en_cours.append({"couche": couche, "fid": fid,
					"genre": genre, "cout_ke": prix,
					"reste_mois": reste_reparation_mois(couche, fid, t)})
	# La pose est un chantier comme un autre : sans elle, « tous les chantiers
	# en cours » en oublierait un, et l'îlot ambre ne serait dans aucune liste.
	for fid in _solaire:
		var e := etat_solaire(fid, t)
		if not e["en_cours"]:
			continue
		en_cours.append({"couche": "i", "fid": fid, "genre": "solaire",
			"cout_ke": float(e["cout_ke"]), "reste_mois": float(e["reste_mois"])})
	for fid in _vert:
		var ev := etat_vert(fid, t)
		if not ev["en_cours"]:
			continue
		en_cours.append({"couche": "i", "fid": fid, "genre": "toit vert",
			"cout_ke": float(ev["cout_ke"]), "reste_mois": float(ev["reste_mois"])})
	# La transformation d'une berge dure 6 à 18 mois : c'est le chantier le plus
	# long du jeu après un pont, et il doit se voir dans la liste.
	for fid in _berge:
		if not berge_en_cours(fid, t):
			continue
		en_cours.append({"couche": "b", "fid": fid, "genre": "berge",
			"cout_ke": float(_berge[fid]["cout_ke"]),
			"reste_mois": berge_reste_mois(fid, t)})
	# 🌳 La plantation est le chantier le plus long après un pont : deux ans
	# avant que l'ombre y soit. Elle se liste comme les autres.
	for fid in _plantation:
		if not plantation_en_cours(fid, t):
			continue
		en_cours.append({"couche": "r", "fid": fid, "genre": "plantation",
			"cout_ke": float(_plantation[fid]["cout_ke"]),
			"reste_mois": plantation_reste_mois(fid, t)})
	# Le plus proche de sa fin en tête : c'est l'ordre dans lequel on lit une
	# liste qui ne tient pas entière à l'écran.
	en_cours.sort_custom(func(a, b): return a["reste_mois"] < b["reste_mois"])
	return {
		"en_cours": en_cours,
		"casses": casses,
		"casses_par_genre": casses_par_genre,
		"faits": faits,
		"reste_ke": reste_ke,
	}


func _genre_chantier(couche: String, fid: int) -> String:
	if couche == "i":
		return "reconstruction"
	return "pont" if str(objets("r").get(fid, {}).get("etat_crue", "")) == "coupe" \
		else "deblaiement"
