module dark.input;

import std.stdio;
import std.conv;
import std.string;
import std.container;
import std.math;

import bindbc.opengl;
import bindbc.glfw;

import dark.core;
import dark.graphics;
import dark.time;

extern (C) void keyCallback(GLFWwindow* window, int key, int scancode, int action, int mods) nothrow
{
    try
    {
        //writeln(format("EVENT: keyCallback(%s, %s, %s, %s)", key, scancode, action, mods));
        Core.input.onKeyCallback(key, scancode, action, mods);
    }
    catch (Exception e)
    {
    }
}

extern (C) void charCallback(GLFWwindow* window, uint codepoint) nothrow
{
    if ((codepoint & 0xff00) == 0xf700)
        return;

    try
    {
        //writeln(format("EVENT: charCallback(%s)", codepoint));
        Core.input.onCharCallback(codepoint);
    }
    catch (Exception e)
    {
    }
}

extern (C) void scrollCallback(GLFWwindow* window, double scrollX, double scrollY) nothrow
{
    try
    {
        //writeln(format("EVENT: scrollCallback(%s, %s)", scrollX, scrollY));
        Core.input.onScrollCallback(scrollX, scrollY);
    }
    catch (Exception e)
    {
    }
}

extern (C) void cursorPosCallback(GLFWwindow* window, double x, double y) nothrow
{
    try
    {
        //writeln(format("EVENT: cursorPosCallback(%s, %s)", x, y));
        Core.input.onCursorPosCallback(x, y);
    }
    catch (Exception e)
    {
    }
}

extern (C) void mouseButtonCallback(GLFWwindow* window, int button, int action, int mods) nothrow
{
    try
    {
        //writeln(format("EVENT: mouseButtonCallback(%s, %s, %s)", button, action, mods));
        Core.input.onMouseButtonCallback(button, action, mods);
    }
    catch (Exception e)
    {
    }
}

public class Input
{
    private GLFWwindow* _window;

    private IInputProcessor inputProcessor;
    private InputEventQueue eventQueue = new InputEventQueue();

    private int mouseX, mouseY;
    private int mousePressed;
    private int deltaX, deltaY;
    private bool justTouched;
    private int pressedKeys;
    private bool keyJustPressed;
    private bool[] justPressedKeys = new bool[256];
    private char lastCharacter;

    // scroll stuff
    private long pauseTime = 250000000L; //250ms
    private float scrollYRemainder;
    private long lastScrollEventTime;

    // cursor pos stuff
    private int logicalMouseY;
    private int logicalMouseX;

    void resetPollingStates()
    {
        justTouched = false;
        keyJustPressed = false;
        for (int i = 0; i < justPressedKeys.length; i++)
        {
            justPressedKeys[i] = false;
        }
        eventQueue.setProcessor(null);
        eventQueue.drain();
    }

    public void windowHandleChanged(GLFWwindow* window)
    {
        _window = window;
        resetPollingStates();
        glfwSetKeyCallback(_window, &keyCallback);
        glfwSetCharCallback(_window, &charCallback);
        glfwSetScrollCallback(_window, &scrollCallback);
        glfwSetCursorPosCallback(_window, &cursorPosCallback);
        glfwSetMouseButtonCallback(_window, &mouseButtonCallback);
    }

    void update()
    {
        eventQueue.setProcessor(inputProcessor);
        eventQueue.drain();
    }

    void prepareNext()
    {
        justTouched = false;

        if (keyJustPressed)
        {
            keyJustPressed = false;
            for (int i = 0; i < justPressedKeys.length; i++)
            {
                justPressedKeys[i] = false;
            }
        }
        deltaX = 0;
        deltaY = 0;
    }

    public void onKeyCallback(int key, int scancode, int action, int mods)
    {
        switch (action)
        {
        case GLFW_PRESS:
            int code = convertKeyCode(key);
            eventQueue.keyDown(code);
            pressedKeys++;
            keyJustPressed = true;
            justPressedKeys[code] = true;
            lastCharacter = 0;
            char character = characterForKeyCode(key);

            if (character != 0)
                onCharCallback(character);
            break;

        case GLFW_RELEASE:
            pressedKeys--;
            eventQueue.keyUp(convertKeyCode(key));
            break;

        case GLFW_REPEAT:
            if (lastCharacter != 0)
            {
                eventQueue.keyTyped(lastCharacter);
            }
            break;

        default:
            writeln(format("ERROR: Unhandled action: %s", action));
            break;
        }
    }

