module dark.gfx.node;

import std.stdio;
import std.algorithm;
import std.typecons;

import dark.math;
import dark.collections;
import dark.gfx.node;
import dark.gfx.node_part;
import dark.gfx.mesh;
import dark.gfx.mesh_part;
import dark.gfx.material;
import dark.gfx.renderable;

class Node
{
    string id;
    bool inheritTransform = true;
    bool isAnimated = false;

    Vec3 translation = Vec3(0, 0, 0);
    Quat rotation = Quat.identity;
    Vec3 scale = Vec3(1, 1, 1);

    Mat4 localTransform = Mat4.identity;
    Mat4 globalTransform = Mat4.identity;

    NodePart[] parts;

    Node parent;
    Node[] children;

    /*
    override size_t toHash()
    {
        return 33 + 7 * typeid(id).getHash(&id) + typeid(globalTransform).getHash(&globalTransform);
    }

    override bool opEquals(Object o)
    {
        Node foo = cast(Node) o;
        return foo && id == foo.id;
    }
    */

    void calculateLocalTransform()
    {
        if (!isAnimated)
            localTransform = Mat4.set(translation, rotation, scale);
    }

    void calculateWorldTransform()
    {
        if (inheritTransform && parent !is null)
            globalTransform = Mat4.mult(parent.globalTransform, localTransform);
        else
            globalTransform = localTransform;
    }

    void calculateTransforms(bool recursive)
    {
        calculateLocalTransform();
        calculateWorldTransform();

        if (recursive)
        {
            foreach (Node child; children)
                child.calculateTransforms(true);
        }
    }

    void calculateBoneTransforms(bool recursive)
    {
        foreach (NodePart part; parts)
        {
            if (part.invBoneBindTransforms.length == 0 || part.bones.length == 0
                    || part.invBoneBindTransforms.length != part.bones.length)
            {
                continue;
            }
            auto n = part.invBoneBindTransforms.length;
            for (int i = 0; i < n; i++)
            {
                Mat4 globalTransform = part.invBoneBindTransforms[i].node.globalTransform;
                Mat4 invTransform = part.invBoneBindTransforms[i].transform;
                part.bones[i] = Mat4.mult(globalTransform, invTransform);
            }
        }

        if (recursive)
        {
            foreach (Node child; children)
                child.calculateBoneTransforms(true);
        }
    }

    void detach()
    {
        if (parent !is null)
        {
            parent.removeChild(this);
            parent = null;
        }
    }

    Node copy()
    {
        Node node = new Node();
        node.set(this);
        return node;
    }

    Node set(Node other)
    {
        detach();

        id = other.id;
        isAnimated = other.isAnimated;
        inheritTransform = other.inheritTransform;
        translation = other.translation;
        rotation = other.rotation;
        scale = other.scale;
        localTransform = other.localTransform;
        globalTransform = other.globalTransform;

        parts.length = other.parts.length;
        for(int i = 0; i < other.parts.length; i++)
        {
            auto nodePart = other.parts[i];
            parts[i] = nodePart.copy();
        }

        children.length = other.children.length;
        for(int i = 0; i < other.children.length; i++)
        {
            auto child = other.children[i];
            insertChild(cast(int)i, child.copy());
        }
        return this;
    }

    void resizeChildren(int l)
    {
        children.length = l;
    }
    int addChild(Node child)
    {
        // todo: resize array
        return insertChild(-1, child);
    }

    int insertChild(int index, Node child)
    {
        // todo: redo this
        for (Node p = this; p !is null; p = p.parent)
        {
            if (p == child)
                throw new Exception("Cannot add a parent as a child");
        }
         Node p = child.parent;
        if (p !is null && !p.removeChild(child))
            throw new Exception("Could not remove child from its current parent");

        children[index] = child;
        child.parent = this;
        return index;
    }

    int indexOf(Node child)
    {
        for (int i = 0; i < children.length; i++)
        {
            if (children[i] == child)
                return i;
        }
        return -1;
    }

    bool removeChild(Node child)
    {
        int index = indexOf(child);
        if (index == -1)
            return false;

        children = children.remove(index, 1);
        child.parent = null;
        return true;
    }
}

Node getNode(ref Node[] nodes, string id, bool recursive = true, bool ignoreCase = false)
{
    int n = cast(int) nodes.length;
    if (ignoreCase)
    {
        throw new Exception("not supported yet");
    }
    else
    {
        for (int i = 0; i < n; i++)
        {
            Node node = nodes[i];
            if (node.id == id)
                return node;
        }
    }

    if (recursive)
    {
        for (int i = 0; i < n; i++)
        {
            Node node = getNode(nodes[i].children, id, true, ignoreCase);
            if (node !is null)
                return node;
        }
    }
    return null;
}
