#version 140

// Lit, textured surfaces: the room, the table, the props and the d20.
// The lighting block between the markers is shared with standee.fp
// (tools/generate.py copies it across), so both stay in one light.

in highp vec3 var_world_pos;
in mediump vec3 var_normal;
in mediump vec2 var_texcoord0;

out vec4 out_fragColor;

uniform mediump sampler2D tex0;

uniform fs_uniforms
{
    highp vec4 lamp_pos;     // xyz = bulb position, w = intensity
    mediump vec4 lamp_color; // rgb = colour, w = range in cm
    highp vec4 fire_pos;     // xyz = campfire position, w = intensity
    mediump vec4 fire_color; // rgb = colour, w = range in cm
    highp vec4 cam_pos;      // xyz = eye, w = imagination amount (0..1)
    mediump vec4 ambient;    // rgb = ambient, w = moonlight strength
    mediump vec4 surface;    // x = specular, y = shininess, z = emissive
    mediump vec4 tint;
};

// BEGIN LIGHTING
vec3 srgb_to_linear(vec3 c)
{
    return pow(max(c, vec3(0.0)), vec3(2.2));
}

vec3 linear_to_srgb(vec3 c)
{
    return pow(max(c, vec3(0.0)), vec3(1.0 / 2.2));
}

vec3 light_scene(vec3 albedo, vec3 n, vec3 wp, float spec_k, float shininess)
{
    vec3 V = normalize(cam_pos.xyz - wp);

    // Pendant lamp: a warm point light, strongest in the cone under the shade.
    vec3 Lv = lamp_pos.xyz - wp;
    float d = length(Lv);
    vec3 L = Lv / max(d, 0.001);
    float att = 1.0 / (1.0 + (d * d) / (lamp_color.w * lamp_color.w));
    float cone = dot(-L, vec3(0.0, -1.0, 0.0));
    float spot = mix(0.16, 1.0, smoothstep(0.30, 0.82, cone));
    float wrap = max((dot(n, L) + 0.3) / 1.3, 0.0);
    vec3 lamp = lamp_color.rgb * (lamp_pos.w * att * spot * wrap * 3.0);
    vec3 H = normalize(L + V);
    float facing = step(0.0, dot(n, L));
    float spec = pow(max(dot(n, H), 0.0), max(shininess, 1.0)) * spec_k * lamp_pos.w * att * spot * facing;

    // Campfire on the battle mat: tiny, orange, flickering.
    vec3 Fv = fire_pos.xyz - wp;
    float fd = length(Fv);
    float fatt = smoothstep(70.0, 20.0, fd) / (1.0 + (fd * fd) / (fire_color.w * fire_color.w));
    float fwrap = max((dot(n, Fv / max(fd, 0.001)) + 0.5) / 1.5, 0.0);
    vec3 fire = fire_color.rgb * (fire_pos.w * fatt * fwrap * 2.0);

    // Cool moonlight through the window, plus a soft hemispheric ambient.
    vec3 M = normalize(vec3(0.3, 0.55, -1.0));
    vec3 moon = vec3(0.45, 0.58, 0.95) * (ambient.w * max(dot(n, M), 0.0) * 0.22);
    vec3 amb = ambient.rgb * mix(0.65, 1.15, n.y * 0.5 + 0.5);

    // Imagination zoom: the room falls away and the diorama stays lit.
    vec3 rel = (wp - vec3(-6.0, 78.0, -2.0)) * vec3(1.0, 1.6, 1.3);
    float near_table = 1.0 - smoothstep(55.0, 120.0, length(rel));
    float room = mix(1.0, mix(0.015, 1.0, near_table), cam_pos.w);

    return albedo * ((amb + lamp + moon) * room + fire) + lamp_color.rgb * (spec * room);
}

vec3 finish(vec3 col)
{
    col = vec3(1.0) - exp(-col * 1.5);
    return linear_to_srgb(col);
}
// END LIGHTING

void main()
{
    vec4 texel = texture(tex0, var_texcoord0) * tint;
    vec3 albedo = srgb_to_linear(texel.rgb);
    vec3 n = normalize(var_normal);
    if (!gl_FrontFacing)
    {
        n = -n;
    }
    vec3 col = light_scene(albedo, n, var_world_pos, surface.x, surface.y);
    // Emissive surfaces fade with the room in the imagination zoom too.
    vec3 rel = (var_world_pos - vec3(-6.0, 78.0, -2.0)) * vec3(1.0, 1.6, 1.3);
    float keep = mix(1.0, 1.0 - smoothstep(55.0, 120.0, length(rel)), cam_pos.w);
    col += albedo * (surface.z * 1.4 * keep);
    out_fragColor = vec4(finish(col), 1.0);
}