    public void onCharCallback(int codepoint)
    {
        lastCharacter = cast(char) codepoint;
        eventQueue.keyTyped(cast(char) codepoint);
    }

    public void onScrollCallback(double scrollX, double scrollY)
    {
        if (scrollYRemainder > 0 && scrollY < 0 || scrollYRemainder < 0
                && scrollY > 0 || nanoTime() - lastScrollEventTime > pauseTime)
        {
            // fire a scroll event immediately:
            //  - if the scroll direction changes; 
            //  - if the user did not move the wheel for more than 250ms
            scrollYRemainder = 0;
            int scrollAmount = cast(int)-sgn(scrollY);
            eventQueue.scrolled(scrollAmount);
            lastScrollEventTime = nanoTime();
        }
        else
        {
            scrollYRemainder += scrollY;
            while (abs(scrollYRemainder) >= 1)
            {
                int scrollAmount = cast(int)-sgn(scrollY);
                eventQueue.scrolled(scrollAmount);
                lastScrollEventTime = nanoTime();
                scrollYRemainder += scrollAmount;
            }
        }
    }

    public void onCursorPosCallback(double x, double y)
    {
        deltaX = cast(int) x - logicalMouseX;
        deltaY = cast(int) y - logicalMouseY;
        mouseX = logicalMouseX = cast(int) x;
        mouseY = logicalMouseY = cast(int) y;

        auto gfx = Core.graphics;

        if (gfx.getHdpiMode() == HdpiMode.Pixels)
        {
            float xScale = gfx.getBackBufferWidth() / cast(float) gfx.getLogicalWidth();
            float yScale = gfx.getBackBufferHeight() / cast(float) gfx.getLogicalHeight();
            deltaX = cast(int)(deltaX * xScale);
            deltaY = cast(int)(deltaY * yScale);
            mouseX = cast(int)(mouseX * xScale);
            mouseY = cast(int)(mouseY * yScale);
        }

        if (mousePressed > 0)
        {
            eventQueue.touchDragged(mouseX, mouseY, 0);
        }
        else
        {
            eventQueue.mouseMoved(mouseX, mouseY);
        }
    }

    public void onMouseButtonCallback(int button, int action, int mods)
    {
        int convertedBtn = convertButton(button);
        if (button != -1 && convertedBtn == -1)
            return;

        if (action == GLFW_PRESS)
        {
            mousePressed++;
            justTouched = true;
            eventQueue.touchDown(mouseX, mouseY, 0, convertedBtn);
        }
        else
        {
            mousePressed = cast(int) fmax(0.0f, mousePressed - 1); // todo: only accepts float? 
            eventQueue.touchUp(mouseX, mouseY, 0, convertedBtn);
        }
    }

    bool is_touched()
    {
        return glfwGetMouseButton(_window, GLFW_MOUSE_BUTTON_1)
            || glfwGetMouseButton(_window, GLFW_MOUSE_BUTTON_2) 
            || glfwGetMouseButton(_window, GLFW_MOUSE_BUTTON_3)
            || glfwGetMouseButton(_window, GLFW_MOUSE_BUTTON_4)
            || glfwGetMouseButton(_window, GLFW_MOUSE_BUTTON_5);
    }

    bool just_touched()
    {
        return justTouched;
    }

    bool is_button_pressed(Buttons button)
    {
        return glfwGetMouseButton(_window, cast(int) button) > 0;
    }

    bool is_key_just_pressed(Keys key)
    {
        if (key == Keys.ANY_KEY)
            return keyJustPressed;
        if (cast(int) key < 0 || cast(int) key > 256)
            return false;

        return justPressedKeys[cast(int) key];
    }

    public float getX()
    {
        return mouseX;
    }

    public float getY()
    {
        return mouseY;
    }

    public float getDeltaX()
    {
        return deltaX;
    }

    public float getDeltaY()
    {
        return deltaY;
    }

    public void setInputProcessor(IInputProcessor processor)
    {
        this.inputProcessor = processor;
    }
}

public final enum Buttons
{
    LEFT = 0,
    RIGHT = 1,
    MIDDLE = 2,
    BACK = 3,
    FORWARD = 4,
}

