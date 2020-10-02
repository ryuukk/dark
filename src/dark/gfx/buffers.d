module dark.gfx.buffers;

import std.stdio;
import std.format;

import bindbc.opengl;

import dark.gfx.shader_program;

class Usage
{
    static immutable int Position = 1;
    static immutable int ColorUnpacked = 2;
    static immutable int ColorPacked = 4;
    static immutable int Normal = 8;
    static immutable int TextureCoordinates = 16;
    static immutable int Generic = 32;
    static immutable int BoneWeight = 64;
    static immutable int Tangent = 128;
    static immutable int BiNormal = 256;
}

class VertexAttributes
{
    private VertexAttribute[] _attributes;
    int vertexSize;
    private ulong _mask = 0;

    this(VertexAttribute[] attr...)
    {
        assert(attr.length > 0, "attributes must be > 0");

        foreach (VertexAttribute a; attr)
            _attributes ~= a;

        vertexSize = calculateOffsets();
    }

    int getOffset(int usage, int defaultIfNotFound)
    {
        VertexAttribute vertexAttribute = findByUsage(usage);
        if (vertexAttribute is null)
            return defaultIfNotFound;
        return vertexAttribute.offset / 4;
    }

    int getOffset(int usage)
    {
        return getOffset(usage, 0);
    }

    VertexAttribute findByUsage(int usage)
    {
        int len = size();
        for (int i = 0; i < len; i++)
            if (get(i).usage == usage)
                return get(i);
        return null;
    }

    private int calculateOffsets()
    {
        int count = 0;
        for (int i = 0; i < _attributes.length; i++)
        {
            auto attribute = _attributes[i];
            attribute.offset = count;
            count += attribute.getSizeInBytes();
        }

        return count;
    }

    int size()
    {
        return cast(int) _attributes.length;
    }

    VertexAttribute get(int index)
    {
        return _attributes[index];
    }

    ulong getMask()
    {
        if (_mask == 0)
        {
            long result = 0;
            for (int i = 0; i < _attributes.length; i++)
            {
                result |= _attributes[i].usage;
            }
            _mask = result;
        }
        return _mask;
    }

    long getMaskWithSizePacked()
    {
        return getMask() | (cast(long) _attributes.length << 32);
    }
}

class VertexAttribute
{
    static VertexAttribute position()
    {
        return new VertexAttribute(Usage.Position, 3, ShaderProgram.POSITION_ATTRIBUTE);
    }

    static VertexAttribute normal()
    {
        return new VertexAttribute(Usage.Normal, 3, ShaderProgram.NORMAL_ATTRIBUTE);
    }

    static VertexAttribute colorPacked()
    {
        return new VertexAttribute(Usage.ColorPacked, 4, ShaderProgram.COLOR_ATTRIBUTE);
    }

    static VertexAttribute colorUnpacked()
    {
        return new VertexAttribute(Usage.ColorUnpacked, 4, ShaderProgram.COLOR_ATTRIBUTE);
    }

    static VertexAttribute tangent()
    {
        return new VertexAttribute(Usage.Tangent, 3, ShaderProgram.TANGENT_ATTRIBUTE);
    }

    static VertexAttribute binormal()
    {
        return new VertexAttribute(Usage.BiNormal, 3, ShaderProgram.BINORMAL_ATTRIBUTE);
    }

    static VertexAttribute boneWeight(int unit)
    {
        return new VertexAttribute(Usage.BoneWeight, 2, format("%s%s",
                ShaderProgram.BONEWEIGHT_ATTRIBUTE, unit), unit);
    }

    static VertexAttribute texCoords(int unit)
    {
        return new VertexAttribute(Usage.TextureCoordinates, 2, format("%s%s",
                ShaderProgram.TEXCOORD_ATTRIBUTE, unit), unit);
    }

    int usage;
    int numComponents;
    bool normalized;
    int type;
    int offset;
    string aliass;
    int unit;
    private int _usageIndex;

