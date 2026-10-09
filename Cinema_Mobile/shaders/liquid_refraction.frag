#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;
uniform vec2 u_view_size;
uniform float u_padding;
uniform float u_native;
uniform float u_touch_x;
uniform float u_pressure;
uniform float u_drag_y;
uniform float u_touch_y;
uniform sampler2D u_texture_input;

out vec4 frag_color;

void main() {
  vec2 view_size = mix(u_view_size, u_size, u_native);
  vec2 uv = FlutterFragCoord().xy / view_size;
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = mix(uv.y, 1.0 - uv.y, u_native);
#endif

  vec2 p = (uv - vec2(0.5)) * view_size;
  float pixel_scale = view_size.y / 88.0;
  float radius = 36.0 * pixel_scale;
  float touch_distance = abs(uv.x - u_touch_x) / 0.3;
  float weight = touch_distance < 1.0 ? (1.0 + cos(3.14159265 * touch_distance)) * 0.5 : 0.0;
  float proximity = 0.6 + 0.4 * (1.0 - abs(uv.y - u_touch_y));
  float bulge = (2.5 + max(0.0, u_drag_y * sign(p.y)) * 0.5 * weight * proximity) * u_pressure * pixel_scale;
  p.y -= sign(p.y) * bulge * min(abs(p.y) / (38.0 * pixel_scale), 1.0);
  vec2 q = abs(p) - (view_size * 0.5 - vec2(0.0, 6.0 * pixel_scale) - vec2(radius));
  vec2 corner = max(q, vec2(0.0));
  float distance_inside = -(length(corner) + min(max(q.x, q.y), 0.0) - radius) / pixel_scale;
  vec2 normal = length(corner) > 0.001
      ? normalize(corner) * sign(p)
      : (q.x > q.y ? vec2(sign(p.x), 0.0) : vec2(0.0, sign(p.y)));

  // A continuous rounded lens: the bevel rolls into a quieter magnified center.
  float bend = (1.0 - smoothstep(0.0, 20.0, distance_inside))
      * (0.55 + 0.45 * smoothstep(0.0, 5.0, distance_inside));
  vec2 refracted = ((uv - vec2(0.5)) / vec2(1.06, 1.16) + vec2(0.5)) * view_size;
  refracted -= normal * bend * 10.0 * pixel_scale;
  vec2 texture_size = view_size + vec2(u_padding * 2.0);
  vec2 refracted_uv = (refracted + vec2(u_padding)) / texture_size;
  vec2 fringe = normal * bend * 0.25 * pixel_scale / texture_size;
  vec4 center = texture(u_texture_input, clamp(refracted_uv, 0.0, 1.0));
  float red = texture(u_texture_input, clamp(refracted_uv + fringe, 0.0, 1.0)).r;
  float blue = texture(u_texture_input, clamp(refracted_uv - fringe, 0.0, 1.0)).b;
  frag_color = vec4(red, center.g, blue, center.a);
}
