# 🌳 La planche numérotée des modèles du pack, celle sur laquelle l'auteur choisit (`MODELES`).
# Blender 5 : blender -b --factory-startup -P Godot/outils/planche_modeles_blender.py --
#   Godot/modeles/arbres Tree QGIS/rendus/wehrau_pack_arbres_numeros.png   (Bush pour les buissons)
import bpy, sys, os, math
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
dossier, prefixe, sortie = args[0], args[1], os.path.abspath(args[2])

bpy.ops.wm.read_factory_settings(use_empty=True)
fichiers = sorted(f for f in os.listdir(dossier) if f.lower().endswith(".fbx") and f.startswith(prefixe))
# La texture du pack, refaite sans elle : verte en haut, brune en bas (comme `Constructeur._modele`).
mat = bpy.data.materials.new("palette")
mat.use_nodes = True
nt = mat.node_tree
bsdf = nt.nodes["Principled BSDF"]
uv = nt.nodes.new("ShaderNodeUVMap")
xyz = nt.nodes.new("ShaderNodeSeparateXYZ")
seuil = nt.nodes.new("ShaderNodeMath")
seuil.operation = "GREATER_THAN"
seuil.inputs[1].default_value = 0.5
mix = nt.nodes.new("ShaderNodeMix")
mix.data_type = "RGBA"
mix.inputs["A"].default_value = (0.13, 0.05, 0.01, 1)
mix.inputs["B"].default_value = (0.03, 0.15, 0.03, 1)
nt.links.new(uv.outputs["UV"], xyz.inputs[0])
nt.links.new(xyz.outputs["Y"], seuil.inputs[0])
nt.links.new(seuil.outputs[0], mix.inputs["Factor"])
nt.links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.9

objs = []
cols = 7
pas = 0.0
for k, f in enumerate(fichiers):
    avant = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=os.path.join(dossier, f))
    nouveaux = [o for o in bpy.data.objects if o not in avant]
    meshes = [o for o in nouveaux if o.type == "MESH"]
    bpy.context.view_layer.update()
    mn = Vector((1e9, 1e9, 1e9)); mx = -mn
    for o in meshes:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            mn = Vector(map(min, mn, w)); mx = Vector(map(max, mx, w))
        o.data.materials.clear(); o.data.materials.append(mat)
    objs.append((nouveaux, mn, mx))

haut = max((mx - mn).z for _, mn, mx in objs)
pas = max(max((mx - mn).x, (mx - mn).y) for _, mn, mx in objs) * 1.25
for k, (nouveaux, mn, mx) in enumerate(objs):
    centre = (mn + mx) / 2
    cible = Vector(((k % cols) * pas, 0, -(k // cols) * haut * 1.45))
    dec = cible - Vector((centre.x, centre.y, mn.z))
    for o in nouveaux:
        o.animation_data_clear()
        if o.parent is None:
            o.matrix_world.translation += dec
    bpy.ops.object.text_add(location=cible + Vector((0, -pas * 0.6, -haut * 0.22)))
    t = bpy.context.object
    t.data.body = str(k + 1)
    t.data.size = pas * 0.28
    t.data.align_x = "CENTER"
    t.rotation_euler = (math.radians(90), 0, 0)
    tm = bpy.data.materials.new("noir"); tm.use_nodes = True; tm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.02, 0.02, 0.02, 1)
    t.data.materials.append(tm)

lignes = (len(objs) + cols - 1) // cols
cx = (cols - 1) * pas / 2
cz = -(lignes - 1) * haut * 1.45 / 2 + haut * 0.4
bpy.ops.object.camera_add(location=(cx, -1000, cz + 1000 * math.tan(math.radians(10))))
cam = bpy.context.object
cam.rotation_euler = (math.radians(80), 0, 0)
cam.data.type = "ORTHO"
cam.data.ortho_scale = max(cols * pas, lignes * haut * 1.45) * 1.05
cam.data.clip_end = 5000
bpy.context.scene.camera = cam
bpy.ops.object.light_add(type="SUN", rotation=(math.radians(40), math.radians(20), math.radians(30)))
bpy.context.object.data.energy = 3.5
w = bpy.data.worlds.new("w"); bpy.context.scene.world = w
w.use_nodes = True
w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.92, 0.92, 0.88, 1)
w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE_NEXT"
sc.render.resolution_x = 1800
sc.render.resolution_y = int(1800 * lignes * haut * 1.45 / (cols * pas)) + 60
sc.render.filepath = sortie
sc.view_settings.view_transform = "Standard"
bpy.ops.render.render(write_still=True)
