# -*- coding: utf-8 -*-
"""apercu_parcelles — voir le parcellaire, parce qu'il ne se voyait nulle part.

Ni `apercu_carte.py` ni `06_etat_zero.py` ne dessinent les parcelles : le
découpage de `04c` ne se jugeait que dans Godot, en bout de chaîne.

    python QGIS/scripts/apercu_parcelles.py
        la ville entière + trois îlots en gros plan

    python QGIS/scripts/apercu_parcelles.py --avant chemin/vers/ancien.gpkg
        la même chose en avant/après, côte à côte

    python QGIS/scripts/apercu_parcelles.py --ilots 15,30,42
        choisir les îlots du gros plan

Ce que l'image doit montrer, et qui décide si `04c` est bon :
  · les parcelles tournées VERS la rue, en lanières, pas en carrés ;
  · un front de rue continu, chaque parcelle touchant la chaussée ;
  · un cœur d'îlot lisible au milieu des îlots profonds.

🎨 DEUX COULEURS SUFFISENT À LIRE L'IMAGE : couleur de tissu = la parcelle a
une façade et sera bâtie ; VERT = aucune façade, elle repart au jardin. Le vert
dispersé entre les maisons est le défaut ; rassemblé en cœur d'îlot, c'est le
résultat cherché.
"""

import math
import os
import sqlite3
import sys

from PIL import Image, ImageDraw

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.dirname(os.path.dirname(ICI))
sys.path.insert(0, ICI)

from apercu_carte import gpkg_vers_wkb, lire_wkb  # noqa: E402

# ⚠️ Les options à valeur mangent l'argument suivant. Sans ce tri, le chemin
# de `--avant` était AUSSI pris pour le GeoPackage positionnel : l'avant/après
# comparait la carte à elle-même sans que rien ne plante.
_A_VALEUR = ("--avant", "--ilots")


def _opt(nom, defaut=None):
    for i, a in enumerate(sys.argv):
        if a == nom and i + 1 < len(sys.argv):
            return sys.argv[i + 1]
        if a.startswith(nom + "="):
            return a.split("=", 1)[1]
    return defaut


def _positionnels():
    out, saute = [], False
    for a in sys.argv[1:]:
        if saute:
            saute = False
            continue
        if a in _A_VALEUR:
            saute = True
        elif not a.startswith("--"):
            out.append(a)
    return out


_ARGS = _positionnels()
GPKG = _ARGS[0] if _ARGS else os.path.join(RACINE, "QGIS", "data",
                                           "travail", "wehrau.gpkg")


AVANT = _opt("--avant")
# 🔴 Le numéro d'îlot est écrit PAR DÉFAUT : sans lui, un défaut se décrit
# (« le bloc allongé en haut à gauche ») au lieu de se nommer.
# `--sans-fids` pour une image propre à montrer.
FIDS = "--sans-fids" not in sys.argv
SORTIE = os.path.join(RACINE, "QGIS", "rendus")

# Une couleur par tissu. Volontairement proches de la palette pastel de la
# maquette (42c) : on compare des formes, pas des teintes.
COULEUR = {
    "coeur_ancien":         (198, 156, 120),
    "maisons_de_ville":     (214, 186, 148),
    "front_commercant":     (206, 148, 132),
    "pavillonnaire":        (196, 208, 168),
    "barre_1970":           (176, 180, 196),
    "equipement":           (168, 186, 206),
    "friche_industrielle":  (176, 168, 156),
    "collectif_1995":       (222, 210, 186),
    "ilot_compact":         (150, 190, 158),
}
DEFAUT = (200, 200, 200)
FOND = (247, 245, 240)
TRAIT = (92, 84, 76)
RUE = (255, 255, 255)
# Les parcelles sans façade, celles qui repartent au jardin.
# ⚠️ Franchement plus sombre que le vert du `pavillonnaire` : trop proches, un
# quartier entier se lisait comme un cœur d'îlot, donc comme le défaut.
JARDIN = (104, 142, 86)
# 🚶 LE CHEMIN — la venelle retirée de l'emprise par 04c. Un gris de pavé : ni
# le blanc de la rue (aucune voiture) ni une couleur de tissu (rien n'y sera
# bâti). Il doit se lire comme une COUPURE.
CHEMIN = (162, 156, 146)
# 🏠 LE BÂTIMENT — `batiments` (04d), dessiné PAR-DESSUS sa parcelle. Un seul
# ton pour tous les tissus : on regarde la forme et l'implantation, et le tissu
# se lit déjà sous le bâtiment.
BATI = (86, 74, 68)
BATI_TRAIT = (48, 40, 36)


