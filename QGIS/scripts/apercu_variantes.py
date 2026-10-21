# -*- coding: utf-8 -*-
"""apercu_variantes — un îlot redessiné sous d'autres règles de parcellaire, sans rien écrire.

    python QGIS/scripts/apercu_variantes.py [--ilots 66,67,59]

Rejoue `04c.decouper_ilot` puis `04d.empreinte` avec les lignes de `VARIANTES`
à la place du tissu de l'îlot → `QGIS/rendus/wehrau_variantes_parcellaire.png`,
une colonne « avant » puis une case numérotée par variante (auteur, 2026-10-21).
"""

import os
import sqlite3
import sys
from importlib import import_module

from PIL import Image, ImageDraw

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)

import apercu_parcelles as AP  # noqa: E402
from apercu_carte import gpkg_vers_wkb, lire_wkb  # noqa: E402

D4C = import_module("04c_parcelles")
D4D = import_module("04d_emprises_batiments")

# 🎚️ LEVEL DESIGN, proposé : les projets des lauréats comme règles de parcellaire.
# base : le tissu dont la variante hérite tout ce que les deux lignes ne disent pas.
# 04c : façade, profondeur, style · 04d : recul, latéral, fond, façade, profondeur,
# plafond d'emprise, famille · niveaux : pour le plancher, donc les logements.
VARIANTES = [
    ("v_ouvert", "Îlot ouvert", "collectif_1995",
     (24.0, 28.0, "peigne"), (5.0, 4.0, 5.0, 16.0, 14.0, 0.40, D4D.DETACHE), 4),
    ("v_ferme", "Îlot fermé", "ilot_compact",
     (16.0, 24.0, "peigne"), (1.0, 0.0, 6.0, None, 12.0, 0.55, D4D.MITOYEN), 4),
    ("v_bande", "Maisons en bande", "maisons_de_ville",
     (6.0, 20.0, "peigne"), (2.0, 0.0, 6.0, None, 9.0, 0.60, D4D.MITOYEN), 2),
    ("v_groupees", "Maisons groupées", "pavillonnaire",
     (20.0, 26.0, "peigne"), (3.0, 2.0, 4.0, 16.0, 10.0, 0.55, D4D.DETACHE), 2),
]
# 🔴 Un parcellaire neuf seulement là où aucun bâtiment n'est resté intact (auteur, 2026-10-21) :
# Verger, Grenier, Four. Ailleurs, les maisons debout restent et seules les tombées se rebâtissent.
ILOTS = [66, 68, 69]
LARG = 420
SORTIE = os.path.join(AP.SORTIE, "wehrau_variantes_parcellaire.png")


def _cloner(mod, base, neuf, ligne):
    """Chaque table de `mod` rangée par sous_type reçoit `neuf` comme `base` ; TISSU, `ligne`."""
    for nom, v in vars(mod).items():
        if not nom.isupper():
            continue
        if isinstance(v, dict) and base in v:
            v[neuf] = ligne if nom == "TISSU" else v[base]
        elif isinstance(v, set) and base in v:
            v.add(neuf)


def lire(chemin):
    con = sqlite3.connect("file:%s?mode=ro" % chemin.replace("\\", "/"), uri=True)
    ilots = D4C.lire(con)
    chemins = D4C.lire_chemins(con, ilots)
    morts = D4C.lire_bords_morts(con, ilots)
    bats = {}
    for fid_ilot, surf, niv, geom in con.execute(
            "SELECT fid_ilot, surface_m2, niveaux, geom FROM batiments"):
        bats.setdefault(fid_ilot, []).append((surf or 0.0, niv or 0.0, lire_wkb(gpkg_vers_wkb(geom))[0][0]))
    avant = dict((f, (a or 0) + (b or 0)) for f, a, b in con.execute(
        "SELECT fid, logements, logements_sinistres FROM ilots"))
    con.close()
    return ilots, chemins, morts, bats, avant


