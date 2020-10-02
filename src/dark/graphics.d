module dark.graphics;

import std.stdio;
import std.conv;
import std.string;
import std.datetime.stopwatch : benchmark, StopWatch, AutoStart;

import bindbc.opengl;
import bindbc.glfw;

import dark.core;
import dark.engine;

extern (C) void onFrameBufferResize(GLFWwindow* window, int width, int height) nothrow
{
	try
	{
		//writeln(format("EVENT: onResize(%s, %s)", width, height));

		
		Core.graphics.updateBackbufferInfo();

		if (!Core.graphics.isInitialized())
		{
			return;
		}
		glViewport(0, 0, width, height);

		Core.graphics.getApp().resize(width, height);

		glfwSwapBuffers(window);
	}
	catch (Exception e)
	{

	}
}

// window specific callbacks

extern (C) void focusCallback(GLFWwindow* window, int focused) nothrow
{
	try
	{
		writeln(format("EVENT: focusCallback(%s)", focused));
	}
	catch (Exception e)
	{

	}
}

extern (C) void iconifyCallback(GLFWwindow* window, int iconified) nothrow
{
	try
	{
		writeln(format("EVENT: iconifyCallback(%s)", iconified));
	}
	catch (Exception e)
	{

	}
}

extern (C) void maximizeCallback(GLFWwindow* window, int maximized) nothrow
{
	try
	{
		writeln(format("EVENT: maximizeCallback(%s)", maximized));
	}
	catch (Exception e)
	{

	}
}

extern (C) void closeCallback(GLFWwindow* window) nothrow
{
	try
	{
		writeln(format("EVENT: closeCallback()"));
	}
	catch (Exception e)
	{

	}
}

extern (C) void dropCallback(GLFWwindow* window, int count, const(char*)* names) nothrow
{
	try
	{
		writeln(format("EVENT: dropCallback(%s, %s)", count, names));
	}
	catch (Exception e)
	{

	}
}

extern (C) void refreshCallback(GLFWwindow* window) nothrow
{
	try
	{
		writeln(format("EVENT: refreshCallback()"));
	}
	catch (Exception e)
	{

	}
}

// --


enum HdpiMode
{
	Logical,
	Pixels
}

class Graphics
{
	private GLFWwindow* _window;
	private int _width = 1280;
	private int _height = 720;
	private int _backBufferWidth;
	private int _backBufferHeight;
	private int _logicalWidth;
	private int _logicalHeight;

	private HdpiMode _hdpiMode = HdpiMode.Logical;

	private bool _iconified = false;

	private StopWatch _sw;
	private long _lastFrameTime = -1;
	private float _deltaTime = 0;
	private long _frameId = 0;
	private long _frameCounterStart = 0;
	private int _frames = 0;
	private int _fps = 0;

	private IApp _app;
	private Config _config;

	private bool _initialized;

	this(IApp app, Config config)
	{
		_app = app;
		_config = config;
		_sw = StopWatch(AutoStart.yes);
	}

	private void updateBackbufferInfo()
	{
		glfwGetFramebufferSize(_window, &_backBufferWidth, &_backBufferHeight);
		glfwGetWindowSize(_window, &_logicalWidth, &_logicalHeight);
	}

