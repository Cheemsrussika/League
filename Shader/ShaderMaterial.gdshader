shader_type canvas_item;

uniform float max_health = 1000.0;
uniform vec4 line_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
    float x_pos = SCREEN_UV.x; 
    float hp_per_pixel = max_health; 
    float grid_100 = mod(UV.x * max_health, 100.0);
    float grid_1000 = mod(UV.x * max_health, 1000.0);
    
    vec4 col = vec4(0.0);
    
    if (grid_100 < (max_health / 200.0)) {
        col = line_color;
    }
    if (grid_1000 < (max_health / 100.0)) {
        col = line_color;
        col.a = 1.0;
    }

    COLOR = col;
}