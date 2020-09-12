import std.stdio;

import bindbc.opengl;
import bindbc.glfw;

import dark.core;
import dark.engine;
import dark.input;
import dark.math;

public class MyGame : IApp
{
    public void create()
    {
    }

    public void update(float dt)
    {
    }

    public void render(float dt)
    {
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glClearColor(0.2f, 0.3f, 0.3f, 1.0f);
    }

    public void resize(int width, int height)
    {
    }

    public void dispose()
    {
    }
}

int main()
{
    return 0;
}
