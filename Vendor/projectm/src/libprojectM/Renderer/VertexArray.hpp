#pragma once

#include "Renderer/OpenGL.h"

namespace libprojectM {
namespace Renderer {

/**
 * @brief Wraps a vertex array object.
 * Creates, destroys and binds a single VAO.
 */
class VertexArray
{
public:
    /**
     * Constructor. Creates a new VAO.
     */
    VertexArray()
    {
#ifndef USE_GLES
        glGenVertexArrays(1, &m_vaoID);
#endif
    }

    /**
     * Destructor. Deletes the stored VAO.
     */
    virtual ~VertexArray()
    {
#ifndef USE_GLES
        if (m_vaoID) {
            glDeleteVertexArrays(1, &m_vaoID);
            m_vaoID = 0;
        }
#endif
    }

    /**
     * Binds the stored VAO.
     */
    void Bind() const
    {
#ifndef USE_GLES
        glBindVertexArray(m_vaoID);
#endif
    }

    /**
     * Binds the default VAO with ID 0.
     */
    static void Unbind()
    {
#ifndef USE_GLES
        glBindVertexArray(0);
#endif
    }

private:
    GLuint m_vaoID{0}; //!< The vertex array object ID for this mesh's vertex data.

};


} // namespace Renderer
} // namespace libprojectM
