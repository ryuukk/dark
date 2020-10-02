module dark.collections.array_map;

import std.math;
import std.algorithm.comparison;


// todo: make it a struct
class ArrayMap(K, V)
{
    K[] keys;
    V[] values;
    int  size;
    bool ordered;

    this(bool ordered = true, int capacity = 16)
    {
        this.ordered = ordered;
        keys  .length = capacity;
        values.length = capacity;
    }

    int put(K key, V value)
    {
        int index = indexOfKey(key);
        if(index == -1)
        {
            if(size == keys.length)
                resize(size + 1);
            index = size++;
        }

        keys[index] = key;
        values[index] = value;
        return index;
    }

    void putAll(ArrayMap!(K, V) map)
    {
        putAll(map, 0, map.size);
    }

    void putAll(ArrayMap!(K, V) map, int offset, int length)
    {
        if(offset + length > map.size) throw new Exception("noope");
        int sizeNeeded = size + length - offset;
        if (sizeNeeded >= keys.length) resize(max(8, cast(int) (sizeNeeded * 1.75f)));

        size = 0;
        keys.length = map.keys.length;
        values.length = map.values.length;
        for (int i = 0; i < map.size; i++)
        {
            put(map.keys[i], map.values[i]);
        }
    }

    int indexOfKey(K key)
    {
        for(int i = 0; i < cast(int) keys.length; i++)
        {
            if(keys[i] == key) return i;
        }
        return -1;
    }

    void resize(int newSize)
    {
        keys.length = newSize;
        values.length = newSize;
    }

    void clear()
    {
        resize(0);
    }
}