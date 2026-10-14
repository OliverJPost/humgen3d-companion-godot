// Hair cards of a Human Generator character, shaded as hair.
//
// A cut-out card lit as a flat surface reads as a ribbon: its highlight is a sheet across
// the card. Hair reflects along its strands instead. This is a Kajiya-Kay strand model with
// the two highlights of Marschner (a white one and one tinted by the hair color, shifted
// apart along the strands), fed by the flow map the export bakes for the cards: the
// direction of the strands in the UV space of the card (red and green) and a noise per
// strand (blue) that breaks the highlights up and varies the color between strands. The
// cards are two-sided and alpha scissored at the half alpha of the export, with alpha to
// coverage for cameras that use MSAA, as the Companion set them up before.
shader_type spatial;
render_mode cull_disabled, alpha_to_coverage, depth_draw_opaque;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic;
uniform float normal_scale : hint_range(-16.0, 16.0) = 1.0;
// The metallic-roughness map of the export, roughness in green
uniform sampler2D roughness_texture : hint_roughness_g, filter_linear_mipmap;
uniform sampler2D flow_texture : filter_linear_mipmap;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.15;
uniform float alpha_antialiasing_edge : hint_range(0.0, 1.0) = 0.3;
// A card seen from its side is a line with all its strands pressed into it. The card is
// faded out before that: below this value of how much the card faces the camera (0 from
// its side, 1 from the front). The cards around it, or the card across it that loose
// strands get, show the hair instead. 0 turns the fade off.
uniform float edge_fade : hint_range(0.0, 1.0) = 0.25;
// How much of the alpha a card keeps from its side. Faded out completely, a lock whose
// card turns its side to the camera halfway down is cut in two, and its tip floats in the
// air. At this value the solid strands stay and the soft ones between them go.
uniform float edge_fade_floor : hint_range(0.0, 1.0) = 0.4;
// The baked color is the color of a single strand. A head of hair is lighter than that, as
// light scatters between the strands and comes back out, and warmer: lit as its plain baked
// color the hair was clearly darker and redder than in Blender under a sun and a sky. The
// tint is a multiplier per channel (red, green, blue) that takes the red and blue down
// against the green, which moves a brown from red towards gold
uniform float brightness : hint_range(0.0, 4.0) = 1.5;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
uniform vec3 tint = vec3(0.87, 1.0, 0.87);
// The highlights are kept weak and wide: stronger or tighter ones lay a grey sheen over
// the crown that makes the hair look wet
uniform float diffuse_wrap : hint_range(0.0, 1.0) = 0.35;
uniform float primary_strength : hint_range(0.0, 2.0) = 0.025;
uniform float primary_shift : hint_range(-1.0, 1.0) = -0.15;
uniform float primary_exponent : hint_range(1.0, 256.0) = 40.0;
uniform float secondary_strength : hint_range(0.0, 2.0) = 0.08;
uniform float secondary_shift : hint_range(-1.0, 1.0) = 0.15;
uniform float secondary_exponent : hint_range(1.0, 256.0) = 12.0;
uniform float shift_noise : hint_range(0.0, 1.0) = 0.6;
uniform float strand_variation : hint_range(0.0, 1.0) = 0.2;

varying vec3 strand_direction;
varying float strand_noise;
varying float smoothness;

