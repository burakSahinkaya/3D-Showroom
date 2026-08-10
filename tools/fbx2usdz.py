"""Blender headless: tek FBX dosyasini USDZ'ye cevirir.
Kullanim: Blender -b -P fbx2usdz.py -- <girdi.fbx> <cikti.usdz>
"""
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
src, dst = argv

# Bos sahneyle basla (varsayilan kup/isik/kamera olmasin)
bpy.ops.wm.read_factory_settings(use_empty=True)

bpy.ops.import_scene.fbx(filepath=src)

# Eksik doku dosyalarina bagli Image Texture dugumlerini kaldir;
# malzeme duz renge doner (uygulama zaten kendi renk presetlerini uyguluyor).
import os
for mat in bpy.data.materials:
    if not mat.use_nodes:
        continue
    tree = mat.node_tree
    for node in list(tree.nodes):
        if node.type == "TEX_IMAGE":
            img = node.image
            # Gomulu (packed) dokular dosya sisteminde olmasa da gecerlidir.
            packed = img is not None and img.packed_file is not None
            on_disk = img is not None and os.path.exists(bpy.path.abspath(img.filepath))
            if not (packed or on_disk):
                tree.nodes.remove(node)
    # Principled BSDF taban rengini notr ahsap tonuna cek
    for node in tree.nodes:
        if node.type == "BSDF_PRINCIPLED":
            node.inputs["Base Color"].default_value = (0.72, 0.60, 0.45, 1.0)
            node.inputs["Roughness"].default_value = 0.6

bpy.ops.wm.usd_export(
    filepath=dst,
    export_materials=True,
)
print("DONE:", dst)
