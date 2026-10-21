# Fabrique gabarit_fenetres.blend : une façade type par famille, où l'auteur modélise chaque ouverture une fois.
# Ouvertures actuelles du jeu recopiées de materiaux.gd ; les autres (rez, variantes) n'existent pas encore au shader.
# ⚠ Le .blend devient une SOURCE dès que l'auteur y modélise : sans --ecraser, on n'y touche plus.
#   blender --background --factory-startup --python gabarit_fenetres.py [-- --ecraser]
import math
import os
import sys

import bmesh
import bpy

ICI = os.path.dirname(os.path.abspath(__file__))
SORTIE = os.path.join(ICI, "gabarit_fenetres.blend")
APERCU = os.path.join(ICI, "..", "..", "..", "QGIS", "rendus", "gabarit_fenetres.png")
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []

ETAGE = 2.7      # ETAGE_M, export_godot/reglages.py
PROF = 0.22      # PROF_FEN : profondeur du tableau
MUR = 0.30
ECART = 3.0

# Ouverture : (nom affiché, largeur, allège, linteau), hauteurs depuis le plancher de la rangée.
# ✅ = taille actuelle du jeu (materiaux.gd).
O = {
    "fen": ("Fenêtre", 1.15, 0.95, 2.25),                    # ✅ FEN_LARGE, ALLEGE, LINTEAU
    "fen_haute": ("Fenêtre haute", 1.00, 0.55, 2.35),
    "fen_courte": ("Fenêtre d'attique", 1.00, 1.10, 2.20),
    "petite": ("Petite fenêtre", 0.60, 1.50, 2.15),
    "porte": ("Porte d'entrée", 1.10, 0.02, 2.15),           # ✅ porte du genre 2
    "porte_anc": ("Porte ancienne", 1.20, 0.02, 2.40),
    "cochere": ("Porte cochère", 2.40, 0.02, 2.55),
    "boutique": ("Boutique ancienne", 2.20, 0.25, 2.45),
    "vitrine": ("Vitrine", 2.40, 0.45, 2.45),                # ✅ pas − 0,80
    "entree": ("Entrée d'immeuble", 1.30, 0.02, 2.40),
    "garage": ("Porte de garage", 2.40, 0.02, 2.15),
    "pf": ("Porte-fenêtre", 1.40, 0.02, 2.20),
    "bande": ("Bande filante", 2.40, 1.00, 2.20),            # ✅ genre 4, pas − 0,30
    "loggia": ("Loggia", 2.40, 0.02, 2.45),
    "hall": ("Hall vitré", 2.40, 0.02, 2.45),
    "cave": ("Soupirail", 1.40, 1.75, 2.30),
    "quai": ("Porte de quai", 2.80, 0.02, 2.55),
    "atelier": ("Porte d'atelier", 1.20, 0.02, 2.25),
    "baie_at": ("Baie d'atelier", 2.80, 0.40, 2.45),
    "pf_balcon": ("Porte-fenêtre de balcon", 1.20, 0.02, 2.25),
    "baie": ("Baie moderne", 1.90, 0.50, 2.48),              # ✅ moderne et étages ajoutés
    "pf_mod": ("Porte-fenêtre moderne", 1.90, 0.02, 2.48),
    "hall_mod": ("Entrée moderne", 2.20, 0.02, 2.48),
    "baie_rez": ("Vitrage de rez", 2.40, 0.10, 2.48),
}

# (clé, titre, entraxe, rangées du rez vers le haut, une ouverture par travée, None = mur plein)
PLANCHES = [
    ("F1", "1  Cœur ancien, maisons de ville", 3.0, [
        ["boutique", "cochere", "porte_anc", "fen_haute"],
        ["fen_haute"] * 4,
        ["fen_courte"] * 4]),
    ("F2", "2  Pavillonnaire", 3.4, [
        ["garage", "porte", "pf"],
        ["fen", "petite", "fen"]]),
    ("F3", "3  Front commerçant", 3.2, [
        ["vitrine", "entree", "vitrine", "vitrine"],
        ["fen"] * 4,
        ["fen"] * 4]),
    ("F4", "4  Barre 1970", 2.7, [
        ["hall", "cave", "cave", "cave"],
        ["bande", "loggia", "bande", "bande"],
        ["bande", "bande", "loggia", "bande"]]),
    ("F5", "5  Friche industrielle", 3.6, [
        ["quai", "atelier", "quai"],
        ["baie_at"] * 3]),
    ("F6", "6  Collectif 1995, îlot compact", 3.2, [
        ["entree", "fen", "fen"],
        ["fen", "pf_balcon", "fen"],
        ["fen", "pf_balcon", "fen"]]),
    ("F7", "7  Moderne, lauréats, étages ajoutés", 3.2, [
        ["hall_mod", "baie_rez", "baie_rez"],
        ["baie", "pf_mod", "baie"],
        ["pf_mod", "baie", "baie"]]),
]
PAR_LIGNE = 4    # planches par ligne dans la scène
LEGENDE = 0.42   # interligne de la légende sous chaque façade

