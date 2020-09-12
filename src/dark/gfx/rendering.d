module darc.gfx.rendering;

import std.stdio;
import std.container;
import bindbc.opengl;

import darc.pool;
import darc.math;
import darc.gfx.texture;
import darc.gfx.renderable;
import darc.gfx.camera;
import darc.gfx.shader;
import darc.gfx.shader_provider;
import darc.gfx.model_instance;

public class RenderContext
{
    public TextureBinder textureBinder;

    private bool blending;
    private int blendSFactor;
    private int blendDFactor;
    private int depthFunc;
    private float depthRangeNear;
    private float depthRangeFar;
    private bool depthMask;
    private int cullFace;

    public this(TextureBinder binder)
    {
        this.textureBinder = binder;
    }

    public void begin()
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

    public void end()
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

    public void setDepthMask(bool value)
    {
        if (depthMask != value)
        {
            depthMask = value;
            glDepthMask(depthMask);
        }
    }

    public void setDepthTest(int depthFunction, float depthRangeNear = 0f, float depthRangeFar = 1f)
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

    public void setBlending(bool enabled, int sFactor, int dFactor)
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

    public void setCullFace(int face)
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

public class RenderableBatch
{
    public abstract class FlushablePool(T) : Pool!T
    {
        Array!T obtained;

        public this(int initialSize = 16, int maxCapacity = 1024)
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
    public class RenderablePool : Pool!Renderable
    {
        public override Renderable newObject()
        {
            return new Renderable;
        }

        public override Renderable obtain()
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

    public Camera camera;
    public Array!Renderable renderables;
    public RenderContext context;
    public bool ownContext;
    public IShaderProvider shaderProvider;
    public RenderablePool renderablesPool;

    public this(IShaderProvider shaderProvider)
    {
        renderables.reserve(16);
        renderablesPool = new RenderablePool;
        ownContext = true;
        context = new RenderContext(new TextureBinder());
        this.shaderProvider = shaderProvider;
    }

    public void begin(Camera camera)
    {
        this.camera = camera;
        if (ownContext)
            context.begin();
    }

    public void end()
    {
        flush();
        if (ownContext)
            context.end();
        camera = null;
    }

    public void flush()
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

    public void render(Renderable renderable)
    {
        renderable.shader = shaderProvider.getShader(renderable);
        renderable.meshPart.mesh.autoBind = false;
        renderables.insert(renderable);
    }

   public void render(IRenderableProvider renderableProvider)
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
