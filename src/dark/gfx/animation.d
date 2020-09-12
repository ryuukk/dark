module dark.gfx.animation;

import std.stdio;
import std.math;

import dark.collections.hashmap;

import dark.math;
import dark.gfx.node;
import dark.gfx.model_instance;
import dark.pool;

public class Animation
{
    public string id;
    public float duration = 0f;
    public NodeAnimation[] nodeAnimations;
}

public class NodeAnimation
{
    public Node node;
    public NodeKeyframe!Vec3[] translation;
    public NodeKeyframe!Quat[] rotation;
    public NodeKeyframe!Vec3[] scaling;
}

public struct NodeKeyframe(T)
{
    public float keytime = 0f;
    public T value;
}

public struct Transform
{
    public Vec3 translation = Vec3(0, 0, 0);
    public Quat rotation = Quat.identity;
    public Vec3 scale = Vec3(1, 1, 1);

    pragma(inline);
    public Mat4 toMat4()
    {
        return Mat4.set(translation, rotation, scale);
    }

    pragma(inline);
    public Transform idt()
    {
        translation = Vec3();
        rotation = Quat.identity;
        scale = Vec3(1f, 1f, 1f);
        return this;
    }

    pragma(inline);
    public Transform set(in Transform other)
    {
        return set(other.translation, other.rotation, other.scale);
    }

    pragma(inline);
    public Transform set(in Vec3 t, in Quat r, in Vec3 s)
    {
        translation = t;
        rotation = r;
        scale = s;
        return this;
    }

    pragma(inline);
    public Transform lerp(in Vec3 targetT, in Quat targetR, in Vec3 targetS, float alpha)
    {
        translation = Vec3.lerp(translation, targetT, alpha);
        rotation.slerp(targetR, alpha);//Quat.slerp(rotation, targetR, alpha);
        scale = Vec3.lerp(scale, targetS, alpha);
        //translation = targetT;
        //rotation = targetR;
        //scale = targetS;
        return this;
    }

    pragma(inline);
    public Transform lerp(in Transform transform, float alpha)
    {
        return lerp(transform.translation, transform.rotation, transform.scale, alpha);
    }
}


public class BaseAnimationController
{
    alias TransformMap = HashMap!(Node,Transform);
    public static TransformMap transforms;

    private bool _applying = false;
    public ModelInstance target;


    public this(ModelInstance target)
    {
        this.target = target;
    }

    protected void begin()
    {
        assert(!_applying);
        _applying = true;
    }

    protected void apply(Animation animation, float time, float weight)
    {
        assert(_applying);

        //writeln(">DEBUG: apply with transforms");
        applyAnimation(transforms, weight, animation, time, true);
    }

    protected void end()
    {
        assert(_applying);
        foreach (ref entry; transforms.byPair())
        {
            entry.key.localTransform = entry.value.toMat4();
            //pool.free(entry.value);
        }

        transforms.clear();
        
        target.calculateTransforms();
        _applying = false;
    }

    protected void removeAnimation(Animation animation)
    {
        foreach (NodeAnimation nodeAnim; animation.nodeAnimations)
            nodeAnim.node.isAnimated = false;
    }

    protected void applyAnimation(Animation animation, float time)
    {
        if (_applying)
            throw new Exception("Call end() first");

        applyAnimation(transforms, 1.0f, animation, time, false);
        target.calculateTransforms();
    }

    protected void applyAnimations(Animation anim1, float time1, Animation anim2,
            float time2, float weight)
    {
        if (anim2 is null || weight == 0.0f)
            applyAnimation(anim1, time1);
        else if (anim1 is null || weight == 1.0f)
            applyAnimation(anim2, time2);
        else if (_applying)
            throw new Exception("Call end() first");
        else
        {
            begin();
            apply(anim1, time1, 1.0f);
            apply(anim2, time2, weight);
            end();
        }
    }