LISEZ_MOI = """GABARIT DES FENÊTRES

Une façade type par famille, aux vraies mesures : un étage = 2,70 m.

1. Dans « Tes fenêtres », chaque famille a une collection par ouverture
   (F1 Porte cochère, F1 Fenêtre haute…).
2. Modélise dans le trou au cadre ORANGE, et seulement là. Les autres trous
   du même type recopient ton modèle tout seuls.
3. Le point de départ (0) est le pied de la travée, sur le nu du mur.
   La vitre actuelle du jeu est à 22 cm de profondeur.
4. Tu peux sortir du mur (appui, volets, balcon, auvent) jusqu'au cadre.
5. Le gris « Gabarit » est verrouillé : on n'y touche pas.

Une ouverture laissée vide garde son dessin actuel dans le jeu.
La caméra « Vue du jeu » regarde comme la maquette (35°).
"""


def collection(nom, parent):
    c = bpy.data.collections.new(nom)
    parent.children.link(c)
    return c


def materiau(nom, rgba):
    m = bpy.data.materials.new(nom)
    m.diffuse_color = rgba
    return m


def mur_perce(nom, x0, z0, W, H, trous, mat, coll):
    """Le mur, de y = 0 (nu de la façade) à y = MUR ; trous = rectangles (x1, x2, z1, z2) percés de part en part."""
    bm = bmesh.new()
    xs = sorted({0.0, W} | {v for t in trous for v in t[:2]})
    zs = sorted({0.0, H} | {v for t in trous for v in t[2:]})
    for i in range(len(xs) - 1):
        for j in range(len(zs) - 1):
            xm, zm = (xs[i] + xs[i + 1]) / 2, (zs[j] + zs[j + 1]) / 2
            if any(a < xm < b and c < zm < d for a, b, c, d in trous):
                continue
            v = [bm.verts.new((x0 + x, y, z0 + z)) for x, y, z in (
                (xs[i], 0, zs[j]), (xs[i + 1], 0, zs[j]), (xs[i + 1], MUR, zs[j]), (xs[i], MUR, zs[j]),
                (xs[i], 0, zs[j + 1]), (xs[i + 1], 0, zs[j + 1]), (xs[i + 1], MUR, zs[j + 1]), (xs[i], MUR, zs[j + 1]))]
            for f in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
                bm.faces.new([v[k] for k in f])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    me = bpy.data.meshes.new(nom)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    ob = bpy.data.objects.new(nom, me)
    coll.objects.link(ob)
    return ob


def cadre(nom, x, z, pas, coll, mat):
    """Fil de fer orange : la travée à modéliser, de 60 cm devant le mur jusqu'au fond du tableau."""
    me = bpy.data.meshes.new(nom)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    ob = bpy.data.objects.new(nom, me)
    ob.location = (x, (-0.6 + PROF) / 2, z + ETAGE / 2)
    ob.scale = (pas, 0.6 + PROF, ETAGE)
    ob.display_type = "WIRE"
    ob.color = mat.diffuse_color
    ob.hide_render = True
    coll.objects.link(ob)


def texte(nom, corps, loc, taille, coll, mat, centre=False):
    cu = bpy.data.curves.new(nom, "FONT")
    cu.body = corps
    cu.size = taille
    if centre:
        cu.align_x = "CENTER"
        cu.align_y = "CENTER"
    ob = bpy.data.objects.new(nom, cu)
    ob.location = loc
    ob.rotation_euler = (math.radians(90), 0, 0)
    cu.materials.append(mat)
    coll.objects.link(ob)


