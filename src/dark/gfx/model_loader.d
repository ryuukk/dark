module darc.gfx.model_loader;

import std.json;
import std.stdio;
import std.container;
import std.typecons;
import std.path;
import std.file : readText;
import std.datetime.stopwatch;

import darc.pool;
import darc.math;
import darc.color;
import darc.core;
import darc.collections;
import darc.gfx.node;
import darc.gfx.material;
import darc.gfx.animation;
import darc.gfx.mesh;
import darc.gfx.buffers;
import darc.gfx.node;
import darc.gfx.renderable;


// data for serialization

ModelData loadModelData(string path)
{
    string json = path.readText;

    JSONValue root = parseJSON(json);

    ModelData data = new ModelData;

    int lo = cast(int) root["version"].array[0].integer;
    int hi = cast(int) root["version"].array[1].integer;
    data.id = ("id" in root) ? root["id"].str : path;

    StopWatch sw;
    sw.start();

    parseMeshes(data, root);
    parseNodes(data, root);
    parseMaterials(data, root, dirName(path));
    parseAnimations(data, root);

    writeln("DEBUG: Loaded model: ", path," in: ", sw.peek.total!"msecs", " msecs");

    return data;
}

void parseMeshes2(ModelData data, in JSONValue root)
{
    if("meshes" in root)
    {
        auto meshes = root["meshes"].array;
        foreach(mesh; meshes)
        {
            auto jsonMesh = new ModelMesh();
            jsonMesh.id = ("id" in mesh) ? mesh["id"].str : "";

            auto attributes = mesh["attributes"].array;
            jsonMesh.attributes = parseAttributes2(attributes);

            auto pv = mesh["vertices"].array;
            auto pvi = 0;
            jsonMesh.vertices = new float[pv.length];
            foreach(pva; pv)
            {
                jsonMesh.vertices[pvi] = pva.floating;
                pvi++;
            }

            auto meshParts = mesh["parts"].array;
            jsonMesh.parts = new ModelMeshPart[meshParts.length];
            for(int i = 0; i < meshParts.length; i++)
            {
                auto meshPart = meshParts[i];
                auto jsonPart = new ModelMeshPart();
                auto partId = meshPart["id"].str;

                foreach(other; jsonMesh.parts)
                {
                    if(other is null) continue;
                    if(other.id == partId) throw new Exception("fuck you");
                }
                jsonPart.id = partId;
                auto ptype = meshPart["type"].str;
                jsonPart.primitiveType = parseType(ptype);

                auto pi = meshPart["indices"].array;
                jsonPart.indices = new short[pi.length];
                auto pii = 0;
                foreach(pva; pi)
                {
                    jsonPart.indices[pii] = cast(short)pva.integer;
                    pii ++;
                }

                jsonMesh.parts[i] = jsonPart;
            }
            data.meshes ~= jsonMesh;
        }
    }
}

VertexAttribute[] parseAttributes2(in JSONValue[] attributes)
{
    int unit = 0;
    int blendWeightCount = 0;
    auto ret = new VertexAttribute[attributes.length];

    for(int i = 0; i < attributes.length; i++)
    {
        auto attr = attributes[i].str;
        if (attr == "POSITION")
        {
            ret[i] = VertexAttribute.position();
        }
        else if (attr == "NORMAL")
        {
            ret[i] = VertexAttribute.normal();
        }
        else if (attr == "COLOR")
        {
            ret[i] = VertexAttribute.colorUnpacked();
        }
        else if (attr == "COLORPACKED")
        {
            ret[i] = VertexAttribute.colorPacked();
        }
        else if (attr == "TANGENT")
        {
            ret[i] = VertexAttribute.tangent();
        }
        else if (attr == "BINORMAL")
        {
            ret[i] = VertexAttribute.binormal();
        }
        else if (attr[0] == 'T' && attr[1] == 'E' && attr[2] == 'X')
        {
            ret[i] = VertexAttribute.texCoords(unit++);
        }
        else if (attr[0] == 'B' && attr[1] == 'L' && attr[2] == 'E')
        {
            ret[i] = VertexAttribute.boneWeight(blendWeightCount++);
        }
        else
        {
            throw new Exception("Unsupported attribute: ", attr);
        }
    }
    return ret;
}

