module dark.gfx.shader_program;

import std.conv : text;
import std.format;
import std.stdio;
import core.math;

import bindbc.opengl;
import dark.math;


public class ShaderProgram
{
    public static immutable string POSITION_ATTRIBUTE = "a_position";
    public static immutable string NORMAL_ATTRIBUTE = "a_normal";
    public static immutable string COLOR_ATTRIBUTE = "a_color";
    public static immutable string TEXCOORD_ATTRIBUTE = "a_texCoord";
    public static immutable string TANGENT_ATTRIBUTE = "a_tangent";
    public static immutable string BINORMAL_ATTRIBUTE = "a_binormal";
    public static immutable string BONEWEIGHT_ATTRIBUTE = "a_boneWeight";
    public static string prependVertexCode = "";
    public static string prependFragmentCode = "";
    public static bool pedantic = true;

    private string _log = "";
    private bool _isCompiled;

    private int[string] _uniforms;
    private int[string] _uniformTypes;
    private int[string] _uniformSizes;
    private string[] _uniformNames;

    private int[string] _attributes;
    private int[string] _attributeTypes;
    private int[string] _attributeSizes;
    private string[] _attributeNames;

    private int _program;
    private int _vertexShaderHandle;
    private int _fragmentShaderHandle;
    private string _vertexShaderSource;
    private string _fragmentShaderSource;

    private bool _invalidated;
    private int _refCount = 0;

    public this(string vertexShader, string fragmentShader)
    {
        assert(vertexShader != null);
        assert(fragmentShader != null);

        if (prependVertexCode !is null && prependVertexCode.length > 0)
            vertexShader = prependVertexCode ~= vertexShader;
        if (prependFragmentCode !is null && prependFragmentCode.length > 0)
            fragmentShader = prependFragmentCode ~= fragmentShader;

        _vertexShaderSource = vertexShader;
        _fragmentShaderSource = fragmentShader;

        compileShaders(vertexShader, fragmentShader);

        if (isCompiled())
        {
            fetchAttributes();
            fetchUniforms();
        }
    }

    private void compileShaders(string vertexShader, string fragmentShader)
    {
        _vertexShaderHandle = loadShader(GL_VERTEX_SHADER, vertexShader);
        _fragmentShaderHandle = loadShader(GL_FRAGMENT_SHADER, fragmentShader);

        if (_vertexShaderHandle == -1 || _fragmentShaderHandle == -1)
        {
            _isCompiled = false;
            return;
        }

        _program = linkProgram(createProgram());
        if (_program == -1)
        {
            _isCompiled = false;
            return;
        }

        _isCompiled = true;
    }

    private int loadShader(GLenum type, string source)
    {
        int shader = glCreateShader(type);
        if (shader == 0)
            return -1;

        int compiled;
        auto ssp = source.ptr;
        int ssl = cast(int) source.length;
        glShaderSource(shader, 1, &ssp, &ssl);
        glCompileShader(shader);
        glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);

        if (compiled == 0)
        {
            GLint logLen;
            glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLen);

