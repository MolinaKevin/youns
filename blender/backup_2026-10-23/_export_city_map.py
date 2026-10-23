
import bpy, os, io, contextlib, addon_utils
B="/home/kevin/Projects/youns/"
for mod in ("io_scene_gltf2","bl_ext.blender_org.io_scene_gltf2"):
    try:
        addon_utils.enable(mod, default_set=True)
    except Exception as e: print("ADDON", mod, e)
print("TIENE_GLTF", hasattr(bpy.ops.export_scene,"gltf"))
D=bpy.data; scn=bpy.context.scene
c=D.objects.get("HubMontana-camcol-colonly"); print("COLLIDER", c is not None, len(c.data.polygons) if c else 0)
lab=D.collections.get("construcciones_lab")
skip=set(lab.all_objects) if lab else set()
for o in scn.objects: o.select_set(False)
n=0
for o in scn.objects:
    if o in skip: continue
    try:
        o.hide_set(False); o.select_set(True); n+=1
    except Exception: pass
with contextlib.redirect_stdout(io.StringIO()):
    bpy.ops.export_scene.gltf(filepath=B+"assets/maps/hub/city_map.glb", export_format='GLB', use_selection=True, export_yup=True, export_apply=True, export_materials='EXPORT', export_extras=False, export_cameras=False, export_lights=False, export_animations=False)
print("EXPORTADOS", n, os.path.getsize(B+"assets/maps/hub/city_map.glb"))