void parseNodes2(ModelData data, in JSONValue root)
{
    if("nodes" in root)
    {
        auto nodes = root["nodes"].array;
        foreach(node; nodes)
        {
            auto n = parseNodeRecursively2(node);
            data.nodes ~= n;
        }
    }
}

ModelNode parseNodeRecursively2(in JSONValue json)
{
    auto jsonNode = new ModelNode();
    jsonNode.id = json["id"].str;

    jsonNode.translation = getVec3OrDefault(json, "translation", Vec3(0, 0, 0));
    jsonNode.rotation = getQuatOrDefault(json, "rotation", Quat.identity);
    jsonNode.scale = getVec3OrDefault(json, "scale", Vec3(1, 1, 1));

    if("mesh" in json) jsonNode.meshId = json["mesh"].str;
    if("parts" in json)
    {
        auto materials = json["parts"].array;
        jsonNode.parts = new ModelNodePart[materials.length];
        for(int i = 0; i < materials.length; i++)
        {
            auto material = materials[i];
            auto nodePart = new ModelNodePart();

            nodePart.materialId = material["materialid"].str;
            nodePart.meshPartId = material["meshpartid"].str;

            if("bones" in material)
            {
                auto bones = material["bones"].array;
                nodePart.bones = new Bone[bones.length];

                for(int j = 0; j < bones.length; j++)
                {
                    auto bone = bones[j];
                    auto nodeId = bone["node"].str;

                    auto transform = Mat4.set(
                        getVec3OrDefault(bone, "translation"),
                        getQuatOrDefault(bone, "rotation"),
                        getVec3OrDefault(bone, "scale"),
                        );

                    nodePart.bones[j] = Bone(nodeId, transform);
                }
            }
            jsonNode.parts[i] = nodePart;
        }
    }
    if("children" in json)
    {
        auto children = json["children"].array;
        jsonNode.children = new ModelNode[children.length];
        for(int i = 0; i < children.length; i++)
        {
            auto child = children[i];
            jsonNode.children[i] = parseNodeRecursively2(child);
        }
    }

    return jsonNode;
}

private void parseAnimations(ModelData model, JSONValue json)
{
    if ("animations" in json)
    {
        JSONValue[] animations = json["animations"].array;
        model.animations.length = animations.length;
        foreach (i, JSONValue anim; animations)
        {
            JSONValue[] nodes = anim["bones"].array;

            ModelAnimation animation = new ModelAnimation;
            model.animations[i] = animation;
            animation.id = anim["id"].str;
            animation.nodeAnimations.length = nodes.length;

            foreach (j, JSONValue node; nodes)
            {
                ModelNodeAnimation nodeAnim = new ModelNodeAnimation;
                animation.nodeAnimations[j] = nodeAnim;
                nodeAnim.nodeId = node["boneId"].str;

                // v0.1
                JSONValue[] keyframes = node["keyframes"].array;
                foreach (k, JSONValue keyframe; keyframes)
                {
                    float keytime = keyframe["keytime"].floating / 1000f;

                    if( "translation" in keyframe )
                    {
                        auto kf = new ModelNodeKeyframe!Vec3;
                        kf.keytime = keytime;
                        kf.value = readVec3(keyframe["translation"]);
                        nodeAnim.translation ~= kf;
                    }

                    if( "rotation" in keyframe )
                    {
                        auto kf = new ModelNodeKeyframe!Quat;
                        kf.keytime = keytime;
                        kf.value = readQuat(keyframe["rotation"]);
                        nodeAnim.rotation ~= kf;
                    }

                    if( "scale" in keyframe )
                    {
                        auto kf = new ModelNodeKeyframe!Vec3;
                        kf.keytime = keytime;
                        kf.value = readVec3(keyframe["scale"]);
                        nodeAnim.scaling ~= kf;
                    }
                }
            }
        }
    }
}