            char[] msgBuffer = new char[logLen];
            glGetShaderInfoLog(shader, logLen, null, &msgBuffer[0]);
            _log ~= type == GL_VERTEX_SHADER ? "Vertex shader\n" : "Fragment shader:\n";
            _log ~= text(msgBuffer);
            return -1;
        }
        return shader;
    }

    private int createProgram()
    {
        auto program = glCreateProgram();
        return program != 0 ? program : -1;
    }

    private int linkProgram(int program)
    {
        if (program == -1)
            return -1;

        glAttachShader(program, _vertexShaderHandle);
        glAttachShader(program, _fragmentShaderHandle);
        glLinkProgram(program);

        int linked;
        glGetProgramiv(program, GL_LINK_STATUS, &linked);
        if (linked == 0)
        {
            GLint logLen;
            glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logLen);

            char[] msgBuffer = new char[logLen];
            glGetProgramInfoLog(program, logLen, null, &msgBuffer[0]);

            _log = text(msgBuffer);
            return -1;
        }

        return program;
    }

    private void fetchAttributes()
    {
        int numAttributes;
        glGetProgramiv(_program, GL_ACTIVE_ATTRIBUTES, &numAttributes);

        _attributeNames.length = numAttributes;
        for (int i = 0; i < numAttributes; i++)
        {
            char[64] buffer;
            GLenum type;
            int size;
            int length;
            glGetActiveAttrib(_program, i, buffer.length, &length, &size, &type, buffer.ptr);

            string name = buffer[0 .. length].idup;
            int location = glGetAttribLocation(_program, buffer.ptr);

            _attributes[name] = location;
            _attributeTypes[name] = type;
            _attributeSizes[name] = size;
            _attributeNames[i] = name;
            
            version(DEBUG_SHADER)
            {
                writefln("ATTRIBUTE: %s loc: %s type: %s size: %s", name, location, type, size);
            }
        }
    }

    private void fetchUniforms()
    {
        int numUniforms;
        glGetProgramiv(_program, GL_ACTIVE_UNIFORMS, &numUniforms);

        _uniformNames.length = numUniforms;
        for (int i = 0; i < numUniforms; i++)
        {
            char[64] buffer;
            GLenum type;
            int size;
            int length;
            glGetActiveUniform(_program, i, buffer.length, &length, &size, &type, buffer.ptr);

            string name = buffer[0 .. length].idup;
            int location = glGetUniformLocation(_program, buffer.ptr);

            _uniforms[name] = location;
            _uniformTypes[name] = type;
            _uniformSizes[name] = size;
            _uniformNames[i] = name;

            version(DEBUG_SHADER)
            {
                writeln("UNIFORM: ", name, "loc:", location, " loc cached: ", _uniforms[name]);

            }
        }
    }

    private int fetchAttributeLocation(string name)
    {
        // -2 == not yet cached
        // -1 == cached but not found
        int location;
        if ((location = _attributes.get(name, -2)) == -2)
        {
            location = glGetAttribLocation(_program, name.ptr);

            _attributes[name] = location;
        }
        return location;
    }

    private void checkManaged()
    {
        if (_invalidated)
        {
            version(DEBUG_SHADER)
            {
                writeln("Recompile shader");
            }
            compileShaders(_vertexShaderSource, _fragmentShaderSource);
            _invalidated = false;
        }
    }

    public void setVertexAttribute(int location, int size, int type,
            bool normalize, int stride, int offset)
    {
        checkManaged();
        glVertexAttribPointer(location, size, type, normalize ? GL_TRUE
                : GL_FALSE, stride, cast(const(void)*) offset);
    }

    public void enableVertexAttribute(int location)
    {
        checkManaged();
        glEnableVertexAttribArray(location);
    }

    public void disableVertexAttribute(string name)
    {
        checkManaged();
        int location = fetchAttributeLocation(name);
        if (location == -1)
            return;
        glDisableVertexAttribArray(location);
    }

    public void disableVertexAttribute(int location)
    {
        checkManaged();
        glDisableVertexAttribArray(location);
    }

    public int getAttributeLocation(string name)
    {
        return _attributes.get(name, -1);
    }

    public void begin()
    {
        checkManaged();

        glUseProgram(_program);
    }

    public void end()
    {
        glUseProgram(0);
    }

    private int fetchUniformLocation(string name)
    {
        return fetchUniformLocation(name, pedantic);
    }

    public int fetchUniformLocation(string name, bool pedantic)
    {
        // -2 == not yet cached
        // -1 == cached but not found
        int location = _uniforms.get(name, -2);
        if (location == -2)
        {
            version(DEBUG_SHADER)
            {
                writeln(format("Uniform not cached yet: %s", name));
            }
            
            location = glGetUniformLocation(_program, name.ptr);
            if (location == -1 && pedantic)
                throw new Exception(format("no uniform with name '%s' in shader", name));
            _uniforms[name] = location;
        }
        return location;
    }

    public void setUniformi(string name, int value)
    {
        checkManaged();
        int location = fetchUniformLocation(name);
        glUniform1i(location, value);
    }

    public void setUniformi(int location, int value)
    {
        checkManaged();
        glUniform1i(location, value);
    }

    public void setUniformMat4(string name, Mat4 value, bool transpose = false)
    {
        checkManaged();
        int location = fetchUniformLocation(name);
        glUniformMatrix4fv(location, 1, transpose, &value.m00);
    }
    public void setUniformMat4(int location, Mat4 value, bool transpose = false)
    {
        checkManaged();
        glUniformMatrix4fv(location, 1, transpose, &value.m00);
    }

    void print(in Mat4 value)
    {
        writeln("\tm00: ", value.m00);
        writeln("\tm10: ", value.m10);
        writeln("\tm20: ", value.m20);
        writeln("\tm30: ", value.m30);
        writeln("\tm01: ", value.m01);
        writeln("\tm11: ", value.m11);
        writeln("\tm21: ", value.m21);
        writeln("\tm31: ", value.m31);
        writeln("\tm02: ", value.m02);
        writeln("\tm12: ", value.m12);
        writeln("\tm22: ", value.m22);
        writeln("\tm32: ", value.m32);
        writeln("\tm03: ", value.m03);
        writeln("\tm13: ", value.m13);
        writeln("\tm23: ", value.m23);
        writeln("\tm33: ", value.m33);
    }

    int a = 0;
    public void setUniformMat4Array(string name, int count, ref Mat4[] value, bool transpose = false)
    {
        //for (int i = 0; i < value.length; i++)
        //{
        //    writeln(i);
        //    print(value[i]);
        //}
        //a++;
        //if (a == 5)
        //    throw new Exception("stop");


        checkManaged();
        int location = fetchUniformLocation(name);

        glUniformMatrix4fv(location, count, transpose, &value[0].m00);
    }

    public void setUniform4f(string name, float a, float b, float c, float d)
    {
        checkManaged();
        int location = fetchUniformLocation(name);
        glUniform4f(location, a, b, c, d);
    }
    
    public void setUniformf(int location, float value1, float value2, float value3, float value4)
    {
        checkManaged();
        glUniform4f(location, value1, value2, value3, value4);
    }

    public bool isCompiled()
    {
        return _isCompiled;
    }

    public string getLog()
    {
        return _log;
    }
}
