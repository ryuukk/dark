module dark.pool;

import std.container;
import std.math;
import std.algorithm.comparison;
import std.stdio;
import std.traits;

interface IPoolable
{
    void reset();
}

abstract class Pool(T)
{
    int maxCapacity = 0;
    int peak = 0;
    T[] freeObjects;
    int count = 0;

    this(int initialSize = 16, int maxCapacity = 1024)
    {
        this.maxCapacity = maxCapacity;
        freeObjects.length = (initialSize);
    }

    protected abstract T newObject();

    T obtain()
    {
        if (count == 0)
            return newObject();

        count--;
        return freeObjects[count];
    }

    void free(T object)
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
