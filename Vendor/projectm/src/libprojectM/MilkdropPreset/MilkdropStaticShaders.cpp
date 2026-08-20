#include "MilkdropStaticShaders.hpp"

namespace libprojectM {
namespace MilkdropPreset {

MilkdropStaticShaders::MilkdropStaticShaders(bool useGLES)
    : m_GLSLGeneratorVersion(M4::GLSLGenerator::Version_100_ES)
    , m_header("precision mediump float;\n")
{
}

std::string MilkdropStaticShaders::PrependHeader(const std::string& shader)
{
    return m_header + shader;
}

// ── Blur ──────────────────────────────────────────────────────────────────
std::string MilkdropStaticShaders::GetBlurVertexShader()
{
    return PrependHeader(R"(
attribute vec2 vertex_position;
attribute vec2 vertex_texture;
uniform int flipVertical;
varying vec2 fragment_texture;

void main() {
    gl_Position = vec4(vertex_position, 0.0, 1.0);
    fragment_texture = vertex_texture;
    if (flipVertical == 1) {
        fragment_texture.y = 1.0 - fragment_texture.y;
    }
}
)");
}

std::string MilkdropStaticShaders::GetBlur1FragmentShader()
{
    return PrependHeader(R"(
varying vec2 fragment_texture;
uniform sampler2D texture_sampler;
uniform vec4 _c0; // source texsize (.xy), and inverse (.zw)
uniform vec4 _c1; // w1..w4
uniform vec4 _c2; // d1..d4
uniform vec4 _c3; // scale, bias, w_div

void main() {
    vec4 srctexsize = _c0;
    float w1 = _c1.x;
    float w2 = _c1.y;
    float w3 = _c1.z;
    float w4 = _c1.w;
    float d1 = _c2.x;
    float d2 = _c2.y;
    float d3 = _c2.z;
    float d4 = _c2.w;
    float fscale = _c3.x;
    float fbias  = _c3.y;
    float w_div  = _c3.z;

    vec2 uv2 = fragment_texture.xy + srctexsize.zw * vec2(1.0, 1.0);
    vec3 blur =
        (texture2D(texture_sampler, uv2 + vec2(d1 * srctexsize.z, 0.0)).xyz +
         texture2D(texture_sampler, uv2 + vec2(-d1 * srctexsize.z, 0.0)).xyz) * w1 +
        (texture2D(texture_sampler, uv2 + vec2(d2 * srctexsize.z, 0.0)).xyz +
         texture2D(texture_sampler, uv2 + vec2(-d2 * srctexsize.z, 0.0)).xyz) * w2 +
        (texture2D(texture_sampler, uv2 + vec2(d3 * srctexsize.z, 0.0)).xyz +
         texture2D(texture_sampler, uv2 + vec2(-d3 * srctexsize.z, 0.0)).xyz) * w3 +
        (texture2D(texture_sampler, uv2 + vec2(d4 * srctexsize.z, 0.0)).xyz +
         texture2D(texture_sampler, uv2 + vec2(-d4 * srctexsize.z, 0.0)).xyz) * w4;
    blur *= w_div;
    blur = blur * fscale + fbias;
    gl_FragColor = vec4(blur, 1.0);
}
)");
}

std::string MilkdropStaticShaders::GetBlur2FragmentShader()
{
    return PrependHeader(R"(
varying vec2 fragment_texture;
uniform sampler2D texture_sampler;
uniform vec4 _c0; // source texsize (.xy), and inverse (.zw)
uniform vec4 _c5; // w1,w2,d1,d2
uniform vec4 _c6; // w_div, edge_darken_c1, edge_darken_c2, edge_darken_c3

void main() {
    vec4 srctexsize = _c0;
    float w1 = _c5.x;
    float w2 = _c5.y;
    float d1 = _c5.z;
    float d2 = _c5.w;
    float edge_darken_c1 = _c6.y;
    float edge_darken_c2 = _c6.z;
    float edge_darken_c3 = _c6.w;
    float w_div   = _c6.x;

    vec2 uv2 = fragment_texture.xy;
    vec3 blur =
        (texture2D(texture_sampler, uv2 + vec2(0.0, d1 * srctexsize.w)).xyz +
         texture2D(texture_sampler, uv2 + vec2(0.0, -d1 * srctexsize.w)).xyz) * w1 +
        (texture2D(texture_sampler, uv2 + vec2(0.0, d2 * srctexsize.w)).xyz +
         texture2D(texture_sampler, uv2 + vec2(0.0, -d2 * srctexsize.w)).xyz) * w2;
    blur *= w_div;

    float t = min(min(fragment_texture.x, fragment_texture.y),
                  1.0 - max(fragment_texture.x, fragment_texture.y));
    t = sqrt(max(0.0, t));
    t = edge_darken_c1 + edge_darken_c2 * clamp(t * edge_darken_c3, 0.0, 1.0);
    blur *= t;
    gl_FragColor = vec4(blur, 1.0);
}
)");
}

// ── Preset warp (per-pixel mesh) ──────────────────────────────────────────
std::string MilkdropStaticShaders::GetPresetWarpVertexShader()
{
    return PrependHeader(R"(
attribute vec2 vertex_position;
attribute vec2 rad_ang;
attribute vec4 transforms;
attribute vec2 warp_center;
attribute vec2 warp_distance;
attribute vec2 stretch;

uniform mat4 vertex_transformation;
uniform vec4 aspect;
uniform float warpTime;
uniform float warpScaleInverse;
uniform vec4 warpFactors;
uniform vec2 texelOffset;
uniform float decay;

varying vec4 frag_COLOR;
varying vec4 frag_TEXCOORD0;
varying vec2 frag_TEXCOORD1;

void main() {
    gl_Position = vertex_transformation * vec4(vertex_position, 0.0, 1.0);

    float zoom = transforms.x;
    float zoomExp = transforms.y;
    float rot = transforms.z;
    float warp = transforms.w;
    float radius = rad_ang.x;

    float zoom2 = pow(max(0.0001, zoom), pow(max(0.0001, zoomExp), radius * 2.0 - 1.0));
    float zoom2Inverse = 1.0 / zoom2;

    float u = vertex_position.x * aspect.x * 0.5 * zoom2Inverse + 0.5;
    float v = vertex_position.y * aspect.y * 0.5 * zoom2Inverse + 0.5;

    vec2 uv_original = vec2(vertex_position.x * 0.5 + 0.5 + texelOffset.x,
                            vertex_position.y * 0.5 + 0.5 + texelOffset.y);

    u = (u - warp_center.x) / stretch.x + warp_center.x;
    v = (v - warp_center.y) / stretch.y + warp_center.y;

    u += warp * 0.0035 * sin(warpTime * 0.333 + warpScaleInverse * (vertex_position.x * warpFactors.x - vertex_position.y * warpFactors.w));
    v += warp * 0.0035 * cos(warpTime * 0.375 - warpScaleInverse * (vertex_position.x * warpFactors.z + vertex_position.y * warpFactors.y));
    u += warp * 0.0035 * cos(warpTime * 0.753 - warpScaleInverse * (vertex_position.x * warpFactors.y - vertex_position.y * warpFactors.z));
    v += warp * 0.0035 * sin(warpTime * 0.825 + warpScaleInverse * (vertex_position.x * warpFactors.x + vertex_position.y * warpFactors.w));

    float u2 = u - warp_center.x;
    float v2 = v - warp_center.y;
    float cosRot = cos(rot);
    float sinRot = sin(rot);
    u = u2 * cosRot - v2 * sinRot + warp_center.x;
    v = u2 * sinRot + v2 * cosRot + warp_center.y;

    u -= warp_distance.x;
    v -= warp_distance.y;

    u = (u - 0.5) * aspect.z + 0.5;
    v = (v - 0.5) * aspect.w + 0.5;

    u += texelOffset.x;
    v += texelOffset.y;

    frag_COLOR = vec4(decay, decay, decay, 1.0);
    frag_TEXCOORD0 = vec4(u, v, uv_original.x, uv_original.y);
    frag_TEXCOORD1 = rad_ang;
}
)");
}

std::string MilkdropStaticShaders::GetPresetWarpFragmentShader()
{
    return PrependHeader(R"(
varying vec4 frag_COLOR;
varying vec4 frag_TEXCOORD0;
varying vec2 frag_TEXCOORD1;
uniform sampler2D texture_sampler;
uniform sampler2D sampler_main;

void main() {
    gl_FragColor = vec4(frag_COLOR.rgb * texture2D(texture_sampler, frag_TEXCOORD0.xy).rgb, 1.0);
}
)");
}

// ── Preset composite ──────────────────────────────────────────────────────
std::string MilkdropStaticShaders::GetPresetCompVertexShader()
{
    return PrependHeader(R"(
attribute vec2 vertex_position;
attribute vec4 vertex_color;
attribute vec2 vertex_texture;
attribute vec2 vertex_rad_ang;

varying vec4 frag_COLOR;
varying vec2 frag_TEXCOORD0;
varying vec2 frag_TEXCOORD1;

void main() {
    gl_Position = vec4(vertex_position, 0.0, 1.0);
    frag_COLOR = vertex_color;
    frag_TEXCOORD0 = vertex_texture;
    frag_TEXCOORD1 = vertex_rad_ang;
}
)");
}

// ── Motion vectors ────────────────────────────────────────────────────────
std::string MilkdropStaticShaders::GetPresetMotionVectorsVertexShader()
{
    return PrependHeader(R"(
attribute vec2 vertex_position;
attribute vec4 vertex_color;
uniform mat4 vertex_transformation;
varying vec4 fragment_color;

void main() {
    gl_Position = vertex_transformation * vec4(vertex_position, 0.0, 1.0);
    fragment_color = vertex_color;
}
)");
}

std::string MilkdropStaticShaders::GetPresetShaderHeader()
{
    return R"(
#define  M_PI   3.14159265359
#define  M_PI_2 6.28318530718
#define  M_INV_PI_2  0.159154943091895

uniform float4   rand_frame;
uniform float4   rand_preset;
uniform float4   _c0;
uniform float4   _c1, _c2, _c3, _c4;
uniform float4   _c5;
uniform float4   _c6;
uniform float4   _c7;
uniform float4   _c8;
uniform float4   _c9;
uniform float4   _c10;
uniform float4   _c11;
uniform float4   _c12;
uniform float4   _c13;
uniform float4   _qa;
uniform float4   _qb;
uniform float4   _qc;
uniform float4   _qd;
uniform float4   _qe;
uniform float4   _qf;
uniform float4   _qg;
uniform float4   _qh;

uniform float4x3 rot_s1;
uniform float4x3 rot_s2;
uniform float4x3 rot_s3;
uniform float4x3 rot_s4;

uniform float4x3 rot_d1;
uniform float4x3 rot_d2;
uniform float4x3 rot_d3;
uniform float4x3 rot_d4;

uniform float4x3 rot_f1;
uniform float4x3 rot_f2;
uniform float4x3 rot_f3;
uniform float4x3 rot_f4;

uniform float4x3 rot_vf1;
uniform float4x3 rot_vf2;
uniform float4x3 rot_vf3;
uniform float4x3 rot_vf4;

uniform float4x3 rot_uf1;
uniform float4x3 rot_uf2;
uniform float4x3 rot_uf3;
uniform float4x3 rot_uf4;

uniform float4x3 rot_rand1;
uniform float4x3 rot_rand2;
uniform float4x3 rot_rand3;
uniform float4x3 rot_rand4;

#define time     _c2.x
#define fps      _c2.y
#define frame    _c2.z
#define progress _c2.w
#define bass _c3.x
#define mid  _c3.y
#define treb _c3.z
#define vol  _c3.w
#define bass_att _c4.x
#define mid_att  _c4.y
#define treb_att _c4.z
#define vol_att  _c4.w
#define q1 _qa.x
#define q2 _qa.y
#define q3 _qa.z
#define q4 _qa.w
#define q5 _qb.x
#define q6 _qb.y
#define q7 _qb.z
#define q8 _qb.w
#define q9 _qc.x
#define q10 _qc.y
#define q11 _qc.z
#define q12 _qc.w
#define q13 _qd.x
#define q14 _qd.y
#define q15 _qd.z
#define q16 _qd.w
#define q17 _qe.x
#define q18 _qe.y
#define q19 _qe.z
#define q20 _qe.w
#define q21 _qf.x
#define q22 _qf.y
#define q23 _qf.z
#define q24 _qf.w
#define q25 _qg.x
#define q26 _qg.y
#define q27 _qg.z
#define q28 _qg.w
#define q29 _qh.x
#define q30 _qh.y
#define q31 _qh.z
#define q32 _qh.w

#define aspect   _c0
#define texsize  _c7

#define roam_cos _c8
#define roam_sin _c9
#define slow_roam_cos _c10
#define slow_roam_sin _c11
#define mip_x   _c12.x
#define mip_y   _c12.y
#define mip_xy  _c12.xy
#define mip_avg _c12.z
#define blur1_min _c6.z
#define blur1_max _c6.w
#define blur2_min _c13.x
#define blur2_max _c13.y
#define blur3_min _c13.z
#define blur3_max _c13.w

#define sampler_FC_main sampler_fc_main
#define sampler_PC_main sampler_pc_main
#define sampler_FW_main sampler_fw_main
#define sampler_PW_main sampler_pw_main

#define GetMain(uv) (tex2D(sampler_main,uv).xyz)
#define GetPixel(uv) (tex2D(sampler_main,uv).xyz)
#define GetBlur1(uv) (tex2D(sampler_blur1,uv).xyz*_c5.x + _c5.y)
#define GetBlur2(uv) (tex2D(sampler_blur2,uv).xyz*_c5.z + _c5.w)
#define GetBlur3(uv) (tex2D(sampler_blur3,uv).xyz*_c6.x + _c6.y)

#define lum(x) (dot(x,float3(0.32,0.49,0.29)))
#define tex2d tex2D
#define tex3d tex3D
)";
}

// ── Generic textured / untextured ─────────────────────────────────────────
std::string MilkdropStaticShaders::GetTexturedDrawFragmentShader()
{
    return PrependHeader(R"(
varying vec4 fragment_color;
varying vec2 fragment_texture;
uniform sampler2D texture_sampler;
void main() {
    gl_FragColor = fragment_color * texture2D(texture_sampler, fragment_texture);
}
)");
}

std::string MilkdropStaticShaders::GetTexturedDrawVertexShader()
{
    return PrependHeader(R"(
attribute vec2 vertex_position;
attribute vec4 vertex_color;
attribute vec2 vertex_texture;
varying vec4 fragment_color;
varying vec2 fragment_texture;
uniform mat4 vertex_transformation;
void main() {
    fragment_color = vertex_color;
    fragment_texture = vertex_texture;
    gl_Position = vertex_transformation * vec4(vertex_position, 0.0, 1.0);
}
)");
}

std::string MilkdropStaticShaders::GetUntexturedDrawFragmentShader()
{
    return PrependHeader(R"(
varying vec4 fragment_color;
void main() {
    gl_FragColor = fragment_color;
}
)");
}

std::string MilkdropStaticShaders::GetUntexturedDrawVertexShader()
{
    return PrependHeader(R"(
attribute vec2 vertex_position;
attribute vec4 vertex_color;
varying vec4 fragment_color;
uniform mat4 vertex_transformation;
uniform float vertex_point_size;
void main() {
    fragment_color = vertex_color;
    gl_PointSize = vertex_point_size;
    gl_Position = vertex_transformation * vec4(vertex_position, 0.0, 1.0);
}
)");
}

} // namespace MilkdropPreset
} // namespace libprojectM

