extends RefCounted
# ❄️🍂 La météo d'une partie : tirée une fois de sa graine, puis fonction pure du mois.
# Visuelle seulement (auteur, 2026-10-10) : ni l'énergie ni la caisse ne la lisent.
# Le réchauffement est une tendance mondiale que le joueur ne change pas (auteur, 2026-10-10).

const Calendrier := preload("res://scripts/calendrier.gd")

## 🎚️ Ordres de grandeur, à juger à l'écran.
const RECHAUFFEMENT_C_AN := 0.06      # ≈ +1,2 °C en vingt ans : l'hiver d'Europe centrale se réchauffe vite
const ECART_SAISON_C := 1.3           # une saison douce ou rude, ses trois mois ensemble
const ECART_MOIS_C := 0.9
## Un mois à 3 °C de moyenne a une chance sur deux de neiger, une sur quatre de
## neiger deux fois. `essai_saison` sur 400 parties : 3,3 semaines blanches par
## hiver des ans 1 à 5, 1,9 des ans 16 à 20 ; un hiver sur quatre sans neige, puis presque un sur deux.
const NEIGE_MI_C := 3.0
const NEIGE_PENTE_C := 0.6
const TOMBE_MOIS := 0.03              # un jour
const FONTE_MOIS := 0.13              # quatre jours
## Les montagnes blanchissent là où le mois passe sous +1 °C, à 6,5 °C par km ;
## le manteau suit avec dix jours de retard. Les reliefs visibles plafonnent vers
## 250 m (plus haut, c'est la brume du bord) : à 0 °C, ils ne blanchissaient jamais.
const MANTEAU_C := 1.0
const GRADIENT_C_M := 0.0065
const RETARD_MANTEAU_MOIS := 0.3
const FOND_M := 120.0                 # plus bas, la vallée ne blanchit que par ses épisodes
const PHENO_MOIS_C := 5.0 / 30.0      # le printemps avance de cinq jours par degré
const MOIS_TABLE := 300               # 25 ans : l'horizon et sa marge

var graine: int
var _ecart := PackedFloat32Array()    # écart du mois m à sa normale, à l'indice m + 2
var _episodes: Array = []             # [début, fin, force], triés par début


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
	# 🔴 La partie s'ouvre sur la crue, sans neige : rien avant le deuxième mois.
	for m in range(1, MOIS_TABLE):
		var moy := posmod(Calendrier.MOIS_DEPART + m, 12)
		if not moy in [10, 11, 0, 1, 2]:
			continue
		var t := temperature_mois(m)
		var p := 1.0 / (1.0 + exp((t - NEIGE_MI_C) / NEIGE_PENTE_C))
		for seuil in [p, p * p]:
			if rng.randf() >= seuil:
				continue
			var debut := float(m) + rng.randf() * 0.9
			var duree := lerpf(0.07, 0.30, rng.randf()) \
				* clampf(1.0 + 0.3 * (NEIGE_MI_C - t), 0.4, 1.6)
			_episodes.append([debut, debut + duree, lerpf(0.45, 1.0, rng.randf())])
	_episodes.sort_custom(func(a, b): return a[0] < b[0])


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


## Le manteau de la vallée, 0 à 1 : il tombe en un jour et fond en quatre.
func neige(t: float) -> float:
	var n := 0.0
	for e in _episodes:
		if e[0] > t:
			break
		if t > e[1] + FONTE_MOIS:
			continue
		var monte := clampf((t - e[0]) / TOMBE_MOIS, 0.0, 1.0)
		var reste := 1.0 - clampf((t - e[1]) / FONTE_MOIS, 0.0, 1.0)
		n = maxf(n, float(e[2]) * monte * reste)
	return n


## Au-dessus de cette hauteur (m sur le fond de vallée), les montagnes sont blanches.
func ligne_de_neige(t: float) -> float:
	var c := temperature(t - RETARD_MANTEAU_MOIS)
	return maxf((c - MANTEAU_C) / GRADIENT_C_M, FOND_M)


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


## Les épisodes de neige de l'hiver qui commence en novembre de l'an `an`.
func episodes_hiver(an: int) -> Array:
	var debut := 12 * (an - 1) - Calendrier.MOIS_DEPART + 10
	return _episodes.filter(func(e): return e[0] >= debut and e[0] < debut + 5)


## Le mois `t` d'un épisode bien blanc de l'hiver de l'an `an`, ou −1 : pour les captures.
func milieu_d_un_episode(an: int, force_min := 0.75) -> float:
	for e in episodes_hiver(an):
		if float(e[2]) >= force_min:
			return (float(e[0]) + float(e[1])) * 0.5
	return -1.0
