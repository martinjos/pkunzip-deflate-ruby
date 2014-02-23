def huffgen(alphabet, lengths)
	group = lengths.group_by(&:to_i)
	lens = group.keys.sort
	starts = {}
	start = 0
	(1..lens[-1]).each{|len|
		num = group[len-1]
		if num && len > 1
			num = num.size
		else
			num = 0
		end
		start = (start + num) << 1
		starts[len] = start
	}
	codes = [0] * alphabet.size
	sorted_info = [alphabet, lengths, (0...lengths.size).to_a].transpose.sort
	sorted_info.each{|symbol, length, i|
		if length != 0
			codes[i] = starts[length]
			starts[length] += 1
		end
	}
	return codes
end