void fragment() {
	vec4 albedo = texture(albedo_texture, UV);
	vec4 flow = texture(flow_texture, UV);
	strand_noise = flow.b;
	// The U and V axes of the card in view space. The tangents of the mesh are made
	// perpendicular to the normals, which follow the shape of the head and lie in the plane
	// of a card that stands on the head or crosses another one: there the axes come from
	// how the position and the UV change over the screen instead, which is exact but
	// constant over a triangle.
	vec3 position_dx = dFdx(VERTEX);
	vec3 position_dy = dFdy(VERTEX);
	vec2 uv_dx = dFdx(UV);
	vec2 uv_dy = dFdy(UV);
	vec3 card_normal = normalize(cross(position_dx, position_dy));
	vec3 perpendicular_dx = cross(card_normal, position_dx);
	vec3 perpendicular_dy = cross(position_dy, card_normal);
	vec3 card_u = normalize(perpendicular_dy * uv_dx.x + perpendicular_dx * uv_dy.x);
	// V points down in Godot, the flow map was baked with V up
	vec3 card_v = -normalize(perpendicular_dy * uv_dx.y + perpendicular_dx * uv_dy.y);
	float mesh_frame = smoothstep(0.2, 0.5, abs(dot(card_normal, NORMAL)));
	card_u = normalize(mix(card_u, TANGENT, mesh_frame));
	card_v = normalize(mix(card_v, BINORMAL, mesh_frame));
	// The strand direction from the flow map, in view space like the normal; straight
	// down the card (its V axis, root to tip) when the map is missing or empty
	vec2 direction = flow.rg * 2.0 - 1.0;
	vec3 along = direction.x * card_u + direction.y * card_v;
	strand_direction = dot(direction, direction) < 0.01 ? -card_v : normalize(along);
	smoothness = 1.0 - texture(roughness_texture, UV).g;
	vec3 color = mix(vec3(dot(albedo.rgb, vec3(0.2126, 0.7152, 0.0722))), albedo.rgb, saturation);
	ALBEDO = color * tint * brightness * (1.0 + (strand_noise - 0.5) * 2.0 * strand_variation);
	float facing = abs(dot(card_normal, VIEW));
	ALPHA = albedo.a * mix(edge_fade_floor, 1.0, smoothstep(edge_fade * 0.3, max(edge_fade, 0.0001), facing));
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
	ALPHA_ANTIALIASING_EDGE = alpha_antialiasing_edge;
	ALPHA_TEXTURE_COORDINATE = UV * vec2(textureSize(albedo_texture, 0));
	// The normals follow the shape of the head, not the card, so which face of a card is
	// seen says little about them: a card across the hair has both faces along its normal.
	// Turn the normal towards the camera by its own direction instead of by the face, or
	// such a card is lit triangle by triangle.
	vec3 head_normal = FRONT_FACING ? NORMAL : -NORMAL;
	NORMAL = dot(head_normal, VIEW) < 0.0 ? -head_normal : head_normal;
	// The frame of the normal map: the axes of the card, made perpendicular to the normal
	// from the one that is the least along it
	vec3 across = card_u - NORMAL * dot(NORMAL, card_u);
	vec3 down = card_v - NORMAL * dot(NORMAL, card_v);
	if (dot(across, across) >= dot(down, down)) {
		TANGENT = normalize(across);
		BINORMAL = cross(NORMAL, TANGENT) * (dot(cross(NORMAL, TANGENT), card_v) < 0.0 ? -1.0 : 1.0);
	} else {
		BINORMAL = normalize(down);
		TANGENT = cross(BINORMAL, NORMAL) * (dot(cross(BINORMAL, NORMAL), card_u) < 0.0 ? -1.0 : 1.0);
	}
	NORMAL_MAP = texture(normal_texture, UV).rgb;
	NORMAL_MAP_DEPTH = normal_scale;
	ROUGHNESS = 1.0 - smoothness;
	METALLIC = 0.0;
	// No reflection of the environment: the lights are the only highlights, so flat cards
	// do not pick up a grey sheen of the sky at glancing angles
	SPECULAR = 0.0;
}

// Kajiya-Kay: the highlight of a strand depends on the angle between the strand and the
// half vector, not on a normal
float strand_specular(vec3 strand, vec3 half_vector, float exponent) {
	float dot_th = dot(strand, half_vector);
	float sin_th = sqrt(clamp(1.0 - dot_th * dot_th, 0.0, 1.0));
	float attenuation = smoothstep(-1.0, 0.0, dot_th);
	return attenuation * pow(sin_th, exponent);
}

void light() {
	float n_dot_l = dot(NORMAL, LIGHT);
	// A card is a flat stand-in for a round bundle: wrap the diffuse so it does not go
	// black where the bundle would still catch light
	float diffuse = clamp((n_dot_l + diffuse_wrap) / (1.0 + diffuse_wrap), 0.0, 1.0);
	vec3 half_vector = normalize(LIGHT + VIEW);
	float shift = (strand_noise - 0.5) * shift_noise;
	vec3 primary_strand = normalize(strand_direction + (primary_shift + shift) * NORMAL);
	vec3 secondary_strand = normalize(strand_direction + (secondary_shift + shift) * NORMAL);
	float exponent_scale = 0.5 + smoothness;
	float primary = strand_specular(primary_strand, half_vector, primary_exponent * exponent_scale);
	float secondary = strand_specular(secondary_strand, half_vector, secondary_exponent * exponent_scale);
	// The white highlight reflects off the surface of the hair, the colored one has passed
	// through it; the noise breaks the colored one up between strands
	vec3 specular = vec3(primary_strength * primary) + secondary_strength * secondary * ALBEDO * (0.5 + strand_noise);
	// No highlight on the unlit side of a card
	specular *= smoothstep(-0.3, 0.3, n_dot_l);
	// LIGHT_COLOR carries a factor PI for physically based models, see the Godot docs
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * diffuse / PI;
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * specular / PI;
}
