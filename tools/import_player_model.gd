extends SceneTree

## Arma el personaje principal a partir de lo que exporta el artista, ya
## acomodado en assets/player (pc_mesh.fbx, animations/*.fbx y textures/*.png;
## el artista lo manda como Export/PC_Mesh.fbx, Export/PC_Mesh.fbm/PC_Texture
## <Color|Normal|…>.png y Export/Animations/<grupo>/<Acción>.fbx: renombrar
## según ANIMATIONS). Genera:
##   - assets/player/player_animations.tres: librería con la animación
##     principal de cada FBX (sin las "acciones" sobrantes de Blender).
##   - assets/player/player_material.tres: material con las texturas (el FBX
##     las busca en otra carpeta y no las encuentra).
## La escena que las usa es features/world/party/player_model.tscn.
##
## Volver a correrlo cuando llegue una exportación nueva, desde la raíz:
##   godot --path . --script res://tools/import_player_model.gd
## (antes abrir el editor una vez, o correr `godot --headless --path . --editor
## --quit`, para que Godot importe los FBX nuevos).

const PLAYER_DIR := "res://assets/player/"
const ANIMATIONS_DIR := PLAYER_DIR + "animations/"
const TEXTURES_DIR := PLAYER_DIR + "textures/"
const LIBRARY_OUT := PLAYER_DIR + "player_animations.tres"
const MATERIAL_OUT := PLAYER_DIR + "player_material.tres"

## Archivo en animations/ → nombre de la animación en el juego. Al lado, cómo
## se llama en la exportación del artista.
const ANIMATIONS := {
	"idle.fbx": "idle",                  # World Actions/Idle
	"walk.fbx": "walk",                  # World Actions/Walk
	"run.fbx": "run",                    # World Actions/Run
	"interact.fbx": "interact",          # Item Interactions/Interact
	"item_give.fbx": "item_give",        # Item Interactions/Item Give
	"pickup_floor.fbx": "pickup_floor",  # Item Interactions/Item Pick-up Floor
	"pickup_waist.fbx": "pickup_waist",  # Item Interactions/Item Pick-up Waist
	"happy.fbx": "happy",                # Creature Interactions/Action Happy_Victory
	"talk.fbx": "talk",                  # Creature Interactions/Action Talk
	"angry.fbx": "angry",                # Creature Interactions/Action Angry_Command
	"think.fbx": "think",                # Creature Interactions/Action Think_Save
}
## Las que se repiten en bucle; el resto se juega una vez.
const LOOPING := ["idle", "walk", "run", "talk"]


func _initialize() -> void:
	_build_library()
	_build_material()
	quit()


func _build_library() -> void:
	var library := AnimationLibrary.new()
	for file in ANIMATIONS:
		var path: String = ANIMATIONS_DIR + file
		if not ResourceLoader.exists(path):
			push_warning("Falta %s (¿se importó?)" % path)
			continue
		var scene: Node = load(path).instantiate()
		var player: AnimationPlayer = scene.find_children("*", "AnimationPlayer")[0]
		var anim := _main_animation(player)
		if anim == null:
			push_warning("%s no tiene animación principal" % path)
		else:
			var anim_name: String = ANIMATIONS[file]
			anim.loop_mode = Animation.LOOP_LINEAR if anim_name in LOOPING else Animation.LOOP_NONE
			library.add_animation(anim_name, anim)
			print("%s: %.1f s, %d pistas" % [anim_name, anim.length, anim.get_track_count()])
		scene.free()
	ResourceSaver.save(library, LIBRARY_OUT)
	print("→ ", LIBRARY_OUT)


## La animación con el nombre de la acción ("Idle", "Talk"…); las de Blender
## se llaman "objeto|acción". Se sacan las pistas del nodo metarig: solo
## repiten la escala y rotación de la importación.
func _main_animation(player: AnimationPlayer) -> Animation:
	for anim_name in player.get_animation_list():
		if "|" in anim_name:
			continue
		var anim: Animation = player.get_animation(anim_name).duplicate(true)
		for t in range(anim.get_track_count() - 1, -1, -1):
			if String(anim.track_get_path(t)) == "metarig":
				anim.remove_track(t)
		return anim
	return null


func _build_material() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(TEXTURES_DIR + "pc_color.png")
	mat.normal_enabled = true
	mat.normal_texture = load(TEXTURES_DIR + "pc_normal.png")
	mat.roughness_texture = load(TEXTURES_DIR + "pc_roughness.png")
	mat.metallic = 1.0
	mat.metallic_texture = load(TEXTURES_DIR + "pc_metallic.png")
	ResourceSaver.save(mat, MATERIAL_OUT)
	print("→ ", MATERIAL_OUT)
