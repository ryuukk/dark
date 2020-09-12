import std.stdio;
import core.memory;
import std.container;
import std.file : readText;
import std.datetime.stopwatch;

import bindbc.opengl;
import bindbc.glfw;

import dark.core;
import dark.engine;
import dark.math;
import dark.util.camera_controller;
import dark.gfx.shader;
import dark.gfx.shader_provider;
import dark.gfx.camera;
import dark.gfx.model;
import dark.gfx.model_instance;
import dark.gfx.model_loader;
import dark.gfx.rendering;
import dark.gfx.animation;

public class Entity
{
    public int id;

    public Vec3 position;
    public Vec3 scale = Vec3(1,1,1);
    public ModelInstance instance;
    public AnimationController controller;
    float a = 0.0f;
    int anim = 0;
    float timer = 0;

    public void update(float dt)
    {
        a += dt;
        timer += dt;
        instance.transform = Mat4.set(position, Quat.fromAxis(0, 1, 0, 0), scale);
        
        if (controller !is null && timer > 3 && instance.animations.length > 0)
        {
           anim = (anim + 1) % cast(int)instance.animations.length;
           timer = 0;

           auto animation = instance.animations[anim];

           // animate(string id, float offset = 0f, float duration = -1f, int loopCount = -1, float speed = 1, float transitionTime = 0f)
           
           // todo: causes mem leak!!
           controller.animate(animation.id, 0, -1, -1, 1.0f, 0.2f);
        }

        if (controller !is null)
        {
            controller.update(dt);
        }

    }

    public void render(RenderableBatch batch)
    {
        batch.render(instance);
    }
}

public class MyGame : IApp
{
    CameraController _controller;
    PerspectiveCamera _cam;
    Model _modelA;
    Model _modelB;

    Array!Entity entities;

    RenderableBatch _batch;

    public void create()
    {
        writeln("create");

        _cam = new PerspectiveCamera(67, Core.graphics.getWidth(), Core.graphics.getHeight());
        _cam.near = 0.1f;
        _cam.far = 100f;
        _cam.position = Vec3(0, 5, 5);
        //_cam.rotate(Vec3.unitX, -45);
        //_cam.lookAt(0,0,5);
        _cam.update();

        _controller = new CameraController(_cam);

        auto dataA = loadModelData("data/models/knight.g3dj");
        assert(dataA !is null, "can't parse dataA");

        auto dataB = loadModelData("data/models/cube.g3dj");
        assert(dataB !is null, "can't parse dataB");

        _modelA = new Model;
        _modelA.load(dataA);

        _modelB = new Model;
        _modelB.load(dataB);

        _batch = new RenderableBatch(new DefaultShaderProvider(
            "data/shaders/default.vert".readText,
            "data/shaders/default.frag".readText)
        );


        writeln("Loading entities..");
        //auto e = new Entity;
        //e.id = 0;
        //e.position = Vec3(0,0,0);
        //e.instance = new ModelInstance(_modelA);
        //e.controller = new AnimationController(e.instance);
        //e.controller.animate("Attack");
        //entities.insert(e);

        bool one = false;

        if(one)
        {
            auto e = new Entity;
            e.id = 1;
            e.position = Vec3(0,0,0);

            e.instance = new ModelInstance(_modelA);
            e.controller = new AnimationController(e.instance);
            e.controller.animate("Attack");
        }
        else
        {
            //entities.reserve(1024);
            int s = 16;
            int pad = 2;
            int id = 0;
            StopWatch sw;
            sw.start();

            
            //GC.disable();
            for (int x = -s; x < s; x++)
            {
                for (int y = -s; y < s; y++)
                {
                    auto e = new Entity;
                    e.id = ++id;
                    e.position = Vec3(x * pad, 0, y * pad);
                    e.timer = id % 3;

                    auto v = id % 2;
                    if (v == 0)
                    {
                        e.instance = new ModelInstance(_modelA);
                        e.controller = new AnimationController(e.instance);
                        e.controller.animate("Attack");
                    }
                    else
                    {
                        e.instance = new ModelInstance(_modelB);
                        e.scale = Vec3(0.5f,0.5f,0.5f);
                    }
                    //else //if(v == 1)
                    //{
                    //    e.instance = new ModelInstance(_modelB);
                    //}
                    //else
                    //{
                    //    e.instance = new ModelInstance(_model);
                    //    e.controller = new AnimationController(e.instance);
                    //    e.controller.animate("run_1h");
                    //}

                    entities.insert(e);
                }
            }
        }
        
        //GC.enable();
        writeln("Added: ", entities.length, " entities");
        Core.input.setInputProcessor(_controller);

        GC.collect();
        GC.minimize();

        GC.disable();
    }

    int fpsAcc = 0;
    int c = 0;
    float timer = 0.0f;
    public void update(float dt)
    {
        auto fps = Core.graphics.fps();
        fpsAcc += fps;
        timer += dt;
        c++;


        if (timer > 1.0f)
        {
            int f = fpsAcc / c;

            // 102.2
            writeln("INFO: FPS: ", fps, " AVG: ", f);
            //writeln("GC: numCollections: ", GC.profileStats.numCollections, " totalPauseTime: ",GC.profileStats.totalPauseTime.toString());
            //writeln("\tGC.stats.usedSize                     ", GC.stats.usedSize/1024/1024,);
            //writeln("\tGC.stats.allocatedInCurrentThread     ", GC.stats.allocatedInCurrentThread/1024/1024,);
            //writeln("\tGC.stats.freeSize                     ", GC.stats.freeSize/1024/1024);

            c = 0;
            fpsAcc = 0;
            timer = 0;
        }
        foreach (entity; entities)
            entity.update(dt);

        _controller.update(dt);
    }

    public void render(float dt)
    {
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glClearColor(0.2f, 0.3f, 0.3f, 1.0f);

        _cam.update();

        glEnable(GL_DEPTH_TEST);

        _batch.begin(_cam);

        foreach (entity; entities)
            entity.render(_batch);

        _batch.end();
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


extern(C) __gshared string[] rt_options = [
    //"gcopt=gc:precise initReserve:32 incPoolSize:16 minPoolSize:1 maxPoolSize:64 cleanup:finalize heapSizeFactor=1.2 profile:1 help"
      "gcopt=gc:precise initReserve:8 incPoolSize:16 minPoolSize:1 maxPoolSize:32 cleanup:finalize heapSizeFactor=1.2 profile:1 help"
     // "gcopt=gc:precise profile:1 help"
];


class Node 
{}

struct Transform
{}


void test(Transform[Node]* map, Node node)
{
    if( node in *map)
    {
        (*map)[node] = Transform();
    }
}

 static Node node;
 static Transform[Node] map;
void main()
{
    
    //import core.thread;
    //node = new Node;
    //while(true)
    //{
    //    test(&map, node);
    //    //Thread.sleep(dur!("msecs")(1));
    //}


    auto config = new Configuration;
    config.windowTitle = "Sample 08 - RenderableBatch";
    config.vsync = false;
    auto game = new MyGame;
    auto engine = new Engine(game, config);
    engine.run();

}
