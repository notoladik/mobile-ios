#pragma once
#include <string>

namespace libprojectM {
namespace Renderer {

static const std::string kTransitionVertexShaderGlsl = R"(
#if __VERSION__ >= 130 || defined(GL_ES) && __VERSION__ >= 300
layout(location = 0) in vec2 vertexPosition;
out vec2 uv;
#else
attribute vec2 vertexPosition;
varying vec2 uv;
#endif

void main() {
    uv = vertexPosition * 0.5 + 0.5;
    gl_Position = vec4(vertexPosition, 0.0, 1.0);
}
)";

static const std::string kTransitionShaderHeaderGlsl = R"(
#if __VERSION__ >= 130 || defined(GL_ES) && __VERSION__ >= 300
in vec2 uv;
out vec4 fragColor;
#define TEXTURE_SAMPLE texture
#define FRAG_COLOR fragColor
#else
varying vec2 uv;
#define TEXTURE_SAMPLE texture2D
#define FRAG_COLOR gl_FragColor
#endif

uniform sampler2D iChannel0;
uniform sampler2D iChannel1;
uniform vec4 durationParams;
uniform vec2 timeParams;
uniform vec3 iResolution;

#define progress (durationParams.y)
)";

static const std::string kTransitionShaderMainGlsl = R"(
void main() {
    FRAG_COLOR = transition(uv);
}
)";

static const std::string kTransitionShaderBuiltInSimpleBlendGlsl330 = R"(
vec4 transition(vec2 p) {
    return mix(TEXTURE_SAMPLE(iChannel0, p), TEXTURE_SAMPLE(iChannel1, p), progress);
}
)";

static const std::string kTransitionShaderBuiltInCircleGlsl330 = R"(
vec4 transition(vec2 p) {
    float dist = distance(p, vec2(0.5, 0.5));
    if (dist < progress * 0.75) {
        return TEXTURE_SAMPLE(iChannel1, p);
    }
    return TEXTURE_SAMPLE(iChannel0, p);
}
)";

static const std::string kTransitionShaderBuiltInPlasmaGlsl330 = R"(
vec4 transition(vec2 p) {
    float v = sin(distance(p, vec2(0.5, 0.5)) * 10.0 - progress * 6.28) * (1.0 - progress) * 0.04;
    vec2 p1 = p + vec2(v, v);
    vec2 p2 = p - vec2(v, v);
    return mix(TEXTURE_SAMPLE(iChannel0, p1), TEXTURE_SAMPLE(iChannel1, p2), progress);
}
)";

static const std::string kTransitionShaderBuiltInSweepGlsl330 = R"(
vec4 transition(vec2 p) {
    float edge = smoothstep(progress - 0.03, progress + 0.03, p.x);
    return mix(TEXTURE_SAMPLE(iChannel1, p), TEXTURE_SAMPLE(iChannel0, p), edge);
}
)";

static const std::string kTransitionShaderBuiltInWarpGlsl330 = R"(
vec4 transition(vec2 p) {
    vec2 offset = vec2(sin(p.y * 10.0 + progress * 3.14159) * (1.0 - progress) * 0.04, 0.0);
    return mix(TEXTURE_SAMPLE(iChannel0, p + offset), TEXTURE_SAMPLE(iChannel1, p), progress);
}
)";

static const std::string kTransitionShaderBuiltInZoomBlurGlsl330 = R"(
vec4 transition(vec2 p) {
    vec2 center = vec2(0.5, 0.5);
    vec2 dir = (center - p) * (1.0 - progress) * 0.04;
    vec4 c1 = TEXTURE_SAMPLE(iChannel0, p + dir);
    vec4 c2 = TEXTURE_SAMPLE(iChannel1, p);
    return mix(c1, c2, progress);
}
)";

} // namespace Renderer
} // namespace libprojectM
