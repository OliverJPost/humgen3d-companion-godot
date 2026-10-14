@tool
extends EditorScenePostImportPlugin
# Runs after Godot imported a glTF or FBX scene. Only a scene with the manifest
# of a Human Generator export next to it (`<Name>.humgen3d.json`, written by
# Human Generator 4.0.32 and later) is set up, when the manifest lists it as the
# character or one of its animation files. Every other scene is left as Godot
# imports it. What each material is (skin, hair cards, haircap) and where the
# flow map of the cards is come from the manifest, not from the names, so
# custom naming works.
#
# What it sets up, all of it idempotent:
# - hair cards: shaded as hair by the shipped hair_cards.gdshader when the export
#   wrote their flow map (the `flow` texture of the material in the manifest):
#   anisotropic highlights
#   along the strands and a variation between them. The standard material the
#   importer made is kept as the meta "humgen3d_plain_material" of the shader
#   material. With or without the map: alpha scissor at HAIR_CUTOFF with alpha
#   to coverage for cameras with MSAA, and no culling, so both sides of a card
#   show
# - haircaps: alpha blend with a depth pre-pass, so the soft edge of the cap sorts,
#   tinted like the cards, darkened as under hair, without a reflection of the sky
# - skin: subsurface scattering in skin mode, as the skin was rendered with
#   scattering in Blender and looks flat and harsh without it, and a lower
#   specular: the skin material of Blender reflects far less than the 0.5 that
#   glTF materials default to, which made the skin look wet
# - a humanoid BoneMap on the Skeleton3D (meta "humgen3d_bone_map"), the bones
#   already carry the names of Godot's SkeletonProfileHumanoid
# - an AnimationPlayer under the root when the scene has none, ready for clips
# - the meta "humgen3d_companion" with the version that set the scene up

# The manifest format this version reads. A newer one is skipped with a warning
const MANIFEST_FORMAT := 1
const MANIFEST_EXTENSION := ".humgen3d.json"

const VERSION := "0.5.0"
const HAIR_SHADER := "res://addons/humgen3d_companion/hair_cards.gdshader"
# Meta of a hair card shader material that keeps the standard material it replaced
const PLAIN_MATERIAL_META := "humgen3d_plain_material"

# The file being imported, from _get_import_options, which Godot asks for the
# options of a scene right before it imports it
var _source_path := ""

# Import options, in the Import dock and the Advanced Import Settings of a scene,
# saved in its .import file. The defaults are what the Companion does without them.
const OPTION := "humgen3d/set_up_character"
const OPT_HAIR_SHADING := "humgen3d/hair/shading"
const OPT_HAIR_CUTOFF := "humgen3d/hair/cutoff"
const OPT_CAP_MODE := "humgen3d/hair/haircap"
const OPT_SKIN_SCATTER := "humgen3d/skin/subsurface_scattering"
const OPT_SKIN_STRENGTH := "humgen3d/skin/scatter_strength"
const OPT_SKIN_SPECULAR := "humgen3d/skin/specular"
const OPT_BONE_MAP := "humgen3d/rig/humanoid_bone_map"
const OPT_PLAYER := "humgen3d/rig/add_animation_player"
# Values of OPT_HAIR_SHADING and OPT_CAP_MODE. They are saved in the .import files
# of users' projects: a value keeps its meaning for good, a removed choice leaves
# its number unused and a new choice takes a new number
const HAIR_SHADER_MODE := 0
const HAIR_CUTOUT_MODE := 1
const CAP_BLENDED := 0
const CAP_AS_IMPORTED := 1
# Alpha below which a hair card texel is cut out. The export bakes the strand
# coverage of the hair atlas into the alpha: solid strands with anti-aliased
# edges and faint fine strands. Godot discards everything under the scissor
# before alpha to coverage, so at the half alpha engines default to the fine
# strands and the edges were lost and the hair looked sparse next to Unity,
# whose alpha to mask turns the same alpha into partial coverage instead of
# clipping it. 0.15 keeps the fine strands; below that the soft fringe of the
# cards starts to show as a halo
const HAIR_CUTOFF := 0.15
# Strength of the subsurface scattering of the skin, 0 to 1
const SKIN_SCATTER := 0.5
# Specular of the skin and the hair cards (the "Specular" slider under Metallic),
# where 0.5 is the glTF default. Blender's skin averages 0.06 and the cards 0.13;
# skin reflects a little more in reality, 0.3 keeps a soft highlight
const SKIN_SPECULAR := 0.3
const HAIR_SPECULAR := 0.25
# The haircaps lie under the hair cards and show between them. They get the tint
# the card shader gives the cards and are darker than their baked color, as the
# hair over them would shade them: lit as a bare surface the cap was the brightest
# hair on the head and showed as an orange parting. And no reflection of the
# environment, which the cards do not have either: with it the sky laid a grey
# sheen over the cap that made it read as skin
const CAP_COLOR := Color(0.7, 0.8, 0.7)
const CAP_SPECULAR := 0.0


