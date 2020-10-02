module dark.gfx.shader;

import std.conv : text;
import std.format;
import std.stdio;
import core.math;

import bindbc.opengl;

import dark.gfx.camera;
import dark.gfx.rendering;
import dark.gfx.material;
import dark.gfx.mesh;
import dark.gfx.buffers;
import dark.gfx.renderable;
import dark.gfx.shader_program;
import dark.math;

interface IShader
{
    void init();
    int compareTo(IShader other);
    bool canRender(Renderable renderable);
    void begin(Camera camera, RenderContext context);
    void render(Renderable renderable);
    void end();
}


interface IValidator
{
    bool validate(BaseShader shader, int inputId, Renderable renderable);
}

interface ISetter
{
    bool isGlobal(BaseShader shader, int inputId);

    void set(BaseShader shader, int inputId, Renderable renderable, Attributes combinedAttributes);
}

abstract class GlobalSetter : ISetter
{
    bool isGlobal(BaseShader shader, int inputId)
    {
        return true;
    }
}

abstract class LocalSetter : ISetter
{
    bool isGlobal(BaseShader shader, int inputId)
    {
        return false;
    }
}

class Uniform : IValidator
{
    string aliass;
    ulong materialMask;
    ulong environmentMask;
    ulong overallMask;

    this(string aliass, ulong materialMask = 0, ulong environmentMask = 0,
            ulong overallMask = 0)
    {
        this.aliass = aliass;
        this.materialMask = materialMask;
        this.environmentMask = environmentMask;
        this.overallMask = overallMask;
    }

    bool validate(BaseShader shader, int inputId, Renderable renderable)
    {
        bool hasMaterial = (renderable !is null && renderable.material !is null);
        bool hasEnvironment = (renderable !is null && renderable.environment !is null);
        ulong matFlags = hasMaterial ? renderable.material.getMask() : 0UL;
        ulong envFlags = hasEnvironment ? renderable.environment.getMask() : 0UL;
        return ((matFlags & materialMask) == materialMask) && ((envFlags & environmentMask) == environmentMask)
            && (((matFlags | envFlags) & overallMask) == overallMask);
    }
}

abstract class BaseShader : IShader
{
    ShaderProgram program;
    RenderContext context;
    Camera camera;
    private Mesh currentMesh;

    string[] uniforms;
    IValidator[] validators;
    ISetter[] setters;
    int[] locations;
    int[] globalUniforms;
    int[] localUniforms;
    int[int] attributes;

    abstract void init();
    abstract int compareTo(IShader other);
    abstract bool canRender(Renderable renderable);

    void begin(Camera camera, RenderContext context)
    {
        this.camera = camera;
        this.context = context;
        program.begin();
        currentMesh = null;
        bindGlobal(camera, context);
    }

    void render(Renderable renderable)
    {
        
        if (currentMesh != renderable.meshPart.mesh)
        {
            if (currentMesh !is null) currentMesh.unbind(program, null);
            currentMesh = renderable.meshPart.mesh;
            currentMesh.bind(program, null);
        }

        bind(renderable);

        renderable.meshPart.render(program, false);
    }

    void end()
    {
        if (currentMesh !is null)
        {
            currentMesh.unbind(program, null);
            currentMesh = null;
        }

        program.end();
    }
    
    abstract void bindGlobal(Camera camera, RenderContext context);
    abstract void bind(Renderable renderable);
}

class DefaultShader : BaseShader
{
    struct Config
    {
        string vertexShader;
        string fragmentShader;
        int numDirectionalLights = 2;
        int numPointLights = 5;
        int numSpotLights = 0;
        int numBones = 20;
        bool ignoreUnimplemented = true;
        int defaultCullFace = -1;
        int defaultDepthFunc = -1;

        this(string vs, string fs)
        {
            vertexShader = vs;
            fragmentShader = fs;
        }
    }

