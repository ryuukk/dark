module darc.gfx.node_part;

import std.stdio;
import std.algorithm;
import std.typecons;

import darc.gfx.node;
import darc.gfx.mesh_part;
import darc.gfx.material;
import darc.gfx.renderable;
import darc.math;

public struct InvBoneBind
{
    public Node node;
    public Mat4 transform;

    public this(Node node, Mat4 transform)
    {
        this.node = node;
        this.transform = transform;
    }
}

public class NodePart
{
    public MeshPart meshPart;
    public Material material;
    public InvBoneBind[] invBoneBindTransforms;
    public Mat4[] bones;
    public bool enabled = true;

    public this()
    {
    }

    public NodePart copy()
    {
        auto node =  new NodePart();
        node.set(this);
        return node;
    }

    public NodePart set(NodePart other)
    {
        meshPart = new MeshPart(other.meshPart);
        material = other.material;
        enabled = other.enabled;

        if(other.invBoneBindTransforms.length > 0)
        {
            invBoneBindTransforms.length = other.invBoneBindTransforms.length;
            bones.length = other.invBoneBindTransforms.length;
            for(int i = 0; i < other.invBoneBindTransforms.length; ++i)
            {
                auto entry = &other.invBoneBindTransforms[i];
                invBoneBindTransforms[i] = InvBoneBind(entry.node, entry.transform);
            }

            for (int i = 0; i < bones.length; i++)
            {
                bones[i] = Mat4.identity;
            }
        }

        return this;
    }
}