module darc.gfx.buffers;

import std.stdio;
import std.format;

import bindbc.opengl;

import darc.gfx.shader_program;

public class Usage
{
    public static immutable int Position = 1;
    public static immutable int ColorUnpacked = 2;
    public static immutable int ColorPacked = 4;
    public static immutable int Normal = 8;
    public static immutable int TextureCoordinates = 16;
    public static immutable int Generic = 32;
    public static immutable int BoneWeight = 64;
    public static immutable int Tangent = 128;
    public static immutable int BiNormal = 256;
}

public class VertexAttributes
{
    private VertexAttribute[] _attributes;
    public int vertexSize;
    private ulong _mask = 0;

    public this(VertexAttribute[] attr...)
    {
        assert(attr.length > 0, "attributes must be > 0");

        foreach (VertexAttribute a; attr)
            _attributes ~= a;

        vertexSize = calculateOffsets();
    }

    public int getOffset(int usage, int defaultIfNotFound)
    {
        VertexAttribute vertexAttribute = findByUsage(usage);
        if (vertexAttribute is null)
            return defaultIfNotFound;
        return vertexAttribute.offset / 4;
    }

    public int getOffset(int usage)
    {
        return getOffset(usage, 0);
    }

    public VertexAttribute findByUsage(int usage)
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

    public int size()
    {
        return cast(int) _attributes.length;
    }

    public VertexAttribute get(int index)
    {
        return _attributes[index];
    }

    public ulong getMask()
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

    public long getMaskWithSizePacked()
    {
        return getMask() | (cast(long) _attributes.length << 32);
    }
}

public class VertexAttribute
{
    public static VertexAttribute position()
    {
        return new VertexAttribute(Usage.Position, 3, ShaderProgram.POSITION_ATTRIBUTE);
    }

    public static VertexAttribute normal()
    {
        return new VertexAttribute(Usage.Normal, 3, ShaderProgram.NORMAL_ATTRIBUTE);
    }

    public static VertexAttribute colorPacked()
    {
        return new VertexAttribute(Usage.ColorPacked, 4, ShaderProgram.COLOR_ATTRIBUTE);
    }

    public static VertexAttribute colorUnpacked()
    {
        return new VertexAttribute(Usage.ColorUnpacked, 4, ShaderProgram.COLOR_ATTRIBUTE);
    }

    public static VertexAttribute tangent()
    {
        return new VertexAttribute(Usage.Tangent, 3, ShaderProgram.TANGENT_ATTRIBUTE);
    }

    public static VertexAttribute binormal()
    {
        return new VertexAttribute(Usage.BiNormal, 3, ShaderProgram.BINORMAL_ATTRIBUTE);
    }

    public static VertexAttribute boneWeight(int unit)
    {
        return new VertexAttribute(Usage.BoneWeight, 2, format("%s%s",
                ShaderProgram.BONEWEIGHT_ATTRIBUTE, unit), unit);
    }

    public static VertexAttribute texCoords(int unit)
    {
        return new VertexAttribute(Usage.TextureCoordinates, 2, format("%s%s",
                ShaderProgram.TEXCOORD_ATTRIBUTE, unit), unit);
    }

    public int usage;
    public int numComponents;
    public bool normalized;
    public int type;
    public int offset;
    public string aliass;
    public int unit;
    private int _usageIndex;

    public this(int usage, int numComponents, string aliass, int unit = 0)
    {
        this(usage, numComponents, usage == Usage.ColorPacked ? GL_UNSIGNED_BYTE
                : GL_FLOAT, usage == Usage.ColorPacked, aliass, unit);
    }

    public this(int usage, int numComponents, int type, bool normalized, string aliass, int unit)
    {
        this.usage = usage;
        this.numComponents = numComponents;
        this.type = type;
        this.normalized = normalized;
        this.aliass = aliass;
        this.unit = unit;
        _usageIndex = numberOfTrailingZeros(usage);
    }

    public static int numberOfTrailingZeros(int i)
    {
        return bitCount((i & -i) - 1);
    }

    public static int bitCount(int i)
    {
        // Algo from : http://aggregate.ee.engr.uky.edu/MAGIC/#Population%20Count%20(ones%20Count)   
        i -= ((i >> 1) & 0x55555555);
        i = (i & 0x33333333) + ((i >> 2) & 0x33333333);
        i = (((i >> 4) + i) & 0x0F0F0F0F);
        i += (i >> 8);
        i += (i >> 16);
        return (i & 0x0000003F);
    }

    public int getKey()
    {
        return (_usageIndex << 8) + (unit & 0xFF);
    }

    public int getSizeInBytes()
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

public class VertexBuffer
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

    public this(bool isStatic, int numVerticies, VertexAttributes attributes)
    {
        _isStatic = isStatic;
        _attributes = attributes;
        _vertices.length = numVerticies * (attributes.vertexSize / 4);

        glGenBuffers(1, &_bufferHandle);
        _usage = _isStatic ? GL_STATIC_DRAW : GL_DYNAMIC_DRAW;

        createVAO();
    }

    public int getNumVertices()
    {
        return cast(int) _vertices.length / (_attributes.vertexSize / 4);
    }

    public int getNumMaxVertices()
    {
        return cast(int) _vertices.length / (_attributes.vertexSize / 4);
    }

    public void setVertices(float[] vertices, int offset, int count)
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

    public void bind(ShaderProgram shader, int[] locations)
    {
        glBindVertexArray(_vaoHandle);

        bindAttributes(shader, locations);

        //if our data has changed upload it:
        bindData();

        _isBound = true;
    }

    public void unbind(ShaderProgram shader, int[] locations)
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

    public void invalidate()
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

public class IndexBuffer
{
    private short[] _buffer;
    private GLuint _bufferHandle;
    private bool _isDirect;
    private bool _isDirty = true;
    private bool _isBound = false;
    private int _usage;

    private bool _empty;

    public this(bool isStatic, int maxIndices)
    {
        _empty = maxIndices == 0;
        if (_empty)
            maxIndices = 1;

        _buffer.length = maxIndices;

        _isDirect = true;
        glGenBuffers(1, &_bufferHandle);
        _usage = isStatic ? GL_STATIC_DRAW : GL_DYNAMIC_DRAW;
    }

    public void setIndices(short[] indices, int offset, int count)
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

    public void bind()
    {
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _bufferHandle);
        if (_isDirty)
        {
            glBufferData(GL_ELEMENT_ARRAY_BUFFER, _buffer.length * 2, _buffer.ptr, _usage);
            _isDirty = false;
        }
        _isBound = true;
    }

    public void unbind()
    {
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
        _isBound = false;
    }

    public void invalidate()
    {
        glGenBuffers(1, &_bufferHandle);
        _isDirty = true;
    }

    public int getNumIndices()
    {
        return _empty ? 0 : cast(int) _buffer.length;
    }

    public int getNumMaxIndices()
    {
        return _empty ? 0 : cast(int) _buffer.length;
    }

    public void dispose()
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
