import std.stdio;

import arc;
import dark.gfx.batch;
import dark.gfx.texture;
import dark.collections;

public class Entity{}
public class MyGame : IApp
{
    SpriteBatch batch;
    TextureRegion region;
    Array!Entity entities;
    public void create()
    {
        writeln("Hi!");

        entities = new Array!Entity;
        batch = new SpriteBatch;

        auto entity = new Entity;
        entities.add(entity);
        

        entities.remove(entity);

    }

    public void update(float dt)
    { }

    public void render(float dt)
    { 
        batch.begin();
        batch.end();
    }

    public void resize(int width, int height)
    { }

    public void dispose()
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