	bool createContext()
	{
		GLFWSupport ret = loadGLFW();

		if (ret != glfwSupport)
		{

			// Handle error. For most use cases, its reasonable to use the the error handling API in
			// bindbc-loader to retrieve error messages for logging and then abort. If necessary, it's 
			// possible to determine the root cause via the return value:

			if (ret == GLFWSupport.noLibrary)
			{
				Core.logger.errorf("Unable to find glfw3 library, %s", ret);
			}
			else if (GLFWSupport.badLibrary)
			{
				// One or more symbols failed to load. The likely cause is that the
				// shared library is for a lower version than bindbc-glfw was configured
				// to load (via GLFW_31, GLFW_32 etc.)
				Core.logger.errorf("Wrong library, %s", ret);
			}
		}

		if (!glfwInit())
		{
			writeln("Unable to init glfw");
			return false;
		}
		glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, _config.glMajVersion);
		glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, _config.glMinVersion);
		glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
		glfwWindowHint(GLFW_RESIZABLE, GL_TRUE);
		
		// delay window opening to avoid positioning glitch and white window
		glfwWindowHint(GLFW_VISIBLE, GL_FALSE);

		_window = glfwCreateWindow(_config.windowWidth, _config.windowHeight, _config.windowTitle.ptr, null, null);
		if (!_window)
		{
			writeln("Unnable to create window ", ret, " ", _config);
			glfwTerminate();
			return false;
		}
		Core.logger.infof("Created window with size: %s:%s", _config.windowWidth, _config.windowHeight);

		if (_config.windowX == -1 && _config.windowY == -1)
		{
			auto primaryMonitor = glfwGetPrimaryMonitor();
			auto vidMode = glfwGetVideoMode(primaryMonitor);

			int windowWidth = 0;
			int windowHeight = 0;
			glfwGetWindowSize(_window, &windowWidth, &windowHeight);

			int windowX = vidMode.width / 2 - windowWidth / 2;
			int windowY = vidMode.height / 2 - windowHeight / 2;
			glfwSetWindowPos(_window, windowX, windowY);
		}



		glfwMakeContextCurrent(_window);
		glfwSwapInterval(_config.vsync ? 1 : 0);

		updateBackbufferInfo();

		GLSupport retVal = loadOpenGL();

		//Core.logger.infof("OpenGL: 	  %s", retVal);
		writeln(retVal);


		// delay window opening to avoid positioning glitch and white window
		glClearColor(0.0f,0.0f,0.0f,1.0f);
		glfwSwapBuffers(_window);
		glfwShowWindow(_window);

		Core.logger.infof("Vendor:    %s", to!string(glGetString(GL_VENDOR)));
		Core.logger.infof("Renderer:  %s", to!string(glGetString(GL_RENDERER)));
		Core.logger.infof("Version:   %s", to!string(glGetString(GL_VERSION)));
		Core.logger.infof("GLSL:      %s", to!string(glGetString(GL_SHADING_LANGUAGE_VERSION)));
		Core.logger.infof("Loaded GL: %s", to!string(retVal));

		glViewport(0, 0, _width, _height);

		glfwSetFramebufferSizeCallback(_window, &onFrameBufferResize);

		// window specific callbacks
		glfwSetWindowFocusCallback(_window, &focusCallback);
		glfwSetWindowIconifyCallback(_window, &iconifyCallback);
		//glfwSetWindowMaximizeCallback(_window, &maximizeCallback);
		glfwSetWindowCloseCallback(_window, &closeCallback);
		glfwSetDropCallback(_window, &dropCallback);
		glfwSetWindowRefreshCallback(_window, &refreshCallback);
		
		
		// --
		return true;
	}

	void update()
	{
		if (!_initialized)
		{
			_app.create();
			_app.resize(_backBufferWidth, _backBufferHeight);
			_initialized = true;
		}
		glfwMakeContextCurrent(_window);

		track();
		_app.update(deltaTime);
		_app.render(deltaTime);
		glfwSwapBuffers(_window);
	}

	void track()
	{
		// auto curr = MonoTime.currTime;
		// auto time = curr.ticks;

		auto time = _sw.peek.total!"nsecs";

		if (_lastFrameTime == -1)
			_lastFrameTime = time;

		_deltaTime = (time - _lastFrameTime) / 1000000000.0f;
		_lastFrameTime = time;

		if (time - _frameCounterStart >= 1000000000)
		{
			_fps = _frames;
			_frames = 0;
			_frameCounterStart = time;
		}

		_frames++;
		_frameId++;
	}

	bool shouldClose()
	{
		return glfwWindowShouldClose(_window) == 1;
	}

	float deltaTime()
	{
		return _deltaTime;
	}

	int fps()
	{
		return _fps;
	}

	GLFWwindow* windowHandle()
	{
		return _window;
	}

	IApp getApp()
	{
		return _app;
	}

	bool isInitialized()
	{
		return _initialized;
	}

	bool isIconified()
	{
		return _iconified;
	}

	HdpiMode getHdpiMode()
	{
		return _hdpiMode;
	}

	int getWidth()
	{
		if (_hdpiMode == HdpiMode.Pixels)
		{
			return _backBufferWidth;
		}
		else
		{
			return _logicalWidth;
		}
	}

	int getHeight()
	{
		if (_hdpiMode == HdpiMode.Pixels)
		{
			return _backBufferHeight;
		}
		else
		{
			return _logicalHeight;
		}
	}

	int getBackBufferWidth()
	{
		return _backBufferWidth;
	}

	int getBackBufferHeight()
	{
		return _backBufferHeight;
	}

	int getLogicalWidth()
	{
		return _logicalWidth;
	}

	int getLogicalHeight()
	{
		return _logicalHeight;
	}
}
