# Fabrique gabarit_fenetres.blend : une planche par famille de façade, où l'auteur modélise sa fenêtre.
# Mesures recopiées de materiaux.gd (ALLEGE, LINTEAU, FEN_LARGE, PROF_FEN, vitrine, porte, bande, moderne).
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

# (clé, titre, entraxe, largeur, allège, linteau, travées, étages)
PLANCHES = [
    ("F1_ancien", "1  Cœur ancien, maisons de ville", 3.2, 1.15, 0.95, 2.25, 3, 3),
    ("F2_pavillon", "2  Pavillonnaire", 3.2, 1.15, 0.95, 2.25, 3, 3),
    ("F3_commerce", "3  Front commerçant (étages)", 3.2, 1.15, 0.95, 2.25, 3, 3),
    ("F4_barre", "4  Barre 1970 (bande)", 2.7, 2.40, 1.00, 2.20, 3, 3),
    ("F5_friche", "5  Friche industrielle", 3.2, 1.15, 0.95, 2.25, 3, 3),
    ("F6_collectif", "6  Collectif 1995, îlot compact", 3.2, 1.15, 0.95, 2.25, 3, 3),
    ("F7_moderne", "7  Moderne, lauréats, étages ajoutés", 3.2, 1.90, 0.50, 2.48, 3, 3),
    ("R1_porte", "Porte d'entrée", 3.2, 1.10, 0.02, 2.15, 1, 1),
    ("R2_vitrine", "Vitrine", 3.2, 2.40, 0.45, 2.45, 3, 1),
]

LISEZ_MOI = """GABARIT DES FENÊTRES

Une planche par famille de façade. Chaque planche est un pan de mur du jeu,
aux vraies mesures : un étage = 2,70 m, une travée = l'entraxe des fenêtres.

1. Ouvre la collection « Tes fenêtres > F1_ancien » (ou une autre).
2. Modélise dans le trou du MILIEU, et seulement là. Les huit autres trous
   recopient ton modèle tout seuls : c'est l'aperçu de la répétition.
3. Le point de départ (0) est le pied de la travée, sur le nu du mur.
   La vitre actuelle du jeu est à 22 cm de profondeur.
4. Tu peux sortir du mur (appui, volets, balcon) jusqu'au cadre en fil de fer.
5. Le gris « Gabarit » est verrouillé : on n'y touche pas.

Laisse vide une planche qui ne t'inspire pas : le jeu garde sa fenêtre actuelle.
La caméra « Vue du jeu » regarde comme la maquette (35°).
"""


def collection(nom, parent):
    c = bpy.data.collections.new(nom)
    parent.children.link(c)
    return c


def materiau(nom, rgba):
    m = bpy.data.materials.new(nom)
    m.diffuse_color = rgba
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = rgba
    return m