def variante(fid, d, st, chemins, morts):
    """Les parcelles et les bâtiments de l'îlot `fid` sous le tissu `st`."""
    parc, _ = D4C.decouper_ilot(d["ext"], st, chemins.get(fid, ()), morts.get(fid, ()))
    emprise = [D4C.ouvrir(d["ext"])]
    idx_b = D4D.index_bord(emprise)
    vens = [a for a, o, _ in parc if o == "chemin"]
    idx_v = D4D.index_bord(vens) if vens else None
    lot = [{"fid": i, "origine": o, "st": st, "anneau": a} for i, (a, o, _) in enumerate(parc)]
    percees = D4D.percees_ilot(lot, idx_b)
    direction = D4D.direction_ilot(emprise)
    parcelles, batiments = [], []
    for i, (a, o, idx) in enumerate(parc):
        parcelles.append((fid, st, o, a, D4C.facade_de(a, idx)))
        if o in D4D.ORIGINES_NUES:
            continue
        emps = D4D.empreinte(a, st, idx_b, idx_v, direction, None, percees.get(i))[0]
        batiments += [(fid, st, e) for e in (emps or [])]
    return parcelles, batiments


def _numero(img, n):
    d = ImageDraw.Draw(img)
    x, y, r = img.width - 34, 34, 22
    d.ellipse([x - r, y - r, x + r, y + r], fill=(196, 40, 40))
    f = AP.police(24)
    mot = str(n)
    d.text((x - d.textlength(mot, font=f) / 2, y - 15), mot, fill=(255, 255, 255), font=f)


def main():
    fids = [int(x) for x in AP._opt("--ilots", ",".join(map(str, ILOTS))).split(",")]
    ilots, chemins, morts, bats, avant = lire(AP.GPKG)
    for cle, _, base, l4c, l4d, _ in VARIANTES:
        _cloner(D4C, base, cle, l4c)
        _cloner(D4D, base, cle, l4d)
    lignes = []
    n = 1
    print("îlot  variante              bâtiments  emprise m²  logements")
    for fid in fids:
        d = ilots[fid]
        boite = AP.cadre([d["ext"]], 0.06)
        nom = d["st"].replace("_", " ")
        b0 = bats.get(fid, [])
        panneaux = [AP.dessiner([], {fid: d["ext"]}, [(fid, d["st"], a) for _, _, a in b0], boite, LARG,
                                "Îlot %d, avant la crue" % fid,
                                "%s, %d bâtiments, %d logements" % (nom, len(b0), avant.get(fid, 0)),
                                legende=False)]
        for cle, titre, base, _, _, niv in VARIANTES:
            parcelles, batiments = variante(fid, d, cle, chemins, morts)
            # La couleur du tissu de base : `cle` n'est pas dans la palette.
            parcelles = [(f, base, o, a, fac) for f, _, o, a, fac in parcelles]
            emp = sum(abs(D4C.aire_signee(a)) for _, _, a in batiments)
            logts = int(round(emp * niv / D4D.M2_BRUT_PAR_LOGEMENT))
            img = AP.dessiner(parcelles, {fid: d["ext"]}, batiments, boite, LARG, titre,
                              "%d bâtiments, environ %d logements" % (len(batiments), logts),
                              legende=False)
            _numero(img, n)
            print("%4d  %d %-20s %9d  %10.0f  %9d" % (fid, n, titre, len(batiments), emp, logts))
            panneaux.append(img)
            n += 1
        lignes.append(panneaux)
    marge = 10
    hauts = [max(p.height for p in l) for l in lignes]
    planche = Image.new("RGB", (len(lignes[0]) * (LARG + marge) + marge,
                                sum(hauts) + marge * (len(lignes) + 1)), (220, 216, 208))
    y = marge
    for l, h in zip(lignes, hauts):
        x = marge
        for p in l:
            planche.paste(p, (x, y))
            x += LARG + marge
        y += h + marge
    planche.save(SORTIE)
    print("→ %s" % SORTIE)


if __name__ == "__main__":
    main()