public final enum Keys
{
    ANY_KEY = -1,
    NUM_0 = 7,
    NUM_1 = 8,
    NUM_2 = 9,
    NUM_3 = 10,
    NUM_4 = 11,
    NUM_5 = 12,
    NUM_6 = 13,
    NUM_7 = 14,
    NUM_8 = 15,
    NUM_9 = 16,
    A = 29,
    ALT_LEFT = 57,
    ALT_RIGHT = 58,
    APOSTROPHE = 75,
    AT = 77,
    B = 30,
    BACK = 4,
    BACKSLASH = 73,
    C = 31,
    CALL = 5,
    CAMERA = 27,
    CLEAR = 28,
    COMMA = 55,
    D = 32,
    DEL = 67,
    BACKSPACE = 67,
    FORWARD_DEL = 112,
    DPAD_CENTER = 23,
    DPAD_DOWN = 20,
    DPAD_LEFT = 21,
    DPAD_RIGHT = 22,
    DPAD_UP = 19,
    CENTER = 23,
    DOWN = 20,
    LEFT = 21,
    RIGHT = 22,
    UP = 19,
    E = 33,
    ENDCALL = 6,
    ENTER = 66,
    ENVELOPE = 65,
    EQUALS = 70,
    EXPLORER = 64,
    F = 34,
    FOCUS = 80,
    G = 35,
    GRAVE = 68,
    H = 36,
    HEADSETHOOK = 79,
    HOME = 3,
    I = 37,
    J = 38,
    K = 39,
    L = 40,
    LEFT_BRACKET = 71,
    M = 41,
    MEDIA_FAST_FORWARD = 90,
    MEDIA_NEXT = 87,
    MEDIA_PLAY_PAUSE = 85,
    MEDIA_PREVIOUS = 88,
    MEDIA_REWIND = 89,
    MEDIA_STOP = 86,
    MENU = 82,
    MINUS = 69,
    MUTE = 91,
    N = 42,
    NOTIFICATION = 83,
    NUM = 78,
    O = 43,
    P = 44,
    PERIOD = 56,
    PLUS = 81,
    POUND = 18,
    POWER = 26,
    Q = 45,
    R = 46,
    RIGHT_BRACKET = 72,
    S = 47,
    SEARCH = 84,
    SEMICOLON = 74,
    SHIFT_LEFT = 59,
    SHIFT_RIGHT = 60,
    SLASH = 76,
    SOFT_LEFT = 1,
    SOFT_RIGHT = 2,
    SPACE = 62,
    STAR = 17,
    SYM = 63,
    T = 48,
    TAB = 61,
    U = 49,
    UNKNOWN = 0,
    V = 50,
    VOLUME_DOWN = 25,
    VOLUME_UP = 24,
    W = 51,
    X = 52,
    Y = 53,
    Z = 54,
    META_ALT_LEFT_ON = 16,
    META_ALT_ON = 2,
    META_ALT_RIGHT_ON = 32,
    META_SHIFT_LEFT_ON = 64,
    META_SHIFT_ON = 1,
    META_SHIFT_RIGHT_ON = 128,
    META_SYM_ON = 4,
    CONTROL_LEFT = 129,
    CONTROL_RIGHT = 130,
    ESCAPE = 131,
    END = 132,
    INSERT = 133,
    PAGE_UP = 92,
    PAGE_DOWN = 93,
    PICTSYMBOLS = 94,
    SWITCH_CHARSET = 95,
    BUTTON_CIRCLE = 255,
    BUTTON_A = 96,
    BUTTON_B = 97,
    BUTTON_C = 98,
    BUTTON_X = 99,
    BUTTON_Y = 100,
    BUTTON_Z = 101,
    BUTTON_L1 = 102,
    BUTTON_R1 = 103,
    BUTTON_L2 = 104,
    BUTTON_R2 = 105,
    BUTTON_THUMBL = 106,
    BUTTON_THUMBR = 107,
    BUTTON_START = 108,
    BUTTON_SELECT = 109,
    BUTTON_MODE = 110,

