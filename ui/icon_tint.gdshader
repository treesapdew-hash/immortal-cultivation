shader_type canvas_item;

// Flips dark icons to light, then tints them.
uniform vec4 tint : source_color = vec4(0.75, 0.85, 0.95, 0.45);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4((vec3(1.0) - tex.rgb) * tint.rgb, tex.a * tint.a);
}