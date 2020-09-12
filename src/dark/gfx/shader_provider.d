module darc.gfx.shader_provider;

import darc.gfx.shader;
import darc.gfx.shader_program;
import darc.gfx.renderable;


public interface IShaderProvider
{
    IShader getShader(Renderable renderable);
}

public abstract class BaseShaderProvider : IShaderProvider
{
    private IShader[] shaders;

    public IShader getShader(Renderable renderable)
    {
        IShader suggestedShader = renderable.shader;
        if (suggestedShader !is null && suggestedShader.canRender(renderable))
            return suggestedShader;
        for (int i = 0; i < shaders.length; i++)
        {
            IShader shader = shaders[i];
            if (shader.canRender(renderable))
                return shader;
        }
        IShader shader = createShader(renderable);
        shader.init();
        shaders ~= shader;
        return shader;
    }

    protected abstract IShader createShader(Renderable renderable);
}

public class DefaultShaderProvider : BaseShaderProvider
{
    public DefaultShader.Config config;

    public this(string vertexShader, string fragmentShader)
    {
        config = DefaultShader.Config(vertexShader, fragmentShader);
    }

    public override IShader createShader(Renderable renderable)
    {
        string vs = "#version 330\n";
        string fs = "#version 330\n";

        string prefix = DefaultShader.createPrefix(renderable, config);

        vs ~= prefix;
        fs ~= prefix;

        vs ~= config.vertexShader;
        fs ~= config.fragmentShader;

        version(DEBUG_SHADER_REFIX)
        {
            writeln("Needed compile new shader..");
            writeln("---");

            writeln("PREFIX:");
            writeln(prefix);

            writeln("---");
        }

        ShaderProgram program = new ShaderProgram(vs, fs);
        assert(program.isCompiled(), program.getLog());


        return new DefaultShader(renderable, config, program);
    }
}