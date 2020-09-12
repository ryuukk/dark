module darc.time;

import std.stdio;
import std.conv;
import std.string;
import std.datetime.stopwatch : benchmark, StopWatch, AutoStart;

StopWatch sw;

static this()
{
    sw = StopWatch(AutoStart.yes);
}

public long nanoTime()
{
    return sw.peek.total!"nsecs";
}
