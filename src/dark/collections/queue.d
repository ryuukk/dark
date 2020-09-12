module dark.collections.queue;


// todo: make it a struct
class Queue(T)
{
    protected T[] values;
    protected int head = 0;
    protected int tail = 0;
    public int size = 0;

    this(int initialSize)
    {
        values.length = initialSize;
    }

    public void addLast(in T value)
    {
        if (size == values.length)
        {
            resize(values.length << 1); // * 2
        }

        values[tail++] = value;
        if (tail == values.length)
        {
            tail = 0;
        }
        size++;
    }

    public void resize(int newSize)
    {
        int head = this.head;
        int tail = this.tail;

    }
}
