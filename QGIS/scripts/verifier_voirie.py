# -*- coding: utf-8 -*-
"""Contrôles des carrefours et terrasses : python QGIS/scripts/verifier_voirie.py."""

import unittest

from export_godot.geometrie import Chenal, Maillage, _aire_xy
from export_godot.voirie import DecoupeChaussees, _raccorder_quais, D4C


class RaccordsVoirie(unittest.TestCase):
    def test_terrasse_continue_au_bord_de_leau(self):
        c = Chenal([[(0, 0), (30, 0), (30, 100), (0, 100)]])
        for x in (0.0, 30.0):
            self.assertAlmostEqual(c.niveau_voirie(x - .001, 50),
                                   c.niveau_voirie(x + .001, 50), places=3)
        self.assertEqual(c.niveau_voirie(15, 50), 0.0)
        self.assertEqual(c.niveau_voirie(-20, 50), 1.0)
        self.assertEqual(c.niveau_voirie(50, 50), -1.0)

    def test_rue_transversale_rejoint_le_quai_decale(self):
        quai = {"parts": [[(-20, 6), (0, 6)]], "decal_m": 6.0}
        suite = {"parts": [[(0, 6), (20, 6)]], "decal_m": 6.0}
        rue = {"parts": [[(0, 20), (0, 0)]]}
        _raccorder_quais({(0, 0): [(quai, 0, -1), (suite, 0, 0), (rue, 0, -1)]})
        self.assertEqual(quai["parts"][0][-1], suite["parts"][0][0])
        self.assertEqual(quai["parts"][0][-1], rue["parts"][0][-1])
        self.assertAlmostEqual(rue["parts"][0][-1][1], 6.0)

    def test_carrefour_sans_recouvrement_ni_bout_en_saillie(self):
        axes = [[(-20, 0), (0, 0)], [(0, 0), (20, 0)], [(0, 0), (0, 20)]]
        routes = [{"fid": i + 1, "largeur_m": 8.5, "hierarchie": "rue",
                   "longueur_m": 20.0, "parts": [axe]}
                  for i, axe in enumerate(axes)]
        dec = DecoupeChaussees(routes, {d["fid"]: [[d["parts"][0]]] for d in routes})
        emitted = {}
        for d in routes:
            m = Maillage()
            G = lambda x, y, h: (x, h, -y)
            dec.emettre(m, d["parts"][0], 8.5, (1, 1, 1), G, d["fid"], 0)
            dec.emettre_noeuds(m, d["fid"], (1, 1, 1), G, 0)
            polys = [[(m.v[j][0], -m.v[j][2]) for j in m.i[k:k + 3]]
                     for k in range(0, len(m.i), 3)]
            self.assertTrue(polys)
            for precedents in emitted.values():
                for a in precedents:
                    for b in polys:
                        intersection = D4C._soustraire_convexe(a, dec.plans(b))[1]
                        self.assertLess(sum(abs(_aire_xy(p)) for p in intersection), 1e-5)
            emitted[d["fid"]] = polys
            self.assertTrue(all(-20 <= p[0] <= 20 and p[1] >= -4.25
                                for poly in polys for p in poly))
        # La chaussée coupe complètement cette bordure qui traversait le nœud.
        self.assertEqual(dec.segments((-3, 0), (3, 0)), [])
        self.assertEqual(dec.hors([(-2, -2), (2, -2), (2, 2), (-2, 2)]), [])


if __name__ == "__main__":
    unittest.main(verbosity=2)
