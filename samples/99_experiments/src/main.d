import std.stdio;
import std.conv;
import std.string;
import std.random;
import core.memory;
import std.path;
import std.file : readText;
import std.socket;
import core.thread;

import bindbc.opengl;
import bindbc.glfw;

import darc.core;
import darc.engine;
import darc.input;
import darc.math;
import darc.gfx.shader;
import darc.gfx.buffers;
import darc.gfx.mesh;
import darc.gfx.texture;
import darc.gfx.batch;
import darc.gfx.camera;
import darc.gfx.model;
import darc.gfx.material;
import darc.gfx.renderable;
import darc.gfx.rendering;
import darc.net.client;

public class MyGame : IApp
{
    NetClient client;
    public void create()
    {
        client = new NetClient();
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

    enum OK;
    
    version(OK)
    {
        writeln("OKkj");
    }
    import core.thread;

    NetClient _client = new NetClient;
    _client.connect("52.47.149.74", 2050);

    while (true)
    {
        Message msg;
        while (_client.getNextMessage(msg))
        {
            switch (msg.eventType)
            {
            case EventType.Connected:
                writeln("INFO: Connected!");
                break;
            case EventType.Disconnected:
                writeln("INFO: Disconnected!");
                break;
            case EventType.Data:
                writeln("INFO: Data -> ID: ", msg.packetId, " L: ", msg.data.length);
                break;
            default:
                writeln("WARN: ", msg.eventType);
                break;
            }
        }
        Thread.sleep(dur!("msecs")(1));
    }

    //auto config = new Configuration;
    //config.windowTitle = "Sample 99 - Experiments";
    //auto game = new MyGame;
    //auto engine = new Engine(game, config);
    //engine.run();
    //return 0;
}
