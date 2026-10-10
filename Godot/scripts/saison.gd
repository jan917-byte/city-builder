extends RefCounted
# ❄️🍂 La météo d'une partie : tirée une fois de sa graine, puis fonction pure du mois.
# Visuelle seulement (auteur, 2026-10-10) : ni l'énergie ni la caisse ne la lisent.
# Le réchauffement est une tendance mondiale que le joueur ne change pas (auteur, 2026-10-10).

const Calendrier := preload("res://scripts/calendrier.gd")

## 🎚️ Ordres de grandeur, à juger à l'écran.
const RECHAUFFEMENT_C_AN := 0.06      # ≈ +1,2 °C en vingt ans : l'hiver d'Europe centrale se réchauffe vite
const ECART_SAISON_C := 1.3           # une saison douce ou rude, ses trois mois ensemble
const ECART_MOIS_C := 0.9
## Une neige par hiver, pas une météo (auteur, 2026-10-10) : elle arrive sur une
## douzaine de jours, collines d'abord, et fond par le bas. Sa tenue suit la
## douceur de l'hiver ; `essai_saison` sur 400 parties en donne les semaines.
const NEIGE_MI_C := 3.0               # la moyenne normale de décembre à février
const TENUE_MOIS := 0.35              # dix jours toute blanche dans un hiver normal
const TENUE_PAR_C := 0.8              # trois semaines de plus par degré plus froid
const ARRIVEE_MOIS := 0.4             # douze jours des sommets aux jardins
const FONTE_MOIS := 0.33              # dix jours
const BAS_M := 40.0                   # la ligne des collines y descend ; la vallée plate suit `neige`
## Les montagnes blanchissent là où le mois passe sous +1 °C, à 6,5 °C par km ;
## le manteau suit avec dix jours de retard. Les reliefs visibles plafonnent vers
## 250 m (plus haut, c'est la brume du bord) : à 0 °C, ils ne blanchissaient jamais.
const MANTEAU_C := 1.0
const GRADIENT_C_M := 0.0065
const RETARD_MANTEAU_MOIS := 0.3
const FOND_M := 120.0                 # plus bas, la vallée ne blanchit que par la neige de l'hiver
const PHENO_MOIS_C := 5.0 / 30.0      # le printemps avance de cinq jours par degré
const MOIS_TABLE := 300               # 25 ans : l'horizon et sa marge

var graine: int
var _ecart := PackedFloat32Array()    # écart du mois m à sa normale, à l'indice m + 2
var _neiges: Array = []               # [début, fin de la tenue], une par hiver, de l'an 1


func _init(g: int) -> void:
	graine = g
	var rng := RandomNumberGenerator.new()
	rng.seed = g
	# Un écart par saison (DJF, MAM, JJA, SON), plus le bruit du mois.
	var saisons := {}
	for m in range(-2, MOIS_TABLE + 2):
		var bloc := int(floor((Calendrier.MOIS_DEPART + m + 1) / 3.0))
		if not saisons.has(bloc):
			var hiver := posmod(bloc, 4) == 0
			saisons[bloc] = rng.randfn(0.0, ECART_SAISON_C * (1.2 if hiver else 1.0))
		_ecart.append(float(saisons[bloc]) + rng.randfn(0.0, ECART_MOIS_C))
	# 🔴 La partie s'ouvre sur la crue, sans neige : la première tombe en décembre.
	for an in range(1, int(MOIS_TABLE / 12.0)):
		var decembre := 12 * an - 3
		var t := (temperature_mois(decembre) + temperature_mois(decembre + 1)
			+ temperature_mois(decembre + 2)) / 3.0
		var debut := decembre + 0.3 + rng.randf() * 1.5     # du 10 décembre au 25 janvier
		var tenue := clampf(TENUE_MOIS + TENUE_PAR_C * (NEIGE_MI_C - t), 0.05, 1.5)
		_neiges.append([debut, debut + ARRIVEE_MOIS + tenue])


## Le mois entier `m` (0 = mars de l'an 1) : normale, tendance, écart tiré.
func temperature_mois(m: int) -> float:
	var i := clampi(m, -2, MOIS_TABLE + 1)
	return Calendrier.TEMPERATURES[posmod(Calendrier.MOIS_DEPART + i, 12)] \
		+ RECHAUFFEMENT_C_AN * i / 12.0 + _ecart[i + 2]


