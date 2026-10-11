#version 140

// Spell areas and zones on the battle mat (real-session pass): a soft tinted square per
// grid square, blended over the felt like the contact shadows.

in mediump vec2 var_texcoord0;

out vec4 out_fragColor;

uniform mediump sampler2D tex0;

uniform fs_uniforms
{
    mediump vec4 tint; // rgb = colour, w = strength
};

void main()
{
    float a = texture(tex0, var_texcoord0).a * tint.w;
    out_fragColor = vec4(tint.rgb, a);
}
