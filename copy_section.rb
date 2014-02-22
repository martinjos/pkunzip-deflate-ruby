def copy_section(str, dist, len)
	pos = str.size - dist
	rlen = len
	while rlen > 0
		chunk_len = [rlen, dist].min
		str += str[pos ... pos + chunk_len]
		rlen -= chunk_len
		pos += chunk_len
	end
	#$stderr.puts "Result: " + str.inspect
	return str
end
