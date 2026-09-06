# -*- coding: utf-8 -*-
"""Contrôles des raccords de rive : python QGIS/scripts/verifier_berges.py."""

import json
import unittest
from pathlib import Path

from export_godot.berges import _arrondir_rives, _bande_berge, _larges_berge, _pente_berge
from export_godot.geometrie import Chenal, Maillage, Relief
from export_godot.reglages import BERGE_BANDE_M, NAPPE_ILSE, TALUS_BAS, Y_SOL


class RaccordsRive(unittest.TestCase):
    def test_arrondi_preserve_le_talus_du_champ(self):
        champ = [(-20, 0), (0, 0), (0, 100), (-20, 100)]
        ilots = {1: {"sous_type": "riviere", "brut": [(0, 0), (30, 0), (30, 100), (0, 100)]},
                 2: {"sous_type": "champ", "brut": champ}}
        _arrondir_rives(ilots)
        c = Chenal([ilots[1]["brut"]])
        relief = Relief(c, {2: champ})
        self.assertEqual(relief.mesures(), (1, 100.0))
        self.assertAlmostEqual(Y_SOL + relief.z(0, 50) + c.niveau_rive(0, 50), TALUS_BAS)

    def test_arrondi_conserve_la_frontiere_entre_biefs(self):
        a = [(0, 0), (30, 0), (30, 40), (0, 40)]
        b = [(0, 40), (30, 40), (40, 80), (10, 80)]
        ilots = {1: {"sous_type": "riviere", "brut": a},
                 2: {"sous_type": "riviere", "brut": b}}
        _arrondir_rives(ilots)
        self.assertEqual(len(a), 4, "L'anneau source est conservé")
        c = Chenal([d["brut"] for d in ilots.values()])
        self.assertFalse(c.est_berge((0, 40), (30, 40)))
        self.assertGreater(len(ilots[1]["brut"]), len(a))

    def test_berge_oblique_sans_saut_de_terrasse(self):
        chenal = Chenal([[(0, 0), (30, 0), (50, 100), (20, 100), (0, 0)]])
        for y in (3.13, 28.09, 54.87, 82.12):
            with self.subTest(y=y):
                self.assertEqual(chenal.niveau_rive(y * 0.2, y), 1.0)
                self.assertEqual(chenal.niveau_rive(30 + y * 0.2, y), -1.0)
                self.assertEqual(chenal.niveau_rive(15 + y * 0.2, y), 0.0)

    def test_champs_des_deux_rives_rejoignent_la_nappe(self):
        chenal = Chenal([[(0, 0), (30, 0), (30, 100), (0, 100), (0, 0)]])
        relief = Relief(chenal, {
            1: [(-20, 0), (0, 0), (0, 100), (-20, 100)],
            2: [(30, 0), (50, 0), (50, 100), (30, 100)],
        })
        for x in (0.0, 30.0):
            altitude = Y_SOL + relief.z(x, 50.13) + chenal.niveau_rive(x, 50.13)
            self.assertAlmostEqual(altitude, TALUS_BAS)
            self.assertLess(altitude, NAPPE_ILSE)

    def test_talus_avance_joint_la_bande_sans_fente(self):
        chenal = Chenal([[(0, 0), (30, 0), (30, 100), (0, 100), (0, 0)]])
        relief = Relief(chenal, {})
        for x, sens in ((0.0, 1.0), (30.0, -1.0)):
            b = {"fid": 1, "i0": 0, "i1": 4,
                 "net": [(x, 50.13 - sens * i * 2) for i in range(5)],
                 "eau": [(sens, 0.0)] * 5, "off": [0.6] * 5,
                 "sous": [False] * 5, "prendre": [True] * 5,
                 "bord": [-3.5, -3.5, -1.0, -3.5, -3.5]}
            def G_eau(px, py, h):
                return (px, h, -py)
            def G_rive(px, py, h):
                return G_eau(px, py, h + chenal.niveau_rive(px, py, False))
            bande, pente = Maillage(), Maillage()
            coul = (0.2, 0.3, 0.1)
            _bande_berge(bande, b, (coul, coul), G_rive, relief)
            _pente_berge(pente, b, coul, coul, G_eau, chenal)
            hauts = {p for p in pente.v if p[1] > NAPPE_ILSE + 0.01}
            self.assertEqual(len(hauts), 5)
            self.assertTrue(hauts.issubset(set(bande.v)))
            for large, bord in zip(_larges_berge(b), b["bord"]):
                self.assertLessEqual(large, min(BERGE_BANDE_M, -bord - 0.1))

    def test_export_talus_et_eau_sans_palier_parasite(self):
        chemin = Path(__file__).resolve().parents[2] / "Godot/data/wehrau.json"
        d = json.loads(chemin.read_text(encoding="utf-8"))
        self.assertEqual(len(d["objets"]["berges"]), 8)
        mesh = d["berges_pente"]
        for fid, debut, nombre in mesh["g"]:
            rive = d["objets"]["berges"][str(fid)]["rive"]
            haut = 1.14 if rive == "droite" else -0.86
            for j in mesh["i"][debut:debut + nombre]:
                self.assertIn(round(mesh["v"][j][1], 2), (-2.6, -2.0, haut))
            for k in range(debut, debut + nombre, 3):
                a, p, q = [mesh["v"][j] for j in mesh["i"][k:k + 3]]
                aire = ((p[2] - a[2]) * (q[0] - a[0])
                        - (p[0] - a[0]) * (q[2] - a[2]))
                self.assertLess(aire, 0.0, "Un triangle du talus se replie")
        self.assertTrue(all(p[1] == -2.0 for p in d["eau"]["v"]))


if __name__ == "__main__":
    unittest.main(verbosity=2)
