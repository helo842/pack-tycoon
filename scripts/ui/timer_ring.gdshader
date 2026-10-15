// El anillo de espera, pero en 3D.
//
// Es el MISMO dibujo que el 2D (TimerRing): la pista del sprite ui_timer_track y
// encima las celdas cuyo angulo ya ha sido recorrido. Aqui no se puede pintar a
// mano celda a celda como en el Control, asi que lo hace el fragment shader con
// la misma rejilla de 16x16 y los mismos radios de banda.
//
// La rejilla se mide en el espacio de la PISTA: UV va de 0 a 1 en el quad, y la
// pista ocupa todo el quad, asi que (UV - 0.5) * 16 son celdas, igual que en
// TimerRing._draw().
shader_type spatial;
// unshaded  -> los colores de la paleta salen tal cual, sin luz que los tina.
// cull_disabled -> el quad se ve por las dos caras (la camara es fija, pero no
//                  cuesta nada y evita sorpresas si algun dia mira de lado).
// depth_draw_never -> es translucido y no tiene que tapar nada: del orden se
//                     encargan render_priority y la distancia.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform sampler2D track : source_color, filter_nearest, repeat_disable;

// Cuanto del anillo esta recorrido, de 0 a 1.
uniform float progress : hint_range(0.0, 1.0) = 0.0;

uniform vec4 ring_color : source_color = vec4(0.910, 0.502, 0.0, 1.0);
uniform vec4 inner_color : source_color = vec4(1.0, 0.847, 0.345, 1.0);
uniform vec4 head_color : source_color = vec4(0.973, 0.753, 0.0, 1.0);

// Los mismos numeros que TimerRing (la rejilla del sprite y su banda pintada).
const float GRID = 16.0;
const float BAND_IN = 6.0;
const float BAND_OUT = 7.6;
const float HEAD = 0.05;
// TAU ya viene definida en el lenguaje de shaders de Godot: no se redeclara.

void fragment() {
	vec2 d = (UV - vec2(0.5)) * GRID;
	float r = length(d);
	vec4 t = texture(track, UV);
	vec3 col = t.rgb;
	float a = t.a;

	if (progress > 0.0 && r >= BAND_IN && r <= BAND_OUT) {
		// Angulo desde las 12 en punto, en sentido horario, de 0 a 1. fract() y
		// no fposmod(): el lenguaje de shaders de Godot no trae fposmod, y
		// fract(atan/TAU) ya deja el angulo en [0,1) sea cual sea su signo.
		float ang = fract(atan(d.x, d.y) / TAU);
		if (ang <= progress) {
			col = (r > (BAND_IN + BAND_OUT) * 0.5) ? ring_color.rgb : inner_color.rgb;
			if (ang >= progress - HEAD) {
				col = head_color.rgb;
			}
			a = 1.0;
		}
	}

	ALBEDO = col;
	ALPHA = a;
}