    NUMPAD_0 = 144,
    NUMPAD_1 = 145,
    NUMPAD_2 = 146,
    NUMPAD_3 = 147,
    NUMPAD_4 = 148,
    NUMPAD_5 = 149,
    NUMPAD_6 = 150,
    NUMPAD_7 = 151,
    NUMPAD_8 = 152,
    NUMPAD_9 = 153,

    // public static int BACKTICK = 0;
    // public static int TILDE = 0;
    // public static int UNDERSCORE = 0;
    // public static int DOT = 0;
    // public static int BREAK = 0;
    // public static int PIPE = 0;
    // public static int EXCLAMATION = 0;
    // public static int QUESTIONMARK = 0;

    // ` | VK_BACKTICK
    // ~ | VK_TILDE
    // : | VK_COLON
    // _ | VK_UNDERSCORE
    // . | VK_DOT
    // (break) | VK_BREAK
    // | | VK_PIPE
    // ! | VK_EXCLAMATION
    // ? | VK_QUESTION
    COLON = 243,
    F1 = 244,
    F2 = 245,
    F3 = 246,
    F4 = 247,
    F5 = 248,
    F6 = 249,
    F7 = 250,
    F8 = 251,
    F9 = 252,
    F10 = 253,
    F11 = 254,
    F12 = 255,
}

char characterForKeyCode(int key)
{
    // Map certain key codes to character codes.
    switch (key)
    {
    case Keys.BACKSPACE:
        return 8;
    case Keys.TAB:
        return '\t';
    case Keys.FORWARD_DEL:
        return 127;
    case Keys.ENTER:
        return '\n';
    default:
        return 0;
    }
}

