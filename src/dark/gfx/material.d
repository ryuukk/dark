module dark.gfx.material;

import dark.color;
import dark.gfx.texture;

abstract class Attribute
{
    private static string[] types;

    private static ulong getAttributeType(string aliass)
    {
        for (int i = 0; i < types.length; i++)
            if (types[i] == aliass)
                return 1UL << i;
        return 0;
    }

    private string getAttributeAlias(ulong type)
    {
        int idx = -1;
        while (type != 0 && ++idx < 63 && (((type >> idx) & 1) == 0))
        {
        }
        return (idx >= 0 && idx < types.length) ? types[idx] : null;
    }

    static ulong register(string aliass)
    {
        long result = getAttributeType(aliass);
        if (result > 0)
            return result;
        types ~= aliass;
        return 1L << (types.length - 1);
    }

    private static int numberOfTrailingZeros(ulong u)
    {
        if (u == 0)
        {
            return 64;
        }

        uint n = 63;
        ulong t;
        t = u << 32;
        if (t != 0)
        {
            n -= 32;
            u = t;
        }
        t = u << 16;
        if (t != 0)
        {
            n -= 16;
            u = t;
        }
        t = u << 8;
        if (t != 0)
        {
            n -= 8;
            u = t;
        }
        t = u << 4;
        if (t != 0)
        {
            n -= 4;
            u = t;
        }
        t = u << 2;
        if (t != 0)
        {
            n -= 2;
            u = t;
        }
        u = (u << 1) >> 63;
        return cast(int)(n - u);
    }

    ulong type;
    private int typeBit;

    protected this(ulong type)
    {
        this.type = type;
        this.typeBit = numberOfTrailingZeros(type);
    }

    protected bool equals(Attribute other)
    {
        return true;
    }
}

class TextureAttribute : Attribute
{
    immutable static string diffuseAlias = "diffuseTexture";
    immutable static ulong diffuse;

    shared static this()
    {
        diffuse = register(diffuseAlias);
        mask = diffuse;
    }

    static ulong mask;

    TextureDescriptor descriptor;
    float offsetU = 0;
    float offsetV = 0;
    float scaleU = 1;
    float scaleV = 1;
    int uvIndex = 0;

    this(ulong type)
    {
        super(type);
        descriptor = new TextureDescriptor();
    }

    this(ulong type, Texture2D texture)
    {
        super(type);
        descriptor = new TextureDescriptor();
        descriptor.texture = texture;
    }

    static TextureAttribute createDiffuse(Texture2D texture)
    {
        return new TextureAttribute(diffuse, texture);
    }
}

class IntAttribute : Attribute
{
    static immutable string cullFaceAlias = "cullface";
    static immutable ulong cullFace;

    shared static this()
    {
        cullFace = register(cullFaceAlias);
    }

    static IntAttribute createCullFace(int value)
    {
        return new IntAttribute(cullFace, value);
    }

    int value;

    this(ulong type, int value)
    {
        super(type);
        this.value = value;
    }
}

class DepthTestAttribute : Attribute
{
    static immutable string aliass = "depthStencil";
    static immutable ulong type;

    shared static this()
    {
        type = register(aliass);
    }

    int depthFunc;
    float depthRangeNear;
    float depthRangeFar;
    bool depthMask;

    this(ulong type)
    {
        super(type);
    }
}

class ColorAttribute : Attribute
{
    immutable static string diffuseAlias = "diffuseColor";
    immutable static string specularAlias = "specularColor";
    immutable static string ambientAlias = "ambientColor";
    immutable static string emissiveAlias = "emissiveColor";
    immutable static string reflectionAlias = "reflectionColor";
    immutable static string ambientLightAlias = "ambientLightColor";
    immutable static string fogAlias = "fogColor";

    immutable static ulong diffuse;
    immutable static ulong specular;
    immutable static ulong ambient;
    immutable static ulong emissive;
    immutable static ulong reflection;
    immutable static ulong ambientLight;
    immutable static ulong fog;

    protected static ulong mask;

    shared static this()
    {
        diffuse = register(diffuseAlias);
        specular = register(specularAlias);
        ambient = register(ambientAlias);
        emissive = register(emissiveAlias);
        reflection = register(reflectionAlias);
        ambientLight = register(ambientLightAlias);
        fog = register(fogAlias);
        mask = ambient | diffuse | specular | emissive | reflection | ambientLight | fog;
    }

    static ColorAttribute createAmbient(Color color)
    {
        return new ColorAttribute(ambient, color);
    }

    static ColorAttribute createDiffuse(Color color)
    {
        return new ColorAttribute(diffuse, color);
    }

    static ColorAttribute createSpecular(Color color)
    {
        return new ColorAttribute(specular, color);
    }

    static ColorAttribute createReflection(Color color)
    {
        return new ColorAttribute(reflection, color);
    }

    Color color;

    this(ulong type, Color color)
    {
        super(type);
        this.color = color;
    }
}

class Attributes
{
    ulong mask;
    Attribute[] attributes;
    bool sorted = true;

    private void enable(ulong mask)
    {
        this.mask |= mask;
    }

    private void disable(ulong mask)
    {
        this.mask &= ~mask;
    }

    void sort()
    {
        if (!sorted)
        {
            // todo: figure out sorting
            //attributes.sort(this);
            sorted = true;
        }
    }

    void set(Attribute attribute)
    {
        int idx = indexOf(attribute.type);
        if (idx < 0)
        {
            enable(attribute.type);
            attributes ~= attribute;
            sorted = false;
        }
        else
        {
            attributes[idx] = attribute;
        }
        sort(); //FIXME: See #4186
    }

    bool has(ulong type)
    {
        return type != 0 && (this.mask & type) == type;
    }

    int indexOf(ulong type)
    {
        if (has(type))
            for (int i = 0; i < attributes.length; i++)
                if (attributes[i].type == type)
                    return i;
        return -1;
    }

    T get(T)(ulong t)
    {
        int index = indexOf(t);
        if (index == -1)
            return null;

        return cast(T) attributes[index];
    }

    ulong getMask()
    {
        return mask;
    }
}

class Material : Attributes
{
    import std.string;

    private static int counter = 0;
    string id;

    this()
    {
        id = format("mtl_%s", (++counter));
    }

    this(string id)
    {
        this.id = id;
    }
}

class Environment : Material
{
}
