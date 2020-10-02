module dark.gfx.renderable;

import std.container;

import dark.pool;
import dark.math;
import dark.gfx.material;
import dark.gfx.mesh_part;
import dark.gfx.shader;

class Renderable : IPoolable
{
    Mat4 worldTransform;
    MeshPart meshPart;
    Material material;
    Environment environment;
    Mat4[]* bones;
    IShader shader;

    this()
    {
        meshPart = new MeshPart;
    }

    void reset()
    {
        
    }
}

interface IRenderableProvider
{
    void getRenderables(ref Array!Renderable renderables, Pool!Renderable pool);
}