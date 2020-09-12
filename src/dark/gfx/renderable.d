module darc.gfx.renderable;

import std.container;

import darc.pool;
import darc.math;
import darc.gfx.material;
import darc.gfx.mesh_part;
import darc.gfx.shader;

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