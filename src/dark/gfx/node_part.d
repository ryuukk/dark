module dark.gfx.node_part;

import std.stdio;
import std.algorithm;
import std.typecons;

import dark.gfx.node;
import dark.gfx.mesh_part;
import dark.gfx.material;
import dark.gfx.renderable;
import dark.math;

struct InvBoneBind
{
    Node node;
    Mat4 transform;

    this(Node node, Mat4 transform)
    {
        this.node = node;
        this.transform = transform;
    }
}

class NodePart
{
    MeshPart meshPart;
    Material material;
    InvBoneBind[] invBoneBindTransforms;
    Mat4[] bones;
    bool enabled = true;

    this()
    {
    }

    NodePart copy()
    {
        auto node =  new NodePart();
        node.set(this);
        return node;
    }

    NodePart set(NodePart other)
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