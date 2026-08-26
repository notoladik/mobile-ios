#include "Renderer/TransitionShaderManager.hpp"

#include "BuiltInTransitionsResources.hpp"

namespace libprojectM {
namespace Renderer {

TransitionShaderManager::TransitionShaderManager()
    : m_transitionShaders({CompileTransitionShader(kTransitionShaderBuiltInCircleGlsl330),
                           CompileTransitionShader(kTransitionShaderBuiltInPlasmaGlsl330),
                           CompileTransitionShader(kTransitionShaderBuiltInSimpleBlendGlsl330),
                           CompileTransitionShader(kTransitionShaderBuiltInSweepGlsl330),
                           CompileTransitionShader(kTransitionShaderBuiltInWarpGlsl330),
                           CompileTransitionShader(kTransitionShaderBuiltInZoomBlurGlsl330)})
    , m_mersenneTwister(m_randomDevice())
{
}

auto TransitionShaderManager::RandomTransition() -> std::shared_ptr<Shader>
{
    if (m_transitionShaders.empty())
    {
        return {};
    }

    return m_transitionShaders.at(m_mersenneTwister() % m_transitionShaders.size());
}

auto TransitionShaderManager::CompileTransitionShader(const std::string& shaderBodyCode) -> std::shared_ptr<Shader>
{
#ifdef USE_GLES
    #ifdef USE_GLES2
        constexpr char versionHeader[] = "#ifdef GL_FRAGMENT_PRECISION_HIGH\nprecision highp float;\n#else\nprecision mediump float;\n#endif\n";
    #else
        constexpr char versionHeader[] = "#version 300 es\n\n#ifdef GL_FRAGMENT_PRECISION_HIGH\nprecision highp float;\n#else\nprecision mediump float;\n#endif\nprecision mediump sampler3D;\n";
    #endif
#else
    constexpr char versionHeader[] = "#version 330\n\n";
#endif

    std::string fragmentShaderSource(static_cast<const char*>(versionHeader));
    fragmentShaderSource.append(kTransitionShaderHeaderGlsl);
    fragmentShaderSource.append("\n");
    fragmentShaderSource.append(shaderBodyCode);
    fragmentShaderSource.append("\n");
    fragmentShaderSource.append(kTransitionShaderMainGlsl);

    try
    {
        auto transitionShader = std::make_shared<Shader>();
        transitionShader->CompileProgram(static_cast<const char*>(versionHeader) + kTransitionVertexShaderGlsl, fragmentShaderSource);
        return transitionShader;
    }
    catch (const ShaderException&)
    {
        // Fallback
        return {};
    }
}

} // namespace Renderer
} // namespace libprojectM