    pragma(inline);
    final private static int getFirstKeyframeIndexAtTime(T)(ref NodeKeyframe!T[] arr, float time)
    {
        int lastIndex = cast(int) arr.length - 1;

        // edges cases : time out of range always return first index
        if (lastIndex <= 0 || time < arr[0].keytime || time > arr[lastIndex].keytime)
        {
            return 0;
        }
        // binary search
        int minIndex = 0;
        int maxIndex = lastIndex;

        while (minIndex < maxIndex)
        {
            int i = (minIndex + maxIndex) / 2;
            if (time > arr[i + 1].keytime)
            {
                minIndex = i + 1;
            }
            else if (time < arr[i].keytime)
            {
                maxIndex = i - 1;
            }
            else
            {
                return i;
            }
        }
        return minIndex;
    }

    final private static Vec3 getTranslationAtTime(NodeAnimation nodeAnim, float time)
    {
        if (nodeAnim.translation.length == 0)
            return nodeAnim.node.translation;
        if (nodeAnim.translation.length == 1)
            return nodeAnim.translation[0].value;

        int index = getFirstKeyframeIndexAtTime(nodeAnim.translation, time);

        auto firstKeyframe = nodeAnim.translation[index];
        Vec3 result = firstKeyframe.value;

        if (++index < nodeAnim.translation.length)
        {
            auto secondKeyframe = nodeAnim.translation[index];
            float t = (time - firstKeyframe.keytime) / (
                    secondKeyframe.keytime - firstKeyframe.keytime);
            result = Vec3.lerp(result, secondKeyframe.value, t);
            //result = secondKeyframe.value;
        }
        return result;
    }

    final private static Quat getRotationAtTime(NodeAnimation nodeAnim, float time)
    {

        if (nodeAnim.rotation.length == 0)
            return nodeAnim.node.rotation;
        if (nodeAnim.rotation.length == 1)
            return nodeAnim.rotation[0].value;

        int index = getFirstKeyframeIndexAtTime(nodeAnim.rotation, time);

        auto firstKeyframe = nodeAnim.rotation[index];
        Quat result = firstKeyframe.value;

        if (++index < nodeAnim.rotation.length)
        {
            auto secondKeyframe = nodeAnim.rotation[index];
            float t = (time - firstKeyframe.keytime) / (
                    secondKeyframe.keytime - firstKeyframe.keytime);
            //result = Quat.lerp(result, secondKeyframe.value, t);
            result.slerp(secondKeyframe.value, t);
            //result = secondKeyframe.value;
        }
        return result;
    }

    final private static Vec3 getScalingAtTime(NodeAnimation nodeAnim, float time)
    {

        if (nodeAnim.scaling.length == 0)
            return nodeAnim.node.scale;
        if (nodeAnim.scaling.length == 1)
            return nodeAnim.scaling[0].value;

        int index = getFirstKeyframeIndexAtTime(nodeAnim.scaling, time);

        auto firstKeyframe = nodeAnim.scaling[index];
        Vec3 result = firstKeyframe.value;

        if (++index < nodeAnim.scaling.length)
        {
            auto secondKeyframe = nodeAnim.scaling[index];
            float t = (time - firstKeyframe.keytime) / (
                    secondKeyframe.keytime - firstKeyframe.keytime);
            result = Vec3.lerp(result, secondKeyframe.value, t);
            //result = secondKeyframe.value;
        }
        return result;
    }

    pragma(inline);
    final private static Transform getNodeAnimationTransform(NodeAnimation nodeAnim, float time)
    {
        // todo: finish implement interpolation
        Transform transform;
        transform.translation = getTranslationAtTime(nodeAnim, time);
        transform.rotation = getRotationAtTime(nodeAnim, time);
        transform.scale = getScalingAtTime(nodeAnim, time);
        return transform;
    }

    private static void applyNodeAnimationDirectly(NodeAnimation nodeAnim, float time)
    {
        Node node = nodeAnim.node;
        node.isAnimated = true;
        Transform transform = getNodeAnimationTransform(nodeAnim, time);
        node.localTransform = transform.toMat4();
    }