def main():
    if os.path.exists(SORTIE) and "--ecraser" not in ARGS:
        print(f"⛔ {SORTIE} existe : c'est le travail de l'auteur. --ecraser pour le refaire.")
        return
    bpy.ops.wm.read_homefile(use_empty=True)
    sc = bpy.context.scene
    sc.unit_settings.system = "METRIC"
    racine = sc.collection
    gab = collection("Gabarit", racine)
    tes = collection("Tes fenêtres", racine)
    gab.hide_select = True
    gris = materiau("Gabarit enduit", (0.62, 0.60, 0.57, 1.0))
    encre = materiau("Gabarit texte", (0.05, 0.05, 0.05, 1.0))
    orange = materiau("Gabarit à modéliser", (1.0, 0.45, 0.05, 1.0))

    x0 = z0 = 0.0
    larg_max = 0.0
    for n, (cle, titre, pas, rangees) in enumerate(PLANCHES):
        if n and n % PAR_LIGNE == 0:
            x0, z0 = 0.0, z0 - 3 * ETAGE - 7 * LEGENDE - 2.0
        W, H = len(rangees[0]) * pas, len(rangees) * ETAGE
        trous, modeles = [], {}
        famille = collection(cle, tes)
        for r, rangee in enumerate(rangees):
            for c, k in enumerate(rangee):
                if k is None:
                    continue
                _, l, bas, haut = O[k]
                cx, fz = c * pas + pas / 2, r * ETAGE
                trous.append((cx - l / 2, cx + l / 2, fz + bas, fz + haut))
                ox, oz = x0 + cx, z0 + fz
                if k not in modeles:
                    sienne = collection(f"{cle} {O[k][0]}", famille)
                    sienne.instance_offset = (ox, 0.0, oz)
                    modeles[k] = sienne
                    cadre(f"Cadre {cle} {k}", ox, oz, pas, gab, orange)
                    zero = bpy.data.objects.new(f"Zéro {cle} {k}", None)
                    zero.empty_display_type = "PLAIN_AXES"
                    zero.empty_display_size = 0.3
                    zero.location = (ox, 0.0, oz)
                    gab.objects.link(zero)
                    # Dans Blender, le nom sous l'ouverture (ou au-dessus) ; à l'aperçu, son numéro dans le trou.
                    num = len(modeles)
                    zt = oz + bas - 0.12 if bas >= 0.3 else oz + haut + 0.11
                    texte(f"Nom {cle} {k}", O[k][0], (ox, -0.02, zt), 0.13, gab, orange, centre=True)
                    gab.objects[f"Nom {cle} {k}"].hide_render = True
                    texte(f"Numéro {cle} {k}", str(num), (ox, -0.02, oz + (bas + haut) / 2), 0.7, gab, orange, centre=True)
                    gab.objects[f"Numéro {cle} {k}"].hide_viewport = True
                    texte(f"Légende {cle} {k}", f"{num}  {O[k][0]}", (x0, -0.02, z0 - 0.5 - (num - 1) * LEGENDE),
                          0.3, gab, encre)
                else:
                    e = bpy.data.objects.new(f"Copie {cle} {k} {c}{r}", None)
                    e.instance_type = "COLLECTION"
                    e.instance_collection = modeles[k]
                    e.location = (ox, 0.0, oz)
                    gab.objects.link(e)
        mur_perce(f"Mur {cle}", x0, z0, W, H, trous, gris, gab)
        texte(f"Titre {cle}", titre, (x0, -0.05, z0 + H + 0.5), 0.45, gab, encre)
        x0 += W + ECART
        larg_max = max(larg_max, x0)

    # 🎥 La maquette : FOV 35°, angle de départ 32° (camera_axo.gd).
    cam = bpy.data.cameras.new("Vue du jeu")
    cam.angle_y = math.radians(35)
    cam.sensor_fit = "VERTICAL"
    ob = bpy.data.objects.new("Vue du jeu", cam)
    cible = (6.0, 0.0, 4.0)
    d = 24.0
    ob.location = (cible[0] + d * 0.35, -d * math.cos(math.radians(32)), cible[2] + d * math.sin(math.radians(32)))
    racine.objects.link(ob)
    vise = bpy.data.objects.new("Cible caméra", None)
    vise.location = cible
    gab.objects.link(vise)
    c = ob.constraints.new("TRACK_TO")
    c.target = vise
    sc.camera = ob

    # Vue d'ensemble, de face : sert à l'aperçu.
    bas_tot = z0 - 7 * LEGENDE
    haut_tot = 3 * ETAGE + 1.2 - bas_tot
    vue = bpy.data.cameras.new("Ensemble")
    vue.type = "ORTHO"
    vue.ortho_scale = max(larg_max, haut_tot)
    ens = bpy.data.objects.new("Ensemble", vue)
    ens.location = (larg_max / 2 - ECART / 2, -40.0, bas_tot + haut_tot / 2)
    ens.rotation_euler = (math.radians(90), 0, 0)
    racine.objects.link(ens)

    soleil = bpy.data.objects.new("Soleil", bpy.data.lights.new("Soleil", "SUN"))
    soleil.rotation_euler = (math.radians(50), 0, math.radians(-30))
    racine.objects.link(soleil)

    t = bpy.data.texts.new("LISEZ-MOI")
    t.write(LISEZ_MOI)

    bpy.ops.wm.save_as_mainfile(filepath=SORTIE)
    print(f"✅ {SORTIE} : {len(bpy.data.collections) - 2 - len(PLANCHES)} ouvertures à modéliser")

    # Aperçu (dérivé, non suivi) : workbench, de face.
    sc.camera = ens
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.world = bpy.data.worlds.new("Blanc")
    sc.world.color = (1.0, 1.0, 1.0)
    sc.view_settings.view_transform = "Standard"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.show_cavity = True
    sc.render.resolution_x = 2400
    sc.render.resolution_y = int(2400 * haut_tot / larg_max)
    sc.render.filepath = os.path.abspath(APERCU)
    bpy.ops.render.render(write_still=True)
    print(f"🖼  {os.path.abspath(APERCU)}")


main()