def police(taille):
    """La police par défaut de PIL est une bitmap ASCII : « îlot » et « après »
    y sortent en carrés. On prend une police du système, sinon on se rabat.
    ⚠️ Ne chercher que dans C:/Windows/Fonts revenait à casser tous les
    accents dès que le script tourne sur le Mac — où il tourne (CLAUDE.md §5)."""
    from PIL import ImageFont
    candidats = [
        os.path.join(os.environ.get("WINDIR", "C:/Windows"), "Fonts", n)
        for n in ("segoeui.ttf", "arial.ttf", "calibri.ttf")
    ] + [
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/Library/Fonts/Arial.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ]
    for chemin in candidats:
        if os.path.exists(chemin):
            try:
                return ImageFont.truetype(chemin, taille)
            except OSError:
                pass
    return ImageFont.load_default()


def charger(chemin):
    con = sqlite3.connect("file:%s?mode=ro" % chemin.replace("\\", "/"), uri=True)
    cols = {r[1] for r in con.execute("PRAGMA table_info(parcelles)")}
    a_origine = "origine" in cols
    parcelles = []
    # `facade_m` existe dans les deux versions, `origine` seulement depuis le
    # peigne : c'est donc la façade qui sert de critère commun, et c'est de
    # toute façon elle qui décide si une maison sera bâtie.
    for ligne in con.execute(
        "SELECT fid_ilot, sous_type, facade_m, geom%s FROM parcelles"
        % (", origine" if a_origine else "")
    ):
        fid, st, fac, geom = ligne[0], ligne[1], ligne[2] or 0.0, ligne[3]
        origine = ligne[4] if a_origine else None
        for anneau in lire_wkb(gpkg_vers_wkb(geom))[0]:
            parcelles.append((fid, st, origine, anneau, fac))
    emprises = {}
    for fid, geom in con.execute("SELECT fid_ilot, geom FROM emprises"):
        emprises[fid] = lire_wkb(gpkg_vers_wkb(geom))[0][0]
    # La couche `batiments` est FACULTATIVE : sans 04d, l'image sort comme
    # avant. C'est ce qui permet de comparer une carte d'avant à une carte
    # d'après sans que le panneau « avant » plante.
    batiments = []
    if con.execute("SELECT count(*) FROM sqlite_master WHERE type='table'"
                   " AND name='batiments'").fetchone()[0]:
        for fid_ilot, st, geom in con.execute(
            "SELECT fid_ilot, sous_type, geom FROM batiments"
        ):
            for anneau in lire_wkb(gpkg_vers_wkb(geom))[0]:
                batiments.append((fid_ilot, st, anneau))
    con.close()
    return parcelles, emprises, batiments


def cadre(anneaux, marge=0.04):
    xs = [p[0] for a in anneaux for p in a]
    ys = [p[1] for a in anneaux for p in a]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    dx, dy = (x1 - x0) * marge, (y1 - y0) * marge
    return x0 - dx, x1 + dx, y0 - dy, y1 + dy


