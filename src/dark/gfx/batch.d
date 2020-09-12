module dark.gfx.batch;

import std.algorithm.comparison : min, max;

import std.stdio;
import std.format;

import bindbc.opengl;

import dark.gfx.shader_program;
import dark.gfx.buffers;
import dark.gfx.texture;
import dark.gfx.mesh;
import dark.color;
import dark.core;
import dark.math;

string vs = "
#version 330

in vec4 a_position;
in vec4 a_color;
in vec2 a_texCoord0;

uniform mat4 u_proj;
uniform mat4 u_trans;

out vec4 v_color;
out vec2 v_texCoords;

void main() {
    v_color = a_color;
    v_color.a = v_color.a * (255.0/254.0);
    v_texCoords = a_texCoord0;
    gl_Position = u_proj * u_trans * a_position;
}
";
string fs = "
#version 330

in vec4 v_color;
in vec2 v_texCoords;

uniform sampler2D u_texture;

out vec4 f_color;

void main() {
        f_color = v_color * texture2D(u_texture, v_texCoords);
}
";

public class SpriteBatch
{
    private Mesh _mesh;

    private float[] _vertices;
    private int _idx;
    private Texture2D _lastTexture;
    private float _invTexWidth;
    private float _invTexHeight;

    private bool _drawing;

    private Mat4 _transformMatrix = Mat4.identity();
    private Mat4 _projectionMatrix = Mat4.identity();

    private bool _blendingDisabled;

    private int _blendSrcFunc = GL_SRC_ALPHA;
    private int _blendDstFunc = GL_ONE_MINUS_SRC_ALPHA;
    private int _blendSrcFuncAlpha = GL_SRC_ALPHA;
    private int _blendDstFuncAlpha = GL_ONE_MINUS_SRC_ALPHA;

    private ShaderProgram _shader;
    private ShaderProgram _customShader;
    private bool _ownsShader;

    private Color _color = Color.WHITE;

    public int renderCalls = 0;
    public int totalRenderCalls = 0;
    public int maxSpritesInBatch = 0;

    public this(int size = 1000, ShaderProgram defaultShader = null)
    {
        assert(size < 8191, "spritebatch too big");

        _mesh = new Mesh(false, size * 4, size * 6, new VertexAttribute(Usage.Position, 2, "a_position"),
                new VertexAttribute(Usage.ColorPacked, 4, "a_color"),
                new VertexAttribute(Usage.TextureCoordinates, 2, "a_texCoord0"));

        _projectionMatrix = Mat4.createOrthographicOffCenter(0f, 0f, Core.graphics.getWidth(), Core.graphics.getHeight());

        _vertices.length = size * 20;
        for (int i = 0; i < _vertices.length; i++)
            _vertices[i] = 0f;

        int len = size * 6;
        short[] indices;
        indices.length = len;
        short j = 0;
        for (int i = 0; i < len; i += 6, j += 4)
        {
            indices[i] = j;
            indices[i + 1] = cast(short)(j + 1);
            indices[i + 2] = cast(short)(j + 2);
            indices[i + 3] = cast(short)(j + 2);
            indices[i + 4] = cast(short)(j + 3);
            indices[i + 5] = cast(short) j;
        }
        _mesh.setIndices(indices);

        if (defaultShader is null)
        {
            _shader = new ShaderProgram(vs, fs);
            assert(_shader.isCompiled(), _shader.getLog());
            _ownsShader = true;
        }
        else
            _shader = defaultShader;
    }

    public void setProjectionMatrix(Mat4 projection)
    {
        assert(!_drawing, "must call end");
        _projectionMatrix = projection;
    }

    public void begin()
    {
        assert(!_drawing, "must call end");
        renderCalls = 0;

        glDepthMask(GL_FALSE);
        if (_customShader !is null)
            _customShader.begin();
        else
            _shader.begin();

        setupMatrices();
        _drawing = true;
    }

    public void end()
    {
        assert(_drawing, "must call begin");
        if (_idx > 0)
            flush();
        _lastTexture = null;
        _drawing = false;

        glDepthMask(GL_TRUE);
        if (isBlendingEnabled())
            glDisable(GL_BLEND);

        if (_customShader !is null)
            _customShader.end();
        else
            _shader.end();
    }

