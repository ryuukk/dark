# Run the samples

- Make sure you got D installed in your system
- ```git clone ```
- ``./run_samples.sh``

# Hello World

```D
import std.stdio;

import dark;

int main()
{
    auto game = new MyGame;
    auto config = Config;
    auto engine = new Engine(game);
    engine.run();

    return 0;
}

class MyGame : IApp
{
    void create()
    {
        writeln("Hi");
    }
    
    void update()
    {}

    void render()
    {}

    void resize(int width, int height)
    {}

    void dispose()
    {}
}

```