    // Global uniforms
    int u_projTrans;
    int u_viewTrans;
    int u_projViewTrans;
    int u_cameraPosition;
    int u_cameraDirection;
    int u_cameraUp;
    int u_cameraNearFar;
    int u_time;
    // Object uniforms
    int u_worldTrans;
    int u_viewWorldTrans;
    int u_projViewWorldTrans;
    int u_normalMatrix;
    int u_bones;
    // Material uniforms
    int u_shininess;
    int u_opacity;
    int u_diffuseColor;
    int u_diffuseTexture;
    int u_diffuseUVTransform;
    int u_specularColor;
    int u_specularTexture;
    int u_specularUVTransform;
    int u_emissiveColor;
    int u_emissiveTexture;
    int u_emissiveUVTransform;
    int u_reflectionColor;
    int u_reflectionTexture;
    int u_reflectionUVTransform;
    int u_normalTexture;
    int u_normalUVTransform;
    int u_ambientTexture;
    int u_ambientUVTransform;
    int u_alphaTest;
        
    // Light uniforms
    int u_ambientCubemap;
    int u_environmentCubemap;
    int u_dirLights0color;
    int u_dirLights0direction;
    int u_dirLights1color;
    int u_pointLights0color;
    int u_pointLights0position;
    int u_pointLights0intensity;
    int u_pointLights1color;
    int u_spotLights0color;
    int u_spotLights0position;
    int u_spotLights0intensity;
    int u_spotLights0direction;
    int u_spotLights0cutoffAngle;
    int u_spotLights0exponent;
    int u_spotLights1color;
    int u_fogColor;
    int u_shadowMapProjViewTrans;
    int u_shadowTexture;
    int u_shadowPCFOffset;

    private Renderable renderable;
    protected immutable ulong attributesMask;
    private immutable ulong vertexMask;
    protected immutable Config config;

    private bool _lighting;

    private immutable static ulong optionalAttributes;

    /** @deprecated Replaced by {@link Config#defaultCullFace} Set to 0 to disable culling */
    static int defaultCullFace = GL_BACK;
    /** @deprecated Replaced by {@link Config#defaultDepthFunc} Set to 0 to disable depth test */
    static int defaultDepthFunc = GL_LEQUAL;

    shared static this()
    {
        optionalAttributes = IntAttribute.cullFace | DepthTestAttribute.type;
    }

    this(Renderable renderable, Config config, ShaderProgram program)
    {
        this.config = config;
        this.program = program;
        this.renderable = renderable;

        attributesMask = renderable.material.getMask() | optionalAttributes;
        vertexMask = renderable.meshPart.mesh.getVertexAttributes().getMaskWithSizePacked();
    }

