// Optional CRT scanlines over the whole screen.
shader_type canvas_item;

void fragment() {
	COLOR = mod(FRAGCOORD.y, 3.0) < 1.0 ? vec4(0.0, 0.0, 0.0, 0.16) : vec4(0.0);
}
