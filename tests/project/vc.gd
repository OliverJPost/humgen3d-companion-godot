extends SceneTree
func _init():
	var root = load("res://Jake.glb").instantiate()
	for mi in _all(root, "MeshInstance3D"):
		if not ("Hair" in mi.name): continue
		for s in mi.mesh.get_surface_count():
			var m = mi.mesh.surface_get_material(s)
			var arrays = mi.mesh.surface_get_arrays(s)
			var col = arrays[Mesh.ARRAY_COLOR]
			var info = "no vertex colors"
			if col != null and col.size() > 0:
				var mn = 1.0; var mx = 0.0; var amn = 1.0
				for c in col: mn = min(mn, c.r); mx = max(mx, c.r); amn = min(amn, c.a)
				info = "vertex colors r %.2f..%.2f, min alpha %.2f" % [mn, mx, amn]
			print(mi.name, " / ", m.resource_name, ": use_as_albedo=", m.vertex_color_use_as_albedo, " scissor=", m.alpha_scissor_threshold, " ", info)
	quit()
func _all(n, cls, out = []):
	if n.get_class() == cls: out.append(n)
	for c in n.get_children(): _all(c, cls, out)
	return out
