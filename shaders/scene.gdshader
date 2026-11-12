// Sky, water column and seabed for one place. Colors come from the place data.
shader_type canvas_item;
render_mode unshaded, blend_disabled;

#include "res://shaders/common.gdshaderinc"

uniform float W = 320.0;
uniform float H = 200.0;
uniform float SURF = 84.0;
uniform float BED = 176.0;
uniform vec3 sky_top = vec3(0.36, 0.55, 0.78);
uniform vec3 sky_hor = vec3(0.81, 0.88, 0.93);
uniform vec4 glow = vec4(1.0, 0.6, 0.4, 0.0);
uniform vec3 water_top = vec3(0.25, 0.52, 0.56);
uniform vec3 water_deep = vec3(0.05, 0.15, 0.2);
uniform vec3 bed0 = vec3(0.6);
uniform vec3 bed1 = vec3(0.5);
uniform vec3 bed2 = vec3(0.4);
uniform vec3 bed3 = vec3(0.3);
// 0 sand, 1 rock, 2 pebble, 3 mud.
uniform int bed_style = 0;
uniform sampler2D bedtex : filter_nearest;

float bed_y(int x) {
	vec2 v = texelFetch(bedtex, ivec2(x, 0), 0).rg;
	return floor(v.r * 255.0 + 0.5) * 256.0 + floor(v.g * 255.0 + 0.5);
}

vec3 bands(vec3 a, vec3 b, float k, int n, int xi, int yi) {
	float fn = float(n);
	float s = clamp(k, 0.0, 1.0) * fn;
	float i = floor(s);
	float f = s - i;
	if (f > 0.72 && (xi + yi) % 2 == 0) i += 1.0;
	return mix(a, b, clamp(i / fn, 0.0, 1.0));
}

void fragment() {
	float x = floor(UV.x * W);
	float y = floor(UV.y * H);
	int xi = int(x);
	int yi = int(y);
	vec3 col;
	if (y < SURF) {
		float k = y / max(1.0, SURF);
		col = bands(sky_top, sky_hor, pow(k, 1.3), 9, xi, yi);
		float g = glow.a * pow(k, 2.4);
		col = mix(col, glow.rgb, clamp(g, 0.0, 1.0));
	} else {
		float by = bed_y(xi);
		if (y >= by) {
			float d = y - by;
			float h = hash2(xi, yi, 3);
			if (bed_style == 1) {
				float c = hash2(xi / 3, yi / 2, 7);
				col = d == 0.0 ? bed0 : (c < 0.35 ? bed1 : (c < 0.75 ? bed2 : bed3));
				if (d > 0.0 && h < 0.12) col = bed3;
				if (d > 0.0 && h > 0.95) col = bed0;
			} else if (bed_style == 2) {
				col = d == 0.0 ? bed0 : (d < 3.0 ? bed1 : (d < 9.0 ? bed2 : bed3));
				float pb = hash2(xi / 2, yi / 2, 11);
				if (d > 0.0 && pb < 0.18) col = bed0;
				else if (d > 0.0 && pb > 0.86) col = bed3;
			} else if (bed_style == 3) {
				col = d == 0.0 ? bed0 : (d < 4.0 ? bed1 : (d < 12.0 ? bed2 : bed3));
				if (d > 0.0 && h < 0.04) col = bed3;
			} else {
				col = d == 0.0 ? bed0 : (d < 3.0 ? bed1 : (d < 9.0 ? bed2 : bed3));
				if (d > 0.0 && h < 0.08) col = bed2;
				else if (d > 0.0 && h > 0.965) col = bed0;
			}
		} else {
			float k = (y - SURF) / max(1.0, BED - SURF);
			col = bands(water_top, water_deep, k, 9, xi, yi);
			if (by - y < 3.0 && (xi + yi) % 2 == 0) col = mix(col, water_deep, 0.25);
		}
	}
	COLOR = vec4(col, 1.0);
}
