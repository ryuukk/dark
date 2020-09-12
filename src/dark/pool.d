module darc.pool;

import std.container;
import std.math;
import std.algorithm.comparison;
import std.stdio;
import std.traits;

public interface IPoolable
{
    void reset();
}

public abstract class Pool(T)
{
    public int maxCapacity = 0;
    public int peak = 0;
    public T[] freeObjects;
    public int count = 0;

    public this(int initialSize = 16, int maxCapacity = 1024)
    {
        this.maxCapacity = maxCapacity;
        freeObjects.length = (initialSize);
    }

    protected abstract T newObject();

    public T obtain()
    {
        if (count == 0)
            return newObject();

        count--;
        return freeObjects[count];
    }

    public void free(T object)
    {
        assert(object !is null, "object shouldn't be null");
    
        if(freeObjects.length <= count)
        {
            writeln("Had to increase pool:", fullyQualifiedName!T, " > ", count, "/", freeObjects.length);
            freeObjects.length = (cast(int)(count * 1.25));
        }
        freeObjects[count] = object;
        count++;
        reset(object);
    }

    protected void reset(T object)
    {
        static if( is(T IPoolable) )
        {
            (cast(IPoolable) object).reset();
        }
    }
}