func _get_import_options(path: String) -> void:
	_source_path = path
	add_import_option_advanced(TYPE_BOOL, OPTION, true)
	# The hair cards: shaded as hair from the flow map (when the export has one), or
	# the standard material cut out
	add_import_option_advanced(TYPE_INT, OPT_HAIR_SHADING, HAIR_SHADER_MODE,
		PROPERTY_HINT_ENUM, "Hair Shader:%d,Standard Cutout:%d" % [HAIR_SHADER_MODE, HAIR_CUTOUT_MODE])
	add_import_option_advanced(TYPE_FLOAT, OPT_HAIR_CUTOFF, HAIR_CUTOFF,
		PROPERTY_HINT_RANGE, "0,1,0.01")
	add_import_option_advanced(TYPE_INT, OPT_CAP_MODE, CAP_BLENDED,
		PROPERTY_HINT_ENUM, "Blended Under The Hair:%d,As Imported:%d" % [CAP_BLENDED, CAP_AS_IMPORTED])
	add_import_option_advanced(TYPE_BOOL, OPT_SKIN_SCATTER, true)
	add_import_option_advanced(TYPE_FLOAT, OPT_SKIN_STRENGTH, SKIN_SCATTER,
		PROPERTY_HINT_RANGE, "0,1,0.01")
	add_import_option_advanced(TYPE_FLOAT, OPT_SKIN_SPECULAR, SKIN_SPECULAR,
		PROPERTY_HINT_RANGE, "0,1,0.01")
	add_import_option_advanced(TYPE_BOOL, OPT_BONE_MAP, true)
	add_import_option_advanced(TYPE_BOOL, OPT_PLAYER, true)


func _get_option_visibility(path: String, for_animation: bool, option: String) -> Variant:
	if not option.begins_with("humgen3d/"):
		return null
	if for_animation:
		return false
	# Only for the files of an export, which have a manifest in their folder
	return path.is_empty() or not _manifest_candidates(path).is_empty()


func _post_process(scene: Node) -> void:
	if not _option(OPTION, true):
		return
	var manifest := _find_manifest(_source_path)
	if manifest.is_empty():
		return
	var skeleton := _find_skeleton(scene)
	if skeleton == null:
		return
	var materials := 0
	for mesh_instance in _find_all(scene, "MeshInstance3D"):
		materials += _set_up_materials(mesh_instance, manifest)
	if _option(OPT_BONE_MAP, true):
		_set_up_bone_map(skeleton)
	if _option(OPT_PLAYER, true) and _find_all(scene, "AnimationPlayer").is_empty():
		var player := AnimationPlayer.new()
		player.name = "AnimationPlayer"
		scene.add_child(player)
		player.owner = scene
	scene.set_meta("humgen3d_companion", VERSION)
	print("Human Generator 3D Companion: set up %s (%d hair and skin materials)" % [scene.name, materials])


# The value of an import option, or its default when the scene was imported
# before the option existed
func _option(name: String, default: Variant) -> Variant:
	var value: Variant = get_option_value(name)
	return default if value == null else value


# The manifest of the export the file belongs to, with its folder as "_folder",
# or an empty dictionary when no manifest lists the file
func _find_manifest(source: String) -> Dictionary:
	if source.is_empty():
		return {}
	for path: String in _manifest_candidates(source):
		var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not (manifest is Dictionary) or not manifest.has("humgen3d_export"):
			continue
		var folder := path.get_base_dir()
		var lists_source := false
		var files: Variant = manifest.get("files")
		if files is Dictionary:
			var listed: Array = [files.get("character")]
			if files.get("animations") is Array:
				listed.append_array(files["animations"])
			for file: Variant in listed:
				if file is String and not file.is_empty() \
						and folder.path_join(file).simplify_path() == source.simplify_path():
					lists_source = true
		var format: Variant = manifest["humgen3d_export"]
		if not (format is float or format is int) or int(format) > MANIFEST_FORMAT:
			# A newer format may list its files differently: the manifest named
			# after the file is enough to know it is an export
			if lists_source or path == source.get_basename() + MANIFEST_EXTENSION:
				push_warning("Human Generator 3D Companion: %s was made by a newer Human Generator 3D (export format %s), update the Companion to set it up" % [source, str(format)])
				return {}
			continue
		if not lists_source:
			continue
		manifest["_folder"] = folder
		return manifest
	return {}


# The manifests that may list a file: `<Name>.humgen3d.json` of a character
# first, then every other manifest in its folder, for an animation file
func _manifest_candidates(source: String) -> PackedStringArray:
	var found := PackedStringArray()
	var own := source.get_basename() + MANIFEST_EXTENSION
	if FileAccess.file_exists(own):
		found.append(own)
	var folder := source.get_base_dir()
	for file in DirAccess.get_files_at(folder):
		var path := folder.path_join(file)
		if file.ends_with(MANIFEST_EXTENSION) and path != own:
			found.append(path)
	return found