public int convertKeyCode(int lwjglKeyCode)
{
    switch (lwjglKeyCode)
    {
    case GLFW_KEY_SPACE:
        return Keys.SPACE;
    case GLFW_KEY_APOSTROPHE:
        return Keys.APOSTROPHE;
    case GLFW_KEY_COMMA:
        return Keys.COMMA;
    case GLFW_KEY_MINUS:
        return Keys.MINUS;
    case GLFW_KEY_PERIOD:
        return Keys.PERIOD;
    case GLFW_KEY_SLASH:
        return Keys.SLASH;
    case GLFW_KEY_0:
        return Keys.NUM_0;
    case GLFW_KEY_1:
        return Keys.NUM_1;
    case GLFW_KEY_2:
        return Keys.NUM_2;
    case GLFW_KEY_3:
        return Keys.NUM_3;
    case GLFW_KEY_4:
        return Keys.NUM_4;
    case GLFW_KEY_5:
        return Keys.NUM_5;
    case GLFW_KEY_6:
        return Keys.NUM_6;
    case GLFW_KEY_7:
        return Keys.NUM_7;
    case GLFW_KEY_8:
        return Keys.NUM_8;
    case GLFW_KEY_9:
        return Keys.NUM_9;
    case GLFW_KEY_SEMICOLON:
        return Keys.SEMICOLON;
    case GLFW_KEY_EQUAL:
        return Keys.EQUALS;
    case GLFW_KEY_A:
        return Keys.A;
    case GLFW_KEY_B:
        return Keys.B;
    case GLFW_KEY_C:
        return Keys.C;
    case GLFW_KEY_D:
        return Keys.D;
    case GLFW_KEY_E:
        return Keys.E;
    case GLFW_KEY_F:
        return Keys.F;
    case GLFW_KEY_G:
        return Keys.G;
    case GLFW_KEY_H:
        return Keys.H;
    case GLFW_KEY_I:
        return Keys.I;
    case GLFW_KEY_J:
        return Keys.J;
    case GLFW_KEY_K:
        return Keys.K;
    case GLFW_KEY_L:
        return Keys.L;
    case GLFW_KEY_M:
        return Keys.M;
    case GLFW_KEY_N:
        return Keys.N;
    case GLFW_KEY_O:
        return Keys.O;
    case GLFW_KEY_P:
        return Keys.P;
    case GLFW_KEY_Q:
        return Keys.Q;
    case GLFW_KEY_R:
        return Keys.R;
    case GLFW_KEY_S:
        return Keys.S;
    case GLFW_KEY_T:
        return Keys.T;
    case GLFW_KEY_U:
        return Keys.U;
    case GLFW_KEY_V:
        return Keys.V;
    case GLFW_KEY_W:
        return Keys.W;
    case GLFW_KEY_X:
        return Keys.X;
    case GLFW_KEY_Y:
        return Keys.Y;
    case GLFW_KEY_Z:
        return Keys.Z;
    case GLFW_KEY_LEFT_BRACKET:
        return Keys.LEFT_BRACKET;
    case GLFW_KEY_BACKSLASH:
        return Keys.BACKSLASH;
    case GLFW_KEY_RIGHT_BRACKET:
        return Keys.RIGHT_BRACKET;
    case GLFW_KEY_GRAVE_ACCENT:
        return Keys.GRAVE;
    case GLFW_KEY_WORLD_1:
    case GLFW_KEY_WORLD_2:
        return Keys.UNKNOWN;
    case GLFW_KEY_ESCAPE:
        return Keys.ESCAPE;
    case GLFW_KEY_ENTER:
        return Keys.ENTER;
    case GLFW_KEY_TAB:
        return Keys.TAB;
    case GLFW_KEY_BACKSPACE:
        return Keys.BACKSPACE;
    case GLFW_KEY_INSERT:
        return Keys.INSERT;
    case GLFW_KEY_DELETE:
        return Keys.FORWARD_DEL;
    case GLFW_KEY_RIGHT:
        return Keys.RIGHT;
    case GLFW_KEY_LEFT:
        return Keys.LEFT;
    case GLFW_KEY_DOWN:
        return Keys.DOWN;
    case GLFW_KEY_UP:
        return Keys.UP;
    case GLFW_KEY_PAGE_UP:
        return Keys.PAGE_UP;
    case GLFW_KEY_PAGE_DOWN:
        return Keys.PAGE_DOWN;
    case GLFW_KEY_HOME:
        return Keys.HOME;
    case GLFW_KEY_END:
        return Keys.END;
    case GLFW_KEY_CAPS_LOCK:
    case GLFW_KEY_SCROLL_LOCK:
    case GLFW_KEY_NUM_LOCK:
    case GLFW_KEY_PRINT_SCREEN:
    case GLFW_KEY_PAUSE:
        return Keys.UNKNOWN;
    case GLFW_KEY_F1:
        return Keys.F1;
    case GLFW_KEY_F2:
        return Keys.F2;
    case GLFW_KEY_F3:
        return Keys.F3;
    case GLFW_KEY_F4:
        return Keys.F4;
    case GLFW_KEY_F5:
        return Keys.F5;
    case GLFW_KEY_F6:
        return Keys.F6;
    case GLFW_KEY_F7:
        return Keys.F7;
    case GLFW_KEY_F8:
        return Keys.F8;
    case GLFW_KEY_F9:
        return Keys.F9;
    case GLFW_KEY_F10:
        return Keys.F10;
    case GLFW_KEY_F11:
        return Keys.F11;
    case GLFW_KEY_F12:
        return Keys.F12;
    case GLFW_KEY_F13:
    case GLFW_KEY_F14:
    case GLFW_KEY_F15:
    case GLFW_KEY_F16:
    case GLFW_KEY_F17:
    case GLFW_KEY_F18:
    case GLFW_KEY_F19:
    case GLFW_KEY_F20:
    case GLFW_KEY_F21:
    case GLFW_KEY_F22:
    case GLFW_KEY_F23:
    case GLFW_KEY_F24:
    case GLFW_KEY_F25:
        return Keys.UNKNOWN;
    case GLFW_KEY_KP_0:
        return Keys.NUMPAD_0;
    case GLFW_KEY_KP_1:
        return Keys.NUMPAD_1;
    case GLFW_KEY_KP_2:
        return Keys.NUMPAD_2;
    case GLFW_KEY_KP_3:
        return Keys.NUMPAD_3;
    case GLFW_KEY_KP_4:
        return Keys.NUMPAD_4;
    case GLFW_KEY_KP_5:
        return Keys.NUMPAD_5;
    case GLFW_KEY_KP_6:
        return Keys.NUMPAD_6;
    case GLFW_KEY_KP_7:
        return Keys.NUMPAD_7;
    case GLFW_KEY_KP_8:
        return Keys.NUMPAD_8;
    case GLFW_KEY_KP_9:
        return Keys.NUMPAD_9;
    case GLFW_KEY_KP_DECIMAL:
        return Keys.PERIOD;
    case GLFW_KEY_KP_DIVIDE:
        return Keys.SLASH;
    case GLFW_KEY_KP_MULTIPLY:
        return Keys.STAR;
    case GLFW_KEY_KP_SUBTRACT:
        return Keys.MINUS;
    case GLFW_KEY_KP_ADD:
        return Keys.PLUS;
    case GLFW_KEY_KP_ENTER:
        return Keys.ENTER;
    case GLFW_KEY_KP_EQUAL:
        return Keys.EQUALS;
    case GLFW_KEY_LEFT_SHIFT:
        return Keys.SHIFT_LEFT;
    case GLFW_KEY_LEFT_CONTROL:
        return Keys.CONTROL_LEFT;
    case GLFW_KEY_LEFT_ALT:
        return Keys.ALT_LEFT;
    case GLFW_KEY_LEFT_SUPER:
        return Keys.SYM;
    case GLFW_KEY_RIGHT_SHIFT:
        return Keys.SHIFT_RIGHT;
    case GLFW_KEY_RIGHT_CONTROL:
        return Keys.CONTROL_RIGHT;
    case GLFW_KEY_RIGHT_ALT:
        return Keys.ALT_RIGHT;
    case GLFW_KEY_RIGHT_SUPER:
        return Keys.SYM;
    case GLFW_KEY_MENU:
        return Keys.MENU;
    default:
        return Keys.UNKNOWN;
    }
}

