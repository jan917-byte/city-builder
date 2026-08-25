# -*- coding: utf-8 -*-
"""
LA CHAÎNE — une seule commande pour refaire la carte depuis la source.

    python QGIS/scripts/chaine.py              02 → 03 → 04 → 04b → 04c → 04d
    python QGIS/scripts/chaine.py --godot      … puis 07, pour la maquette 3D
    python QGIS/scripts/chaine.py --court      seulement le compte rendu final
    python QGIS/scripts/chaine.py --depuis 04  reprendre au milieu

L'ordre des étapes est une contrainte réelle (`04d` a besoin de `04c`, qui a
besoin de `04b`…) qui était tenue de mémoire, recopiée dans six notes. Elle est
maintenant tenue par le code.

🔴 OUBLIER UNE ÉTAPE ICI NE SE VOIT PAS. `04d`, écrit le 2026-08-17, annonçait
la nouvelle chaîne dans son en-tête sans y être ajouté : la carte de travail
n'avait aucune couche `batiments` et les aperçus sortaient sans bâtiment.

🔄 Chaque étape se lançait à la main, précédée d'une passe `--blanc`, parce que
les scripts écrivaient dans un GeoPackage suivi par git. La carte de travail
est DÉRIVÉE et gitignorée depuis le 2026-08-17 ; la passe à blanc ne reste utile
que là où elle protège du LEVEL DESIGN (`00`, `00b`, `tracer_chemins`).

Le piège refermé est celui du 2026-08-14 : la carte du dépôt datait de deux
commits avant le code, et une session entière est passée à décrire un défaut
déjà corrigé. `02` rebâtit depuis la source à chaque passage.
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

# `07` n'en fait pas partie : la maquette 3D est un autre métier et une autre
# attente, d'où `--godot`.
ETAPES = [
    ("02", "02_qualifier.py",        "la carte de travail, bâtie depuis la source"),
    ("03", "03_adjacences.py",       "qui touche qui"),
    ("04", "04_deriver_attributs.py", "les attributs dérivés"),
    ("04b", "04b_emprises_baties.py", "les emprises bâties"),
    ("04c", "04c_parcelles.py",      "le parcellaire"),
    ("04d", "04d_emprises_batiments.py", "les emprises des bâtiments"),
    ("04e", "04e_crue.py",               "la crue : dégâts et ponts coupés"),
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
            # Les étapes suivantes liraient une carte à moitié écrite et
            # sortiraient des chiffres qui ont l'air bons.
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