    override void init()
    {
            u_projTrans = program.fetchUniformLocation("u_proj", false);
            u_viewTrans = program.fetchUniformLocation("u_viewTrans", false);
            u_projViewTrans = program.fetchUniformLocation("u_projViewTrans", false);
            u_cameraPosition = program.fetchUniformLocation("u_cameraPosition", false);
            u_cameraDirection = program.fetchUniformLocation("u_cameraDirection", false);
            u_cameraUp = program.fetchUniformLocation("u_cameraUp", false);
            u_cameraNearFar = program.fetchUniformLocation("u_cameraNearFar", false);
            
            u_time = program.fetchUniformLocation("u_time", false);


            u_worldTrans = program.fetchUniformLocation("u_worldTrans", false);
            u_viewWorldTrans = program.fetchUniformLocation("u_viewWorldTrans", false);
            u_projViewWorldTrans = program.fetchUniformLocation("u_projViewWorldTrans", false);
            u_normalMatrix = program.fetchUniformLocation("u_normalMatrix", false);
            u_bones = program.fetchUniformLocation("u_bones", false);

            u_shininess = program.fetchUniformLocation("u_shininess", false);
            u_opacity = program.fetchUniformLocation("u_opacity", false);
            u_diffuseColor = program.fetchUniformLocation("u_diffuseColor", false);
            u_diffuseTexture = program.fetchUniformLocation("u_diffuseTexture", false);
            u_diffuseUVTransform = program.fetchUniformLocation("u_diffuseUVTransform", false);
            u_specularColor = program.fetchUniformLocation("u_specularColor", false);
            u_specularTexture = program.fetchUniformLocation("u_specularTexture", false);
            u_specularUVTransform = program.fetchUniformLocation("u_specularUVTransform", false);
            u_emissiveColor = program.fetchUniformLocation("u_emissiveColor", false);
            u_emissiveTexture = program.fetchUniformLocation("u_emissiveTexture", false);
            u_emissiveUVTransform = program.fetchUniformLocation("u_emissiveUVTransform", false);
            u_reflectionColor = program.fetchUniformLocation("u_reflectionColor", false);
            u_reflectionTexture = program.fetchUniformLocation("u_reflectionTexture", false);
            u_reflectionUVTransform = program.fetchUniformLocation("u_reflectionUVTransform", false);
            u_normalTexture = program.fetchUniformLocation("u_normalTexture", false);
            u_normalUVTransform = program.fetchUniformLocation("u_normalUVTransform", false);
            u_ambientTexture = program.fetchUniformLocation("u_ambientTexture", false);
            u_ambientUVTransform = program.fetchUniformLocation("u_ambientUVTransform", false);
            u_alphaTest = program.fetchUniformLocation("u_alphaTest", false);

            
            u_ambientCubemap = program.fetchUniformLocation("u_ambientCubemap", false);
            u_environmentCubemap = program.fetchUniformLocation("u_environmentCubemap", false);
            
            u_dirLights0color = program.fetchUniformLocation("u_dirLights[0].color", false);
            u_dirLights0direction = program.fetchUniformLocation("u_dirLights[0].direction", false);
            u_dirLights1color = program.fetchUniformLocation("u_dirLights[1].color", false);
            u_pointLights0color = program.fetchUniformLocation("u_pointLights[0].color", false);
            u_pointLights0position = program.fetchUniformLocation("u_pointLights[0].position", false);
            u_pointLights0intensity = program.fetchUniformLocation("u_pointLights[0].intensity", false);
            u_pointLights1color = program.fetchUniformLocation("u_pointLights[1].color", false);
            u_spotLights0color = program.fetchUniformLocation("u_spotLights[0].color", false);
            u_spotLights0position = program.fetchUniformLocation("u_spotLights[0].position", false);
            u_spotLights0intensity = program.fetchUniformLocation("u_spotLights[0].intensity", false);
            u_spotLights0direction = program.fetchUniformLocation("u_spotLights[0].direction", false);
            u_spotLights0cutoffAngle = program.fetchUniformLocation("u_spotLights[0].cutoffAngle", false);
            u_spotLights0exponent = program.fetchUniformLocation("u_spotLights[0].exponent", false);
            u_spotLights1color = program.fetchUniformLocation("u_spotLights[1].color", false);
            
            u_fogColor = program.fetchUniformLocation("u_fogColor", false);
            u_shadowMapProjViewTrans = program.fetchUniformLocation("u_shadowMapProjViewTrans", false);
            u_shadowTexture = program.fetchUniformLocation("u_shadowTexture", false);
            u_shadowPCFOffset = program.fetchUniformLocation("u_shadowPCFOffset", false);
    }
    
    override int compareTo(IShader other)
    {
        if (other is null) return -1;
        if (other == this) return 0;
        return 0; // FIXME compare shaders on their impact on performance
    }

    override bool canRender(Renderable renderable)
    {
        auto mask = combineAttributeMasks(renderable);
        return (attributesMask == (mask | optionalAttributes))
               && (vertexMask == renderable.meshPart.mesh.getVertexAttributes().getMaskWithSizePacked()) 
               && (renderable.environment !is null) == _lighting;
    }