public int convertButton(int button)
{
    if (button == 0)
        return Buttons.LEFT;
    if (button == 1)
        return Buttons.RIGHT;
    if (button == 2)
        return Buttons.MIDDLE;
    if (button == 3)
        return Buttons.BACK;
    if (button == 4)
        return Buttons.FORWARD;
    return -1;
}

public interface IInputProcessor
{
    bool keyDown(int keycode);

    bool keyUp(int keycode);

    bool keyTyped(char character);

    bool touchDown(int screenX, int screenY, int pointer, int button);

    bool touchUp(int screenX, int screenY, int pointer, int button);

    bool touchDragged(int screenX, int screenY, int pointer);

    bool mouseMoved(int screenX, int screenY);

    bool scrolled(int amount);
}

// todo: optimize array shit
public class InputEventQueue : IInputProcessor
{
    import dark.collections.array;

    static private immutable int SKIP = -1;
    static private immutable int KEY_DOWN = 0;
    static private immutable int KEY_UP = 1;
    static private immutable int KEY_TYPED = 2;
    static private immutable int TOUCH_DOWN = 3;
    static private immutable int TOUCH_UP = 4;
    static private immutable int TOUCH_DRAGGED = 5;
    static private immutable int MOUSE_MOVED = 6;
    static private immutable int SCROLLED = 7;

    private IInputProcessor processor;
    private Array!int queue;
    private Array!int processingQueue;
    private long currentEventTime;

    public this()
    {
        queue = new Array!int();
        processingQueue = new Array!int();
        queue.ensureCapacity(512);
        processingQueue.ensureCapacity(512);
    }

    public void setProcessor(IInputProcessor processor)
    {
        this.processor = processor;
    }

    public void drain()
    {
        if (processor is null)
        {
            queue.clear();
            return;
        }

        processingQueue.clear();
        processingQueue.addAll(queue);
        queue.clear();

        for (int i = 0, n = cast(int) processingQueue.count(); i < n;)
        {
            int type = processingQueue[i++];
            currentEventTime = cast(long) processingQueue[i++] << 32
                | processingQueue[i++] & 0xFFFFFFFFL;
            switch (type)
            {
            case SKIP:
                i += processingQueue[i];
                break;
            case KEY_DOWN:
                processor.keyDown(processingQueue[i++]);
                break;
            case KEY_UP:
                processor.keyUp(processingQueue[i++]);
                break;
            case KEY_TYPED:
                processor.keyTyped(cast(char) processingQueue[i++]);
                break;
            case TOUCH_DOWN:
                processor.touchDown(processingQueue[i++], processingQueue[i++],
                        processingQueue[i++], processingQueue[i++]);
                break;
            case TOUCH_UP:
                processor.touchUp(processingQueue[i++], processingQueue[i++],
                        processingQueue[i++], processingQueue[i++]);
                break;
            case TOUCH_DRAGGED:
                processor.touchDragged(processingQueue[i++],
                        processingQueue[i++], processingQueue[i++]);
                break;
            case MOUSE_MOVED:
                processor.mouseMoved(processingQueue[i++], processingQueue[i++]);
                break;
            case SCROLLED:
                processor.scrolled(processingQueue[i++]);
                break;
            default:
                throw new Exception("wut");
            }

        }
        processingQueue.clear();
    }