private void parseMaterials(ModelData model, JSONValue json, string materialDir)
{

    JSONValue materials = json["materials"];
    model.materials.length = materials.array.length;

    Core.logger.infof("Model %s has %s materials !!", model.id, model.materials.length);
    foreach (i, material; materials.array)
    {
        ModelMaterial jsonMaterial = new ModelMaterial;
        jsonMaterial.id = material["id"].str;

        if ("textures" in material)
        {
            JSONValue textures = material["textures"];
            jsonMaterial.textures.length = textures.array.length;

            foreach (j, texture; textures.array)
            {
                ModelTexture jsonTexture = new ModelTexture;
                jsonTexture.id = texture["id"].str;
                jsonTexture.fileName = materialDir ~ "/" ~ texture["filename"].str;

                // todo: uv data
                jsonTexture.uvTranslation = Vec2(0, 0);
                jsonTexture.uvScaling = Vec2(1, 1);

                jsonTexture.usage = parseTextureUsage(texture["type"].str);

                jsonMaterial.textures[j] = jsonTexture;
            }
        }
        else
        {
            Core.logger.errorf("Model %s has no texture !!", model.id);
        }
        model.materials[i] = jsonMaterial;
    }
}

private int parseTextureUsage(string type)
{
    switch (type)
    {
    case "AMBIENT":
        return ModelTexture.USAGE_AMBIENT;
    case "BUMP":
        return ModelTexture.USAGE_BUMP;
    case "DIFFUSE":
        return ModelTexture.USAGE_DIFFUSE;
    case "EMISSIVE":
        return ModelTexture.USAGE_EMISSIVE;
    case "NONE":
        return ModelTexture.USAGE_NONE;
    case "NORMAL":
        return ModelTexture.USAGE_NORMAL;
    case "REFLECTION":
        return ModelTexture.USAGE_REFLECTION;
    case "SHININESS":
        return ModelTexture.USAGE_SHININESS;
    case "SPECULAR":
        return ModelTexture.USAGE_SPECULAR;
    case "TRANSPARENCY":
        return ModelTexture.USAGE_TRANSPARENCY;

    default:
        return ModelTexture.USAGE_UNKNOWN;
    }
}

private void parseNodes(ModelData model, JSONValue json)
{
    if ("nodes" in json)
    {
        JSONValue[] nodes = json["nodes"].array;

        model.nodes.length = nodes.length;
        foreach (i, JSONValue node; nodes)
        {
            model.nodes[i] = parseNodesRecursively(node);
        }
    }
}

private ModelNode parseNodesRecursively(JSONValue json)
{
    ModelNode jsonNode = new ModelNode;
    jsonNode.id = json["id"].str;

    if ("translation" in json)
        jsonNode.translation = readVec3(json["translation"]);
    else
        jsonNode.translation = Vec3(0,0,0);

    if ("scale" in json)
        jsonNode.scale = readVec3(json["scale"]);
    else
        jsonNode.scale = Vec3(1, 1, 1);

    if ("rotation" in json)
        jsonNode.rotation = readQuat(json["rotation"]);
    else
        jsonNode.rotation = Quat.identity;

    jsonNode.meshId = ("mesh" in json) ? json["mesh"].str : "";

    if ("parts" in json)
    {
        JSONValue[] materials = json["parts"].array;
        jsonNode.parts.length = materials.length;

        foreach (i, material; materials)
        {
            ModelNodePart nodePart = new ModelNodePart();
            nodePart.meshPartId = material["meshpartid"].str;
            nodePart.materialId = material["materialid"].str;

            if ("bones" in material)
            {
                JSONValue[] bones = material["bones"].array;
                nodePart.bones.length = bones.length;
                nodePart.bones.reserve(cast(int) bones.length);
                foreach (j, JSONValue bone; bones)
                {
                    string nodeId = bone["node"].str;

                    Vec3 translation = readVec3(bone["translation"]);
                    Quat rotation = readQuat(bone["rotation"]);
                    Vec3 scale = readVec3(bone["scale"]);

                    Mat4 transform = Mat4.set(translation, rotation, scale);

                    nodePart.bones[j] = Bone(nodeId, transform);
                }
            }

            jsonNode.parts[i] = nodePart;
        }
    }

    if ("children" in json)
    {
        JSONValue[] children = json["children"].array;
        jsonNode.children.length = children.length;
        jsonNode.children.reserve(cast(int)children.length);

        foreach (i, JSONValue child; children)
        {
            jsonNode.children[i] = parseNodesRecursively(child);
        }

    }

    return jsonNode;
}

