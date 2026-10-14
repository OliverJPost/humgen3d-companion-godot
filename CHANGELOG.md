# Changelog

## 0.5.0

- Only files with the manifest of their export next to them are set up: `<Name>.humgen3d.json`,
  written by Human Generator 4.0.32 and later, which lists the file as the character or one of
  its animation files. Exports without a manifest, from earlier versions included, are no longer
  set up and import as Godot imports them; export them again to get the manifest. The `*_Body`
  mesh and `*_Skin` material are no longer used to recognise a character.
- Skin, hair card and haircap materials are taken from the types in the manifest and the flow
  map of the cards from its `flow` file, instead of from the names, so custom naming works.
- A manifest of a newer export format is skipped with a warning to update the Companion.
- The `Humgen3d` import options only show for files with a manifest in their folder. The values
  of the hair shading and haircap choices are fixed numbers (0 and 1, as before), so the
  `.import` files keep their meaning.

## 0.4.0

- Import options for what the Companion sets up, in the Import dock and the Advanced Import
  Settings of a scene, saved per file in its `.import` file: hair shader or standard cutout, the
  hair cutoff, the haircap blended or as imported, subsurface scattering of the skin and its
  strength, the skin specular, the humanoid bone map and the AnimationPlayer. The defaults are
  what 0.3.0 did.

## 0.3.0

- Hair cards are cut out at alpha 0.15 instead of 0.5. Godot discards everything under the
  scissor before alpha to coverage, so at 0.5 the fine strands and the anti-aliased edges of the
  baked alpha were lost and the hair looked much sparser than in Unity, whose alpha to mask
  keeps them as partial coverage. Needs MSAA on the camera for soft edges, as before.
- Hair cards get the shipped `hair_cards.gdshader` when the export wrote their `*_Flow` map
  next to the scene (Human Generator 4.0.28 and later): highlights along the strands and a
  variation between them, with the scissor, alpha to coverage and both sides kept. The standard
  material is kept as the meta `humgen3d_plain_material` of the shader material.
  The highlights are weak and wide by default (`primary_strength` 0.025, `secondary_strength`
  0.08): stronger ones laid a grey sheen over the crown that made the hair look wet.
  The color is lifted and warmed (`brightness` 1.5, `tint` 0.87, 1, 0.87) to the color the hair
  has in Blender: lit as its plain baked color it was clearly darker and redder under a sun
  and a sky.
- The hair shader fades a card out when the camera looks along it (`edge_fade`, 0.25; 0 turns
  it off), where it would be a line with all its strands pressed into it. The card keeps a
  share of its alpha (`edge_fade_floor`, 0.4), so the solid strands stay and no tip of a lock
  is left floating in the air.
- The hair shader takes the axes of a card from the screen where the tangents of the mesh are
  invalid, and turns the normal towards the camera by its own direction instead of by the face.
  The normals of the cards follow the shape of the head, so cards that stand on the head or
  cross another card were lit dark, triangle by triangle, most visibly in an afro.
- Haircaps get the tint of the cards at 0.8 of their baked color (`CAP_COLOR`) and no
  reflection of the environment. Lit as a bare surface with the sky reflected in it, the cap
  was lighter than the hair over it and read as skin in every parting.


## 0.2.0

- Hair cards are cut out at alpha 0.5, the Godot default, as the export now bakes the strand
  coverage of the hair atlas into the alpha, with alpha to coverage for cameras that use MSAA.
- The skin material gets subsurface scattering in skin mode and a specular of 0.3, the hair
  cards a specular of 0.25, closer to the Blender materials than the glTF default of 0.5.
- The import check reports the scissor threshold, the alpha antialiasing and the scattering.

## 0.1.0

- Post-import setup of Human Generator characters: hair card and haircap transparency, humanoid
  BoneMap on the skeleton, an AnimationPlayer, and the `humgen3d_companion` meta.
- Import option `humgen3d/set_up_character` to turn it off per file.
- Headless import check in `tests/project`.