def mur_perce(nom, x0, pas, larg, bas, haut, cols, rows, mat, coll):
    """Le mur, de y = 0 (nu de la façade) à y = MUR, percé de part en part."""
    bm = bmesh.new()
    W, H = cols * pas, rows * ETAGE
    # Grille des coupures : chaque trou découpe le mur en rectangles pleins.
    xs = sorted({0.0, W} | {c * pas + pas / 2 + s * larg / 2 for c in range(cols) for s in (-1, 1)})
    zs = sorted({0.0, H} | {r * ETAGE + z for r in range(rows) for z in (bas, haut)})
    for i in range(len(xs) - 1):
        for j in range(len(zs) - 1):
            xm, zm = (xs[i] + xs[i + 1]) / 2, (zs[j] + zs[j + 1]) / 2
            dans_trou = abs(xm % pas - pas / 2) < larg / 2 and bas < zm % ETAGE < haut
            if dans_trou:
                continue
            v = [bm.verts.new((x0 + x, y, z)) for x, y, z in (
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


def cadre(nom, x, z, pas, coll):
    """Fil de fer : la travée, de 60 cm devant le mur jusqu'au fond du tableau."""
    me = bpy.data.meshes.new(nom)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(nom, me)
    ob.location = (x, (-0.6 + PROF) / 2, z + ETAGE / 2)
    ob.scale = (pas, 0.6 + PROF, ETAGE)
    ob.display_type = "WIRE"
    ob.hide_render = True
    coll.objects.link(ob)


def texte(nom, corps, loc, taille, coll, mat):
    cu = bpy.data.curves.new(nom, "FONT")
    cu.body = corps
    cu.size = taille
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

    x0 = 0.0
    for cle, titre, pas, larg, bas, haut, cols, rows in PLANCHES:
        mur_perce(f"Mur {cle}", x0, pas, larg, bas, haut, cols, rows, gris, gab)
        texte(f"Titre {cle}", titre, (x0, -0.05, rows * ETAGE + 0.5), 0.45, gab, encre)
        cc, rc = cols // 2, rows // 2
        ox, oz = x0 + cc * pas + pas / 2, rc * ETAGE
        cadre(f"Cadre {cle}", ox, oz, pas, gab)
        sienne = collection(cle, tes)
        sienne.instance_offset = (ox, 0.0, oz)
        # Repère du point zéro : l'auteur modélise autour de lui.
        zero = bpy.data.objects.new(f"Zéro {cle}", None)
        zero.empty_display_type = "PLAIN_AXES"
        zero.empty_display_size = 0.3
        zero.location = (ox, 0.0, oz)
        gab.objects.link(zero)
        for c in range(cols):
            for r in range(rows):
                if (c, r) == (cc, rc):
                    continue
                e = bpy.data.objects.new(f"Copie {cle} {c}{r}", None)
                e.instance_type = "COLLECTION"
                e.instance_collection = sienne
                e.location = (x0 + c * pas + pas / 2, 0.0, r * ETAGE)
                gab.objects.link(e)
        x0 += cols * pas + ECART

    # 🎥 La maquette : FOV 35°, angle de départ 32° (camera_axo.gd).
    cam = bpy.data.cameras.new("Vue du jeu")
    cam.angle_y = math.radians(35)
    cam.sensor_fit = "VERTICAL"
    ob = bpy.data.objects.new("Vue du jeu", cam)
    cible = (4.8, 0.0, 4.0)
    d = 22.0
    ob.location = (cible[0] + d * 0.35, -d * math.cos(math.radians(32)), cible[2] + d * math.sin(math.radians(32)))
    racine.objects.link(ob)
    vise = bpy.data.objects.new("Cible caméra", None)
    vise.location = cible
    gab.objects.link(vise)
    c = ob.constraints.new("TRACK_TO")
    c.target = vise
    sc.camera = ob

    # Vue d'ensemble, de face : sert à l'aperçu.
    vue = bpy.data.cameras.new("Ensemble")
    vue.type = "ORTHO"
    vue.ortho_scale = x0
    ens = bpy.data.objects.new("Ensemble", vue)
    ens.location = (x0 / 2, -40.0, 5.0)
    ens.rotation_euler = (math.radians(90), 0, 0)
    racine.objects.link(ens)

    soleil = bpy.data.objects.new("Soleil", bpy.data.lights.new("Soleil", "SUN"))
    soleil.rotation_euler = (math.radians(50), 0, math.radians(-30))
    racine.objects.link(soleil)

    t = bpy.data.texts.new("LISEZ-MOI")
    t.write(LISEZ_MOI)

    bpy.ops.wm.save_as_mainfile(filepath=SORTIE)
    print(f"✅ {SORTIE}")

    # Aperçu (dérivé, non suivi) : workbench, de face.
    sc.camera = ens
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.show_cavity = True
    sc.render.resolution_x, sc.render.resolution_y = 2400, int(2400 * 11.5 / x0)
    sc.render.filepath = os.path.abspath(APERCU)
    bpy.ops.render.render(write_still=True)
    print(f"🖼  {os.path.abspath(APERCU)}")


main()
