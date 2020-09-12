import std.stdio;
import core.memory;
import std.file : readText;

import bindbc.opengl;
import bindbc.glfw;

import darc.core;
import darc.engine;
import darc.math;
import darc.gfx.shader;
import darc.gfx.shader_provider;
import darc.gfx.shader_program;
import darc.gfx.camera;
import darc.gfx.node;
import darc.gfx.node_part;
import darc.gfx.material;
import darc.gfx.model;
import darc.gfx.model_instance;
import darc.gfx.model_loader;
import darc.gfx.rendering;
import darc.gfx.animation;
import darc.gfx.renderable;

public class MyGame : IApp
{
    PerspectiveCamera _cam;
    Model _model;
    ModelInstance _modelInstance;
    AnimationController _animController;

    float _a = 0.0f;
    Mat4 _transform = Mat4.identity;

    RenderableBatch _batch;
    ShaderProgram _program;

    public void create()
    {
        _cam = new PerspectiveCamera(67, Core.graphics.getWidth(), Core.graphics.getHeight());
        _cam.position = Vec3(0, 0, 1);
        _cam.update();

        {
            auto data = loadModelData("data/models/knight.g3dj");
            assert(data !is null, "can't parse data");

            _model = new Model;
            _model.load(data);

            _modelInstance = new ModelInstance(_model);
            _animController = new AnimationController(_modelInstance);
            auto desc = _animController.animate("Attack");
        }

        //_batch = new RenderableBatch(new DefaultShaderProvider("data/default.vert".readText, "data/default.frag".readText));
        _program = new ShaderProgram(vs, fs);

        GC.collect();
    }

    public void update(float dt)
    {
        _a += dt * 2;
        
        _animController.update(dt);
    }

    public void render(float dt)
    {
        _a += dt;

        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glClearColor(0.2f, 0.3f, 0.3f, 1.0f);

        _cam.update();

        glEnable(GL_DEPTH_TEST);

        _program.begin();
        _program.setUniformMat4("u_proj", _cam.projection);
        _program.setUniformMat4("u_view", _cam.view);



        auto q = Quat.fromAxis(0, 1, 0, _a);
        _transform.set(Vec3(0,0,0), q, Vec3(1,1,1));

        writeln(q.x, ":", q.y,":",q.z,":",q.w);
        

        foreach(Node node; _modelInstance.nodes)
        {
            renderNode(node);
        }
        _program.end();
    }

    void renderNode(Node node)
    {
         auto transform = _transform * node.globalTransform;
        _program.setUniformMat4("u_world", transform);
        foreach(NodePart part; node.parts)
        {
            _program.setUniformMat4Array("u_bones", cast(int) part.bones.length, part.bones);

            if(part.material.has(TextureAttribute.diffuse))
            {
                auto ta = part.material.get!TextureAttribute(TextureAttribute.diffuse);
                ta.descriptor.texture.bind();
                _program.setUniformi("u_texture", 0);
            }

            for(int i = 0; i < part.bones.length;i++)
            {
                auto t = part.bones[i];
                //writeln("T: ",i);
                //t.print();
            }

            part.meshPart.render(_program, true);
        }

        foreach(Node child; node.children)
            renderNode(child);
    }

    public void resize(int width, int height)
    {
        _cam.viewportWidth = width;
        _cam.viewportHeight = height;
    }

    public void dispose()
    {
    }
}

int main()
{
    auto config = new Configuration;
    config.windowTitle = "Sample 09 - Skeletal Animation";
    auto game = new MyGame;
    auto engine = new Engine(game, config);
    engine.run();

    return 0;
}


const string vs = 
"
#version 330

in vec3 a_position;
in vec3 a_normal;
in vec4 a_color;
in vec2 a_texCoord0;
in vec2 a_boneWeight0;
in vec2 a_boneWeight1;
in vec2 a_boneWeight2;
in vec2 a_boneWeight3;

uniform mat4 u_proj;
uniform mat4 u_view;
uniform mat4 u_world;

uniform mat4 u_bones[20];

out vec4 v_color;
out vec2 v_texCoord;

void main()
{

	mat4 skinning = mat4(0.0);
	skinning += (a_boneWeight0.y) * u_bones[int(a_boneWeight0.x)];
	skinning += (a_boneWeight1.y) * u_bones[int(a_boneWeight1.x)];
	skinning += (a_boneWeight2.y) * u_bones[int(a_boneWeight2.x)];
	skinning += (a_boneWeight3.y) * u_bones[int(a_boneWeight3.x)];


    vec4 pos = u_world * skinning * vec4(a_position, 1.0);
    gl_Position = u_proj * u_view * pos;

    v_color = a_color;
    v_texCoord = a_texCoord0;
}
";

const string fs = 
"
#version 330

in vec4 v_color;
in vec2 v_texCoord;

uniform sampler2D u_texture;

out vec4 f_color;

void main()
{
    vec3 color = texture2D(u_texture, v_texCoord).rgb;
    f_color = vec4(color, 1.0) * v_color;
    //f_color = v_color;
}
";