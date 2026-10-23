
import bpy, bmesh, os, shutil, io, contextlib
B="/home/kevin/Projects/youns/"
bk=B+"blender/backup_2026-10-23/"
os.makedirs(bk,exist_ok=True)
shutil.copy2(B+"blender/city_map.blend", bk+"city_map.blend")
shutil.copy2(B+"assets/maps/hub/city_map.glb", bk+"city_map.glb")
D=bpy.data; scn=bpy.context.scene
old=D.objects.get("HubMontana-camcol-colonly")
if old: D.objects.remove(old)
dg=bpy.context.evaluated_depsgraph_get()
bm=bmesh.new()
for n in ("Montana_Norte","Montana_Sur","Montana_Cascadas"):
    o=D.objects[n]
    me=bpy.data.meshes.new_from_object(o.evaluated_get(dg))
    me.transform(o.matrix_world)
    bm.from_mesh(me)
    D.meshes.remove(me)
bmesh.ops.remove_doubles(bm,verts=bm.verts[:],dist=0.05)
me=D.meshes.new("HubMontana-camcol-colonly"); bm.to_mesh(me); bm.free()
col_obj=D.objects.new("HubMontana-camcol-colonly",me); scn.collection.objects.link(col_obj)
dec=col_obj.modifiers.new("dec","DECIMATE"); dec.ratio=0.12
sol=col_obj.modifiers.new("sol","SOLIDIFY"); sol.thickness=1.5; sol.offset=-1.0
dg=bpy.context.evaluated_depsgraph_get()
newme=bpy.data.meshes.new_from_object(col_obj.evaluated_get(dg))
col_obj.modifiers.clear(); old_me=col_obj.data; col_obj.data=newme; D.meshes.remove(old_me)
newme.name="HubMontana-camcol-colonly"
print("COLLIDER", len(newme.vertices), len(newme.polygons))
bpy.ops.wm.save_mainfile()
lab=D.collections.get("construcciones_lab")
skip=set(lab.all_objects) if lab else set()
for o in scn.objects: o.select_set(False)
n=0
for o in scn.objects:
    if o in skip: continue
    try:
        o.hide_set(False); o.select_set(True); n+=1
    except Exception as e: pass
with contextlib.redirect_stdout(io.StringIO()):
    bpy.ops.export_scene.gltf(filepath=B+"assets/maps/hub/city_map.glb", export_format='GLB', use_selection=True, export_yup=True, export_apply=True, export_materials='EXPORT', export_extras=False, export_cameras=False, export_lights=False, export_animations=False)
print("EXPORTADOS", n, os.path.getsize(B+"assets/maps/hub/city_map.glb"))