def dessiner(parcelles, emprises, batiments, boite, larg, titre, sous_titre,
             legende=True):
    """Un panneau : les emprises en blanc dessous, les parcelles par-dessus."""
    x0, x1, y0, y1 = boite
    ech = larg / (x1 - x0)
    haut = int((y1 - y0) * ech)
    bandeau = 76
    pieds = 56 if legende else 0
    img = Image.new("RGB", (larg, haut + bandeau + pieds), FOND)
    d = ImageDraw.Draw(img)

    def pt(p):
        # y inversé : les coordonnées cartographiques montent, les pixels non.
        return ((p[0] - x0) * ech, bandeau + (y1 - p[1]) * ech)

    for fid, an in emprises.items():
        if len(an) >= 3:
            d.polygon([pt(p) for p in an], fill=RUE)

    fin = 1 if larg < 1400 else 2
    for fid, st, origine, an, fac in parcelles:
        if len(an) < 3:
            continue
        forme = [pt(p) for p in an]
        # ⚠️ Le chemin se teste AVANT la façade : ses deux bouts touchent le
        # bord de l'emprise, donc il a une façade non nulle et sortirait en
        # couleur de tissu — une venelle déguisée en rangée de maisons.
        if origine == "chemin":
            coul = CHEMIN
        else:
            coul = JARDIN if fac < 0.5 else COULEUR.get(st, DEFAUT)
        d.polygon(forme, fill=coul, outline=TRAIT)
        if fin > 1:
            d.line(forme + [forme[0]], fill=TRAIT, width=fin)

    # 🏠 Les bâtiments par-dessus : on doit voir en même temps l'empreinte ET
    # ce qui reste de la parcelle autour d'elle — c'est le couple des deux qui
    # dit si la règle de retrait donne du tissu ou du fromage.
    for _, st, an in batiments:
        if len(an) < 3:
            continue
        f = [pt(p) for p in an]
        d.polygon(f, fill=BATI, outline=BATI_TRAIT)

    d.text((16, 14), titre, fill=(40, 36, 32), font=police(23))
    d.text((16, 46), sous_titre, fill=(110, 100, 92), font=police(16))

    if FIDS:
        # Le numéro d'îlot au centre de son emprise — sans lui, désigner un
        # défaut vu sur l'image oblige à le décrire au lieu de le nommer.
        f = police(17 if larg < 1400 else 20)
        for fid, an in emprises.items():
            if len(an) < 3:
                continue
            cx = sum(p[0] for p in an) / len(an)
            cy = sum(p[1] for p in an) / len(an)
            px, py = pt((cx, cy))
            mot = str(fid)
            w = d.textlength(mot, font=f)
            d.rectangle([px - w / 2 - 4, py - 12, px + w / 2 + 4, py + 12],
                        fill=(255, 255, 255))
            d.text((px - w / 2, py - 10), mot, fill=(180, 40, 40), font=f)

    if legende:
        # Les tissus réellement présents, les plus fournis d'abord — une
        # légende qui liste des teintes absentes de l'image se relit mal.
        compte = {}
        for _, st, origine, _, fac in parcelles:
            if fac >= 0.5 and origine != "chemin":
                compte[st] = compte.get(st, 0) + 1
        ordre = sorted(compte, key=lambda s: -compte[s])
        queue = ["__jardin__"]
        if any(o == "chemin" for _, _, o, _, _ in parcelles):
            queue.append("__chemin__")
        if batiments:
            queue.append("__bati__")
        f = police(15)
        y = bandeau + haut + 18
        x = 16
        for st in ordre + queue:
            jardin = st == "__jardin__"
            chemin = st == "__chemin__"
            bati = st == "__bati__"
            coul = (JARDIN if jardin else CHEMIN if chemin
                    else BATI if bati else COULEUR.get(st, DEFAUT))
            mot = ("sans façade : jardin" if jardin
                   else "chemin" if chemin
                   else "bâtiment" if bati else st.replace("_", " "))
            if x + 26 + 9 * len(mot) > larg - 16:   # on passe à la ligne
                break
            d.rectangle([x, y, x + 20, y + 15], fill=coul, outline=TRAIT)
            d.text((x + 27, y - 1), mot, fill=(88, 80, 74), font=f)
            x += 27 + int(d.textlength(mot, font=f)) + 22
    return img