# The type of a material in the manifest (skin, hair_cards, haircap, ...), empty
# for a material the manifest does not list
func _material_type(manifest: Dictionary, material_name: String) -> String:
	var materials: Variant = manifest.get("materials")
	if not (materials is Dictionary) or not (materials.get(material_name) is Dictionary):
		return ""
	var type: Variant = materials[material_name].get("type")
	return type if type is String else ""


func _set_up_materials(mesh_instance: MeshInstance3D, manifest: Dictionary) -> int:
	var count := 0
	var mesh: Mesh = mesh_instance.mesh
	for i in mesh.get_surface_count():
		var material := _surface_material(mesh_instance, i)
		if material == null or not (material is BaseMaterial3D):
			continue
		var type := _material_type(manifest, material.resource_name)
		if type == "hair_cards":
			var cutoff: float = _option(OPT_HAIR_CUTOFF, HAIR_CUTOFF)
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			material.alpha_scissor_threshold = cutoff
			material.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.metallic_specular = HAIR_SPECULAR
			var flow: Texture2D = null
			if _option(OPT_HAIR_SHADING, HAIR_SHADER_MODE) == HAIR_SHADER_MODE:
				flow = _flow_texture(manifest, material.resource_name)
			if flow != null:
				var hair := _hair_material(material, flow, cutoff)
				if hair != null:
					mesh.surface_set_material(i, hair)
					mesh_instance.set_surface_override_material(i, null)
			count += 1
		elif type == "haircap" or type == "face_haircap":
			if _option(OPT_CAP_MODE, CAP_BLENDED) != CAP_BLENDED:
				continue
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
			material.albedo_color = CAP_COLOR
			material.metallic_specular = CAP_SPECULAR
			count += 1
		elif type == "skin":
			if _option(OPT_SKIN_SCATTER, true):
				material.subsurf_scatter_enabled = true
				material.subsurf_scatter_skin_mode = true
				material.subsurf_scatter_strength = _option(OPT_SKIN_STRENGTH, SKIN_SCATTER)
			material.metallic_specular = _option(OPT_SKIN_SPECULAR, SKIN_SPECULAR)
			count += 1
	return count


func _flow_texture(manifest: Dictionary, material_name: String) -> Texture2D:
	# The flow map of the cards, the "flow" file of the material in the manifest
	var textures: Variant = manifest["materials"][material_name].get("textures")
	if not (textures is Dictionary):
		return null
	var flow: Variant = textures.get("flow")
	if not (flow is Dictionary) or not (flow.get("file") is String):
		return null
	var path: String = manifest["_folder"].path_join(flow["file"]).simplify_path()
	if not FileAccess.file_exists(path):
		return null
	if ResourceLoader.exists(path):
		var texture := load(path)
		if texture is Texture2D:
			return texture
	# Not imported yet, when the scene imports before its textures
	var image := Image.load_from_file(path)
	if image != null:
		return ImageTexture.create_from_image(image)
	return null


func _hair_material(plain: BaseMaterial3D, flow: Texture2D, cutoff: float) -> ShaderMaterial:
	var shader := load(HAIR_SHADER)
	if shader == null:
		return null
	var material := ShaderMaterial.new()
	material.shader = shader
	material.resource_name = plain.resource_name
	material.set_shader_parameter("albedo_texture", plain.albedo_texture)
	material.set_shader_parameter("normal_texture", plain.normal_texture)
	material.set_shader_parameter("normal_scale", plain.normal_scale if plain.normal_enabled else 0.0)
	material.set_shader_parameter("roughness_texture", plain.roughness_texture)
	material.set_shader_parameter("flow_texture", flow)
	material.set_shader_parameter("alpha_scissor_threshold", cutoff)
	material.set_meta(PLAIN_MATERIAL_META, plain)
	return material


func _set_up_bone_map(skeleton: Skeleton3D) -> void:
	var profile := SkeletonProfileHumanoid.new()
	var bone_map := BoneMap.new()
	bone_map.profile = profile
	for i in profile.get_bone_size():
		var bone := profile.get_bone_name(i)
		if skeleton.find_bone(bone) >= 0:
			bone_map.set_skeleton_bone_name(bone, bone)
	skeleton.set_meta("humgen3d_bone_map", bone_map)


func _surface_material(mesh_instance: MeshInstance3D, surface: int) -> Material:
	var material := mesh_instance.get_surface_override_material(surface)
	if material == null:
		material = mesh_instance.mesh.surface_get_material(surface)
	return material


func _find_skeleton(node: Node) -> Skeleton3D:
	var found := _find_all(node, "Skeleton3D")
	return found[0] if not found.is_empty() else null


func _find_all(node: Node, cls: String, out: Array = []) -> Array:
	if node.get_class() == cls:
		out.append(node)
	for child in node.get_children():
		_find_all(child, cls, out)
	return out
