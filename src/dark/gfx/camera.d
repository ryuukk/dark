module darc.gfx.camera;

import core.math;

import darc.math;

public abstract class Camera
{
    public Vec3 position = Vec3();
    public Vec3 direction = Vec3(0, 0, -1);
    public Vec3 up = Vec3(0, 1, 0);

    public Mat4 projection = Mat4();
    public Mat4 view = Mat4();
    public Mat4 combined = Mat4();
    public Mat4 invProjectionView = Mat4();

    public float near = 1;
    public float far = 100;

    public float viewportWidth = 0;
    public float viewportHeight = 0;

    public abstract void update(bool updateFrustum = true);

    public void lookAt(float x, float y, float z)
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

    public void normalizeUp()
    {
        auto tmpVec = direction.crs(up).nor();
        up = tmpVec.crs(direction).nor();
    }

    public void rotate(Vec3 axis, float angle)
    {
        direction.rotate(axis, angle);
        up.rotate(axis, angle);
    }
}

public class OrthographicCamera : Camera
{
    public float zoom = 1;

    public this()
    {
        this.near = 0;
    }

    public this(float viewportWidth, float viewportHeight)
    {
        this.viewportWidth = viewportWidth;
        this.viewportHeight = viewportHeight;
        this.near = 0;
        update();
    }

    public override void update(bool updateFrustrum = true)
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

    public void setToOrtho(float viewportWidth, float viewportHeight, bool yDown = false)
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

public class PerspectiveCamera : Camera
{
    public float fieldOfView = 67;

    public this()
    {}

    public this(float fov, float viewportWidth, float viewportHeight)
    {
        this.fieldOfView = fov;
        this.viewportWidth = viewportWidth;
        this.viewportHeight = viewportHeight;
    }

    public override void update(bool updateFrustrum = true)
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
