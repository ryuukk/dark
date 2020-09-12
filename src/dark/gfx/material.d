module darc.gfx.material;

import darc.color;
import darc.gfx.texture;

public abstract class Attribute
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

    public static ulong register(string aliass)
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

    public ulong type;
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

public class TextureAttribute : Attribute
{
    public immutable static string diffuseAlias = "diffuseTexture";
    public immutable static ulong diffuse;

    shared static this()
    {
        diffuse = register(diffuseAlias);
        mask = diffuse;
    }

    public static ulong mask;

    public TextureDescriptor descriptor;
    public float offsetU = 0;
    public float offsetV = 0;
    public float scaleU = 1;
    public float scaleV = 1;
    public int uvIndex = 0;

    public this(ulong type)
    {
        super(type);
        descriptor = new TextureDescriptor();
    }

    public this(ulong type, Texture2D texture)
    {
        super(type);
        descriptor = new TextureDescriptor();
        descriptor.texture = texture;
    }

    public static TextureAttribute createDiffuse(Texture2D texture)
    {
        return new TextureAttribute(diffuse, texture);
    }
}

public class IntAttribute : Attribute
{
    public static immutable string cullFaceAlias = "cullface";
    public static immutable ulong cullFace;

    shared static this()
    {
        cullFace = register(cullFaceAlias);
    }

    public static IntAttribute createCullFace(int value)
    {
        return new IntAttribute(cullFace, value);
    }

    public int value;

    public this(ulong type, int value)
    {
        super(type);
        this.value = value;
    }
}

public class DepthTestAttribute : Attribute
{
    public static immutable string aliass = "depthStencil";
    public static immutable ulong type;

    shared static this()
    {
        type = register(aliass);
    }

    public int depthFunc;
    public float depthRangeNear;
    public float depthRangeFar;
    public bool depthMask;

    public this(ulong type)
    {
        super(type);
    }
}

public class ColorAttribute : Attribute
{
    public immutable static string diffuseAlias = "diffuseColor";
    public immutable static string specularAlias = "specularColor";
    public immutable static string ambientAlias = "ambientColor";
    public immutable static string emissiveAlias = "emissiveColor";
    public immutable static string reflectionAlias = "reflectionColor";
    public immutable static string ambientLightAlias = "ambientLightColor";
    public immutable static string fogAlias = "fogColor";

    public immutable static ulong diffuse;
    public immutable static ulong specular;
    public immutable static ulong ambient;
    public immutable static ulong emissive;
    public immutable static ulong reflection;
    public immutable static ulong ambientLight;
    public immutable static ulong fog;

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

    public static ColorAttribute createAmbient(Color color)
    {
        return new ColorAttribute(ambient, color);
    }

    public static ColorAttribute createDiffuse(Color color)
    {
        return new ColorAttribute(diffuse, color);
    }

    public static ColorAttribute createSpecular(Color color)
    {
        return new ColorAttribute(specular, color);
    }

    public static ColorAttribute createReflection(Color color)
    {
        return new ColorAttribute(reflection, color);
    }

    public Color color;

    public this(ulong type, Color color)
    {
        super(type);
        this.color = color;
    }
}

public class Attributes
{
    public ulong mask;
    public Attribute[] attributes;
    public bool sorted = true;

    private void enable(ulong mask)
    {
        this.mask |= mask;
    }

    private void disable(ulong mask)
    {
        this.mask &= ~mask;
    }

    public void sort()
    {
        if (!sorted)
        {
            // todo: figure out sorting
            //attributes.sort(this);
            sorted = true;
        }
    }

    public void set(Attribute attribute)
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

    public bool has(ulong type)
    {
        return type != 0 && (this.mask & type) == type;
    }

    public int indexOf(ulong type)
    {
        if (has(type))
            for (int i = 0; i < attributes.length; i++)
                if (attributes[i].type == type)
                    return i;
        return -1;
    }

    public T get(T)(ulong t)
    {
        int index = indexOf(t);
        if (index == -1)
            return null;

        return cast(T) attributes[index];
    }

    public ulong getMask()
    {
        return mask;
    }
}

public class Material : Attributes
{
    import std.string;

    private static int counter = 0;
    public string id;

    public this()
    {
        id = format("mtl_%s", (++counter));
    }

    public this(string id)
    {
        this.id = id;
    }
}

public class Environment : Material
{
}
