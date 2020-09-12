module darc.util.camera_controller;

import darc.gfx.camera;
import darc.math;
import darc.input;
import darc.core;

class CameraController : InputAdapter
{
    private Camera _camera;

    private static immutable int STRAFE_LEFT = Keys.A;
    private static immutable int STRAFE_RIGHT = Keys.D;
    private static immutable int FORWARD = Keys.W;
    private static immutable int BACKWARD = Keys.S;
    private static immutable int UP = Keys.Q;
    private static immutable int DOWN = Keys.E;

    private bool _strafeLeft;
    private bool _strafeRight;
    private bool _forward;
    private bool _backward;
    private bool _up;
    private bool _down;

    private float _velocity = 10;
    private float _degreesPerPixel = 0.005f;

    this(Camera camera)
    {
        _camera = camera;
    }

    public override bool keyDown(int keycode)
    {
        switch (keycode)
        {
        case STRAFE_LEFT:
            _strafeLeft = true;
            break;
        case STRAFE_RIGHT:
            _strafeRight = true;
            break;

        case FORWARD:
            _forward = true;
            break;
        case BACKWARD:
            _backward = true;
            break;
        case UP:
            _up = true;
            break;
        case DOWN:
            _down = true;
            break;
            default: return false;
        }
        return _strafeLeft || _strafeRight || _forward || _backward || _up || _down;
    }

    public override bool keyUp(int keycode)
    {
        switch (keycode)
        {
        case STRAFE_LEFT:
            _strafeLeft = false;
            break;
        case STRAFE_RIGHT:
            _strafeRight = false;
            break;

        case FORWARD:
            _forward = false;
            break;
        case BACKWARD:
            _backward = false;
            break;
        case UP:
            _up = false;
            break;
        case DOWN:
            _down = false;
            break;
            default: return false;
        }
        return _strafeLeft || _strafeRight || _forward || _backward || _up || _down;
    }
    
    public override bool touchDragged(int screenX, int screenY, int pointer)
    {
        float deltaX = -Core.input.getDeltaX() * _degreesPerPixel;
        float deltaY = -Core.input.getDeltaY() * _degreesPerPixel;

        _camera.direction = Vec3.rotate(_camera.direction, _camera.up, deltaX);

        auto tmp = Vec3.cross(_camera.direction, _camera.up).nor();
        
        _camera.direction = Vec3.rotate(_camera.direction, tmp, deltaY);

        return true;
    }

    public void update(float dt)
    {
        if (_forward)
        {
            _camera.position += _camera.direction.nor() * (_velocity * dt);
        }

        if (_backward)
        {
            _camera.position += _camera.direction.nor() * -(_velocity * dt);
        }

        if (_strafeLeft)
        {
            _camera.position += Vec3.cross(_camera.direction, _camera.up)
                .nor() * -(_velocity * dt);
        }

        if (_strafeRight)
        {
            _camera.position += Vec3.cross(_camera.direction, _camera.up)
                .nor() * (_velocity * dt);
        }

        if (_up)
        {
            _camera.position += _camera.up.nor() * (_velocity * dt);
        }

        if (_down)
        {
            _camera.position += _camera.up.nor() * -(_velocity * dt);
        }

        _camera.update(true);
    }
}
