shader_type spatial;
// Asfalto con bordes blancos y línea central discontinua. La carretera va a lo largo de X o de Z.
uniform vec3 asphalt : source_color = vec3(0.24, 0.25, 0.28);
uniform vec3 asphalt_b : source_color = vec3(0.28, 0.29, 0.32);
uniform vec3 paint : source_color = vec3(0.93, 0.92, 0.85);
uniform bool along_x = false;
uniform float width = 8.0;
uniform vec3 center = vec3(0.0);
uniform bool center_line = true;

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float along = along_x ? wpos.x : wpos.z;
	float across = along_x ? wpos.z - center.z : wpos.x - center.x;
	float half_w = width * 0.5;
	vec3 col = mix(asphalt, asphalt_b, hash(floor(wpos.xz * 2.0)) * 0.6);
	float edge = step(half_w - 0.45, abs(across)) * step(abs(across), half_w - 0.3);
	float dash = step(abs(across), 0.08) * step(0.5, fract(along / 6.0)) * float(center_line);
	col = mix(col, paint, max(edge, dash));
	ALBEDO = col;
	ROUGHNESS = 0.9;
}
