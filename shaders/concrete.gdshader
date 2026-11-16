shader_type spatial;
// Beton-Paneele in Weltkoordinaten: Fugenraster, Farbvariation pro Platte,
// Schmutzfahnen an Wänden. Braucht keine UVs, skaliert mit jeder Boxgröße.

uniform vec3 base_color : source_color = vec3(0.36, 0.37, 0.38);
uniform float panel_size = 4.0;
uniform float seam = 0.035;
uniform float variation = 0.10;

varying vec3 w_pos;
varying vec3 w_nrm;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	vec3 n = abs(normalize(w_nrm));
	vec2 uv;
	float wall = 1.0;
	if (n.y > n.x && n.y > n.z) {
		uv = w_pos.xz;
		wall = 0.0;
	} else if (n.x > n.z) {
		uv = w_pos.zy;
	} else {
		uv = w_pos.xy;
	}
	vec2 g = uv / panel_size;
	vec2 cell = floor(g);
	vec2 f = fract(g);

	float tint = hash(cell);
	float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)) * panel_size;
	float dist_fade = clamp(1.0 - (-VERTEX.z) / (panel_size * 70.0), 0.0, 1.0);
	float line = (1.0 - smoothstep(seam, seam * 2.5, edge)) * dist_fade;

	// Schmutzfahnen: laufen von der oberen Fuge nach unten aus
	float streak = hash(vec2(floor(uv.x * 2.5), cell.y + 7.0));
	float drip = wall * step(0.55, streak) * pow(f.y, 3.0) * 0.22 * dist_fade;

	vec3 col = base_color * (1.0 + (tint - 0.5) * variation * 2.0);
	col *= 1.0 - drip;
	col *= 1.0 - line * 0.6;

	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
}