    private static void applyNodeAnimationBlending(NodeAnimation nodeAnim, ref TransformMap outt, float alpha, float time)
    {
        // mem leak here, related to outt

        Node node = nodeAnim.node;
        node.isAnimated = true;
        Transform transform = getNodeAnimationTransform(nodeAnim, time);
 
        if (node in outt)
        {
            if (alpha > 0.99999f)
            {
                (outt)[node] = transform;
            }
            else
            {
                auto l = (outt).fetch(node).value.lerp(transform, alpha);
                (outt)[node] = l;
            }
        }
        else
        {
            if (alpha > 0.99999f)
                (outt)[node] = Transform().set(transform);
            else
                (outt)[node] = Transform().set(node.translation, node.rotation, node.scale).lerp(transform, alpha);
        }
    }

    protected static void applyAnimation(ref TransformMap outt, float alpha,
            Animation animation, float time, bool useOut)
    {
        if (!useOut)
        {
            for (int i = 0; i < animation.nodeAnimations.length; i++)
            {
                auto nodeAnim = animation.nodeAnimations[i];
                applyNodeAnimationDirectly(nodeAnim, time);
            }
        }
        else
        {
            foreach (ref node; outt.byKey())
            {
                node.isAnimated = false;
            }

            foreach (ref nodeAnim; animation.nodeAnimations)
            {
                applyNodeAnimationBlending(nodeAnim, outt, alpha, time);
            }

            foreach (ref e; outt.byPair())
            {
                if (!e.key.isAnimated)
                {
                    e.key.isAnimated = true;
                    e.value.lerp(e.key.translation, e.key.rotation, e.key.scale, alpha);
                }
            }
        }
    }
}

