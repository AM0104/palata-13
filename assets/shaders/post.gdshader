shader_type canvas_item;
// Постобработка: виньетка, зерно, вспышка урона, затемнение, обесцвечивание.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float vignette_strength : hint_range(0.0, 1.5) = 0.85;
uniform float vignette_radius : hint_range(0.0, 1.5) = 0.30;
uniform float grain_amount : hint_range(0.0, 0.3) = 0.045;
uniform float damage_flash : hint_range(0.0, 1.0) = 0.0;
uniform float darkness : hint_range(0.0, 1.0) = 0.0;
uniform float desaturate : hint_range(0.0, 1.0) = 0.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec3 col = texture(screen_texture, SCREEN_UV).rgb;
	float d = distance(SCREEN_UV, vec2(0.5));
	float v = smoothstep(vignette_radius, 0.80, d);
	col *= mix(1.0, 0.16, v * vignette_strength);
	float g = fract(sin(dot(SCREEN_UV * (vec2(1024.0, 768.0) + vec2(TIME * 60.0)), vec2(12.9898, 78.233))) * 43758.5453);
	col += (g - 0.5) * grain_amount;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum), desaturate);
	col = mix(col, vec3(0.55, 0.04, 0.05), damage_flash * 0.55);
	col *= tint.rgb;
	col *= (1.0 - darkness);
	col *= (1.0 - pulse * 0.10);
	COLOR = vec4(col, 1.0);
}
