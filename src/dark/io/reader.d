module dark.io.reader;

import std.stdio;
import std.bitmanip;
import std.file;

class BinaryReader
{
	ubyte[] _data;
	int currentPos;

	bool littleEndian = false;

	this(ubyte[] data = [], int offset = 0)
	{
		_data = data;
		currentPos = offset;
	}

	void reset(ubyte[] data)
	{
		_data = data;
		currentPos = 0;
	}

	// todo: use that?
	bool check(int amount)
	{
		if(_data.length < currentPos + amount) return false;
		return true;
	}

	ubyte readByte()
	{
		ubyte value = _data[currentPos];
		currentPos++;
		return value;
	}

	ubyte[] readBytes(ushort len)
	{
		ubyte[] value = new ubyte[len];
		for (int i = 0; i < len; i++)
		{
			value[i] = readByte();
		}
		//_data = _data[len..$];
		return value;
	}

	float readFloat()
	{
		ubyte[4] data = readBytes(4);
		if (littleEndian)
			return *cast(float*) data;
		else
			return bigEndianToNative!float(data);
	}

	int readInt()
	{
		ubyte[4] data = readBytes(4);
		if (littleEndian)
			return *cast(int*) data;
		else
			return bigEndianToNative!int(data);
	}

	uint readUInt()
	{
		ubyte[4] data = readBytes(4);
		if (littleEndian)
			return *cast(uint*) data;
		else
			return bigEndianToNative!uint(data);
	}

	short readShort()
	{
		ubyte[2] data = readBytes(2);

		if (littleEndian)
			return *cast(short*) data;
		else
			return bigEndianToNative!(short,2)(data);
	}

	ushort readUShort()
	{
		ubyte[2] data = readBytes(2);
		if (littleEndian)
			return *cast(ushort*) data;
		else
			return bigEndianToNative!ushort(data);
	}

	double readDouble()
	{
		ubyte[8] data = readBytes(8);
		if (littleEndian)
			return *cast(double*) data;
		else
			return bigEndianToNative!double(data);
	}

	int read7bitEncodedInt()
	{
		int num1 = 0;
		int num2 = 0;
		while (num2 != 35)
		{
			byte num3 = readByte();
			num1 |= (cast(int) num3 & cast(int) byte.max) << num2;
			num2 += 7;
			if ((cast(int) num3 & 128) == 0)
				return num1;
		}
		throw new Exception("unknown");
	}

	string readString()
	{
		short l = readShort();
		auto data = readBytes(cast(ushort) l);
		return cast(string) cast(char[]) data;
	}

	string readUTF32()
	{
		int l = readInt();
		auto data = readBytes(cast(ushort) l);
		return cast(string) cast(char[]) data;
	}

	string readCSHARPString()
	{
		int size = read7bitEncodedInt();
		if (size == 0)
			return "";
		ubyte[] data = readBytes(cast(ushort) size);
		return cast(string) cast(char[]) data;
	}

	char[] readUTFBytes(ushort size)
	{
		ubyte[] data = readBytes(size);
		char[] string = cast(char[]) data;
		return string;
	}

	bool readBool()
	{
		bool value = true;
		if (readByte() == 0)
			return false;
		return value;
	}

	ubyte[] getData()
	{
		return _data;
	}

	void seek(int pos)
	{
		currentPos = pos;
	}

	ushort bytesAvailable()
	{
		return cast(ushort)(this._data.length - currentPos);
	}
}