    // todo: should be synchronized
    int next(int nextType, int i)
    {
        for (int n = cast(int) queue.count(); i < n;)
        {
            int type = queue[i];
            if (type == nextType)
                return i;
            i += 3;
            switch (type)
            {
            case SKIP:
                i += queue[i];
                break;
            case KEY_DOWN:
                i++;
                break;
            case KEY_UP:
                i++;
                break;
            case KEY_TYPED:
                i++;
                break;
            case TOUCH_DOWN:
                i += 4;
                break;
            case TOUCH_UP:
                i += 4;
                break;
            case TOUCH_DRAGGED:
                i += 3;
                break;
            case MOUSE_MOVED:
                i += 2;
                break;
            case SCROLLED:
                i++;
                break;
            default:
                throw new Exception(format("Unknow input type: %s", type));
            }
        }
        return -1;
    }

    private void queueTime()
    {
        long time = nanoTime();

        queue.add(cast(int)(time >> 32));
        queue.add(cast(int) time);
    }

    public bool keyDown(int keycode)
    {
        queue.add(KEY_DOWN);
        queueTime();
        queue.add(keycode);
        return false;
    }

    public bool keyUp(int keycode)
    {
        queue.add(KEY_UP);
        queueTime();
        queue.add(keycode);
        return false;
    }

    public bool keyTyped(char character)
    {
        queue.add(KEY_TYPED);
        queueTime();
        queue.add(character);
        return false;
    }

    public bool touchDown(int screenX, int screenY, int pointer, int button)
    {
        queue.add(TOUCH_DOWN);
        queueTime();
        queue.add(screenX);
        queue.add(screenY);
        queue.add(pointer);
        queue.add(button);
        return false;
    }

    public bool touchUp(int screenX, int screenY, int pointer, int button)
    {
        queue.add(TOUCH_UP);
        queueTime();
        queue.add(screenX);
        queue.add(screenY);
        queue.add(pointer);
        queue.add(button);
        return false;
    }

    public bool touchDragged(int screenX, int screenY, int pointer)
    {
        // Skip any queued touch dragged events for the same pointer.
        for (int i = next(TOUCH_DRAGGED, 0); i >= 0; i = next(TOUCH_DRAGGED, i + 6))
        {
            if (queue[i + 5] == pointer)
            {
                queue[i] = SKIP;
                queue[i + 3] = 3;
            }
        }
        queue.add(TOUCH_DRAGGED);
        queueTime();
        queue.add(screenX);
        queue.add(screenY);
        queue.add(pointer);
        return false;
    }

    public bool mouseMoved(int screenX, int screenY)
    {
        // Skip any queued mouse moved events.
        for (int i = next(MOUSE_MOVED, 0); i >= 0; i = next(MOUSE_MOVED, i + 5))
        {
            queue[i] = SKIP;
            queue[i + 3] = 2;
        }
        queue.add(MOUSE_MOVED);
        queueTime();
        queue.add(screenX);
        queue.add(screenY);
        return false;
    }

    public bool scrolled(int amount)
    {
        queue.add(SCROLLED);
        queueTime();
        queue.add(amount);
        return false;
    }

    public long getCurrentEventTime()
    {
        return currentEventTime;
    }
}

public class InputAdapter : IInputProcessor
{
    public bool keyDown(int keycode)
    {
        return false;
    }

    public bool keyUp(int keycode)
    {
        return false;
    }

    public bool keyTyped(char character)
    {
        return false;
    }

    public bool touchDown(int screenX, int screenY, int pointer, int button)
    {
        return false;
    }

    public bool touchUp(int screenX, int screenY, int pointer, int button)
    {
        return false;
    }

    public bool touchDragged(int screenX, int screenY, int pointer)
    {
        return false;
    }

    public bool mouseMoved(int screenX, int screenY)
    {
        return false;
    }

    public bool scrolled(int amount)
    {
        return false;
    }
}
