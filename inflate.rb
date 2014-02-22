#!/usr/bin/env ruby

require_relative 'bitstream'
require_relative 'hufftree'
require_relative 'var_size_int'
require_relative 'copy_section'

FixLLAlph = (0 .. 287).to_a
FixLLBits = [8] * (143 - 0 + 1) +
			[9] * (255 - 144 + 1) +
			[7] * (279 - 256 + 1) +
			[8] * (287 - 280 + 1)
FixLLTree = Tree.new(FixLLAlph, FixLLBits)

LLVSI = VarSizeInt.new([257, 265, 269, 273, 277, 281, 285, 286],
					   (0..5).to_a + [0],
					   3)
LLVSI.starts[285] = 258 # strange redundant case defined in RFC
DVSI = VarSizeInt.new([0, 4, 6, 8, 10, 12, 14, 16, 18,
					   20, 22, 24, 26, 28, 30],
					  (0..13).to_a,
					  1)

def inflate(str, lfh)
	b = BitStream.new(str)

	#$stderr.puts b.binary
	result = ""

	final = 0
	while final != 1
		final = b.get(1)
		type = b.get(2)
		if type == 0b00 # literal
			len = b.get_aligned_int(2)
			b.get_aligned_int(2) # just ~len
			result += b.get_string(len)
		elsif type == 0b01 # fixed Huffman
			while true
				llcode = FixLLTree.read(b)
				if llcode < 256
					result += llcode.chr
					#$stderr.puts "Done literal Huffman char (#{llcode.chr.inspect})"
				elsif llcode > 256
					#$stderr.puts "Got so far: " + result.inspect
					#$stderr.puts "Code is #{llcode}"
					len = LLVSI.read(b, llcode)
					# Order not explicitly specified by RFC -
					# but, empirically, it should be MSB-first.
					dcode = b.get_reverse(5)
					dist = DVSI.read(b, dcode)
					#$stderr.puts "dist=#{dist}, len=#{len}"
					result = copy_section(result, dist, len)
				else
					break # end of block
				end
			end
		elsif type == 0b10
			raise "Not implemented"
		else
			raise "Bad block type"
		end
	end

	return result
end