/*
public struct Transform
{
    public Vec3 translation = Vec3(0, 0, 0);
    public Quat rotation = Quat.identity;
    public Vec3 scale = Vec3(1, 1, 1);
    public static Transform identity = Transform();

    pragma(inline);
    public Mat4 toMat4()
    {
        return Mat4.set(translation, rotation, scale);
    }

    pragma(inline);
    public Transform idt()
    {
        translation = Vec3();
        rotation = Quat.identity;
        scale = Vec3(1f, 1f, 1f);
        return this;
    }

    pragma(inline);
    public ref Transform lerp(in Vec3 targetT, in Quat targetR, in Vec3 targetS, float alpha)
    {
        translation = Vec3.lerp(translation, targetT, alpha);
        rotation = Quat.lerp(rotation, targetR, alpha);
        scale = Vec3.lerp(scale, targetS, alpha);
        //translation = targetT;
        //rotation = targetR;
        //scale = targetS;
        return this;
    }

    pragma(inline);
    public ref Transform lerp(in Transform transform, float alpha)
    {
        return lerp(transform.translation, transform.rotation, transform.scale, alpha);
    }
}

public class BaseAnimationController
{
    public Transform[Node] transforms;

    private bool _applying = false;
    public ModelInstance target;

    public this(ModelInstance target)
    {
        this.target = target;
    }

    protected void begin()
    {
        assert(!_applying);
        _applying = true;
    }

    protected void apply(Animation animation, float time, float weight)
    {
        assert(_applying);

        //writeln(">DEBUG: apply with transforms");
        applyAnimation(transforms, weight, animation, time, true);
    }

    protected void end()
    {
        assert(_applying);
        foreach (ref entry; transforms.byKeyValue())
        {
            entry.key.localTransform = entry.value.toMat4();
        }
        transforms.clear();
        target.calculateTransforms();
        _applying = false;
    }

    protected void removeAnimation(Animation animation)
    {
        foreach (NodeAnimation nodeAnim; animation.nodeAnimations)
            nodeAnim.node.isAnimated = false;
    }

    protected void applyAnimation(Animation animation, float time)
    {
        if (_applying)
            throw new Exception("Call end() first");

        applyAnimation(transforms, 1.0f, animation, time, false);
        target.calculateTransforms();
    }

    protected void applyAnimations(Animation anim1, float time1, Animation anim2,
            float time2, float weight)
    {
        if (anim2 is null || weight == 0.0f)
            applyAnimation(anim1, time1);
        else if (anim1 is null || weight == 1.0f)
            applyAnimation(anim2, time2);
        else if (_applying)
            throw new Exception("Call end() first");
        else
        {
            begin();
            apply(anim1, time1, 1.0f);
            apply(anim2, time2, weight);
            end();
        }
    }

    pragma(inline);
    final private static int getFirstKeyframeIndexAtTime(T)(ref NodeKeyframe!T[] arr, float time)
    {
        int lastIndex = cast(int) arr.length - 1;

        // edges cases : time out of range always return first index
        if (lastIndex <= 0 || time < arr[0].keytime || time > arr[lastIndex].keytime)
        {
            return 0;
        }
        // binary search
        int minIndex = 0;
        int maxIndex = lastIndex;

        while (minIndex < maxIndex)
        {
            int i = (minIndex + maxIndex) / 2;
            if (time > arr[i + 1].keytime)
            {
                minIndex = i + 1;
            }
            else if (time < arr[i].keytime)
            {
                maxIndex = i - 1;
            }
            else
            {
                return i;
            }
        }
        return minIndex;
    }

    final private static Vec3 getTranslationAtTime(NodeAnimation nodeAnim, float time)
    {
        if (nodeAnim.translation.length == 0)
            return nodeAnim.node.translation;
        if (nodeAnim.translation.length == 1)
            return nodeAnim.translation[0].value;

        int index = getFirstKeyframeIndexAtTime(nodeAnim.translation, time);

        auto firstKeyframe = nodeAnim.translation[index];
        Vec3 result = firstKeyframe.value;

        if (++index < nodeAnim.translation.length)
        {
            auto secondKeyframe = nodeAnim.translation[index];
            float t = (time - firstKeyframe.keytime) / (
                    secondKeyframe.keytime - firstKeyframe.keytime);
            result = Vec3.lerp(result, secondKeyframe.value, t);
            result = secondKeyframe.value;
        }
        return result;
    }

    final private static Quat getRotationAtTime(NodeAnimation nodeAnim, float time)
    {

        if (nodeAnim.rotation.length == 0)
            return nodeAnim.node.rotation;
        if (nodeAnim.rotation.length == 1)
            return nodeAnim.rotation[0].value;

        int index = getFirstKeyframeIndexAtTime(nodeAnim.rotation, time);

        auto firstKeyframe = nodeAnim.rotation[index];
        Quat result = firstKeyframe.value;

        if (++index < nodeAnim.rotation.length)
        {
            auto secondKeyframe = nodeAnim.rotation[index];
            float t = (time - firstKeyframe.keytime) / (
                    secondKeyframe.keytime - firstKeyframe.keytime);
            result = Quat.lerp(result, secondKeyframe.value, t);
            result = secondKeyframe.value;
        }
        return result;
    }

    final private static Vec3 getScalingAtTime(NodeAnimation nodeAnim, float time)
    {

        if (nodeAnim.scaling.length == 0)
            return nodeAnim.node.scale;
        if (nodeAnim.scaling.length == 1)
            return nodeAnim.scaling[0].value;

        int index = getFirstKeyframeIndexAtTime(nodeAnim.scaling, time);

        auto firstKeyframe = nodeAnim.scaling[index];
        Vec3 result = firstKeyframe.value;

        if (++index < nodeAnim.scaling.length)
        {
            auto secondKeyframe = nodeAnim.scaling[index];
            float t = (time - firstKeyframe.keytime) / (
                    secondKeyframe.keytime - firstKeyframe.keytime);
            result = Vec3.lerp(result, secondKeyframe.value, t);
            result = secondKeyframe.value;
        }
        return result;
    }

    pragma(inline);
    final private static Transform getNodeAnimationTransform(NodeAnimation nodeAnim, float time)
    {
        // todo: finish implement interpolation
        Transform transform;
        transform.translation = getTranslationAtTime(nodeAnim, time);
        transform.rotation = getRotationAtTime(nodeAnim, time);
        transform.scale = getScalingAtTime(nodeAnim, time);
        return transform;
    }

    private static void applyNodeAnimationDirectly(NodeAnimation nodeAnim, float time)
    {
        Node node = nodeAnim.node;
        node.isAnimated = true;
        Transform transform = getNodeAnimationTransform(nodeAnim, time);
        node.localTransform = transform.toMat4();
    }

    private static void applyNodeAnimationBlending(NodeAnimation nodeAnim,
            ref Transform[Node] outt, float alpha, float time)
    {
        Node node = nodeAnim.node;
        node.isAnimated = true;
        Transform transform = getNodeAnimationTransform(nodeAnim, time);

        if (node in outt)
        {
            if (alpha > 0.99999f)
                outt[node] = transform;
            else
                outt[node] = outt[node].lerp(transform, alpha);
        }
        else
        {
            if (alpha > 0.99999f)
                outt[node] = transform;
            else
                outt[node] = Transform(node.translation, node.rotation, node.scale).lerp(transform,
                        alpha);
        }
    }

    protected static void applyAnimation(ref Transform[Node] outt, float alpha,
            Animation animation, float time, bool useOut)
    {
        if (!useOut)
        {
            for (int i = 0; i < animation.nodeAnimations.length; i++)
            {
                auto nodeAnim = animation.nodeAnimations[i];
                applyNodeAnimationDirectly(nodeAnim, time);
            }
        }
        else
        {
            foreach (ref node; outt.keys)
            {
                node.isAnimated = false;
            }

            foreach (ref nodeAnim; animation.nodeAnimations)
            {
                applyNodeAnimationBlending(nodeAnim, outt, alpha, time);
            }

            foreach (ref e; outt.byKeyValue())
            {
                if (!e.key.isAnimated)
                {
                    e.key.isAnimated = true;
                    e.value.lerp(e.key.translation, e.key.rotation, e.key.scale, alpha);
                }
            }
        }
    }
}
*/
public class AnimationDesc : IPoolable
{
    public Animation animation;
    public float speed = 0f;
    public float time = 0f;
    public float offset = 0f;
    public float duration = 0f;
    public int loopCount = 0;