Vec2 getVec2OrDefault(in JSONValue json, string key, Vec2 d = Vec2())
{
    if(key in json)
    {
        auto value = json[key].array;
        return Vec2(value[0].floating, value[1].floating);
    }
    else return d;
}
Vec3 getVec3OrDefault(in JSONValue json, string key, Vec3 d = Vec3())
{
    if(key in json)
    {
        auto value = json[key].array;
        return Vec3(value[0].floating, value[1].floating, value[2].floating);
    }
    else return d;
}
Quat getQuatOrDefault(in JSONValue json, string key, Quat d = Quat.identity)
{
    if(key in json)
    {
        auto value = json[key].array;
        return Quat(value[0].floating, value[1].floating, value[2].floating, value[3].floating);
    }
    else return d;
}

private Vec3 readVec3(in JSONValue value)
{
    return Vec3(value.array[0].floating, value.array[1].floating, value.array[2].floating);
}

private Vec2 readVec2(in JSONValue value)
{
    return Vec2(value.array[0].floating, value.array[1].floating);
}

private Quat readQuat(in JSONValue value)
{
    return Quat(value.array[0].floating, value.array[1].floating,
            value.array[2].floating, value.array[3].floating);
}

private void parseMeshes(ModelData model, JSONValue json)
{
    if ("meshes" in json)
    {
        JSONValue meshes = json["meshes"];
        model.meshes.length = meshes.array.length;
        foreach (i, mesh; meshes.array)
        {
            ModelMesh jsonMesh = new ModelMesh;

            jsonMesh.id = ("id" in mesh) ? mesh["id"].str : "";

            JSONValue attributes = mesh["attributes"];
            JSONValue vertices = mesh["vertices"];
            JSONValue parts = mesh["parts"];
            parseAttributes(jsonMesh, attributes);
            parseVertices(jsonMesh, vertices);
            parseMeshParts(jsonMesh, parts);

            model.meshes[i] = jsonMesh;
        }
    }
    else
    {

    }
}

private void parseMeshParts(ModelMesh modelMesh, JSONValue parts)
{
    auto array = parts.array;
    modelMesh.parts.length = array.length;

    for (int i = 0; i < array.length; i++)
    {
        JSONValue meshPart = array[i];
        ModelMeshPart jsonPart = new ModelMeshPart;
        jsonPart.id = meshPart["id"].str;
        string type = meshPart["type"].str;
        jsonPart.primitiveType = parseType(type);

        JSONValue indices = meshPart["indices"];
        parseIndices(jsonPart, indices);
        modelMesh.parts[i] = jsonPart;
    }
}

private int parseType(string type)
{
    import bindbc.opengl;

    switch (type)
    {
    case "TRIANGLES":
        return GL_TRIANGLES;
    case "LINES":
        return GL_LINES;
    case "POINTS":
        return GL_POINTS;
    case "TRIANGLE_STRIP":
        return GL_TRIANGLE_STRIP;
    case "LINE_STRIP":
        return GL_LINE_STRIP;

    default:
        throw new Exception("Not supported type");
    }
}

private void parseIndices(ModelMeshPart modelMesh, JSONValue indices)
{
    auto array = indices.array;
    modelMesh.indices.length = array.length;
    for (int i = 0; i < array.length; i++)
    {
        modelMesh.indices[i] = cast(short) array[i].integer;
    }
}

private void parseVertices(ModelMesh modelMesh, JSONValue vertices)
{
    auto array = vertices.array;
    modelMesh.vertices.length = array.length;
    for (int i = 0; i < array.length; i++)
    {
        modelMesh.vertices[i] = array[i].floating;
    }
}

