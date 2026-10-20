extends SceneTree
## 📊 Qui coûte quoi, en 1920×1080 : chaque morceau de la scène éteint à son tour, puis les
## à-coups quand le temps court. `--seulement-temps` : les à-coups seuls ; `--reglages` : le panneau Graphismes.
##   Godot_console.exe --path Godot --position 6000,6000 --script res://outils/sonde_perfs.gd -- --ouverture --auteur
const IMAGES := 120

var jeu
var vp: RID


func _initialize() -> void:
	call_deferred("executer")


func images(n: int) -> void:
	for i in n:
		await process_frame


func mesurer(n := IMAGES) -> Dictionary:
	await images(30)
	var t0 := Time.get_ticks_usec()
	var avant := t0
	var gpu := 0.0
	var pire := 0.0
	var proc := 0.0
	var proc_pire := 0.0
	var lentes := 0
	for i in n:
		await process_frame
		var m := Time.get_ticks_usec()
		var d := float(m - avant) / 1000.0
		avant = m
		pire = maxf(pire, d)
		if d > 16.7:
			lentes += 1
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		var p := float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
		proc += p
		proc_pire = maxf(proc_pire, p)
	return {"ms": float(Time.get_ticks_usec() - t0) / 1000.0 / n, "pire": pire,
		"gpu": gpu / n, "script": proc / n, "script_pire": proc_pire, "lentes": lentes,
		"appels": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"tri": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))}


func ligne(nom: String, r: Dictionary, ref := {}) -> void:
	var s := "  %-34s %6.2f ms  GPU %5.2f  pire image %5.1f  >16,7 ms : %3d  %4d appels  %5.2f M tri" % [
		nom, r.ms, r.gpu, r.pire, r.lentes, r.appels, r.tri / 1e6]
	if not ref.is_empty():
		s += "   → GPU %+.2f ms, %+.2f M tri, %+d appels" % [
			r.gpu - ref.gpu, (r.tri - ref.tri) / 1e6, r.appels - ref.appels]
	print(s)


func executer() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	jeu = load("res://maquette.tscn").instantiate()
	root.add_child(jeu)
	current_scene = jeu
	vp = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	await images(60)
	jeu.pivot.set_process_unhandled_input(false)
	jeu._sur_vitesse(0.0)
	print("\n=== SONDE · %s · %s ===" % [RenderingServer.get_video_adapter_name(),
		str(root.size)])

	if "--reglages" in OS.get_cmdline_user_args():
		await reglages()
		quit(0)
		return
	if "--seulement-temps" in OS.get_cmdline_user_args():
		await temps_qui_court()
		quit(0)
		return
	jeu._repere("ville")
	jeu._rafraichir(true)
	var ref := await mesurer(180)
	print("\n-- ville entière, en pause : le paysage, par famille --")
	ligne("tout", ref)
	var familles := {}
	for n in jeu.paysage.get_children():
		var cle := str(n.name).rstrip("0123456789_")
		if not familles.has(cle):
			familles[cle] = []
		familles[cle].append(n)
	for cle in familles:
		for n in familles[cle]:
			n.visible = false
		var r := await mesurer(90)
		for n in familles[cle]:
			n.visible = true
		ligne("sans %s (%d)" % [cle, familles[cle].size()], r, ref)
	print("  ombres de la forêt seules coupées :")
	var forets := []
	for n in jeu.paysage.get_children():
		if str(n.name).begins_with("Foret"):
			forets.append(n)
			n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ligne("forêt sans ombre portée", await mesurer(180), ref)
	for n in forets:
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	for cadrage in [["ville", "ville entière"], ["compact", "cœur ancien"]]:
		jeu._repere(cadrage[0])
		jeu._rafraichir(true)
		print("\n-- %s, en pause : les réglages --" % cadrage[1])
		ref = await mesurer(180)
		ligne("tout", ref)
		jeu._environnement.ssao_enabled = false
		ligne("sans SSAO", await mesurer(180), ref)
		jeu._environnement.ssao_enabled = true
		await mesurer(30)
		root.msaa_3d = Viewport.MSAA_DISABLED
		ligne("sans MSAA", await mesurer(180), ref)
		root.msaa_3d = Viewport.MSAA_2X
		await mesurer(30)
		RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
		ligne("ombre douce basse", await mesurer(180), ref)
		RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_ULTRA)
		await mesurer(30)
		RenderingServer.directional_shadow_atlas_set_size(4096, true)
		ligne("ombre 4096", await mesurer(180), ref)
		RenderingServer.directional_shadow_atlas_set_size(8192, true)
		await mesurer(30)

	await temps_qui_court()
	print("=== fin ===\n")
	quit(0)


func temps_qui_court() -> void:
	jeu._repere("ville")
	print("\n-- le temps qui court, ville entière : les à-coups --")
	for v in [1.0, 4.0]:
		jeu._sur_vitesse(v)
		await images(30)
		var durees := []
		var avant := Time.get_ticks_usec()
		for i in 600:
			await process_frame
			var m := Time.get_ticks_usec()
			durees.append(float(m - avant) / 1000.0)
			avant = m
		var tri := durees.duplicate()
		tri.sort()
		var lourdes := []
		for i in durees.size():
			if durees[i] > 11.0:
				lourdes.append(i)
		var total := 0.0
		for d in durees:
			total += d
		print("  ×%d : médiane %.1f ms, 95e %.1f ms, pire %.1f ms ; %d images > 11 ms sur 600 (%.1f par seconde)" % [
			int(v), tri[300], tri[570], tri[599], lourdes.size(), lourdes.size() / (total / 1000.0)])
		var ecarts := []
		for i in range(1, mini(lourdes.size(), 16)):
			ecarts.append(lourdes[i] - lourdes[i - 1])
		print("     écart entre deux à-coups (en images) : ", ecarts)
	jeu._sur_vitesse(0.0)


## `-- --reglages` : le panneau Graphismes, réglage par réglage, contre le rendu par défaut.
func reglages() -> void:
	var g = jeu.graphismes
	for cadrage in [["ville", "ville entière"], ["compact", "cœur ancien"]]:
		jeu._repere(cadrage[0])
		jeu._rafraichir(true)
		print("
-- %s : les réglages du panneau --" % cadrage[1])
		var ref := await mesurer(240)
		ligne("par défaut", ref)
		for r in [["ombres", "moyennes"], ["ombres", "legeres"], ["ombres", "aucune"],
				["bois", false], ["recoins", false], ["rebonds", true], ["anticrenelage", "leger"],
				["anticrenelage", "non"], ["echelle", "85"], ["echelle", "70"]]:
			g.choisir(r[0], r[1])
			ligne("%s %s" % [r[0], str(r[1])], await mesurer(240), ref)
			g.choisir(r[0], g.DEFAUT[r[0]])
		for preset in [["tout bas", {"ombres": "legeres", "bois": false, "recoins": false,
				"anticrenelage": "non", "echelle": "70"}]]:
			for k in preset[1]:
				g.choisir(k, preset[1][k])
			ligne(preset[0], await mesurer(240), ref)
			for k in preset[1]:
				g.choisir(k, g.DEFAUT[k])
