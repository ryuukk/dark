module dark.gfx.font;

import dark.gfx.texture;


struct GlyphRun
{}

struct GlyphLayout
{
    
}

struct Glyph
{}

class BitmapFontCache
{

}


class BitmapFontData
{
}

public class BitmapFont
{
    const int LOG2_PAGE_SIZE = 9;
    const int PAGE_SIZE = 1 << LOG2_PAGE_SIZE;
    const int PAGES = 0x10000 / PAGE_SIZE;

    public BitmapFontData data;
    public TextureRegion[] regions;
    private BitmapFontCache _cache;
    private bool _flipped;
    private bool _integer;
    private bool _ownsTexture;
}
