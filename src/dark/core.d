module dark.core;

import std.stdio;
import std.conv;
import std.string;
import core.time;
import std.datetime.stopwatch : benchmark, StopWatch, AutoStart;
import std.datetime.systime;
import std.experimental.logger;

import bindbc.opengl;
import bindbc.glfw;

import dark.graphics;
import dark.audio;
import dark.input;

class Core
{
	static Graphics graphics;
	static Audio audio;
	static Input input;
	static Logger logger;
}

interface IApp
{
	void create();
	void update(float dt);
	void render(float dt);
	void resize(int width, int height);
	void dispose();
}