# Human Generator 3D Companion for Godot

Sets up a character exported with the **Godot** recipe of [Human Generator](https://humgen3d.com)'s
Process tab the moment Godot imports the `.glb`, so nothing is left to do by hand. Godot already
gets most of it right on its own; the Companion makes it complete and keeps it that way.

It only sets up a file that has the manifest of its export next to it: `<Name>.humgen3d.json`,
which Human Generator 4.0.32 and later write next to every exported character, and which lists
the file as the character or one of its animation files. The manifest says what every material
is and where the flow map of the hair cards is, so the Companion does not depend on the names
and custom naming works. Every other file, a Human Generator export without a manifest
included, is imported by Godot as usual. A manifest of a newer export format than the
Companion reads is skipped with a warning to update the Companion.

- hair cards shaded as hair by the shipped `hair_cards.gdshader` when the export wrote their
  flow map (the `flow` texture of the cards in the manifest):
  a Kajiya-Kay strand model with a white and a color-tinted highlight that run along the strands,
  broken up and varied between strands by the noise of the map, alpha scissor at 0.15 with alpha
  to coverage for cameras that use MSAA, both sides shown. The export bakes the strand coverage
  of the hair atlas into the alpha, solid strands with anti-aliased edges and faint fine strands;
  Godot discards everything under the scissor before alpha to coverage, so at the half alpha of
  the earlier versions the fine strands were lost and the hair looked sparse next to Unity, whose
  alpha to mask turns the same alpha into partial coverage. Below 0.15 the soft fringe of the
  cards shows as a halo. The standard material the importer made is kept
  as the meta `humgen3d_plain_material` of the shader material, and is what cards without a flow
  map get. Haircaps as alpha blend with a depth pre-pass, tinted like the cards and without a reflection of the environment
- subsurface scattering in skin mode on the skin material, as the skin was rendered with
  scattering in Blender and looks flat and harsh without it, and a specular of 0.3 on the skin
  and 0.25 on the hair cards: the Blender materials reflect far less than the 0.5 that glTF
  materials default to, which made the skin look wet
- a humanoid `BoneMap` on the `Skeleton3D` (meta `humgen3d_bone_map`), as the bones carry the
  names of Godot's `SkeletonProfileHumanoid`
- an `AnimationPlayer` under the root when the scene has none, ready for clips
- the meta `humgen3d_companion` with the version that set the scene up


## Import options

Select the `.glb` in the FileSystem dock: for a file with a manifest in its folder the
**Import** dock (and *Advanced Import Settings*) shows a `Humgen3d` section with what the Companion sets up for that file. Change an option and
press *Reimport*; the choice is saved in the file's `.import` file, so it is kept on every later
reimport and in version control. The defaults are what the Companion does without them.

| Option | Default | What it does |
|---|---|---|
| `humgen3d/set_up_character` | on | Off leaves the file as Godot imports it |
| `humgen3d/hair/shading` | Hair Shader | *Standard Cutout* keeps the importer's standard material on the cards (alpha scissor, both sides) instead of the hair shader |
| `humgen3d/hair/cutoff` | 0.15 | Alpha below which a card texel is cut out |
| `humgen3d/hair/haircap` | Blended Under The Hair | *As Imported* leaves the haircap materials as the glTF importer made them |
| `humgen3d/skin/subsurface_scattering` | on | Subsurface scattering in skin mode on the skin |
| `humgen3d/skin/scatter_strength` | 0.5 | Its strength |
| `humgen3d/skin/specular` | 0.3 | The specular of the skin (0.5 is the glTF default) |
| `humgen3d/rig/humanoid_bone_map` | on | The humanoid `BoneMap` meta on the skeleton |
| `humgen3d/rig/add_animation_player` | on | An `AnimationPlayer` when the scene has none |

What Godot does by itself with the plain export is on the
[Export to Godot](https://humgen3d.com/docs/process/export-to-godot) page.

## Install

The download and the steps are on
[humgen3d.com/docs/process/godot-companion](https://humgen3d.com/docs/process/godot-companion).
In short: copy `addons/humgen3d_companion` into your project, enable **Human Generator 3D
Companion for Godot** under *Project > Project Settings > Plugins*, and keep the
`<Name>.humgen3d.json` next to the `.glb` when you copy an export into the project. Reimport
characters imported before that from the Import dock.

Tested with Godot 4.7.2 only. Other Godot 4 versions may work but are not verified.

## Import check

`tests/project/check.gd` loads an exported `.glb` (copied with its manifest and flow map) headless and writes `report.json` with the bones,
the humanoid profile match, materials, blend shapes and what the Companion set up. The test
project has the plugin enabled:

```
cp <export>/Jake.glb <export>/Jake.humgen3d.json <export>/Jake_HairCards_Flow.png tests/project/
godot --headless --path tests/project --import
godot --headless --path tests/project --script check.gd
```

Last run on 2026-10-14 with Godot 4.7.2 on an export with a manifest: the hook runs during the
headless import, all 56 profile bones match, hair shader with flow map, skin scattering, one
AnimationPlayer added. The same file without its manifest is left as Godot imports it.

## Status

Early access. Feedback on what the export should set up for you goes to
[humgen3d.com/feedback/process](https://humgen3d.com/feedback/process).

## License

MIT. The Human Generator add-on for Blender is a separate, paid product; this Companion works on
what it exports.
