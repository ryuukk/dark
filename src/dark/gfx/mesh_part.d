module dark.gfx.mesh_part;

import dark.math;
import dark.gfx.shader_program;
import dark.gfx.mesh;

class MeshPart
{
    string id;
    int primitiveType;
    int offset;
    int size;
    Mesh mesh;

    Vec3 center;
    Vec3 halfExtents;
    float radius = -1;

    this()
    {}

    this(MeshPart other)
    {
        set(other);
    }

    void update()
    {
        // todo: update bounds
    }
    
	MeshPart set (string id, Mesh mesh, int offset, int size, int type) 
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
    
	MeshPart set (MeshPart other) {
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
    
	void render (ShaderProgram shader, bool autoBind) 
    {
		mesh.render(shader, primitiveType, offset, size, autoBind);
	}
}