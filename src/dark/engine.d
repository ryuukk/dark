module dark.engine;

import std.stdio;
import std.format;
import std.experimental.logger;

import bindbc.opengl;
import bindbc.glfw;

import dark.core;
import dark.graphics;
import dark.audio;
import dark.input;

struct Config
{
	int glMinVersion = 3;
	int glMajVersion = 3;

	int windowWidth = 1280;;
	int windowHeight = 720;

	int windowX = -1;
	int windowY = -1;

	string windowTitle = "DARK";

	bool vsync = true;

	bool logToFile = false;
	string logPath = "log.txt";
}

Config default_config(string title)
{
	Config config;
	config.glMinVersion = 3;
	config.glMajVersion = 3;
	config.windowWidth = 1280;
	config.windowHeight = 720;
	config.windowX = -1;
	config.windowY = -1;
	config.windowTitle = title;
	config.vsync = true;
	config.logToFile = false;
	config.logPath = "log.txt";
	return config;
}

class Engine
{
	private Graphics _graphics;
	private Audio _audio;
	private Input _input;
	private IApp _app;
	private Logger _logger;
	private Config _config;
	private bool _running = true;

	this(IApp app, in Config config)
	{
		_app = app;
		_config = config;
	}

	void run()
	{
		_graphics = new Graphics(_app, _config);
		_audio = new Audio;
		_input = new Input;
		if (_config.logToFile)
			_logger = new FileLogger(_config.logPath);
		else
			_logger = new AppLogger();

		Core.graphics = _graphics;
		Core.audio = _audio;
		Core.input = _input;
		Core.logger = _logger;

		if(!_graphics.createContext())
		{
			writeln("Unnable to create context");
			return;
		}
		_input.windowHandleChanged(_graphics.windowHandle());

		while (_running)
		{
			// runables

			if (!_graphics.isIconified())
				_input.update();

			_graphics.update();

			if (!_graphics.isIconified())
				_input.prepareNext();

			_running = !_graphics.shouldClose();

			glfwPollEvents();
		}

		glfwTerminate();

		_app.dispose();
	}

	void exit()
	{
		_running = false;
	}
}

class AppLogger : Logger
{
	this(LogLevel lv = LogLevel.all) @safe
	{
		super(lv);
	}

	override void writeLogMsg(ref LogEntry payload)
	{
		writeln(format("[%s] (%s:%s) %s", payload.logLevel, payload.funcName,
				payload.line, payload.msg));
	}
}