#pragma once
#include <string>

namespace libprojectM {
namespace UserSprites {

static const std::string kMilkdropSpriteVertexGlsl330 = R"(
layout(location = 0) in vec2 vertexPosition;
layout(location = 1) in vec2 vertexUV;
out vec2 uv;
void main() {
    uv = vertexUV;
    gl_Position = vec4(vertexPosition, 0.0, 1.0);
}
)";

static const std::string kMilkdropSpriteFragmentGlsl330 = R"(
in vec2 uv;
out vec4 fragColor;
uniform sampler2D textureSampler;
uniform vec4 spriteColor;
void main() {
    fragColor = texture(textureSampler, uv) * spriteColor;
}
)";

} // namespace UserSprites
} // namespace libprojectM
