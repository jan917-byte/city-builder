# -*- coding: utf-8 -*-
"""Comparer un export conservé avant une modification à celui que 07 vient de produire."""
import hashlib
import sys
from pathlib import Path

SORTIE = Path(__file__).resolve().parents[2] / "Godot/data/wehrau.json"


def empreinte(chemin):
    digest = hashlib.sha256()
    with Path(chemin).open("rb") as fichier:
        for bloc in iter(lambda: fichier.read(1024 * 1024), b""):
            digest.update(bloc)
    return digest.hexdigest()


def main():
    if len(sys.argv) not in (2, 3):
        raise SystemExit("Usage : python QGIS/scripts/verifier_export.py reference.json [nouvel_export.json]")
    reference = Path(sys.argv[1])
    actuel = Path(sys.argv[2]) if len(sys.argv) == 3 else SORTIE
    if not reference.is_file() or not actuel.is_file():
        raise SystemExit("EXPORT : un des deux fichiers est absent.")
    if empreinte(reference) != empreinte(actuel):
        raise SystemExit("EXPORT DIFFÉRENT : le contenu a changé ; contrôler avant de poursuivre.")
    print("EXPORT IDENTIQUE : mêmes octets, mêmes données et mêmes maillages.")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
