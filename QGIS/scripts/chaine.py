# -*- coding: utf-8 -*-
"""
LA CHAÎNE — une seule commande pour refaire la carte depuis la source.

    python QGIS/scripts/chaine.py              02 → 03 → 04 → 04b → 04c
    python QGIS/scripts/chaine.py --godot      … puis 07, pour la maquette 3D
    python QGIS/scripts/chaine.py --court      seulement le compte rendu final
    python QGIS/scripts/chaine.py --depuis 04  reprendre au milieu

═══════════════════════════════════════════════════════════════════════════
POURQUOI CE FICHIER EXISTE
═══════════════════════════════════════════════════════════════════════════

L'ordre des étapes est une contrainte réelle — `04c` a besoin des emprises de
`04b`, qui ont besoin des largeurs de `04`, qui ont besoin des adjacences de
`03` — mais c'était une contrainte tenue de mémoire, recopiée dans six notes.
Elle est maintenant tenue par le code.

🔴 CE QU'IL Y AVAIT AVANT, ET LE PIÈGE QUE ÇA A COÛTÉ. Chaque étape se lançait
à la main, précédée d'une passe `--blanc`. La passe à blanc existait parce que
les scripts écrivaient dans un GeoPackage suivi par git : une écriture ratée
salissait un binaire que git ne sait pas fusionner, donc on regardait avant de
sauter. Depuis le 2026-08-17 la carte de travail est DÉRIVÉE et gitignorée —
la casser ne coûte plus qu'un relancement. La passe à blanc reste utile là où
elle protège du LEVEL DESIGN (`00`, `00b`, `tracer_chemins`, qui écrivent la
source), et elle n'a plus de raison d'être dans la chaîne.

Le piège que ça referme est celui du 2026-08-14 : la carte du dépôt datait de
deux commits avant le code, rien ne le signalait, et une session entière est
passée à décrire un défaut déjà corrigé. Ici `02` rebâtit la carte depuis la
source à chaque passage — elle ne peut plus être plus vieille que le code.
"""

import os
import subprocess
import sys
import time

for flux in (sys.stdout, sys.stderr):
    try:
        flux.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, OSError):
        pass

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.dirname(os.path.dirname(ICI))

# L'ordre est la seule chose que ce fichier sait, et c'est tout ce qu'on lui
# demande. `07` n'en fait pas partie : il alimente la maquette 3D, ce qui est
# un autre métier et une autre attente — d'où `--godot`.
ETAPES = [
    ("02", "02_qualifier.py",        "la carte de travail, bâtie depuis la source"),
    ("03", "03_adjacences.py",       "qui touche qui"),
    ("04", "04_deriver_attributs.py", "les attributs dérivés"),
    ("04b", "04b_emprises_baties.py", "les emprises bâties"),
    ("04c", "04c_parcelles.py",      "le parcellaire"),
]
GODOT = ("07", "07_exporter_godot.py", "l'export vers la maquette 3D")


def main():
    args = sys.argv[1:]
    court = "--court" in args
    depuis = None
    if "--depuis" in args:
        depuis = args[args.index("--depuis") + 1]

    etapes = list(ETAPES)
    if "--godot" in args:
        etapes.append(GODOT)
    if depuis:
        noms = [e[0] for e in etapes]
        if depuis not in noms:
            raise SystemExit("étape inconnue : %s — au choix : %s"
                             % (depuis, ", ".join(noms)))
        etapes = etapes[noms.index(depuis):]

    print("=" * 74)
    print("LA CHAÎNE — %d étapes" % len(etapes))
    print("=" * 74)

    resume = []
    for num, script, quoi in etapes:
        t0 = time.time()
        print("\n▶ %-4s %s" % (num, quoi))
        r = subprocess.run([sys.executable, os.path.join(ICI, script)],
                           cwd=RACINE,
                           capture_output=court, text=True,
                           encoding="utf-8", errors="replace")
        dt = time.time() - t0
        if r.returncode != 0:
            # On s'arrête net : les étapes suivantes liraient une carte à
            # moitié écrite et sortiraient des chiffres qui ont l'air bons.
            if court and r.stdout:
                print(r.stdout[-3000:])
            if r.stderr:
                print(r.stderr[-3000:])
            print("\n🔴 ARRÊT à l'étape %s après %.1f s — rien n'a été lancé"
                  " ensuite." % (num, dt))
            raise SystemExit(r.returncode)
        resume.append((num, quoi, dt))
        if court:
            print("   ✅ %.1f s" % dt)

    print("\n" + "=" * 74)
    print("%-6s %-46s %8s" % ("ÉTAPE", "CE QU'ELLE A FAIT", "DURÉE"))
    print("-" * 74)
    for num, quoi, dt in resume:
        print("%-6s %-46s %7.1f s" % (num, quoi, dt))
    print("-" * 74)
    print("%-6s %-46s %7.1f s" % ("", "total", sum(d for _, _, d in resume)))
    print("=" * 74)
    print("\nLa carte de travail : QGIS/data/travail/wehrau.gpkg")
    print("Pour la regarder    : python QGIS/scripts/apercu_parcelles.py")


if __name__ == "__main__":
    main()
