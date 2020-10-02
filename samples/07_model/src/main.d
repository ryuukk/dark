import std.stdio;
import std.conv;
import std.string;
import core.memory;

import bindbc.opengl;
import bindbc.glfw;

import dark.core;
import dark.engine;
import dark.input;
import dark.math;
import dark.gfx.shader_program;
import dark.gfx.buffers;
import dark.gfx.mesh;
import dark.gfx.texture;
import dark.gfx.batch;
import dark.gfx.camera;
import dark.gfx.model;
import dark.gfx.model_loader;
import dark.gfx.material;

string vs = "
#version 330

in vec3 a_position;
in vec3 a_normal;
in vec4 a_color;
in vec2 a_texCoord0;

uniform mat4 u_proj;
uniform mat4 u_view;
uniform mat4 u_world;

out vec4 v_color;
out vec2 v_texCoord;

void main()
{
    gl_Position = u_proj * u_view * u_world * vec4(a_position, 1.0);

    v_color = a_color;
    v_texCoord = a_texCoord0;
}
";
string fs = "
#version 330

in vec4 v_color;
in vec2 v_texCoord;

uniform sampler2D u_texture;

out vec4 f_color;

void main()
{
    vec3 color = texture2D(u_texture, v_texCoord).rgb;
    f_color = vec4(color, 1.0) * v_color;
}
";

class MyGame : IApp
{
    PerspectiveCamera _cam;
    ShaderProgram _shader;
    Model _model;


    Mat4 _transform = Mat4.identity;
    float _a = 0f;

    void create()
    {
        _cam = new PerspectiveCamera(67, Core.graphics.getWidth(), Core.graphics.getHeight());
        _cam.near = 1f;
        _cam.far = 100f;
        _cam.position = Vec3(0, 10, 5)*0.5f;
        _cam.lookAt(0, 0, 0);
        _cam.update();

        _shader = new ShaderProgram(vs, fs);
		
        assert(_shader.isCompiled(), _shader.getLog());


        auto data = loadModelData("data/knight.g3dj");
        assert(data !is null, "can't parse data");

        _model = new Model;
        _model.load(data);

        GC.collect();
    }


    void update(float dt)
    {
        _a += dt * 2;

        _transform.set(Vec3(), Quat.fromAxis(0,1,0, _a));
    }

    void render(float dt)
    {
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glClearColor(0.2f, 0.3f, 0.3f, 1.0f);

        glEnable(GL_DEPTH_TEST);

        _cam.update();

        _shader.begin();
        _shader.setUniformMat4("u_proj", _cam.projection);
        _shader.setUniformMat4("u_view", _cam.view);
        _shader.setUniformMat4("u_world", _transform);
        
        foreach(Mesh mesh; _model.meshes)
        {
            if(_model.materials[0].has(TextureAttribute.diffuse))
            {
                auto ta = _model.materials[0].get!TextureAttribute(TextureAttribute.diffuse);
                ta.descriptor.texture.bind();
                _shader.setUniformi("u_texture", 0);
            }
            mesh.render(_shader, GL_TRIANGLES);
        }
        _shader.end();
    }

    void resize(int width, int height)
    {
        _cam.viewportWidth = width;
        _cam.viewportHeight = height;
    }

    void dispose()
    {
    }
}

int main()
{
    auto config = Config();
    config.windowTitle = "Sample 07 - Model";
    auto game = new MyGame;
    auto engine = new Engine(game, config);
    engine.run();

    return 0;
}
