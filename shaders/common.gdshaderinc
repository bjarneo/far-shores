// Integer hash from the original engine. It gives the same pixel noise as the canvas version.
float hash2(int x, int y, int s) {
	uint h = (uint(x) * 374761393u) ^ (uint(y) * 668265263u) ^ (uint(s + 1) * 982451653u);
	h = (h ^ (h >> 13u)) * 1274126177u;
	h = h ^ (h >> 16u);
	return float(h) / 4294967296.0;
}

float jround(float v) {
	return floor(v + 0.5);
}

vec3 rgb8(int r, int g, int b) {
	return vec3(float(r), float(g), float(b)) / 255.0;
}