    protected float update(float dt)
    {
        if (loopCount != 0 && animation !is null)
        {
            int loops = 0;
            float diff = speed * dt;
            if (duration != 0f)
            {
                time += diff;
                loops = cast(int) fabs(time / duration);
                if (time < 0f)
                {
                    loops++;
                    while (time < 0f)
                        time += duration;
                }
                time = abs(time % duration);
            }
            else
                loops = 1;

            for (int i = 0; i < loops; i++)
            {
                if (loopCount > 0)
                    loopCount--;
                if (loopCount != 0)
                {
                    //onLoop?.Invoke(this);
                }
                if (loopCount == 0)
                {
                    float result = ((loops - 1) - i) * duration + (diff < 0f
                            ? duration - time : time);
                    time = (diff < 0f) ? 0f : duration;

                    //onEnd?.Invoke(this);

                    return result;
                }
            }
            return 0f;
        }
        else
            return dt;
    }

    public override void reset()
    {
        animation = null;
        speed = 0;
        time = 0;
        offset = 0;
        duration = 0;
        loopCount = 0;
    }
}
public final class AnimationController : BaseAnimationController
{
    static Pool!AnimationDesc animationPool;
    
    public AnimationDesc current;
    public AnimationDesc queued;
    public float queuedTransitionTime = 0f;
    public AnimationDesc previous;
    public float transitionCurrentTime = 0f;
    public float transitionTargetTime = 0f;
    public bool inAction;
    public bool paused;
    public bool allowSameAnimation;
    private bool justChangedAnimation;

