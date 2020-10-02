module dark.gfx.mesh;

import std.stdio;
import std.format;

import bindbc.opengl;

import dark.math;
import dark.gfx.shader_program;
import dark.gfx.buffers;

class Mesh
{
    private VertexBuffer _vertices;
    private IndexBuffer _indices;
    private VertexAttributes _attributes;

    bool autoBind = true;
    private bool _isVertexArray;

    this(bool isStatic, int maxVertices, int maxIndices, VertexAttribute[] attributes...)
    {
        _attributes = new VertexAttributes(attributes);
        _vertices = new VertexBuffer(isStatic, maxVertices, _attributes);
        _indices = new IndexBuffer(isStatic, maxIndices);
        _isVertexArray = false;
    }

    this(bool isStatic, int maxVertices, int maxIndices, VertexAttributes attributes)
    {
        // todo: for the moment max vertices/indices have no effect, since when created, it'll use what ever length the vertices data will have
        // this can be problematic since we can have dynamic meshes
        // what if the new update is larger than what was used to create it ?
        // i should define the max then check before uploading data
        _attributes = attributes;
        _vertices = new VertexBuffer(isStatic, maxVertices, attributes);
        _indices = new IndexBuffer(isStatic, maxIndices);
        _isVertexArray = false;
    }

    void bind(ShaderProgram shader, int[] locations)
    {
        _vertices.bind(shader, locations);
        if (_indices.getNumIndices() > 0)
            _indices.bind();
    }

    void unbind(ShaderProgram shader, int[] locations)
    {
        _vertices.unbind(shader, locations);
        if (_indices.getNumIndices() > 0)
            _indices.unbind();
    }

    void setVertices(float[] vertices)
    {
        _vertices.setVertices(vertices, 0, cast(int) vertices.length);
    }
    void setVertices(float[] vertices, int offset, int count)
    {
        _vertices.setVertices(vertices, offset, count);
    }

    void setIndices(short[] indices)
    {
        _indices.setIndices(indices, 0, cast(int) indices.length);
    }

    void render(ShaderProgram shader, int primitiveType)
    {
        render(shader, primitiveType, 0, _indices.getNumMaxIndices() > 0 ? getNumIndices() : getNumVertices(), autoBind);
    }

    void render(ShaderProgram shader, int primitiveType, int offset, int count, bool autoBind)
    {
        if (count == 0)
            return;

        if (autoBind)
            bind(shader, null);

        if (_isVertexArray)
        {
            if (_indices.getNumIndices() > 0)
            {
                auto ptr = _indices.getBufferPointer();
                glDrawElements(primitiveType, count, GL_UNSIGNED_SHORT, ptr);
            }
            else
            {
                glDrawArrays(primitiveType, offset, count);
            }
        }
        else
        {
            if (_indices.getNumIndices() > 0)
            {
                auto or = offset * 2;
                glDrawElements(primitiveType, count, GL_UNSIGNED_SHORT, cast(void*) or);
            }
            else
            {
                glDrawArrays(primitiveType, offset, count);
            }
        }

        if (autoBind)
            unbind(shader, null);
    }

    int getNumIndices()
    {
        return _indices.getNumIndices();
    }

    int getNumVertices()
    {
        return _vertices.getNumVertices();
    }

    int getMaxVertices()
    {
        return _vertices.getNumMaxVertices();
    }

    int getMaxIndices()
    {
        return _indices.getNumMaxIndices();
    }

    VertexAttributes getVertexAttributes()
    {
        return _attributes;
    }
}
