import std.stdio;

import dark;

class MyGame : IApp
{
    void create()
    {
        writeln("Hi!");
    }

    void update(float dt)
    { }

    void render(float dt)
    {  }

    void resize(int width, int height)
    { }

    void dispose()
    { }
}

int main()
{
    auto config = new Configuration;
    config.windowTitle = "Sample 01 - Hello";
    auto game = new MyGame;
    auto engine = new Engine(game, config);
    engine.run();
    return 0;
}
