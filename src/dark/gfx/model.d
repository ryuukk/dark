module dark.gfx.model;

import std.container;
import std.stdio;
import std.format;
import std.typecons;

import dark.pool;
import dark.math;
import dark.color;
import dark.core;
import dark.collections;
import dark.gfx.node;
import dark.gfx.material;
import dark.gfx.animation;
import dark.gfx.mesh;
import dark.gfx.mesh_part;
import dark.gfx.buffers;
import dark.gfx.node;
import dark.gfx.renderable;
import dark.gfx.model_loader;
import dark.gfx.node_part;

class Model
{
    string id;
    Material[] materials;
    Node[] nodes;
    Animation[] animations;
    Mesh[] meshes;
    MeshPart[] meshParts;

    Bone[][NodePart] nodePartBones;

    void load(ModelData data)
    {
        id = data.id;
        loadMeshes(data.meshes);
        loadMaterials(data.materials /*, contentManager */ );
        loadNodes(data);
        loadAnimations(data.animations);
        calculateTransforms();
    }

    private void loadMeshes(ModelMesh[] meshes)
    {
        for (int i = 0; i < meshes.length; i++)
        {
            convertMesh(meshes[i]);
        }
    }

    private void convertMesh(ModelMesh modelMesh)
    {
        int numIndices = 0;
        for (int i = 0; i < modelMesh.parts.length; i++)
        {
            numIndices += modelMesh.parts[i].indices.length;
        }
        
        bool hasIndices = numIndices > 0;

        auto attributes = new VertexAttributes(modelMesh.attributes);
        int numVertices = cast(int) modelMesh.vertices.length / (attributes.vertexSize / 4);

        Mesh mesh = new Mesh(true, numVertices, numIndices, attributes);
        meshes ~= mesh;

        mesh.setVertices(modelMesh.vertices);
        short[] indices;
        
        int offset = 0;
        meshParts.length = modelMesh.parts.length;
        foreach (i, part; modelMesh.parts)
        {
            MeshPart meshPart = new MeshPart;
            meshPart.id = part.id;
            meshPart.primitiveType = part.primitiveType;
            meshPart.offset = offset;
            meshPart.size = hasIndices ? cast(int) part.indices.length : numVertices;
            meshPart.mesh = mesh;
            if (hasIndices)
               indices ~= part.indices;
            offset += meshPart.size;
            meshParts[i] = meshPart;
        }

        mesh.setIndices(indices);
        foreach (part; meshParts)
            part.update();
    }

    private void loadMaterials(ModelMaterial[] modelMaterials)
    {
        foreach (mtl; modelMaterials)
            convertMaterial(mtl);
    }

    private void convertMaterial(ModelMaterial mtl)
    {
        import dark.gfx.texture;

        Material result = new Material(mtl.id);

        if (mtl.textures.length > 0)
        {
            Texture2D texture = Texture2D.fromFile(mtl.textures[0].fileName);
            result.set(TextureAttribute.createDiffuse(texture));
        }

        materials ~= result;
    }


    private void loadNodes(ModelData data)
    {
        nodePartBones.clear();
        nodes.length = data.nodes.length;
        foreach (i, node; data.nodes)
        {
            nodes[i] = loadNode(node);
        }

        foreach(ref e; nodePartBones.byKeyValue())
        {
            e.key.invBoneBindTransforms.length = e.value.length;

            for(int i = 0; i < e.value.length; i++)
            {
                auto pair = e.value[i];
                auto node = getNode(nodes, pair.id);
                if(node is null) 
                    throw new Exception(format("node: %s can't be found...", pair.id));
                
                auto invTransform = Mat4.inv(pair.transform);
                e.key.invBoneBindTransforms[i] = InvBoneBind(node, invTransform);
            }
        }
    }

