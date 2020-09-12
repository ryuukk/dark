module dark.gfx.renderable;

import std.container;

import dark.pool;
import dark.math;
import dark.gfx.material;
import dark.gfx.mesh_part;
import dark.gfx.shader;

public class Renderable : IPoolable
{
    public Mat4 worldTransform;
    public MeshPart meshPart;
    public Material material;
    public Environment environment;
    public Mat4[]* bones;
    public IShader shader;

    public this()
    {
        meshPart = new MeshPart;
    }

    public void reset()
    {
        
    }
}

public interface IRenderableProvider
{
    void getRenderables(ref Array!Renderable renderables, Pool!Renderable pool);
}