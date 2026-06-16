shader_type canvas_item;

uniform vec2 blur_velocity = vec2(0.0, 0.0); 
uniform int blur_samples = 10;

void fragment() {
    vec4 color = vec4(0.0);
    
    for (int i = 0; i < blur_samples; i++) {
        // Offset strictly BACKWARDS along the vector, rather than both directions
        float offset = float(i) / float(blur_samples - 1);
        vec4 sampled_color = texture(TEXTURE, UV - (blur_velocity * offset));
        
        // Accumulate color, but weigh it by its alpha. 
        // This entirely prevents the transparent "black void" pixels from muddying the sprite!
        color.rgb += sampled_color.rgb * sampled_color.a;
        color.a += sampled_color.a;
    }
    
    if (color.a > 0.0) {
        color.rgb /= color.a; // Divide RGB by total alpha to keep colors bright
        color.a /= float(blur_samples); // Average the alpha for the smooth fade
    }
    
    COLOR = color;
}