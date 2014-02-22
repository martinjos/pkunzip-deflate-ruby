def huffgen(alphabet, lengths)
	group = lengths.group_by(&:to_i)
	lens = group.keys.sort
	starts = {}
	start = 0
	(1..lens[-1]).each{|len|
		num = group[len-1]
		if num
			num = num.size
		else
			num = 0
		end
		start = (start + num) << 1
		starts[len] = start
	}
	codes = [0] * alphabet.size
	lengths.each_with_index{|length, i|
		codes[i] = starts[length]
		starts[length] += 1
	}
	return codes
end