    this(int usage, int numComponents, string aliass, int unit = 0)
    {
        this(usage, numComponents, usage == Usage.ColorPacked ? GL_UNSIGNED_BYTE
                : GL_FLOAT, usage == Usage.ColorPacked, aliass, unit);
    }

    this(int usage, int numComponents, int type, bool normalized, string aliass, int unit)
    {
        this.usage = usage;
        this.numComponents = numComponents;
        this.type = type;
        this.normalized = normalized;
        this.aliass = aliass;
        this.unit = unit;
        _usageIndex = numberOfTrailingZeros(usage);
    }

    static int numberOfTrailingZeros(int i)
    {
        return bitCount((i & -i) - 1);
    }

    static int bitCount(int i)
    {
        // Algo from : http://aggregate.ee.engr.uky.edu/MAGIC/#Population%20Count%20(ones%20Count)   
        i -= ((i >> 1) & 0x55555555);
        i = (i & 0x33333333) + ((i >> 2) & 0x33333333);
        i = (((i >> 4) + i) & 0x0F0F0F0F);
        i += (i >> 8);
        i += (i >> 16);
        return (i & 0x0000003F);
    }

    int getKey()
    {
        return (_usageIndex << 8) + (unit & 0xFF);
    }

    int getSizeInBytes()
    {
        switch (type)
        {
        case GL_FLOAT:
            return 4 * numComponents;
        case GL_UNSIGNED_BYTE:
        case GL_BYTE:
            return numComponents;
        case GL_UNSIGNED_SHORT:
        case GL_SHORT:
            return 2 * numComponents;
        default:
            throw new Exception("Type not supported");
        }
        // return 0;
    }
}

class VertexBuffer
{
    private VertexAttributes _attributes;
    private GLuint _bufferHandle;
    private bool _isStatic;
    private int _usage;
    private bool _isDirty = false;
    private bool _isBound = false;
    private GLuint _vaoHandle;

    private float[] _vertices;
    private int[] _cachedLocations;

    this(bool isStatic, int numVerticies, VertexAttributes attributes)
    {
        _isStatic = isStatic;
        _attributes = attributes;
        _vertices.length = numVerticies * (attributes.vertexSize / 4);

        glGenBuffers(1, &_bufferHandle);
        _usage = _isStatic ? GL_STATIC_DRAW : GL_DYNAMIC_DRAW;

        createVAO();
    }

    int getNumVertices()
    {
        return cast(int) _vertices.length / (_attributes.vertexSize / 4);
    }

    int getNumMaxVertices()
    {
        return cast(int) _vertices.length / (_attributes.vertexSize / 4);
    }

    void setVertices(float[] vertices, int offset, int count)
    {
        _isDirty = true;

        //_vertices = vertices[offset .. offset + count];

        _vertices.length = count;
        for(int i = 0; i < count; i++)
            _vertices[i] = vertices[offset + i];

        bufferChanged();
    }

    private void bufferChanged()
    {
        if (_isBound)
        {
            glBufferData(GL_ARRAY_BUFFER, (_vertices.length * float.sizeof), _vertices.ptr, _usage);
            _isDirty = false;
        }
    }

    void bind(ShaderProgram shader, int[] locations)
    {
        glBindVertexArray(_vaoHandle);

        bindAttributes(shader, locations);

        //if our data has changed upload it:
        bindData();

        _isBound = true;
    }

    void unbind(ShaderProgram shader, int[] locations)
    {
        glBindVertexArray(0);
        _isBound = false;
    }

