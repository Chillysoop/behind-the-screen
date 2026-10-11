#version 140

// Soft contact shadows under minis and the d20, blended over the table.

in mediump vec2 var_texcoord0;

out vec4 out_fragColor;

uniform mediump sampler2D tex0;

uniform fs_uniforms
{
    mediump vec4 tint; // w = darkness
};

void main()
{
    float a = texture(tex0, var_texcoord0).a * tint.w;
    out_fragColor = vec4(0.06, 0.03, 0.02, a);
}
