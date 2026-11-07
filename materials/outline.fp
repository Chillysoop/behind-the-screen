#version 140

// A player's outline at the table (the playtest, November 3): a flat colour in the shape of their
// sprite, a little bigger and just behind it, so it shows as a rim. Gold in character, blue out of
// character, lavender thinking (game/ui/panels.lua SPEAK).

in highp vec3 var_world_pos;
in mediump vec2 var_texcoord0;

out vec4 out_fragColor;

uniform mediump sampler2D texture_sampler;

uniform fs_uniforms
{
    mediump vec4 tint;
};

void main()
{
    float a = texture(texture_sampler, var_texcoord0).a;
    if (a < 0.4 || tint.w < 0.01)
        discard;
    out_fragColor = vec4(tint.rgb, 1.0);
}
