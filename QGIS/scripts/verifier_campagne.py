"""Contrat du paysage : parcelles sélectionnables et ville simulée inchangée."""
import json
from pathlib import Path
import sys
import unittest

RACINE = Path(__file__).resolve().parents[2]
DONNEES = json.loads((RACINE / "Godot/data/wehrau.json").read_text(encoding="utf-8"))


class Campagne(unittest.TestCase):
    def test_chaque_parcelle_a_un_maillage_et_une_surface(self):
        r = DONNEES["paysage"]["campagne"]
        groupes = {str(g[0]):g for g in r["sols"]["g"]}
        self.assertEqual(set(groupes), set(r["objets"]))
        for fid, o in r["objets"].items():
            self.assertGreater(o["surface_m2"], 90)
            self.assertGreater(groupes[fid][2], 0)

    def test_les_routes_partent_des_sorties_existantes(self):
        r = DONNEES["paysage"]["campagne"]
        self.assertGreaterEqual(len(r["sorties"]), 3)
        for s in r["sorties"]:
            self.assertIn(str(s["rue"]), DONNEES["objets"]["routes"])
            axes = DONNEES["couloirs"][str(s["rue"])][1]
            self.assertTrue(any(sum((a[k]-s["depart"][k])**2 for k in (0,1))<1
                                or sum((a[-2+k]-s["depart"][k])**2 for k in (0,1))<1 for a in axes))
            self.assertGreater(sum((s["fin"][k]-s["depart"][k])**2 for k in (0,1)), 1000**2)

    def test_la_frontiere_de_la_carte_ne_decoupe_pas_les_parcelles(self):
        r = DONNEES["paysage"]["campagne"]
        hx,hz = DONNEES["paysage"]["demi_emprise"]
        traversantes = 0
        for _,debut,nb in r["sols"]["g"]:
            sommets = [r["sols"]["v"][i] for i in r["sols"]["i"][debut:debut+nb]]
            interieur = any(abs(p[0])<hx-2 and abs(p[2])<hz-2 for p in sommets)
            exterieur = any(abs(p[0])>hx+2 or abs(p[2])>hz+2 for p in sommets)
            traversantes += interieur and exterieur
        self.assertGreaterEqual(traversantes, 12)

    def test_les_indicateurs_et_la_ville_restent_identiques(self):
        reference = RACINE / "QGIS/rendus/campagne_reference.json"
        if not reference.exists():
            self.skipTest("Pas d'export de référence local.")
        avant = json.loads(reference.read_text(encoding="utf-8"))
        for cle in ("objets", "riverains", "crue", "masses", "voirie", "repare", "berges"):
            self.assertEqual(avant[cle], DONNEES[cle], cle)


if __name__ == "__main__":
    for flux in (sys.stdout, sys.stderr):
        flux.reconfigure(encoding="utf-8", errors="replace")
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(Campagne)
    resultat = unittest.TextTestRunner(verbosity=2).run(suite)
    print("Campagne : contrat des parcelles et invariants urbains %s." % ("validés" if resultat.wasSuccessful() else "en échec"))
    sys.exit(not resultat.wasSuccessful())
