#version 140

// Additive glow sprites (flame, bulb halo). The textures are emission on
// black with full alpha, so they look the same with or without premultiply.

in mediump vec2 var_texcoord0;

out vec4 out_fragColor;

uniform mediump sampler2D texture_sampler;

uniform fs_uniforms
{
    mediump vec4 tint;
    mediump vec4 glow; // x = strength
};

void main()
{
    vec3 c = texture(texture_sampler, var_texcoord0).rgb * tint.rgb * glow.x;
    out_fragColor = vec4(c, 0.0);
}
