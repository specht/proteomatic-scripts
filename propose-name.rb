require 'yaml'
require 'set'


def mergeFilenames(ak_Names)
	lk_Names = ak_Names.dup

	# split into numbers/non-numbers
	ls_AllPattern = nil
	lk_AllParts = nil
	lk_Names.each do |x|
		ls_Pattern = nil
		lk_Parts = Array.new
		(0...x.size).each do |i|
			lb_IsDigit = (/\d/ =~ x[i, 1])
			ls_Marker = lb_IsDigit ? '0' : 'a'
			unless ls_Pattern
				ls_Pattern = ls_Marker 
				lk_Parts.push('')
			end
			unless ls_Pattern[-1, 1] == ls_Marker
				ls_Pattern += ls_Marker 
				lk_Parts.push('')
			end
			lk_Parts.last << x[i, 1]
		end
	
		# check whether pattern is constant
		if ls_AllPattern
			if (ls_AllPattern != ls_Pattern)
				puts 'Error: Unable to propose a merged name.'
			end
		else
			ls_AllPattern = ls_Pattern
		end
	
		# convert number strings to numbers
		(0...lk_Parts.size).each { |i| lk_Parts[i] = lk_Parts[i].to_i if ls_Pattern[i, 1] == '0' }

		# create part sets when they don't exist on first iteration
		unless lk_AllParts
			lk_AllParts = Array.new
			(0...lk_Parts.size).each { |i| lk_AllParts.push(Set.new) }
		end
	
		# insert parts into part sets
		(0...lk_Parts.size).each { |i| lk_AllParts[i].add(lk_Parts[i]) }
	end

	ls_MergedName = ''

	(0...ls_AllPattern.size).each do |i|
		lk_Part = lk_AllParts[i].to_a.sort
		if (lk_Part.size == 1)
			ls_MergedName << lk_Part.first.to_s
		else
			if (ls_AllPattern[i, 1] == '0')
				# we have multiple entries and it's a number part, try to find ranges!
				li_Start = nil
				li_Stop = nil
				li_Last = nil
				lk_OldPart = lk_Part.dup
				lk_Part = Array.new
				lk_OldPart.each do |i|
					unless li_Start 
						li_Start = i
						li_Stop = i 
						li_Last = i
						next
					end
					if i == li_Last + 1
						# extend range
						li_Stop = i
						li_Last = i
						next
					else
						if (li_Start == li_Stop)
							lk_Part << "#{li_Start}"
						else
							lk_Part << "#{li_Start}-#{li_Stop}"
						end
						li_Start = i
						li_Last = i
						li_Stop = i
					end
				end
				if (li_Start == li_Stop)
					lk_Part << "#{li_Start}"
				else
					lk_Part << "#{li_Start}-#{li_Stop}"
				end
			end
			ls_MergedName << lk_Part.join(',')
		end
	end
	return ls_MergedName
end


lk_Names = File::read('propose-names.txt').split("\n").reject { |x| x.strip.empty? }
lk_Names.collect! { |x| File::basename(x).split('.').first }

puts mergeFilenames(lk_Names)


