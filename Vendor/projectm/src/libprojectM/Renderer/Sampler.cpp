#include "Sampler.hpp"
#include "Renderer/OpenGL.h"

namespace libprojectM {
namespace Renderer {

Sampler::Sampler(const GLint wrapMode, const GLint filterMode)
    : m_wrapMode(wrapMode)
    , m_filterMode(filterMode)
{
    // glGenSamplers is OpenGL ES 3.0+ only.
    // On GLES2 we skip sampler objects and apply parameters directly to textures.
    m_samplerId = 0;
}


Sampler::~Sampler()
{
    // Nothing to delete — sampler objects not used.
}

void Sampler::Bind(GLuint unit) const
{
    // No-op: texture parameters are set directly when textures are created/bound.
}

void Sampler::Unbind(GLuint unit)
{
    // No-op.
}

auto Sampler::WrapMode() const -> GLint
{
    return m_wrapMode;
}

void Sampler::WrapMode(GLint wrapMode)
{
    m_wrapMode = wrapMode;
}

auto Sampler::FilterMode() const -> GLint
{
    return m_filterMode;
}

void Sampler::FilterMode(GLint filterMode)
{
    m_filterMode = filterMode;
}

} // namespace Renderer
} // namespace libprojectM
