class VarSizeInt
	attr_reader :starts # allow some manual fixups

	# N.B. code_mins should have one extra entry, giving the exclusive upper
	# bound
	def initialize(code_mins, bits, start)
		@starts = {}
		@bits_for_code = {}
		bits.each_index{|i|
			nums = 1 << bits[i]
			(code_mins[i] ... code_mins[i+1]).each{|code|
				@starts[code] = start
				@bits_for_code[code] = bits[i]
				start += nums
			}
		}
	end

	def read(bitstream, code)
		value = @starts[code]
		num_bits = @bits_for_code[code]
		if num_bits > 0
			# The RFC says this is MSB-first; therefore, reverse.
			# However, empirically, it is LSB-first.
			value += bitstream.get(num_bits)
		end
		#$stderr.puts "code=#{code}, @starts[code]=#{@starts[code]}, value=#{value}"
		return value
	end
end
