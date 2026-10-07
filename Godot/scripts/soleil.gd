extends DirectionalLight3D
# ☀ La carte d'ombre suit la caméra EN PERSPECTIVE : elle s'arrête au bout du
# sol visible, et ses quatre tranches se partagent le sol vu, pas l'air entre
# la caméra et la ville. Une caméra ortho (la miniature) règle la sienne.

## La portée fixe d'avant : la ville dézoomée garde exactement ses ombres.
const PORTEE_MAX := 3000.0
const PORTEE_MIN := 40.0
## L'ombre s'efface sur les derniers 10 % : la marge les met hors du cadre.
const MARGE := 1.12
const FONDU := 0.9
## 0 = tranches égales, 1 = géométriques ; à 1 la première tranche est trop mince.
const LOG := 0.6

var _portee_vue := 0.0
var _proche_vu := 0.0


## 📊 `-- --banc --sans-ombre` : ce que coûtent les ombres, par différence.
func _ready() -> void:
	if "--sans-ombre" in OS.get_cmdline_user_args():
		shadow_enabled = false


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam.projection != Camera3D.PROJECTION_PERSPECTIVE:
		return
	# Sur un bord du cadre, tout le sol est à la même profondeur de vue : le
	# bas et le haut de l'image suffisent.
	var demi := deg_to_rad(cam.fov * 0.5)
	var plongee := asin(clampf(cam.global_basis.z.y, -1.0, 1.0))
	var h := maxf(cam.global_position.y, 1.0) * cos(demi)
	var loin := PORTEE_MAX
	if plongee - demi > deg_to_rad(2.0):
		loin = h / sin(plongee - demi)
	var portee := clampf(loin * MARGE, PORTEE_MIN, PORTEE_MAX)
	var proche := clampf(h / sin(minf(plongee + demi, PI - 0.01)) / portee, 0.01, 0.95)
	if absf(portee - _portee_vue) < 0.01 * portee and absf(proche - _proche_vu) < 0.01:
		return
	_portee_vue = portee
	_proche_vu = proche
	directional_shadow_max_distance = portee
	directional_shadow_fade_start = FONDU
	directional_shadow_split_1 = _tranche(proche, 1)
	directional_shadow_split_2 = _tranche(proche, 2)
	directional_shadow_split_3 = _tranche(proche, 3)


## Pratique PSSM entre le sol le plus proche (`r`, en part de la portée) et le bout.
func _tranche(r: float, i: int) -> float:
	var t := float(i) / 4.0
	return lerpf(r + (1.0 - r) * t, pow(r, 1.0 - t), LOG)
