shader_type spatial;
// Baldosas o adoquines con juntas, en coordenadas del mundo.
uniform vec3 color_a : source_color = vec3(0.86, 0.8, 0.68);
uniform vec3 color_b : source_color = vec3(0.8, 0.73, 0.6);
uniform vec3 grout : source_color = vec3(0.6, 0.55, 0.47);
uniform float tile = 1.2;
uniform float joint = 0.05;

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz / tile;
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float j = joint / tile;
	float line = 1.0 - step(j, f.x) * step(j, f.y);
	vec3 col = mix(color_a, color_b, hash(cell));
	ALBEDO = mix(col, grout, line);
	ROUGHNESS = 0.85;
}
