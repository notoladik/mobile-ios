
#include "config.h"
#include "GladLoader.hpp"

#include "../OpenGL.h"
#include "GLProbe.hpp"
#include "GLResolver.hpp"
#include "Logging.hpp"

#include <dlfcn.h>
#include <string>

namespace {

/**
 * @brief Resolves a GL function by name using GladResolverThunk.
 * @note Adapts opaque void* handle to GLAD type
 *
 * @param name GL function name.
 *
 * @return Function pointer as GLADapiproc.
 */
auto GladBridgeGetProcAddressThunk(const char* name) -> GLADapiproc
{
    return libprojectM::Renderer::Platform::SymbolToFunction<GLADapiproc>(libprojectM::Renderer::Platform::GLResolver::GetProcAddressThunk(name));
}

} // namespace

namespace libprojectM {
namespace Renderer {
namespace Platform {

auto GladLoader::Instance() -> GladLoader&
{
    static GladLoader instance;
    return instance;
}

auto GladLoader::CheckGLRequirements() -> bool
{
    return true;
}

auto GladLoader::Initialize() -> bool
{
    const std::unique_lock<std::mutex> lock(m_mutex);
    if (m_isLoaded)
    {
        return true;
    }

#ifdef USE_GLES
    gladLoadGLES2([](const char* name) -> GLADapiproc {
        void* ptr = dlsym(RTLD_DEFAULT, name);
        if (!ptr) {
            return GladBridgeGetProcAddressThunk(name);
        }
        return reinterpret_cast<GLADapiproc>(ptr);
    });
    m_isLoaded = true;
    return true;
#else
    const int result = gladLoadGL(&GladBridgeGetProcAddressThunk);
    m_isLoaded = (result != 0);
    return m_isLoaded;
#endif
}

} // namespace Platform
} // namespace Renderer
} // namespace libprojectM
