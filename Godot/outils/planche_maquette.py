"""La planche numérotée ① couleurs ② flou, après `apercu_maquette.gd` : python Godot/outils/planche_maquette.py [--saisons]"""
from PIL import Image, ImageDraw, ImageFont
import os, sys

R = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "QGIS", "rendus")
COLONNES = [("0_avant", "0  avant"), ("1_couleurs", "1  couleurs"), ("2_flou", "2  flou de maquette"),
    ("3_les_deux", "1 + 2  les deux")]
SAISONS = "--saisons" in sys.argv
VUES = [("saison_printemps", "A  printemps"), ("saison_ete", "B  été"), ("saison_automne", "C  automne"),
    ("saison_hiver", "D  hiver")] if SAISONS else \
    [("ville", "A  la ville"), ("faubourg", "B  le faubourg"), ("coeur", "C  le cœur ancien")]
W, H = 800, 450
MARGE, TITRE, GAUCHE = 12, 40, 240
planche = Image.new("RGB", (GAUCHE + len(COLONNES) * (W + MARGE) + MARGE,
    TITRE + len(VUES) * (H + MARGE) + MARGE), (245, 245, 236))
d = ImageDraw.Draw(planche)
# La police par défaut de PIL n'a pas le « œ ».
f = ImageFont.truetype(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "polices", "Rubik.ttf"), 26)
for i, (_, nom) in enumerate(COLONNES):
    d.text((GAUCHE + MARGE + i * (W + MARGE), 6), nom, fill=(30, 30, 30), font=f)
for j, (vue, nom) in enumerate(VUES):
    y = TITRE + MARGE + j * (H + MARGE)
    d.text((MARGE, y + H // 2 - 14), nom, fill=(30, 30, 30), font=f)
    for i, (cle, _) in enumerate(COLONNES):
        im = Image.open(os.path.join(R, "maquette_%s_%s.png" % (vue, cle))).convert("RGB")
        planche.paste(im.resize((W, H), Image.LANCZOS), (GAUCHE + MARGE + i * (W + MARGE), y))
nom = "maquette_planche_saisons.png" if SAISONS else "maquette_planche.png"
planche.save(os.path.join(R, nom))
print("planche → QGIS/rendus/" + nom)