private void parseAttributes(ModelMesh modelMesh, JSONValue attributes)
{
    import std.algorithm.searching : startsWith;

    int unit = 0;
    int blendWeightCount = 0;
    foreach (value; attributes.array)
    {
        string attribute = value.str;

        if (attribute.startsWith("TEXCOORD"))
            modelMesh.attributes ~= VertexAttribute.texCoords(unit++);
        else if (attribute.startsWith("BLENDWEIGHT"))
            modelMesh.attributes ~= VertexAttribute.boneWeight(blendWeightCount++);
        else if (attribute == "POSITION")
            modelMesh.attributes ~= VertexAttribute.position();
        else if (attribute == "NORMAL")
            modelMesh.attributes ~= VertexAttribute.normal();
        else if (attribute == "COLOR")
            modelMesh.attributes ~= VertexAttribute.colorUnpacked();
        else if (attribute == "COLORPACKED")
            modelMesh.attributes ~= VertexAttribute.colorPacked();
        else if (attribute == "TANGENT")
            modelMesh.attributes ~= VertexAttribute.tangent();
        else if (attribute == "BINORMAL")
            modelMesh.attributes ~= VertexAttribute.binormal();
        else
            Core.logger.errorf("Unsupported attribute: %s", attribute);
    }
}

public class ModelData
{
    public string id;
    public ModelMesh[] meshes;
    public ModelMaterial[] materials;
    public ModelNode[] nodes;
    public ModelAnimation[] animations;
}

public class ModelMesh
{
    public string id;
    public VertexAttribute[] attributes;
    public float[] vertices;
    public ModelMeshPart[] parts;
}

public class ModelMeshPart
{
    public string id;
    public short[] indices;
    public int primitiveType;
}

public class ModelMaterial
{
    public enum MaterialType
    {
        Lambert,
        Phong
    }

    public string id;

    public MaterialType type;

    public Color ambient;
    public Color diffuse;
    public Color specular;
    public Color emissive;
    public Color reflection;

    public float shininess;
    public float opacity = 1.0f;

    public ModelTexture[] textures;
}

public class ModelTexture
{
    public immutable static int USAGE_UNKNOWN = 0;
    public immutable static int USAGE_NONE = 1;
    public immutable static int USAGE_DIFFUSE = 2;
    public immutable static int USAGE_EMISSIVE = 3;
    public immutable static int USAGE_AMBIENT = 4;
    public immutable static int USAGE_SPECULAR = 5;
    public immutable static int USAGE_SHININESS = 6;
    public immutable static int USAGE_NORMAL = 7;
    public immutable static int USAGE_BUMP = 8;
    public immutable static int USAGE_TRANSPARENCY = 9;
    public immutable static int USAGE_REFLECTION = 10;

    public string id;
    public string fileName;
    public Vec2 uvTranslation;
    public Vec2 uvScaling;
    public int usage;
}

public class ModelNode
{
    public string id;
    public Vec3 translation = Vec3();
    public Quat rotation = Quat.identity;
    public Vec3 scale = Vec3(1, 1, 1);
    public string meshId;
    public ModelNodePart[] parts;
    public ModelNode[] children;
}

public struct Bone
{
    public string id;
    public Mat4 transform;

    public this(string id, Mat4 transform)
    {
        this.id = id;
        this.transform = transform;
    }
}

public class ModelNodePart
{
    public string materialId;
    public string meshPartId;
    public Bone[] bones;
    public int[][] uvMapping;
}

public class ModelAnimation
{
    public string id;
    public ModelNodeAnimation[] nodeAnimations;
}

public class ModelNodeAnimation
{
    public string nodeId;
    public ModelNodeKeyframe!Vec3[] translation;
    public ModelNodeKeyframe!Quat[] rotation;
    public ModelNodeKeyframe!Vec3[] scaling;
}

public class ModelNodeKeyframe(T)
{
    public float keytime;
    public T value;
}
