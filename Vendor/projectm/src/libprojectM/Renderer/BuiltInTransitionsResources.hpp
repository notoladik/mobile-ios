#pragma once
#include <string>

namespace libprojectM {
namespace Renderer {

static const std::string kTransitionVertexShaderGlsl330 = R"(
layout(location = 0) in vec2 vertexPosition;
layout(location = 1) in vec2 vertexUV;
out vec2 uv;
void main() {
    uv = vertexUV;
    gl_Position = vec4(vertexPosition, 0.0, 1.0);
}
)";

static const std::string kTransitionShaderHeaderGlsl330 = R"(
in vec2 uv;
out vec4 fragColor;
uniform sampler2D texture1;
uniform sampler2D texture2;
uniform float progress;
)";

static const std::string kTransitionShaderMainGlsl330 = R"(
void main() {
    fragColor = transition(uv);
}
)";

static const std::string kTransitionShaderBuiltInSimpleBlendGlsl330 = R"(
vec4 transition(vec2 p) {
    return mix(texture(texture1, p), texture(texture2, p), progress);
}
)";

static const std::string kTransitionShaderBuiltInCircleGlsl330 = R"(
vec4 transition(vec2 p) {
    float dist = distance(p, vec2(0.5, 0.5));
    if (dist < progress * 0.707) {
        return texture(texture2, p);
    }
    return texture(texture1, p);
}
)";

static const std::string kTransitionShaderBuiltInPlasmaGlsl330 = R"(
vec4 transition(vec2 p) {
    vec2 dir = p - vec2(0.5);
    float dist = length(dir);
    float angle = atan(dir.y, dir.x);
    float v = sin(dist * 10.0 - progress * 6.28);
    return mix(texture(texture1, p), texture(texture2, p), clamp(progress + v * 0.1, 0.0, 1.0));
}
)";

static const std::string kTransitionShaderBuiltInSweepGlsl330 = R"(
vec4 transition(vec2 p) {
    if (p.x < progress) {
        return texture(texture2, p);
    }
    return texture(texture1, p);
}
)";

static const std::string kTransitionShaderBuiltInWarpGlsl330 = R"(
vec4 transition(vec2 p) {
    vec2 offset = vec2(sin(p.y * 10.0 + progress * 3.14) * (1.0 - progress) * 0.05, 0.0);
    return mix(texture(texture1, p + offset), texture(texture2, p), progress);
}
)";

static const std::string kTransitionShaderBuiltInZoomBlurGlsl330 = R"(
vec4 transition(vec2 p) {
    vec2 center = vec2(0.5, 0.5);
    vec2 toCenter = center - p;
    vec4 c1 = texture(texture1, p);
    vec4 c2 = texture(texture2, p);
    return mix(c1, c2, progress);
}
)";

} // namespace Renderer
} // namespace libprojectM
