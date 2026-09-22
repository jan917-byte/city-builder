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
from apercu_carte import dedans
from export_godot.geometrie import Chenal, Relief, aire_signee
from export_godot.voirie import DecoupeChaussees, D4C

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

    def test_les_places_tiennent_dans_le_champ(self):
        emprises = self.d["emprises"]
        for f, places in self.camps.items():
            an = [(p[0], p[2]) for p in emprises[f]]
            x0, x1 = min(p[0] for p in an), max(p[0] for p in an)
            z0, z1 = min(p[1] for p in an), max(p[1] for p in an)
            rangs = set()
            for x, _y, z, _ang, rang in places:
                self.assertTrue(x0 <= x <= x1 and z0 <= z <= z1,
                                "place hors du champ %s" % f)
                rangs.add(rang)
            # La rangée sert la teinte des abris dans la maquette : un champ
            # d'une seule rangée sortirait d'un seul ton.
            self.assertTrue(rangs, "champ %s sans rangée" % f)

    def test_les_ponts_coupes_ne_portent_aucun_morceau(self):
        coupes = [f for f, v in self.d["objets"]["routes"].items()
                  if v["etat_crue"] == "coupe"]
        self.assertEqual(len(coupes), 3)

    def test_chaque_pont_relie_le_faubourg_au_reste_de_la_ville(self):
        sinistres = next(iter(self.sinistres.values()))["morceau"]
        for fid, route in self.d["objets"]["routes"].items():
            if route["etat_crue"] == "coupe":
                self.assertIn(sinistres, route["morceaux_reunis"], fid)
                self.assertIn(0, route["morceaux_reunis"], fid)

    def test_les_trois_champs_ne_recouvrent_plus_la_desserte(self):
        m = self.d["voirie"]
        _, debut, nombre = next(g for g in m["g"] if g[0] == 178)
        triangles = [[(m["v"][j][0], m["v"][j][2])
                      for j in m["i"][k:k + 3]]
                     for k in range(debut, debut + nombre, 3)]
        for fid in (1082, 1083, 1084):
            champ = [(p[0], p[2]) for p in self.d["emprises"][str(fid)]]
            for tri in triangles:
                if abs(aire_signee(tri)) < 1e-5:
                    continue
                _, commun = D4C._soustraire_convexe(champ, DecoupeChaussees.plans(tri))
                self.assertLess(sum(abs(aire_signee(p)) for p in commun), 0.02)
            self.assertAlmostEqual(abs(aire_signee(champ)),
                                   self.champs[str(fid)]["surface_m2"], delta=2.0)

    def test_empreinte_complete_des_containers_dans_les_trois_champs(self):
        lg, la, _ = self.d["camps"]["boite"]
        for fid in (1082, 1083, 1084):
            champ = [(p[0], p[2]) for p in self.d["emprises"][str(fid)]]
            champ.append(champ[0])
            for x, _, z, g, _ in self.camps[str(fid)]:
                for dx in (-lg / 2, lg / 2):
                    for dz in (-la / 2, la / 2 + 0.44):
                        p = (x + dx * math.cos(g) + dz * math.sin(g),
                             z - dx * math.sin(g) + dz * math.cos(g))
                        self.assertTrue(dedans(champ, p), "Container hors du champ %s" % fid)

    def test_la_berge_ne_remonte_pas_entre_deux_champs(self):
        chenal = Chenal([[(0, 0), (20, 0), (20, 100), (0, 100)]])
        relief = Relief(chenal, {
            1: [(20, 0), (60, 0), (60, 50), (20, 50)],
            2: [(20, 50), (60, 50), (60, 100), (20, 100)],
        })
        self.assertLess(relief.z(22, 49.99), -0.5)
        self.assertAlmostEqual(relief.z(22, 49.99), relief.z(22, 50.01), places=4)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    unittest.main(verbosity=2)
