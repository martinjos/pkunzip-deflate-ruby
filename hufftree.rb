require_relative 'huffgen'

class Tree
	attr_reader :tree

	class Node
		def initialize
			@vals = [nil, nil]
		end

		def value
			if @vals.is_a? Array
				return nil
			else
				return @vals
			end
		end
		
		def set(y)
			@vals = y
		end

		# only use if !value
		def [](x)
			if !@vals[x]
				@vals[x] = Node.new
			end
			@vals[x]
		end
	end

	def initialize(alphabet, lengths)
		@alphabet = alphabet
		@lengths = lengths
		@code = huffgen(alphabet, lengths)
		@tree = Node.new
		@alphabet.each_index{|i|
			add(@code[i], @lengths[i], @alphabet[i])
		}
	end

	def add(code, length, value)
		node = @tree
		(0...length).to_a.reverse.each{|i|
			node = node[(code >> i) & 1]
		}
		node.set value
	end

	def read(bitstream)
		node = @tree
		while !node.value
			node = node[bitstream.get(1)]
		end
		return node.value
	end
end
