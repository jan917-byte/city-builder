# -*- coding: utf-8 -*-
"""Le relogement tient-il debout dans l'export ?
   python QGIS/scripts/verifier_relogement.py

🌉 Ce que ces cas protègent : que « seuls les champs du faubourg peuvent
accueillir les sinistrés » reste un FAIT MESURÉ. Le jour où un pont, une
desserte ou un contour de champ bouge, c'est ici que ça se voit — pas à
l'écran, trois semaines plus tard.
"""
import json
import math
import sys
import unittest
from pathlib import Path

SORTIE = Path(__file__).resolve().parents[2] / "Godot/data/wehrau.json"


def _charger():
    with SORTIE.open(encoding="utf-8") as f:
        return json.load(f)


class Relogement(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not SORTIE.is_file():
            raise unittest.SkipTest("export absent : lancer chaine.py --godot")
        cls.d = _charger()
        cls.ilots = cls.d["objets"]["ilots"]
        cls.camps = cls.d["camps"]["places"]
        cls.sinistres = {f: v for f, v in cls.ilots.items()
                         if v["logements_sinistres"] > 0}
        cls.champs = {f: v for f, v in cls.ilots.items()
                      if v["sous_type"] == "champ"}

    def test_le_faubourg_sinistre_est_un_seul_morceau_detache(self):
        morceaux = {v["morceau"] for v in self.sinistres.values()}
        self.assertEqual(len(morceaux), 1, "les sinistrés sont éparpillés")
        # 0 est le gros de la ville : un faubourg coupé ne peut pas y être.
        self.assertGreater(morceaux.pop(), 0, "le faubourg n'est plus coupé")

    def test_seuls_les_champs_du_faubourg_sont_atteignables(self):
        m = next(iter(self.sinistres.values()))["morceau"]
        atteignables = sorted(int(f) for f, v in self.champs.items()
                              if v["morceau"] == m)
        self.assertEqual(atteignables, [1082, 1083, 1084])
        # Et le reste de la campagne est bien de l'autre côté de l'eau.
        for f, v in self.champs.items():
            if int(f) not in atteignables:
                self.assertNotEqual(v["morceau"], m, "champ %s" % f)

    def test_chaque_champ_atteignable_a_des_places(self):
        m = next(iter(self.sinistres.values()))["morceau"]
        for f, v in self.champs.items():
            if v["morceau"] != m:
                continue
            self.assertGreater(v["camp_places"], 0, "champ %s sans place" % f)
            self.assertEqual(v["camp_places"], len(self.camps[f]))

    def test_aucun_champ_ne_loge_a_lui_seul_tous_les_sinistres(self):
        """🎚️ LEVEL DESIGN, pas une règle : c'est ce qui fait que le choix du
        champ est un choix. Si un jour un champ suffit, c'est une décision de
        l'auteur — et elle se prend en changeant la case du camp, pas ici."""
        besoin = sum(v["logements_sinistres"] for v in self.sinistres.values())
        m = next(iter(self.sinistres.values()))["morceau"]
        plus_grand = max(v["camp_places"] for v in self.champs.values()
                         if v["morceau"] == m)
        self.assertLess(plus_grand, besoin)
        total = sum(v["camp_places"] for v in self.champs.values()
                    if v["morceau"] == m)
        self.assertGreaterEqual(total, besoin, "à trois champs on n'y arrive"
                                " toujours pas : personne ne peut être logé")

    def test_les_places_tiennent_dans_le_champ(self):
        emprises = self.d["emprises"]
        for f, places in self.camps.items():
            an = [(p[0], p[2]) for p in emprises[f]]
            x0, x1 = min(p[0] for p in an), max(p[0] for p in an)
            z0, z1 = min(p[1] for p in an), max(p[1] for p in an)
            for x, _y, z, _ang in places:
                self.assertTrue(x0 <= x <= x1 and z0 <= z <= z1,
                                "place hors du champ %s" % f)

    def test_les_ponts_coupes_ne_portent_aucun_morceau(self):
        coupes = [f for f, v in self.d["objets"]["routes"].items()
                  if v["etat_crue"] == "coupe"]
        self.assertEqual(len(coupes), 3)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    unittest.main(verbosity=2)
