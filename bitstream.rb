#!/usr/bin/env ruby

class BitStream
	def initialize(str)
		@str = str.bytes.to_a
		@yp = 0 # bYte position
		@ip = 0 # bIt position
	end

	def remaining
		return ((@str.size - @yp) << 3) - @ip
	end

	# default ordering (LSB-first)
	def get(n)
		if remaining < n
			raise "Not enough bits"
		end
		bits = 0
		done = 0
		while n > 0
			if @yp >= @str.size
				raise "Not enough bits"
			end
			num_from_byte = [8 - @ip, n].min
			new_bits = (@str[@yp] >> @ip) & ((1 << num_from_byte) - 1)
			#puts "Got %u bits (%0*b) from this byte" %
			#	[num_from_byte, num_from_byte, new_bits]
			bits |= new_bits << done
			done += num_from_byte
			n -= num_from_byte
			@ip += num_from_byte
			if @ip == 8
				@yp += 1
				@ip = 0
			end
		end
		return bits
	end

	# alternative ordering (MSB-first)
	def get_reverse(n)
		bits = 0
		(0...n).each{
			bit = get(1)
			bits = (bits << 1) | bit
		}
		return bits
	end

	def byte_align
		if @ip > 0
			@ip = 0
			@yp += 1
		end
	end

	def get_bytes(n)
		byte_align
		if @yp + n > @str.size
			raise "Not enough bytes"
		end
		bytes = @str[@yp...@yp+n]
		@yp += n
		return bytes
	end

	def get_string(n)
		get_bytes(n).map(&:chr).join("")
	end

	def get_aligned_int(n)
		bytes = get_bytes(n)
		result = 0
		# LSBs need to come first - so reverse
		bytes.reverse.each{|byte|
			result = (result << 8) | byte
		}
	end

	def binary
		return @str.map{|x| "%08b" % x }.join(" ")
	end
end
