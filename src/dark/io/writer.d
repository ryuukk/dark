module dark.io.writer;

import std.stdio;
import std.bitmanip;
import std.file;

class BinaryWriter
{
	ubyte[] _data;
	uint _index;

	this(int bufferSize = 4096)
	{
		_data.length = bufferSize;
		_index = 0;
	}

	ubyte[] getRange()
	{
		return _data[0 .. _index];
	}

    void reset()
    {
		_data.length = 4096;
		for(int i = 0; i < _data.length; i++)
		{
			_data[i] = 0;
		}
        _index = 0;
    }

	void writeByte(ubyte data)
	{
		if (_data.length < _index + 1)
		{
			_data.length = cast(uint)(_data.length * 1.2f);
			writeln("DEBUG: resize buffer: ", _data.length);
		}
		_data[_index] = data;
		_index++;
	}

	void writeBytes(in ubyte[] data)
	{
		if (_data.length < _index + data.length)
		{
			_data.length = cast(uint)(_data.length * 1.2f);
			writeln("DEBUG: resize buffer: ", _data.length);
		}
		for (int i = 0; i < data.length; i++)
		{
			_data[_index + i] = data[i];
		}
		_index += data.length;
	}

	void writeFloat(float data)
	{
		ubyte[4] value = nativeToBigEndian(data);
		writeBytes(value);
	}

	void writeInt(int data)
	 {
		ubyte[4] value = nativeToBigEndian(data);
		writeBytes(value);
	}

	void writeUInt(uint data)
	 {
		ubyte[4] value = nativeToBigEndian(data);
		writeBytes(value);
	}

	void writeShort(short data)
	 {
		ubyte[2] value = nativeToBigEndian(data);
		writeBytes(value);
	}

	void writeUShort(ushort data)
	 {
		ubyte[2] value = nativeToBigEndian(data);
		writeBytes(value);
	}

	void writeDouble(double data)
	{
		ubyte[8] value = nativeToBigEndian(data);
		writeBytes(value);
	}

	void writeUTF(in char[] data)
	{
		int size = cast(int)data.length;
		ubyte[] string = cast(ubyte[])data;
		writeInt(size);
		writeBytes(string);
	}
	void writeString(in char[] data)
	{
		short size = cast(short)data.length;
		ubyte[] string = cast(ubyte[])data;
		writeShort(size);
		writeBytes(string);
	}

	void writeUTFBytes(in char[] data)
	 {
		ubyte[] str = cast(ubyte[])data;
		writeBytes(str);
	}

	void writeBool(bool data)
	{
		if(data) writeByte(1);
		if(!data) writeByte(0);
	}

	ubyte[] getData()
	{
		return _data;
	}
}