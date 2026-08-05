shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 0.847, 0.416, 1.0);
uniform vec2 pixel_size = vec2(0.001, 0.001);

void fragment() {
    vec4 source = texture(TEXTURE, UV);
    float neighbor_alpha = 0.0;
    neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(pixel_size.x, 0.0)).a);
    neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV - vec2(pixel_size.x, 0.0)).a);
    neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(0.0, pixel_size.y)).a);
    neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV - vec2(0.0, pixel_size.y)).a);

    if (source.a <= 0.01 && neighbor_alpha > 0.01) {
        COLOR = outline_color;
    } else {
        COLOR = vec4(source.rgb, 0.0);
    }
}
