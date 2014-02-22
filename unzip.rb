#!/usr/bin/env ruby

require_relative 'inflate'

class ZipFile

	BadFile = "Invalid or unsupported file"

	def self.magic(a, b)
		"PK" + a.chr + b.chr
	end

	Magic_EOCD = self.magic(5, 6)
	Magic_CFH = self.magic(1, 2)

	EOCD = Struct.new(:sig, :diskno, :stcd_diskno, :disk_cdents, :cdents,
					  :cdsize, :cdoffs, :comm_len, :comm)
	EOCD_PackStr = "a4S<4L<2S<a*"

	CFH = Struct.new(:sig, :src_ver, :targ_ver, :bits, :comp, :mod_time,
				     :mod_date, :crc, :comp_size, :uncomp_size, :fname_len,
					 :extra_len, :comm_len, :st_diskno, :int_attrs,
					 :ext_attrs, :local_offs, :fname, :extra, :comm)
	CFH_PackStr = "a4S<6L<3S<5L<2"
	CFH_Len = 46

	LFH = Struct.new(:sig, :targ_ver, :bits, :comp, :mod_time, :mod_date,
					 :crc, :comp_size, :uncomp_size, :fname_len, :extra_len,
					:fname, :extra)
	LFH_PackStr = "a4S<5L<3S<2"
	LFH_Len = 30

	def initialize(fname)

		@fname = fname

		@f = File.read(fname, {
			external_encoding: Encoding::ASCII_8BIT,
			internal_encoding: nil,
			binmode: true,
		})
		eocd_pos = @f.rindex(Magic_EOCD) or raise BadFile
		eocd_str = @f[eocd_pos .. -1]
		eocd = EOCD.new(*@f[eocd_pos .. -1].unpack(EOCD_PackStr))
		if eocd.diskno != 0 || eocd.stcd_diskno != 0 ||
		   eocd.disk_cdents != eocd.cdents
			$stderr.puts eocd.inspect
			raise BadFile
		end
		cd = @f[eocd.cdoffs ... eocd.cdoffs + eocd.cdsize]

		pos = 0
		@ents = []
		while cd.size >= CFH_Len + pos
			ent = CFH.new(*(cd[pos...pos+CFH_Len].unpack(CFH_PackStr) +
						  [""]*3))
			if ent.sig != Magic_CFH
				$stderr.puts "Got #{@ents.size} ents so far"
				raise BadFile
			end
			pos += CFH_Len
			endpos = pos + ent.fname_len
			ent.fname = cd[pos ... endpos]
			pos = endpos
			endpos += ent.extra_len
			ent.extra = cd[pos ... endpos]
			pos = endpos
			endpos += ent.comm_len
			ent.extra = cd[pos ... endpos]
			pos = endpos
			@ents << ent
		end
		if cd.size > pos
			$stderr.puts "Warning: trailing bytes in central directory"
		end
		if @ents.size != eocd.cdents
			$stderr.puts "Warning: wrong number of central directory entries"
		end

	end

	def inspect_filenames

		@ents.each{|ent|
			puts "%u - %s" % [ent.comp, ent.fname.inspect]
		}

	end

	def get_ent(i)
		raise "Invalid index" if i < 0 || i >= @ents.size
		ent = @ents[i]
		return ent
	end

	def get_raw(i)
		ent = get_ent(i)
		raise "Encryption not supported" if ent.bits & 1 != 0

		pos = ent.local_offs
		endpos = pos + LFH_Len
		lfhstr = @f[pos ... endpos]
		lfh = LFH.new(*(lfhstr.unpack(LFH_PackStr) + [""]*2))
		pos = endpos
		endpos += lfh.fname_len
		lfh.fname = @f[pos ... endpos]
		pos = endpos
		endpos += lfh.extra_len
		lfh.extra = @f[pos ... endpos]
		pos = endpos

		if lfh.fname_len != ent.fname_len
			$stderr.puts "Warning: filename length differs"
		end

		# Seems quite common
		#if lfh.extra_len != ent.extra_len
		#	$stderr.puts "Warning: extra length differs: #{lfh.extra_len} != #{ent.extra_len}"
		#end

		#$stderr.puts lfh.sig.inspect

		endpos += lfh.comp_size
		raw = @f[pos ... endpos]

		return [raw, lfh]
	end

	def get(i)
		(str, lfh) = get_raw(i)
		if ![0, 8].member? lfh.comp
			raise "Compression method not supported: #{lfh.comp}"
		end
		if lfh.comp == 8
			str = inflate(str, lfh)
		end
		return str
	end

end

if __FILE__ == $0
	z = ZipFile.new(ARGV[0])
	if ARGV.size < 2
		z.inspect_filenames
	else
		#puts z.get_raw(ARGV[1].to_i).first.inspect
		puts z.get(ARGV[1].to_i).inspect
	end
end
