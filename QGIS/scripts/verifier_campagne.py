"""Régressions du raccord SVG : python QGIS/scripts/verifier_campagne.py."""
import math
import unittest

from export_godot.sorties import portes, tracer, hors_routes, Surface
from export_godot.batiments import _bandes_de_fauche
from export_godot.geometrie import aire_signee, Maillage


class Campagne(unittest.TestCase):
    def test_dessertes_177_178_sarretent_aux_ilots(self):
        routes = [{"fid": fid, "hierarchie": "rue", "largeur_m": 8,
                   "parts": [[(0, y), (100, y)]]} for fid, y in [(177, 0), (178, 50)]]
        self.assertEqual(portes(routes), [])

    def test_route_suit_les_triangles_et_non_un_dome_theorique(self):
        m = Maillage()
        m.triangle((0, 0, 0), (10, 0, 0), (0, 10, 10), (1, 1, 1))
        surface = Surface([m])
        self.assertAlmostEqual(surface.hauteur(2, 3, 999), 3)
        self.assertEqual(surface.hauteur(20, 20, 999), 999)

    def test_sorties_excluent_impasse_interieure_et_boucle(self):
        routes = [{"fid": i, "hierarchie": "rue", "largeur_m": 8,
                   "parts": [p]} for i, p in enumerate([
                       [(0, 0), (50, 0)], [(50, 0), (100, 0)],
                       [(50, 0), (50, 20), (60, 20)],
                       [(50, 0), (50, 100)],
                       [(20, 40), (40, 40), (30, 60), (20, 40)]])]
        self.assertEqual({r[0]["fid"] for r in portes(routes)}, {0, 1, 3})

    def test_continuation_contourne_eau_sans_couper_les_angles(self):
        libre = lambda p: not (40 <= p[0] <= 70 and 0 <= p[1] <= 65)
        ligne = tracer((10, 30), (0, 30), 2, (0, 0, 120, 120), libre, lambda x, y: 0)
        self.assertEqual(ligne[0], (10, 30))
        self.assertEqual(ligne[-1][0], 120)
        self.assertTrue(all(libre(p) for p in ligne))
        self.assertTrue(all(math.dist(a, b) <= 4.01 for a, b in zip(ligne, ligne[1:])))

    def test_bandes_conservent_aire_et_sens_du_champ(self):
        champ = [(0, 0), (120, 0), (120, 60), (0, 60)]
        bandes = _bandes_de_fauche(champ, (.3, .4, .2))
        self.assertAlmostEqual(sum(abs(aire_signee(p)) for p, _ in bandes), 7200)
        self.assertGreater(len(bandes), 1)
        for p, _ in bandes:
            self.assertAlmostEqual(max(q[0] for q in p) - min(q[0] for q in p), 120)

    def test_arbres_degagent_chaussees_et_accotements(self):
        arbres = [[[10, 0, 0], [10, 0, 30]], []]
        axes = [{"largeur_m": 8, "points": [(0, 0), (50, 0)]}]
        self.assertEqual(hors_routes(arbres, axes), [[[10, 0, 30]], []])


if __name__ == "__main__":
    unittest.main(verbosity=2)
