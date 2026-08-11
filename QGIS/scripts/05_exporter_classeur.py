#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
05 — Exporte la carte qualifiée vers les feuilles du classeur.

    python3 QGIS/scripts/05_exporter_classeur.py

Sort trois fichiers dans Classeur/ : ilots.csv, routes.csv, adjacences.csv.
Ce sont des DÉRIVÉS. On ne les édite jamais à la main : on relance 02 → 03 → 04,
puis ce script. Les feuilles de design (decisions, effets, chantiers, partie) ne
sont pas touchées.

N'écrit rien dans le GeoPackage. Se lance sans QGIS : sqlite3 seul.
Le séparateur est le point-virgule (Excel FR/DE l'ouvre sans assistant d'import).
"""

import math
import os
import sqlite3
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.dirname(os.path.dirname(ICI))
sys.path.insert(0, ICI)

from apercu_carte import gpkg_vers_wkb, lire_wkb  # noqa: E402  (même lecteur WKB)

SOURCE = os.path.join(RACINE, "QGIS", "data", "Prototype_qualifie.gpkg")
SORTIE = os.path.join(RACINE, "Classeur")
SEP = ";"

# Colonnes exportées, dans l'ordre. La géométrie ne sort pas : le classeur
# travaille sur des identifiants et des attributs, la forme reste dans QGIS.
COLS_ILOTS = [
    "fid", "fonction", "sous_type", "exception", "surface_m2", "densite",
    "logements", "emplois", "hauteur", "impermeabilise", "canopee", "desserte_tc",
    "riverain", "stationnement", "altitude_relative", "alea",
    "position_fil_eau", "rive",
]
COLS_ROUTES = [
    "fid", "hierarchie", "largeur_m", "emprise_libre_m", "stationnement",
    "charge", "canopee",
]
COLS_ADJ = ["id_a", "id_b", "hierarchie_separatrice", "longueur_m", "permeabilite"]


def longueur(blob):
    """Longueur d'une polyligne, en mètres (les données sont en projection métrique)."""
    parts, _ = lire_wkb(gpkg_vers_wkb(blob))
    total = 0.0
    for p in parts:
        for a, b in zip(p, p[1:]):
            total += math.hypot(b[0] - a[0], b[1] - a[1])
    return total


def verifier_colonnes(con, table, cols):
    """Un message clair plutôt qu'un « no such column » de sqlite.

    `emplois` est arrivé dans 04 après coup : sans ce contrôle, un dépôt
    fraîchement tiré plante sans dire qu'il manque juste un maillon."""
    presentes = {r[1] for r in con.execute("PRAGMA table_info(%s)" % table)}
    manque = [c for c in cols if c not in presentes]
    if manque:
        raise SystemExit(
            "Colonnes absentes de `%s` : %s\n"
            "Relancer d'abord :  python3 QGIS/scripts/04_deriver_attributs.py"
            % (table, ", ".join(manque)))


def fmt(v):
    if v is None:
        return ""
    if isinstance(v, float):
        return ("%.4f" % v).rstrip("0").rstrip(".")
    return str(v)


def ecrire(chemin, entete, lignes):
    lignes = list(lignes)
    with open(chemin, "w", encoding="utf-8", newline="\n") as f:
        f.write(SEP.join(entete) + "\n")
        for l in lignes:
            f.write(SEP.join(fmt(v) for v in l) + "\n")
    print("  %-16s %4d lignes" % (os.path.basename(chemin), len(lignes)))


def main():
    if not os.path.exists(SOURCE):
        sys.exit("Introuvable : %s — lancer 02 → 03 → 04 d'abord." % SOURCE)
    os.makedirs(SORTIE, exist_ok=True)
    con = sqlite3.connect(SOURCE)
    verifier_colonnes(con, "ilots", COLS_ILOTS)
    verifier_colonnes(con, "routes", COLS_ROUTES)
    print("Export de %s" % os.path.basename(SOURCE))

    ecrire(
        os.path.join(SORTIE, "ilots.csv"), COLS_ILOTS,
        con.execute("SELECT %s FROM ilots ORDER BY fid" % ",".join(COLS_ILOTS)),
    )

    # Les routes gagnent une colonne longueur_m : c'est l'unité de coût des
    # décisions de voirie (planter, désimperméabiliser, retirer la voiture).
    lignes = []
    for r in con.execute(
        "SELECT %s, geom FROM routes ORDER BY fid" % ",".join(COLS_ROUTES)
    ):
        lignes.append(list(r[:-1]) + [round(longueur(r[-1]), 1)])
    ecrire(os.path.join(SORTIE, "routes.csv"), COLS_ROUTES + ["longueur_m"], lignes)

    ecrire(
        os.path.join(SORTIE, "adjacences.csv"), COLS_ADJ,
        con.execute("SELECT %s FROM adjacences ORDER BY id_a, id_b" % ",".join(COLS_ADJ)),
    )
    con.close()


if __name__ == "__main__":
    main()
