shader_type spatial;
// Agua sencilla: dos azules que se mueven y algo de brillo.
uniform vec3 deep : source_color = vec3(0.16, 0.42, 0.62);
uniform vec3 shallow : source_color = vec3(0.3, 0.62, 0.78);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float w = sin(wpos.x * 0.9 + TIME * 1.3) * 0.5 + sin(wpos.z * 0.35 - TIME * 0.9) * 0.5;
	float w2 = sin((wpos.x + wpos.z) * 2.1 + TIME * 2.0);
	ALBEDO = mix(deep, shallow, w * 0.25 + 0.4 + w2 * 0.08);
	ROUGHNESS = 0.12;
	METALLIC = 0.0;
	SPECULAR = 0.6;
}