    override void bindGlobal(Camera camera, RenderContext context)
    {
        //for (int i = 0; i < _dirLights.Length; i++)
        //{
        //    _dirLights[i].set(Color.BLACK, new Vector3(0,-1,0));
        //}
        //for (int i = 0; i < _pointLights.Length; i++)
        //{
        //    _pointLights[i].set(Color.BLACK, Vector3.Zero, 0f);
        //}
        //for (int i = 0; i < _spotLights.Length; i++)
        //{
        //    _spotLights[i].set(Color.BLACK, Vector3.Zero, new Vector3(0, -1, 0), 0f, 1f, 0f);
        //}
        
        
        // todo: impl _time
        
        program.setUniformMat4(u_projViewTrans, camera.combined);
        
        //if(_lighting) 
        //    program.setUniform3fv(u_ambientCubemap, AmbientCubemap.white, 0, AmbientCubemap.white.Length);
    }

    override void bind(Renderable renderable)
    {
        
        program.setUniformMat4(u_worldTrans, renderable.worldTransform);
        
        if(config.numBones > 0 && renderable.bones !is null && renderable.bones.length > 0)
            program.setUniformMat4Array("u_bones", config.numBones, *renderable.bones);
        
        //if (!renderable.material.has(BlendingAttribute.Type))
        //    context.setBlending(false, BlendingFactorSrc.SrcAlpha, BlendingFactorDest.OneMinusSrcAlpha);


        bindMaterial(renderable.material);
        //if (_lighting)
        //    bindLights(renderable, renderable.environment);
    }

    private void bindMaterial(Attributes attributes)
    {
        int cullFace = config.defaultCullFace == -1 ? defaultCullFace : config.defaultCullFace;
        int depthFunc = config.defaultDepthFunc == -1 ? defaultDepthFunc : config.defaultDepthFunc;
        float depthRangeNear = 0f;
        float depthRangeFar = 1f;
        bool depthMask = true;
        
        if (attributes.has(TextureAttribute.diffuse))
        {
            auto ta = attributes.get!TextureAttribute(TextureAttribute.diffuse);
            auto unit = context.textureBinder.bind(ta.descriptor);
            program.setUniformi(u_diffuseTexture, unit);
            program.setUniformf(u_diffuseUVTransform, ta.offsetU, ta.offsetV, ta.scaleU, ta.scaleV);
        }
        context.setCullFace(cullFace);
        context.setDepthTest(depthFunc, depthRangeNear, depthRangeFar);
        context.setDepthMask(depthMask);
    }

    private static ulong combineAttributeMasks(Renderable renderable)
    {
        ulong mask = 0;
        if (renderable.environment !is null)
            mask |= renderable.environment.getMask();
        if (renderable.material !is null)
            mask |= renderable.material.getMask();
        return mask;
    }

