module dark.io;

import dark.io.reader;
import dark.io.writer;

import std.stdio;
import std.bitmanip;
import std.file;

ubyte[] readFile(string path)
{
    auto data = cast(ubyte[]) std.file.read(path);
    return data;
}
void saveFile(string path, in ubyte[] data)
{
    std.file.write(path, data);
}

bool isFileExist(string path)
{
    return exists(path);
}