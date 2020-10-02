module dark.color;

struct Color
{
    union Stuff
    {
        uint packedColor;
        float floatBits;
    }

    static @property Color WHITE()
    {
        return Color(0xFFFFFFFF);
    }

    static @property Color BLACK()
    {
        return Color(0x000000FF);
    }

    static @property Color RED()
    {
        return Color(0xFF0000FF);
    }
    static @property Color GREEN()
    {
        return Color(0x00FF00FF);
    }
    static @property Color BLUE()
    {
        return Color(0x0000FFFF);
    }

    ubyte r;
    ubyte g;
    ubyte b;
    ubyte a;

    this(uint value)
    {
        r = cast(ubyte)((value & 0xff000000) >> 24);
        g = cast(ubyte)((value & 0x00ff0000) >> 16);
        b = cast(ubyte)((value & 0x0000ff00) >> 8);
        a = cast(ubyte)((value & 0x000000ff));
    }

    float toFloatBits()
    {
        auto s = Stuff();
        s.packedColor = cast(uint)((r << 24) | (g << 16) | (b << 8) | (a));
        return s.floatBits;
    }
}
