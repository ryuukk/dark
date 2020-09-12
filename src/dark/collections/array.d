module darc.collections.array;

import darc.math;
import std.stdio;
import std.algorithm.mutation : copy;

// todo: make it a struct
public class DelayedRemovalArray(T)
{
    public Array!T array;
    public Array!int _remove;
    private int _iterating;
    private int _clear;
}


// todo: make it a struct
public class Array(T)
{
    private T[] _items;
    private int _count = 0;
    private int _version = 0;

    public int count()
    {
        return _count;
    }

    ref T opIndex(int index)
    {
        if ((index < 0) || (index >= _count))
            throw new Exception("out of bound");
        return _items[index];
    }

    void opIndexAssign(T value, in int index)
    {
        if (index >= _count)
            throw new Exception("out of bound");
        _items[index] = value;
        ++_version;
    }

    int opApply(int delegate(ref T) dg)
    {
        int result;
        //foreach (ref T item; _items)
        for(int i = 0; i < _count; i++)
            if ((result = dg(_items[i])) != 0)
                break;
        return result;
    }

    public T get(int index)
    {
        if ((index < 0) || (index >= _count))
            throw new Exception("out of bound");
        return _items[index];
    }

    public void set(int index, ref T value)
    {
        if (index >= _count)
            throw new Exception("out of bound");
        _items[index] = value;
        ++_version;
    }

    public void ensureCapacity(int newSize)
    {
        int originalLength = cast(int) _items.length;
        int diff = newSize - originalLength;
        _items.length = newSize;

        if (diff > 0)
        {
            // todo: fill stuff with default values
            for (int i = originalLength; i < originalLength + diff; i++)
            {
                _items[i] = T.init;
            }
        }
    }

    private void shiftRight(size_t index, int amount)
    {
        _items.length += amount;
        for (size_t i = _items.length - 1; i > index; i--)
            _items[i] = _items[i - 1];
    }

    public void clear()
    {
        for (int i = 0; i < _items.length; i++)
        {
            _items[i] = T.init;
        }

        _count = 0;
        _version++;
    }

    public void add(T item)
    {
        auto length = cast(int) _items.length;
        if (_count + 1 > length)
        {
            auto expand = (length < 1000) ? (length + 1) * 4 : 1000;

            ensureCapacity(length + expand);
        }

        _items[_count++] = item;
        _version++;
    }

    public void addAll(ref Array!T items)
    {
        // todo: optimize
        for(int i = 0; i < items.count(); i++)
            add(items[i]);
    }

    public bool remove(ref T item)
    {
        int index = indexOf(item);
        if (index < 0)
            return false;
        removeAt(index);
        return true;
    }

    public int indexOf(T item)
    {
        for (int i = 0; i < _count - 1; i++)
        {
            if (_items[i] == item)
                return i;
        }
        return -1;
    }

    public T removeAt(int index)
    {
        if (index > _count)
            throw new Exception("out of bound");

        _count--;
        auto removed = _items[index];
        for (int i = index; i < _count - 1; i++)
            _items[i] = _items[i + 1];
        _items.length = _items.length - 1;
        _version++;

        return removed;
    }

    

    unittest {
        auto array = new Array!int;

        assert(array.count == 0);
        array.add(5);
        array.add(10);
        array.add(15);
        assert(array.count == 3);

        assert(array[2] == 10);

        array.removeAt(2);
        assert(array[2] == 15);
    }
}
