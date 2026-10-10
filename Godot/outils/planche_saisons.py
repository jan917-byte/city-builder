"""La planche numérotée des saisons, après `apercu_saisons.gd` : python Godot/outils/planche_saisons.py"""
from PIL import Image, ImageDraw, ImageFont
import os

R = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "QGIS", "rendus")
tuiles = [
    ("saisons_rue_1_mars", "1er mars, an 1 : la partie s'ouvre"),
    ("saisons_rue_2_avril", "mi-avril : premiers verts"),
    ("saisons_rue_3_juillet", "juillet"),
    ("saisons_rue_4_octobre", "fin octobre : l'automne"),
    ("saisons_rue_5_novembre", "fin novembre : arbres nus"),
    ("saisons_rue_6_neige", "décembre : un épisode de neige"),
    ("saisons_pavillons_2_avril", "mi-avril : fruitiers en fleurs"),
    ("saisons_pavillons_4_octobre", "fin octobre, de plus près"),
    ("saisons_pavillons_6_neige", "la neige, de plus près"),
    ("saisons_collines_a_juillet", "les collines en juillet"),
    ("saisons_collines_b_janvier_an1", "janvier de l'an 1 : sommets blancs"),
    ("saisons_collines_c_janvier_an18", "janvier de l'an 18 : plus de neige"),
]
W, H = 640, 400
COL = 3
MARGE = 12
TITRE = 40
lignes = (len(tuiles) + COL - 1) // COL
planche = Image.new("RGB", (COL * W + (COL + 1) * MARGE,
    lignes * (H + TITRE) + (lignes + 1) * MARGE), (245, 245, 236))
d = ImageDraw.Draw(planche)
try:
    f = ImageFont.truetype("arial.ttf", 22)
    fb = ImageFont.truetype("arialbd.ttf", 24)
except OSError:
    f = fb = ImageFont.load_default()
for k, (nom, legende) in enumerate(tuiles):
    im = Image.open(os.path.join(R, "wehrau_%s.png" % nom)).convert("RGB").resize((W, H), Image.LANCZOS)
    x = MARGE + (k % COL) * (W + MARGE)
    y = MARGE + (k // COL) * (H + TITRE + MARGE)
    d.text((x, y + 6), "%d" % (k + 1), fill=(33, 61, 54), font=fb)
    d.text((x + 34, y + 8), legende, fill=(33, 61, 54), font=f)
    planche.paste(im, (x, y + TITRE))
sortie = os.path.normpath(os.path.join(R, "wehrau_saisons_planche.png"))
planche.save(sortie)
print("planche :", sortie)
