module darc.color;

public struct Color
{
    union Stuff
    {
        public uint packedColor;
        public float floatBits;
    }

    public static @property Color WHITE()
    {
        return Color(0xFFFFFFFF);
    }

    public static @property Color BLACK()
    {
        return Color(0x000000FF);
    }

    public static @property Color RED()
    {
        return Color(0xFF0000FF);
    }
    public static @property Color GREEN()
    {
        return Color(0x00FF00FF);
    }
    public static @property Color BLUE()
    {
        return Color(0x0000FFFF);
    }

    public ubyte r;
    public ubyte g;
    public ubyte b;
    public ubyte a;

    public this(uint value)
    {
        r = cast(ubyte)((value & 0xff000000) >> 24);
        g = cast(ubyte)((value & 0x00ff0000) >> 16);
        b = cast(ubyte)((value & 0x0000ff00) >> 8);
        a = cast(ubyte)((value & 0x000000ff));
    }

    public float toFloatBits()
    {
        auto s = Stuff();
        s.packedColor = cast(uint)((r << 24) | (g << 16) | (b << 8) | (a));
        return s.floatBits;
    }
}