## Interpolée d'un milieu de mois au suivant, comme `Calendrier.temperature`.
func temperature(t: float) -> float:
	var x := t - 0.5
	var m := int(floor(x))
	return lerpf(temperature_mois(m), temperature_mois(m + 1), x - m)


## Où en est la neige de l'hiver : 0 avant, 1 toute posée, retour à 0 en fondant.
func avancee(t: float) -> float:
	for e in _neiges:
		if t < e[0]:
			return 0.0
		if t < e[1] + FONTE_MOIS:
			return minf(clampf((t - e[0]) / ARRIVEE_MOIS, 0.0, 1.0),
				1.0 - clampf((t - e[1]) / FONTE_MOIS, 0.0, 1.0))
	return 0.0


## Le manteau de la vallée, 0 à 1 : il suit les collines et part avant elles.
func neige(t: float) -> float:
	return smoothstep(0.35, 1.0, avancee(t))


## La ligne des collines que le froid du mois tient blanches, hors de la neige de l'hiver.
func ligne_collines(t: float) -> float:
	var c := temperature(t - RETARD_MANTEAU_MOIS)
	return maxf((c - MANTEAU_C) / GRADIENT_C_M, FOND_M)


## Au-dessus de cette hauteur (m sur le fond de vallée), les collines sont blanches.
func ligne_de_neige(t: float) -> float:
	return lerpf(ligne_collines(t), BAS_M, smoothstep(0.0, 0.5, avancee(t)))


## Les flocons, 0 à 1 : ils tombent pendant que la neige arrive, pas après.
func flocons(t: float) -> float:
	for e in _neiges:
		var x := t - float(e[0])
		if x < -0.03:
			return 0.0
		if x < ARRIVEE_MOIS + 0.05:
			return smoothstep(-0.03, 0.03, x) * (1.0 - smoothstep(ARRIVEE_MOIS - 0.05, ARRIVEE_MOIS + 0.05, x))
	return 0.0


## Le décalage de l'année de `t`, en mois : printemps (< 0 = en avance), automne (> 0 = en retard).
func decalage(t: float) -> Vector2:
	var debut := 12 * (Calendrier.an(t) - 1) - Calendrier.MOIS_DEPART
	var tendance := RECHAUFFEMENT_C_AN * (debut + 6) / 12.0
	var printemps := (_ecart_de(debut + 2) + _ecart_de(debut + 3)) * 0.5 + tendance
	var automne := (_ecart_de(debut + 8) + _ecart_de(debut + 9)) * 0.5 + tendance
	return Vector2(-printemps * PHENO_MOIS_C, automne * PHENO_MOIS_C * 0.6)


## L'herbe jaunie de fin d'été, 0 à 1 : plus l'été est chaud, plus elle sèche.
func secheresse(t: float) -> float:
	var debut := 12 * (Calendrier.an(t) - 1) - Calendrier.MOIS_DEPART
	var chaud := (_ecart_de(debut + 5) + _ecart_de(debut + 6) + _ecart_de(debut + 7)) / 3.0 \
		+ RECHAUFFEMENT_C_AN * (debut + 6) / 12.0
	var mo := fposmod(Calendrier.MOIS_DEPART + t, 12.0)
	var ete := smoothstep(6.3, 7.3, mo) * (1.0 - smoothstep(8.6, 9.5, mo))
	return clampf(0.3 + 0.35 * chaud, 0.0, 1.0) * ete


func _ecart_de(m: int) -> float:
	return _ecart[clampi(m, -2, MOIS_TABLE + 1) + 2]


## Les globales de `saison.gdshaderinc`, lues par tous les matériaux.
func poser(t: float) -> void:
	RenderingServer.global_shader_parameter_set("saison_mois",
		fposmod(Calendrier.MOIS_DEPART + t, 12.0))
	RenderingServer.global_shader_parameter_set("saison_decalage", decalage(t))
	RenderingServer.global_shader_parameter_set("saison_neige", neige(t))
	RenderingServer.global_shader_parameter_set("saison_neige_altitude", ligne_de_neige(t))
	RenderingServer.global_shader_parameter_set("saison_secheresse", secheresse(t))


## La neige de l'hiver qui commence en décembre de l'an `an` : [début, fin de la tenue].
func neige_hiver(an: int) -> Array:
	return _neiges[clampi(an - 1, 0, _neiges.size() - 1)]