    static this()
    {
        animationPool = new class Pool!AnimationDesc
        {
            protected override AnimationDesc newObject()
            {
                return new AnimationDesc;
            }
        };
    }

    public this(ModelInstance target)
    {
        super(target);
    }

    private AnimationDesc obtain(Animation anim, float offset, float duration,
            int loopCount, float speed)
    {
        if (anim is null)
            return null;
        AnimationDesc result = animationPool.obtain();
        result.animation = anim;
        result.loopCount = loopCount;
        result.speed = speed;
        result.offset = offset;
        result.duration = duration < 0 ? (anim.duration - offset) : duration;
        result.time = speed < 0 ? result.duration : 0.0f;
        return result;
    }

    private AnimationDesc obtain(string id, float offset, float duration, int loopCount, float speed)
    {
        if (id.length == 0)
            return null;
        Animation anim = target.getAnimation(id);
        if (anim is null)
            throw new Exception("Unknown animation: ", id);
        return obtain(anim, offset, duration, loopCount, speed);
    }

    public void update(float delta)
    {
        if (paused)
            return;
        if (previous !is null && ((transitionCurrentTime += delta) >= transitionTargetTime))
        {
            removeAnimation(previous.animation);
            justChangedAnimation = true;
            animationPool.free(previous);
            previous = null;
        }
        if (justChangedAnimation)
        {
            target.calculateTransforms();
            justChangedAnimation = false;
        }
        if (current is null || current.loopCount == 0 || current.animation is null)
            return;
        float remain = current.update(delta);
        if (remain != 0f && queued !is null)
        {
            inAction = false;
            animate(queued, queuedTransitionTime);
            queued = null;
            update(remain);
            return;
        }
        if (previous !is null)
            applyAnimations(previous.animation, previous.offset + previous.time, current.animation,
                    current.offset + current.time, transitionCurrentTime / transitionTargetTime);
        else
            applyAnimation(current.animation, current.offset + current.time);
    }

    protected AnimationDesc animate(AnimationDesc anim, float transitionTime)
    {
        if (current is null)
            current = anim;
        else if (inAction)
            queue(anim, transitionTime);
        else if (!allowSameAnimation && anim !is null && current.animation == anim.animation)
        {
            anim.time = current.time;
            animationPool.free(current);
            current = anim;
        }
        else
        {
            if (previous !is null)
            {
                removeAnimation(previous.animation);
                animationPool.free(previous);
                previous = null;
            }
            previous = current;
            current = anim;
            transitionCurrentTime = 0f;
            transitionTargetTime = transitionTime;
        }
        return anim;
    }

    public AnimationDesc animate(string id, float offset = 0f, float duration = -1f,
            int loopCount = -1, float speed = 1, float transitionTime = 0f)
    {
        auto desc = obtain(id, offset, duration, loopCount, speed);
        return animate(desc, transitionTime);
    }

    protected AnimationDesc queue(AnimationDesc anim, float transitionTime)
    {
        if (current is null || current.loopCount == 0)
            animate(anim, transitionTime);
        else
        {
            if (queued !is null)
                animationPool.free(queued);
            queued = anim;
            queuedTransitionTime = transitionTime;
            if (current.loopCount < 0)
                current.loopCount = 1;
        }
        return anim;
    }

    public AnimationDesc setAnimation(string id, float offset = 0f,
            float duration = -1f, int loopCount = -1, float speed = 1f)
    {
        return setAnimation(obtain(id, offset, duration, loopCount, speed));
    }

    protected AnimationDesc setAnimation(AnimationDesc anim)
    {
        if (current is null)
            current = anim;
        else
        {
            if (!allowSameAnimation && anim !is null && current.animation == anim.animation)
                anim.time = current.time;
            else
                removeAnimation(current.animation);
            animationPool.free(current);
            current = anim;
        }
        justChangedAnimation = true;
        return anim;
    }

}