    private Node loadNode(ModelNode modelNode)
    {
        Node node = new Node;
        node.id = modelNode.id;
        node.translation = modelNode.translation;
        node.rotation = modelNode.rotation;
        node.scale = modelNode.scale;

        if (modelNode.parts.length > 0)
        {
            node.parts.length = modelNode.parts.length;

            foreach (i, ModelNodePart modelNodePart; modelNode.parts)
            {
                MeshPart meshPart = null;
                Material meshMaterial = null;

                if (modelNodePart.meshPartId.length > 0)
                {
                    foreach (part; meshParts)
                    {
                        if(modelNodePart.meshPartId == part.id)
                        {
                            meshPart = part;
                            break;
                        }
                    }
                }

                if (modelNodePart.materialId.length > 0)
                {
                    foreach (material; materials)
                    {
                        if(modelNodePart.materialId == material.id)
                        {
                            meshMaterial = material;
                            break;
                        }
                    }
                }

                if (meshPart is null || meshMaterial is null)
                    throw new Exception("invalid node");

                NodePart nodePart = new NodePart();
                nodePart.meshPart = meshPart;
                nodePart.material = meshMaterial;
                node.parts[i] = nodePart;

                if (modelNodePart.bones.length > 0)
                    nodePartBones[nodePart] = modelNodePart.bones;
            }
        }

        if (modelNode.children.length > 0)
        {
            // todo: clean this shit
            node.resizeChildren(cast(int) modelNode.children.length);
            foreach (i, ModelNode child; modelNode.children)
            {
                auto c = loadNode(child);
                node.insertChild(cast(int)i, c);
            }
        }

        return node;
    }

    private void loadAnimations(in ModelAnimation[] modelAnimations)
    {
        for (int i = 0; i < modelAnimations.length; i++)
        {
            auto anim = modelAnimations[i];
            auto animation = new Animation;
            animation.id = anim.id;

            for (int j = 0; j < anim.nodeAnimations.length; j++)
            {
                auto nanim = anim.nodeAnimations[j];
                auto node = getNode(nodes, nanim.nodeId);
                if(node is null) throw new Exception("node can't be found...");

                NodeAnimation nodeAnim = new NodeAnimation;
                nodeAnim.node = node;

                if (nanim.translation.length > 0)
                {
                    nodeAnim.translation.length = nanim.translation.length;
                    foreach (k, kf; nanim.translation)
                    {
                        if (kf.keytime > animation.duration)
                            animation.duration = kf.keytime;

                        // todo: some might not have value, so we might was take node translation instead
                        auto nkt = NodeKeyframe!Vec3();
                        nkt.keytime = kf.keytime;
                        nkt.value = kf.value;
                        nodeAnim.translation[k] = nkt;
                    }
                }

                if (nanim.rotation.length > 0)
                {
                    nodeAnim.rotation.length = nanim.rotation.length;
                    foreach (k, kf; nanim.rotation)
                    {
                        if (kf.keytime > animation.duration)
                            animation.duration = kf.keytime;
                        // todo: some might not have value, so we might was take node translation instead
                        auto nkt = NodeKeyframe!Quat();
                        nkt.keytime = kf.keytime;
                        nkt.value = kf.value;
                        nodeAnim.rotation[k] = nkt;
                    }
                }

                if (nanim.scaling.length > 0)
                {
                    nodeAnim.scaling.length = nanim.scaling.length;
                    foreach (k, kf; nanim.scaling)
                    {
                        if (kf.keytime > animation.duration)
                            animation.duration = kf.keytime;
                        // todo: some might not have value, so we might was take node translation instead
                        auto nkt = NodeKeyframe!Vec3();
                        nkt.keytime = kf.keytime;
                        nkt.value = kf.value;
                        nodeAnim.scaling[k] = nkt;
                    }
                }
                
                animation.nodeAnimations ~= nodeAnim;
            }
            if (animation.nodeAnimations.length > 0)
                animations ~= animation;
        }
    }

    void calculateTransforms()
    {
        int n = cast(int) nodes.length;
        for (int i = 0; i < n; i++)
        {
            nodes[i].calculateTransforms(true);
        }
        for (int i = 0; i < n; i++)
        {
            nodes[i].calculateBoneTransforms(true);
        }
    }
}

