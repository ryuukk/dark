module darc.core;

import std.stdio;
import std.conv;
import std.string;
import core.time;
import std.datetime.stopwatch : benchmark, StopWatch, AutoStart;
import std.datetime.systime;
import std.experimental.logger;

import bindbc.opengl;
import bindbc.glfw;

import darc.graphics;
import darc.audio;
import darc.input;

public class Core
{
	public static Graphics graphics;
	public static Audio audio;
	public static Input input;
	public static Logger logger;
}

public interface IApp
{
	void create();
	void update(float dt);
	void render(float dt);
	void resize(int width, int height);
	void dispose();
}