def stats(parcelles, batiments=()):
    # Le chemin n'est pas une parcelle : il se compte à part, sinon il gonfle
    # le total et fait baisser la part de sans-façade sans que rien ait bougé.
    ch = sum(1 for x in parcelles if x[2] == "chemin")
    lot = [x for x in parcelles if x[2] != "chemin"]
    n = len(lot)
    if not n:
        return "aucune parcelle"
    sans = sum(1 for x in lot if x[4] < 0.5)
    return ("%d parcelles · %d sur rue · %d sans façade (%.0f %%), en vert%s%s"
            % (n, n - sans, sans, 100.0 * sans / n,
               " · %d chemin(s)" % ch if ch else "",
               " · %d bâtiments" % len(batiments) if batiments else ""))


def main():
    if not os.path.exists(GPKG):
        raise SystemExit("introuvable : %s" % GPKG)
    os.makedirs(SORTIE, exist_ok=True)

    apres, emprises, batis = charger(GPKG)
    versions = [("après", apres, emprises, batis)]
    if AVANT:
        if not os.path.exists(AVANT):
            raise SystemExit("introuvable : %s" % AVANT)
        av, emp_av, bat_av = charger(AVANT)
        versions.insert(0, ("avant", av, emp_av, bat_av))

    boite = cadre([an for _, _, _, an, _ in apres])
    ecrits = []

    # ---------------------------------------------------- la ville entière
    panneaux = [dessiner(p, e, b, boite, 1500,
                         "Wehrau — le parcellaire (%s)" % nom, stats(p, b))
                for nom, p, e, b in versions]
    ecrits.append(coller(panneaux, "parcelles_ville"))

    # ------------------------------------------------------- les gros plans
    choix = _opt("--ilots")
    if choix:
        ilots = [int(x) for x in choix.replace(",", " ").split()]
    else:
        # Un de chaque tissu de rue, pris parmi les îlots les plus fournis :
        # c'est là que la différence de méthode se voit.
        par_st = {}
        for fid, st, _, _, _ in apres:
            par_st.setdefault(st, {}).setdefault(fid, 0)
            par_st[st][fid] += 1
        ilots = []
        for st in ("coeur_ancien", "maisons_de_ville", "pavillonnaire"):
            if st in par_st:
                ilots.append(max(par_st[st], key=lambda f: par_st[st][f]))

    for fid in ilots:
        if fid not in emprises:
            continue
        b = cadre([emprises[fid]], marge=0.08)
        panneaux = []
        for nom, p, e, bat in versions:
            sel = [x for x in p if x[0] == fid]
            selb = [x for x in bat if x[0] == fid]
            panneaux.append(dessiner(
                sel, {fid: e[fid]} if fid in e else {}, selb, b, 900,
                "îlot %d — %s (%s)" % (fid, sel[0][1] if sel else "?", nom),
                stats(sel, selb)))
        ecrits.append(coller(panneaux, "parcelles_ilot_%d" % fid))

    for c in ecrits:
        print("PNG    →  %s" % c)


def coller(panneaux, nom):
    """Deux panneaux côte à côte, ou un seul s'il n'y a pas d'avant."""
    if len(panneaux) == 1:
        img = panneaux[0]
    else:
        h = max(p.height for p in panneaux)
        img = Image.new("RGB", (sum(p.width for p in panneaux) + 24, h), FOND)
        x = 0
        for p in panneaux:
            img.paste(p, (x, 0))
            x += p.width + 24
    chemin = os.path.join(SORTIE, "%s.png" % nom)
    img.save(chemin)
    return chemin


if __name__ == "__main__":
    for flux in (sys.stdout, sys.stderr):
        try:
            flux.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, OSError):
            pass
    main()
