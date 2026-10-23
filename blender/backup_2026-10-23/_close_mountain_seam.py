
import bpy, bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
D=bpy.data; scn=bpy.context.scene
SEAM=10.0; W=8.0; FOOT=0.6
dg=bpy.context.evaluated_depsgraph_get()
N=D.objects["Montana_Norte"]; S=D.objects["Montana_Sur"]
def bvh(o): return (BVHTree.FromObject(o,dg),o.matrix_world.copy(),o.matrix_world.inverted())
bn=bvh(N); bs=bvh(S)
def h(b,x,z):
    t,mw,mi=b; r=t.ray_cast(mi@Vector((x,-z,300)),(mi.to_3x3()@Vector((0,0,-1))).normalized())
    return None if r[0] is None else (mw@r[0]).z
def ridge(x):
    a=h(bn,x,SEAM-W); c=h(bs,x,SEAM+W)
    if a is None or c is None: return None
    return min(a,c)
cache={}
def R(x):
    k=round(x,1)
    if k not in cache: cache[k]=ridge(x)
    return cache[k]
moved=0
for o in (N,S):
    mw=o.matrix_world; mi=mw.inverted()
    for v in o.data.vertices:
        p=mw@v.co; x=p.x; z=-p.y
        dz=abs(z-SEAM)
        if dz>=W or p.z<FOOT: continue
        r=R(x)
        if r is None or r<=p.z: continue
        w=1.0-dz/W
        target=p.z+(r-p.z)*w
        if target>p.z+0.01:
            p.z=target; v.co=mi@p; moved+=1
    o.data.update()
print("MOVIDOS",moved)
# collider de cámara de nuevo
old=D.objects.get("HubMontana-camcol-colonly")
if old: D.objects.remove(old)
dg=bpy.context.evaluated_depsgraph_get()
bm=bmesh.new()
for n in ("Montana_Norte","Montana_Sur","Montana_Cascadas"):
    o=D.objects[n]; me=D.meshes.new_from_object(o.evaluated_get(dg)); me.transform(o.matrix_world); bm.from_mesh(me); D.meshes.remove(me)
bmesh.ops.remove_doubles(bm,verts=bm.verts[:],dist=0.05)
me=D.meshes.new("HubMontana-camcol-colonly"); bm.to_mesh(me); bm.free()
c=D.objects.new("HubMontana-camcol-colonly",me); scn.collection.objects.link(c)
d=c.modifiers.new("dec","DECIMATE"); d.ratio=0.12
s=c.modifiers.new("sol","SOLIDIFY"); s.thickness=1.5; s.offset=-1.0
dg=bpy.context.evaluated_depsgraph_get()
nm=D.meshes.new_from_object(c.evaluated_get(dg)); c.modifiers.clear(); om=c.data; c.data=nm; D.meshes.remove(om); nm.name="HubMontana-camcol-colonly"
print("COLLIDER",len(nm.polygons))
bpy.ops.wm.save_mainfile()
print("GUARDADO")
