shader_type spatial;
// Suelo low-poly: mezcla de dos colores con manchas suaves en coordenadas del mundo.
uniform vec3 color_a : source_color = vec3(0.45, 0.68, 0.32);
uniform vec3 color_b : source_color = vec3(0.36, 0.58, 0.27);
uniform vec3 color_c : source_color = vec3(0.55, 0.72, 0.36);
uniform float scale = 0.045;
uniform float detail = 0.35;

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz * scale;
	float n = noise(p) * 0.65 + noise(p * 3.1) * 0.35;
	float m = noise(p * 7.0 + 13.0);
	vec3 col = mix(color_a, color_b, smoothstep(0.35, 0.75, n));
	col = mix(col, color_c, smoothstep(0.7, 0.95, m) * detail);
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
}
