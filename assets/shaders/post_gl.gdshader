shader_type canvas_item;
// Постобработка для рендерера Compatibility (в том числе веб-сборки).
//
// Экранную текстуру (hint_screen_texture) там читать нельзя — кадр приходит белым,
// поэтому эффект строится наложением: виньетка и зерно затемняют через альфу
// (mix к чёрному на (1-k) — это ровно умножение на k), а вспышка урона подмешивается
// тем же слоем. Набор параметров совпадает с post.gdshader, чтобы Main.gd не ветвился.
// tint и desaturate этим слоем не поддерживаются — в игре они не используются.

uniform float vignette_strength : hint_range(0.0, 1.5) = 0.85;
uniform float vignette_radius : hint_range(0.0, 1.5) = 0.30;
uniform float grain_amount : hint_range(0.0, 0.3) = 0.045;
uniform float damage_flash : hint_range(0.0, 1.0) = 0.0;
uniform float darkness : hint_range(0.0, 1.0) = 0.0;
uniform float desaturate : hint_range(0.0, 1.0) = 0.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	// множитель виньетки: 1 в центре, 0.16 по краям
	float d = distance(SCREEN_UV, vec2(0.5));
	float v = smoothstep(vignette_radius, 0.80, d);
	float k = mix(1.0, 0.16, v * vignette_strength);
	// зерно: тот же шум, но только затемняет — смешать ярче наложения нельзя
	float g = fract(sin(dot(SCREEN_UV * (vec2(1024.0, 768.0) + vec2(TIME * 60.0)), vec2(12.9898, 78.233))) * 43758.5453);
	k *= clamp(1.0 + (g - 0.5) * grain_amount, 0.0, 1.0);
	k *= (1.0 - darkness) * (1.0 - pulse * 0.10);
	// вспышка урона: подмешиваем красный поверх затемнения
	float f = damage_flash * 0.55;
	float a = clamp(1.0 - k * (1.0 - f), 0.0, 1.0);
	vec3 c = vec3(0.55, 0.04, 0.05) * f / max(a, 0.0001);
	COLOR = vec4(c, a);
}
