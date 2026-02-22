shader_type canvas_item;

uniform float health : hint_range(0.0, 1.0) = 1.0;
uniform int plate_count = 5;
uniform int plates_broken = 0;

uniform vec4 health_color : source_color = vec4(0.2, 0.8, 0.2, 1.0); // Green
uniform vec4 plate_color : source_color = vec4(0.8, 0.6, 0.0, 1.0);  // Gold/Orange
uniform vec4 broken_color : source_color = vec4(0.1, 0.1, 0.1, 1.0); // Dark Gray
uniform vec4 divider_color : source_color = vec4(0.0, 0.0, 0.0, 1.0); // Black

void fragment() {
	vec2 uv = UV;
	
	// 1. Determine which plate this pixel belongs to
	// We use floor(uv.x * float(plate_count)) to find the index (0 to 4)
	float segment_idx = floor(uv.x * float(plate_count));
	
	// 2. Determine if this segment is "Active" (not yet broken)
	// Plates are broken from right to left (index 4 down to 0)
	bool is_plate_active = (segment_idx >= float(plates_broken));
	
	// 3. Draw the Fill
	vec4 final_color;
	if (uv.x <= health) {
		// Use gold color if the segment still has plating, otherwise use normal green
		final_color = is_plate_active ? plate_color : health_color;
	} else {
		final_color = broken_color;
	}
	
	// 4. Draw vertical Dividers
	// Check if we are near the edge of a segment
	float thickness = 0.02; // Adjust for divider width
	float grid = fract(uv.x * float(plate_count));
	if (grid < thickness || grid > 1.0 - thickness) {
		final_color = divider_color;
	}
	
	// Apply texture alpha if you're using a specific shape/mask TextureRect
	vec4 tex_color = texture(TEXTURE, uv);
	COLOR = vec4(final_color.rgb, tex_color.a * final_color.a);
}