    static string createPrefix(Renderable renderable, Config config)
    {
        import std.array;

        Attributes attributes = renderable.material;
        ulong attributesMask = attributes.getMask();
        ulong vertexMask = renderable.meshPart.mesh.getVertexAttributes().getMask();

        auto strBuilder = appender!string;

        if (and(vertexMask, Usage.Position))
            strBuilder.put("#define positionFlag\n");
        if (or(vertexMask, Usage.ColorUnpacked | Usage.ColorPacked))
            strBuilder.put("#define colorFlag\n");
        if (and(vertexMask, Usage.BiNormal))
            strBuilder.put("#define binormalFlag\n");
        if (and(vertexMask, Usage.Tangent))
            strBuilder.put("#define tangentFlag\n");
        if (and(vertexMask, Usage.Normal))
            strBuilder.put("#define normalFlag\n");

        // env

        int n = renderable.meshPart.mesh.getVertexAttributes().size();
        for (int i = 0; i < n; i++)
        {
            VertexAttribute attr = renderable.meshPart.mesh.getVertexAttributes().get(i);
            if (attr.usage == Usage.BoneWeight)
                strBuilder.put(format("#define boneWeight%sFlag\n", attr.unit));
            else if (attr.usage == Usage.TextureCoordinates)
                strBuilder.put(format("#define texCoord%sFlag\n", attr.unit));
        }
        //if ((attributesMask & BlendingAttribute.Type) == BlendingAttribute.Type)
        //	strBuilder.put("#define " ~ BlendingAttribute.Alias ~ "Flag\n");
        if ((attributesMask & TextureAttribute.diffuse) == TextureAttribute.diffuse)
        {
            strBuilder.put("#define " ~ TextureAttribute.diffuseAlias ~ "Flag\n");
            strBuilder.put("#define " ~ TextureAttribute.diffuseAlias ~ "Coord texCoord0\n"); // FIXME implement UV mapping
        }
        //if ((attributesMask & TextureAttribute.Specular) == TextureAttribute.Specular) {
        //	strBuilder.put("#define " ~ TextureAttribute.SpecularAlias ~ "Flag\n");
        //	strBuilder.put("#define " ~ TextureAttribute.SpecularAlias ~ "Coord texCoord0\n"); // FIXME implement UV mapping
        //}
        //if ((attributesMask & TextureAttribute.Normal) == TextureAttribute.Normal) {
        //	strBuilder.put("#define " ~ TextureAttribute.NormalAlias ~ "Flag\n");
        //	strBuilder.put("#define " ~ TextureAttribute.NormalAlias ~ "Coord texCoord0\n"); // FIXME implement UV mapping
        //}
        //if ((attributesMask & TextureAttribute.Emissive) == TextureAttribute.Emissive) {
        //	strBuilder.put("#define " ~ TextureAttribute.EmissiveAlias ~ "Flag\n");
        //	strBuilder.put("#define " ~ TextureAttribute.EmissiveAlias ~ "Coord texCoord0\n"); // FIXME implement UV mapping
        //}
        //if ((attributesMask & TextureAttribute.Reflection) == TextureAttribute.Reflection) {
        //	strBuilder.put("#define " ~ TextureAttribute.ReflectionAlias ~ "Flag\n");
        //	strBuilder.put("#define " ~ TextureAttribute.ReflectionAlias ~ "Coord texCoord0\n"); // FIXME implement UV mapping
        //}
        //if ((attributesMask & TextureAttribute.Ambient) == TextureAttribute.Ambient) {
        //	strBuilder.put("#define " ~ TextureAttribute.AmbientAlias ~ "Flag\n");
        //	strBuilder.put("#define " ~ TextureAttribute.AmbientAlias ~ "Coord texCoord0\n"); // FIXME implement UV mapping
        //}
        //if ((attributesMask & ColorAttribute.Diffuse) == ColorAttribute.Diffuse)
        //	strBuilder.put("#define " ~ ColorAttribute.DiffuseAlias ~ "Flag\n");
        //if ((attributesMask & ColorAttribute.Specular) == ColorAttribute.Specular)
        //	strBuilder.put("#define " ~ ColorAttribute.SpecularAlias ~ "Flag\n");
        //if ((attributesMask & ColorAttribute.Emissive) == ColorAttribute.Emissive)
        //	strBuilder.put("#define " ~ ColorAttribute.EmissiveAlias ~ "Flag\n");
        //if ((attributesMask & ColorAttribute.Reflection) == ColorAttribute.Reflection)
        //	strBuilder.put("#define " ~ ColorAttribute.ReflectionAlias ~ "Flag\n");
        //if ((attributesMask & FloatAttribute.Shininess) == FloatAttribute.Shininess)
        //	strBuilder.put("#define " ~ FloatAttribute.ShininessAlias ~ "Flag\n");
        //if ((attributesMask & FloatAttribute.AlphaTest) == FloatAttribute.AlphaTest)
        //	strBuilder.put("#define " ~ FloatAttribute.AlphaTestAlias ~ "Flag\n");


        if (renderable.bones.length > 0 && config.numBones > 0) strBuilder.put(format("#define numBones %s\n", config.numBones));

        return strBuilder.data;
    }

    private static bool and(ulong mask, ulong flag)
    {
        return (mask & flag) == flag;
    }

    private static bool or(ulong mask, ulong flag)
    {
        return (mask & flag) != 0;
    }
}
