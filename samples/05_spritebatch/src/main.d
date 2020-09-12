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
import dark.gfx.shader;
import dark.gfx.buffers;
import dark.gfx.mesh;
import dark.gfx.texture;
import dark.gfx.batch;
import dark.gfx.camera;

class MyGame : IApp
{
    Texture2D _tex;
    OrthographicCamera _cam;
    SpriteBatch _batch;

    void create()
    {
        _tex = Texture2D.fromFile("data/bg_stars.png");

        _cam = new OrthographicCamera();
        _cam.setToOrtho(Core.graphics.getWidth(), Core.graphics.getHeight());
        _cam.update();

        _batch = new SpriteBatch();
    }

    void update(float dt)
    {
    }

    void render(float dt)
    {
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glClearColor(0.2f, 0.3f, 0.3f, 1.0f);

        //_cam.position.x += 10f * dt;
        _cam.update();

        _batch.setProjectionMatrix(_cam.combined);
        _batch.begin();

        float w = Core.graphics.getWidth();
        float h = Core.graphics.getHeight();

        _batch.draw(_tex, 0, 0, 256, 256);
        _batch.draw(_tex, w - 256, 0, 256, 256);

        _batch.draw(_tex, 0, h - 256, 256, 256);
        _batch.draw(_tex, w - 256, h - 256, 256, 256);

        _batch.end();

        //writeln(format("SpriteBatch > RenderCalls: %s Total: %s", _batch.renderCalls, _batch.totalRenderCalls));
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
    auto config = new Configuration;
    config.windowTitle = "Sample 05 - SpriteBatch";
    auto game = new MyGame;
    auto engine = new Engine(game, config);
    engine.run();

    return 0;
}