    private void bindAttributes(ShaderProgram shader, int[] locations)
    {
        auto stillValid = _cachedLocations.length != 0;
        auto numAttributes = _attributes.size();

        if (stillValid)
        {
            if (locations == null)
            {
                for (int i = 0; stillValid && i < numAttributes; i++)
                {
                    VertexAttribute attribute = _attributes.get(i);
                    int location = shader.getAttributeLocation(attribute.aliass);

                    stillValid = location == _cachedLocations[i];

                }
            }
            else
            {
                stillValid = locations.length == _cachedLocations.length;
                for (int i = 0; stillValid && i < numAttributes; i++)
                {
                    stillValid = locations[i] == _cachedLocations[i];
                }
            }
        }

        if (!stillValid)
        {
            glBindBuffer(GL_ARRAY_BUFFER, _bufferHandle);
            unbindAttributes(shader);
            _cachedLocations.length = numAttributes;

            for (int i = 0; i < numAttributes; i++)
            {
                VertexAttribute attribute = _attributes.get(i);
                if (locations == null)
                {
                    int l = (shader.getAttributeLocation(attribute.aliass));
                    _cachedLocations[i] = l;
                }
                else
                {
                    _cachedLocations[i] = (locations[i]);
                }

                int location = _cachedLocations[i];
                if (location < 0)
                {
                    continue;
                }

                shader.enableVertexAttribute(location);
                shader.setVertexAttribute(location, attribute.numComponents, attribute.type,
                        attribute.normalized, _attributes.vertexSize, attribute.offset);
            }
        }
    }

    private void unbindAttributes(ShaderProgram shaderProgram)
    {
        if (_cachedLocations.length == 0)
        {
            return;
        }
        int numAttributes = _attributes.size();
        for (int i = 0; i < numAttributes; i++)
        {
            int location = _cachedLocations[i];
            if (location < 0)
            {
                continue;
            }
            shaderProgram.disableVertexAttribute(location);
        }
    }

    private void bindData()
    {
        if (_isDirty)
        {
            glBindBuffer(GL_ARRAY_BUFFER, _bufferHandle);
            glBufferData(GL_ARRAY_BUFFER, (_vertices.length * float.sizeof), _vertices.ptr, _usage);
            _isDirty = false;
        }
    }

    void invalidate()
    {
        glGenBuffers(1, &_bufferHandle);
        createVAO();
        _isDirty = true;
    }

    private void createVAO()
    {
        glGenVertexArrays(1, &_vaoHandle);
    }

}

class IndexBuffer
{
    private short[] _buffer;
    private GLuint _bufferHandle;
    private bool _isDirect;
    private bool _isDirty = true;
    private bool _isBound = false;
    private int _usage;

    private bool _empty;

    this(bool isStatic, int maxIndices)
    {
        _empty = maxIndices == 0;
        if (_empty)
            maxIndices = 1;

        _buffer.length = maxIndices;

        _isDirect = true;
        glGenBuffers(1, &_bufferHandle);
        _usage = isStatic ? GL_STATIC_DRAW : GL_DYNAMIC_DRAW;
    }

    void setIndices(short[] indices, int offset, int count)
    {
        _isDirty = true;

        //_buffer = indices[offset .. offset + count];

        _buffer.length = count;
        for(int i = 0; i < count; i++)
            _buffer[i] = indices[offset + i];


        if (_isBound)
        {
            glBufferData(GL_ELEMENT_ARRAY_BUFFER, _buffer.length * 2, _buffer.ptr, _usage);
            _isDirty = false;
        }
    }

    void bind()
    {
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _bufferHandle);
        if (_isDirty)
        {
            glBufferData(GL_ELEMENT_ARRAY_BUFFER, _buffer.length * 2, _buffer.ptr, _usage);
            _isDirty = false;
        }
        _isBound = true;
    }

    void unbind()
    {
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
        _isBound = false;
    }

    void invalidate()
    {
        glGenBuffers(1, &_bufferHandle);
        _isDirty = true;
    }

    int getNumIndices()
    {
        return _empty ? 0 : cast(int) _buffer.length;
    }

    int getNumMaxIndices()
    {
        return _empty ? 0 : cast(int) _buffer.length;
    }

    void dispose()
    {
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
        glDeleteBuffers(1, &_bufferHandle);
        _bufferHandle = 0;
    }

    auto getBufferPointer()
    {
        return _buffer.ptr;
    }

    ref short[] getBuffer()
    {
        return _buffer;
    }
}
