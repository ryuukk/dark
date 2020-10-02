module dark.gfx.rendering;

import std.stdio;
import std.container;
import bindbc.opengl;

import dark.pool;
import dark.math;
import dark.gfx.texture;
import dark.gfx.renderable;
import dark.gfx.camera;
import dark.gfx.shader;
import dark.gfx.shader_provider;
import dark.gfx.model_instance;

class RenderContext
{
    TextureBinder textureBinder;

    private bool blending;
    private int blendSFactor;
    private int blendDFactor;
    private int depthFunc;
    private float depthRangeNear;
    private float depthRangeFar;
    private bool depthMask;
    private int cullFace;

    this(TextureBinder binder)
    {
        this.textureBinder = binder;
    }

    void begin()
    {
        glDisable(GL_DEPTH_TEST);
        depthFunc = 0;
        glDepthMask(true);
        depthMask = true;
        glDisable(GL_BLEND);
        blending = false;
        glDisable(GL_CULL_FACE);
        cullFace = blendSFactor = blendDFactor = 0;
        textureBinder.begin();
    }

    void end()
    {
        if (depthFunc != 0)
            glDisable(GL_DEPTH_TEST);
        if (!depthMask)
            glDepthMask(true);
        if (blending)
            glDisable(GL_BLEND);
        if (cullFace > 0)
            glDisable(GL_CULL_FACE);
        textureBinder.end();
    }

    void setDepthMask(bool value)
    {
        if (depthMask != value)
        {
            depthMask = value;
            glDepthMask(depthMask);
        }
    }

    void setDepthTest(int depthFunction, float depthRangeNear = 0f, float depthRangeFar = 1f)
    {
        bool wasEnabled = depthFunc != 0;
        bool enabled = depthFunction != 0;
        if (depthFunc != depthFunction)
        {
            depthFunc = depthFunction;
            if (enabled)
            {
                glEnable(GL_DEPTH_TEST);
                glDepthFunc(depthFunction);
            }
            else
                glDisable(GL_DEPTH_TEST);
        }
        if (enabled)
        {
            if (!wasEnabled || depthFunc != depthFunction)
                glDepthFunc(depthFunc = depthFunction);
            if (!wasEnabled || this.depthRangeNear != depthRangeNear
                    || this.depthRangeFar != depthRangeFar)
            {
                this.depthRangeNear = depthRangeNear;
                this.depthRangeFar = depthRangeFar;
                glDepthRange(this.depthRangeNear, this.depthRangeFar);
            }
        }
    }

    void setBlending(bool enabled, int sFactor, int dFactor)
    {
        if (enabled != blending)
        {
            blending = enabled;
            if (enabled)
                glEnable(GL_BLEND);
            else
                glDisable(GL_BLEND);
        }
        if (enabled && (blendSFactor != sFactor || blendDFactor != dFactor))
        {
            glBlendFunc(sFactor, dFactor);
            blendSFactor = sFactor;
            blendDFactor = dFactor;
        }
    }

    void setCullFace(int face)
    {
        if (face != cullFace)
        {
            cullFace = face;
            if ((face == GL_FRONT) || (face == GL_BACK) || (face == GL_FRONT_AND_BACK))
            {
                glEnable(GL_CULL_FACE);
                glCullFace(face);
            }
            else
                glDisable(GL_CULL_FACE);
        }
    }
}

class RenderableBatch
{
    abstract class FlushablePool(T) : Pool!T
    {
        Array!T obtained;

        this(int initialSize = 16, int maxCapacity = 1024)
        {
            super(initialSize, maxCapacity);
            obtained = new Array!T();
            obtained.reserve(initialSize);
        }

        protected override T obtain()
        {
            T result = super.obtain();
            obtain.insert();
            return result;
        }
        protected override void flush()
        {
            super.flushAll(obtained);
            obtained.clear();
        }

        protected override void free(T object)
        {
        }

    }
    class RenderablePool : Pool!Renderable
    {
        override Renderable newObject()
        {
            return new Renderable;
        }

        override Renderable obtain()
        {
            Renderable renderable = super.obtain();
            renderable.environment = null;
            renderable.material = null;
            renderable.meshPart.set("", null, 0, 0, 0);
            renderable.shader = null;
            renderable.worldTransform = Mat4.identity;
            renderable.bones = null;
            return renderable;
        }
    }

    Camera camera;
    Array!Renderable renderables;
    RenderContext context;
    bool ownContext;
    IShaderProvider shaderProvider;
    RenderablePool renderablesPool;

    this(IShaderProvider shaderProvider)
    {
        renderables.reserve(16);
        renderablesPool = new RenderablePool;
        ownContext = true;
        context = new RenderContext(new TextureBinder());
        this.shaderProvider = shaderProvider;
    }

    void begin(Camera camera)
    {
        this.camera = camera;
        if (ownContext)
            context.begin();
    }

    void end()
    {
        flush();
        if (ownContext)
            context.end();
        camera = null;
    }

    void flush()
    {
        // sort
        IShader currentShader = null;

        foreach(renderable; renderables)
        {
            if (currentShader !is renderable.shader)
            {
                if (currentShader !is null)
                    currentShader.end();

                currentShader = renderable.shader;
                currentShader.begin(camera, context);
            }
            currentShader.render(renderable);
        }
        if (currentShader !is null)
            currentShader.end();

        foreach(renderable; renderables)
        {
            renderablesPool.free(renderable);
        }
        renderables.clear();

    }

    void render(Renderable renderable)
    {
        renderable.shader = shaderProvider.getShader(renderable);
        renderable.meshPart.mesh.autoBind = false;
        renderables.insert(renderable);
    }

   void render(IRenderableProvider renderableProvider)
   {
       int offset = cast(int) renderables.length;
       renderableProvider.getRenderables(renderables, renderablesPool);
       for (int i = offset; i < renderables.length; i++)
       {
           Renderable renderable = renderables[i];
           renderable.shader = shaderProvider.getShader(renderable);
       }
   }
}
