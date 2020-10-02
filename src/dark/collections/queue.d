module dark.collections.queue;


class Queue(T) {
private:
	T[] m_data;
	size_t m_left = 0;
	size_t m_right = 1;
	size_t m_count = 0;
	
public:
	this() {
		m_data.length = 64;
	}
	
	void put(T item) {
		if (m_left != m_right) {
			size_t index = (m_right == 0) ? (m_data.length - 1) : (m_right - 1);
			m_data[index] = item;
			++m_right;
			if (m_right == m_data.length) m_right = 0;
		}
		else {	// left == right -- create overflow space and add to it
			size_t oldLength = m_data.length;
			size_t moveAmount = oldLength - m_left;
			m_data.length = oldLength + oldLength;	// double the length
			
			m_data[($-moveAmount)..$] = m_data[m_left..oldLength];	// move data to the end of the buffer
			m_left = m_data.length - moveAmount;
			
			size_t index = (m_right == 0) ? (m_data.length - 1) : (m_right - 1);	// insert the item as normal
			m_data[index] = item;
			++m_right;
			if (m_right == m_data.length) m_right = 0;
		}

		++m_count;	// increment last in case there's an OOM error
	}
	
	T take() {
		--m_count;
		
		T ret = m_data[m_left];
		++m_left;
		if (m_left == m_data.length) m_left = 0;
		
		return ret;
	}
	
	void emptyIt() {
		m_right = m_left + 1;
		if (m_right == m_data.length) m_right = 0;
	}

	bool empty()
	{
		return count() == 0;
	}
	
	void clear()
	{
		while(!empty())
		{
			take();
		}
	}

	size_t count() {
		return m_count;
	}
}