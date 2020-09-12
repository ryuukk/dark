module darc.gfx.mesh;

import std.stdio;
import std.format;

import bindbc.opengl;

import darc.math;
import darc.gfx.shader_program;
import darc.gfx.buffers;

public class Mesh
{
    private VertexBuffer _vertices;
    private IndexBuffer _indices;
    private VertexAttributes _attributes;

    public bool autoBind = true;
    private bool _isVertexArray;

    public this(bool isStatic, int maxVertices, int maxIndices, VertexAttribute[] attributes...)
    {
        _attributes = new VertexAttributes(attributes);
        _vertices = new VertexBuffer(isStatic, maxVertices, _attributes);
        _indices = new IndexBuffer(isStatic, maxIndices);
        _isVertexArray = false;
    }

    public this(bool isStatic, int maxVertices, int maxIndices, VertexAttributes attributes)
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

    public void bind(ShaderProgram shader, int[] locations)
    {
        _vertices.bind(shader, locations);
        if (_indices.getNumIndices() > 0)
            _indices.bind();
    }

    public void unbind(ShaderProgram shader, int[] locations)
    {
        _vertices.unbind(shader, locations);
        if (_indices.getNumIndices() > 0)
            _indices.unbind();
    }

    public void setVertices(float[] vertices)
    {
        _vertices.setVertices(vertices, 0, cast(int) vertices.length);
    }
    public void setVertices(float[] vertices, int offset, int count)
    {
        _vertices.setVertices(vertices, offset, count);
    }

    public void setIndices(short[] indices)
    {
        _indices.setIndices(indices, 0, cast(int) indices.length);
    }

    public void render(ShaderProgram shader, int primitiveType)
    {
        render(shader, primitiveType, 0, _indices.getNumMaxIndices() > 0 ? getNumIndices() : getNumVertices(), autoBind);
    }

    public void render(ShaderProgram shader, int primitiveType, int offset, int count, bool autoBind)
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

    public int getNumIndices()
    {
        return _indices.getNumIndices();
    }

    public int getNumVertices()
    {
        return _vertices.getNumVertices();
    }

    public int getMaxVertices()
    {
        return _vertices.getNumMaxVertices();
    }

    public int getMaxIndices()
    {
        return _indices.getNumMaxIndices();
    }

    public VertexAttributes getVertexAttributes()
    {
        return _attributes;
    }
}
