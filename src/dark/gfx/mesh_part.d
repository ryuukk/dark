module darc.gfx.mesh_part;

import darc.math;
import darc.gfx.shader_program;
import darc.gfx.mesh;

public class MeshPart
{
    public string id;
    public int primitiveType;
    public int offset;
    public int size;
    public Mesh mesh;

    public Vec3 center;
    public Vec3 halfExtents;
    public float radius = -1;

    public this()
    {}

    public this(MeshPart other)
    {
        set(other);
    }

    public void update()
    {
        // todo: update bounds
    }
    
	public MeshPart set (string id, Mesh mesh, int offset, int size, int type) 
    {
		this.id = id;
		this.mesh = mesh;
		this.offset = offset;
		this.size = size;
		this.primitiveType = type;
		this.center = Vec3(0, 0, 0);
		this.halfExtents = Vec3(0, 0, 0);
		this.radius = -1f;
		return this;
	}
    
	public MeshPart set (MeshPart other) {
		this.id = other.id;
		this.mesh = other.mesh;
		this.offset = other.offset;
		this.size = other.size;
		this.primitiveType = other.primitiveType;
		this.center = other.center;
		this.halfExtents = other.halfExtents;
		this.radius = other.radius;
		return this;
	}
    
	public void render (ShaderProgram shader, bool autoBind) 
    {
		mesh.render(shader, primitiveType, offset, size, autoBind);
	}
}