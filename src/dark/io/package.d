module dark.io;

public import dark.io.reader;
public import dark.io.writer;

import std.stdio;
import std.bitmanip;
import std.file;

public ubyte[] readFile(string path)
{
    auto data = cast(ubyte[]) std.file.read(path);
    return data;
}
public void saveFile(string path, in ubyte[] data)
{
    std.file.write(path, data);
}

public bool isFileExist(string path)
{
    return exists(path);
}