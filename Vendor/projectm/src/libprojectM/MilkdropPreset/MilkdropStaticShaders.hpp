#pragma once

#include <GLSLGenerator.h>
#include <Renderer/Shader.hpp>
#include <memory>
#include <string>

namespace libprojectM {
namespace MilkdropPreset {

class MilkdropStaticShaders
{
public:
    static std::shared_ptr<MilkdropStaticShaders> Get()
    {
        static std::shared_ptr<MilkdropStaticShaders> instance(new MilkdropStaticShaders(true));
        return instance;
    }

    M4::GLSLGenerator::Version GetGlslGeneratorVersion()
    {
        return m_GLSLGeneratorVersion;
    }

    std::string GetBlur1FragmentShader();
    std::string GetBlur2FragmentShader();
    std::string GetBlurVertexShader();
    std::string GetPresetCompVertexShader();
    std::string GetPresetMotionVectorsVertexShader();
    std::string GetPresetShaderHeader();
    std::string GetPresetWarpFragmentShader();
    std::string GetPresetWarpVertexShader();
    std::string GetTexturedDrawFragmentShader();
    std::string GetTexturedDrawVertexShader();
    std::string GetUntexturedDrawFragmentShader();
    std::string GetUntexturedDrawVertexShader();

private:
    MilkdropStaticShaders(bool useGLES);
    std::string PrependHeader(const std::string& shader);

    M4::GLSLGenerator::Version m_GLSLGeneratorVersion;
    std::string m_header;
};

} // namespace MilkdropPreset
} // namespace libprojectM