    public void flush()
    {
        if (_idx == 0)
            return;

        renderCalls++;
        totalRenderCalls++;

        int spritesInBatch = _idx / 20;
        if (spritesInBatch > maxSpritesInBatch)
            maxSpritesInBatch = spritesInBatch;
        int count = spritesInBatch * 6;

        _lastTexture.bind();
        _mesh.setVertices(_vertices, 0, _idx);

        if (_blendingDisabled)
        {
            glDisable(GL_BLEND);
        }
        else
        {
            glEnable(GL_BLEND);
            if (_blendSrcFunc != -1)
                glBlendFuncSeparate(_blendSrcFunc, _blendDstFunc, _blendSrcFuncAlpha, _blendDstFuncAlpha);
        }

        _mesh.render(_customShader !is null ? _customShader : _shader, GL_TRIANGLES, 0, count, true);

        _idx = 0;
    }

    private void setupMatrices()
    {
        if (_customShader !is null)
        {
            _customShader.setUniformMat4("u_proj", _projectionMatrix);
            _customShader.setUniformMat4("u_trans", _transformMatrix);
            _customShader.setUniformi("u_texture", 0);
        }
        else
        {
            _shader.setUniformMat4("u_proj", _projectionMatrix);
            _shader.setUniformMat4("u_trans", _transformMatrix);
            _shader.setUniformi("u_texture", 0);
        }
    }

    private void switchTexture(Texture2D texture)
    {
        flush();
        _lastTexture = texture;
        _invTexWidth = 1.0f / texture.getWidth();
        _invTexHeight = 1.0f / texture.getHeight();
    }

    public void draw(Texture2D texture, float x, float y, float width, float height)
    {
        assert(_drawing, "must call begin");

        if (texture != _lastTexture)
            switchTexture(texture);
        else if (_idx == _vertices.length) //
            flush();

        float fx2 = x + width;
        float fy2 = y + height;
        float u = 0;
        float v = 1;
        float u2 = 1;
        float v2 = 0;

        float color = _color.toFloatBits();

        int idx = _idx;
        _vertices[idx] = x;
        _vertices[idx + 1] = y;
        _vertices[idx + 2] = color;
        _vertices[idx + 3] = u;
        _vertices[idx + 4] = v;

        _vertices[idx + 5] = x;
        _vertices[idx + 6] = fy2;
        _vertices[idx + 7] = color;
        _vertices[idx + 8] = u;
        _vertices[idx + 9] = v2;

        _vertices[idx + 10] = fx2;
        _vertices[idx + 11] = fy2;
        _vertices[idx + 12] = color;
        _vertices[idx + 13] = u2;
        _vertices[idx + 14] = v2;

        _vertices[idx + 15] = fx2;
        _vertices[idx + 16] = y;
        _vertices[idx + 17] = color;
        _vertices[idx + 18] = u2;
        _vertices[idx + 19] = v;

        _idx = idx + 20;
    }

    public void draw(Texture2D texture, float[] v, int offset, int count)
    {
        assert(_drawing, "must call begin");

        int verticesLength = cast(int) _vertices.length;
        int remainingVertices = verticesLength;
        if (texture != _lastTexture)
            switchTexture(texture);
        else
        {
            remainingVertices -= _idx;
            if (remainingVertices == 0)
            {
                flush();
                remainingVertices = verticesLength;
            }
        }
        int copyCount = min(remainingVertices, count);

        // arraycopy(Object src, int srcPos, Object dest, int destPos, int length)
        // arraycopy(v, offset, vertices, idx, copyCount);
        _vertices[_idx .. copyCount] = v[offset .. copyCount];

        _idx += copyCount;
        count -= copyCount;
        while (count > 0)
        {
            offset += copyCount;
            flush();
            copyCount = min(verticesLength, count);

            // arraycopy(Object src, int srcPos, Object dest, int destPos, int length)
            // arraycopy(v, offset, vertices, 0, copyCount);
            _vertices[0 .. copyCount] = v[offset .. copyCount];

            _idx += copyCount;
            count -= copyCount;
        }
    }

    public bool isBlendingEnabled()
    {
        return !_blendingDisabled;
    }
}
