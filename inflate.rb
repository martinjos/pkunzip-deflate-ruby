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

CodeLenOrder = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3,
				13, 2, 14, 1, 15]

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
					# This makes sense if you consider it as a "degenerate"
					# Huffman code.
					dcode = b.get_reverse(5)
					dist = DVSI.read(b, dcode)
					#$stderr.puts "dist=#{dist}, len=#{len}"
					result = copy_section(result, dist, len)
				else
					break # end of block
				end
			end
		elsif type == 0b10 # dynamic Huffman
			num_ll_clens   = b.get(5) + 257
			num_dist_clens = b.get(5) + 1
			num_clen_clens = b.get(4) + 4
			clen_clens = (0 ... num_clen_clens).map{ b.get(3) }
			#$stderr.puts clen_clens.inspect
			clen_tree = Tree.new(CodeLenOrder[0...clen_clens.size], clen_clens)
			lld_clens = []
			num_lld_clens = num_ll_clens + num_dist_clens
			while lld_clens.size < num_lld_clens
				clen_code = clen_tree.read(b)
				if clen_code < 16
					lld_clens << clen_code
				elsif clen_code == 16
					raise "No code-lengths to repeat" if lld_clens.size == 0
					rep_len = b.get(2) + 3
					lld_clens.concat [lld_clens[-1]] * rep_len
				elsif clen_code == 17
					rep_len = b.get(3) + 3
					lld_clens.concat [0] * rep_len
				elsif clen_code == 18
					rep_len = b.get(7) + 11
					lld_clens.concat [0] * rep_len
				else
					raise "Invalid code-length code"
				end
			end
			ll_clens = lld_clens[0...num_ll_clens]
			dist_clens = lld_clens[num_ll_clens..-1]
			ll_tree = Tree.new((0...num_ll_clens).to_a, ll_clens)
			dist_tree = Tree.new((0...num_dist_clens).to_a, dist_clens)
			while true
				llcode = ll_tree.read(b)
				if llcode < 256
					result += llcode.chr
					$stderr.puts "Done literal Huffman char (#{llcode.chr.inspect})"
				elsif llcode > 256
					$stderr.puts "Got so far: " + result.inspect
					$stderr.puts "Code is #{llcode}"
					len = LLVSI.read(b, llcode)
					dcode = dist_tree.read(b)
					dist = DVSI.read(b, dcode)
					$stderr.puts "dist=#{dist}, len=#{len}"
					result = copy_section(result, dist, len)
					$stderr.puts "Result: #{result.inspect}"
				else
					break # end of block
				end
			end
		else
			raise "Bad block type"
		end
	end

	return result
end
