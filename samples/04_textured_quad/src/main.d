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

class MyGame : IApp
{
    string vs = "
#version 330

in vec4 a_position;
in vec2 a_texCoord0;

out vec2 v_texCoords;

void main() {
    v_texCoords = a_texCoord0;
    gl_Position = a_position;
}
";
    string fs = "
#version 330

in vec2 v_texCoords;

uniform sampler2D u_texture;

out vec4 f_color;

void main() {
        vec3 color = texture2D(u_texture, v_texCoords).rgb;
        f_color = vec4(color, 1.0);
}
";
    ShaderProgram _shader;
    Mesh _mesh;
    Texture2D _tex;

    void create()
    {
        _tex = Texture2D.fromFile("data/bg_stars.png");

        _mesh = new Mesh(true, 6, 0, 
        new VertexAttribute(Usage.Position, 3, "a_position"), 
        new VertexAttribute(Usage.TextureCoordinates, 2, "a_texCoord0"));

        _mesh.setVertices([
                -1.0f, 1.0f, 0.0f,     0.0f, 0.0f,    
                1.0f, 1.0f, 0.0f,      1.0f, 0.0f,    
                1.0f, -1.0f, 0.0f,     1.0f, 1.0f,    

                -1.0f, 1.0f, 0.0f,     0.0f, 0.0f,    
                1.0f, -1.0f, 0.0f,      1.0f, 1.0f,   
                -1.0f,  -1.0f, 0.0f,     0.0f, 1.0f,  

            ]);

        //_mesh.setIndices([ 
        //    0, 1, 2,   // first triangle
        //    3,4,5
        //    ]);

        _shader = new ShaderProgram(vs, fs);

        assert(_shader.isCompiled(), _shader.getLog());
    }

    void update(float dt)
    {
    }

    void render(float dt)
    {
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glClearColor(0.2f, 0.3f, 0.3f, 1.0f);

        _shader.begin();

        _tex.bind();
        _shader.setUniformi("u_texture", 0);

        _mesh.render(_shader, GL_TRIANGLES);

        _shader.end();
    }

    void resize(int width, int height)
    {
    }

    void dispose()
    {
    }
}

int main()
{
    auto config = new Configuration;
    config.windowTitle = "Sample 04 - Textured Quad";
    auto game = new MyGame;
    auto engine = new Engine(game, config);
    engine.run();
    return 0;
}
