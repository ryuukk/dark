module dark.gfx.camera;

import core.math;

import dark.math;

abstract class Camera
{
    Vec3 position = Vec3();
    Vec3 direction = Vec3(0, 0, -1);
    Vec3 up = Vec3(0, 1, 0);

    Mat4 projection = Mat4();
    Mat4 view = Mat4();
    Mat4 combined = Mat4();
    Mat4 invProjectionView = Mat4();

    float near = 1;
    float far = 100;

    float viewportWidth = 0;
    float viewportHeight = 0;

    abstract void update(bool updateFrustum = true);

    void lookAt(float x, float y, float z)
    {
        auto tmpVec = (Vec3(x, y, z) - position).nor();

        if (!tmpVec.isZero())
        {
            float dot = tmpVec.dot(up); // up and direction must ALWAYS be orthonormal vectors
            if (fabs(dot - 1) < 0.000000001f)
            {
                // Collinear
                up = direction * -1;
            }
            else if (fabs(dot + 1) < 0.000000001f)
            {
                // Collinear opposite
                up = direction;
            }
            direction = tmpVec;
            normalizeUp();
        }
    }

    void normalizeUp()
    {
        auto tmpVec = direction.crs(up).nor();
        up = tmpVec.crs(direction).nor();
    }

    void rotate(in Vec3 axis, float angle)
    {
            direction = Vec3.rotate(direction, axis, angle);
            up = Vec3.rotate(up, axis, angle);
    }
}

class OrthographicCamera : Camera
{
    float zoom = 1;

    this()
    {
        this.near = 0;
    }

    this(float viewportWidth, float viewportHeight)
    {
        this.viewportWidth = viewportWidth;
        this.viewportHeight = viewportHeight;
        this.near = 0;
        update();
    }

    override void update(bool updateFrustrum = true)
    {
        projection = Mat4.createOrthographic(zoom * -viewportWidth / 2, zoom * (viewportWidth / 2), zoom * -(viewportHeight / 2),
                zoom * viewportHeight / 2, near, far);

        view = Mat4.createLookAt(position, position + direction, up);

        combined = projection * view;

        if (updateFrustrum)
        {
            // todo: finish
        }
    }

    void setToOrtho(float viewportWidth, float viewportHeight, bool yDown = false)
    {
        if (yDown)
        {
            up = Vec3(0, -1, 0);
            direction = Vec3(0, 0, 1);
        }
        else
        {
            up = Vec3(0, 1, 0);
            direction = Vec3(0, 0, -1);
        }
        position = Vec3(zoom * viewportWidth / 2.0f, zoom * viewportHeight / 2.0f, 0);
        this.viewportWidth = viewportWidth;
        this.viewportHeight = viewportHeight;
        update();
    }

}

class PerspectiveCamera : Camera
{
    float fieldOfView = 67;

    this()
    {}

    this(float fov, float viewportWidth, float viewportHeight)
    {
        this.fieldOfView = fov;
        this.viewportWidth = viewportWidth;
        this.viewportHeight = viewportHeight;
    }

    override void update(bool updateFrustrum = true)
    {
        float aspect = viewportWidth / viewportHeight;

        projection = Mat4.createProjection(fabs(near), fabs(far), fieldOfView, aspect);

        view = Mat4.createLookAt(position, position + direction, up);
        combined = projection * view;

        if(updateFrustrum)
        {
            // todo: finish
        }
    }
}
