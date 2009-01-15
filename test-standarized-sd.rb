require 'yaml'

def meanAndStandardDeviation(ak_Values)
	ld_Mean = 0.0
	ld_Sd = 0.0
	ak_Values.each { |x| ld_Mean += x }
	ld_Mean /= ak_Values.size
	ak_Values.each { |x| ld_Sd += ((x - ld_Mean) ** 2.0) }
	ld_Sd /= ak_Values.size
	ld_Sd = Math.sqrt(ld_Sd)
	return ld_Mean, ld_Sd
end

def standarize(ak_Values)
	ld_Mean, ld_Sd = meanAndStandardDeviation(ak_Values)
	lk_Values = Array.new
	ak_Values.each do |ld_Value|
		lk_Values.push((ld_Value - ld_Mean) / ld_Sd)
	end
	return lk_Values
end


lk_One = [3.0, 4.0, 3.2, 3.6, 4.1, 3.7]
lk_Two = [6.0, 6.2, 5.9, 5.7, 6.1, 6.2]

lk_Quotient = Array.new
(0...lk_One.size).each do |i|
	lk_Quotient.push(lk_One[i] / lk_Two[i])
end

puts lk_Quotient.to_yaml
ld_Mean, ld_Sd = meanAndStandardDeviation(lk_Quotient)
puts "mean: #{ld_Mean}, sd: #{ld_Sd}"

lk_StandarizedQuotient = standarize(lk_Quotient)
puts lk_StandarizedQuotient.to_yaml
ld_Mean, ld_Sd = meanAndStandardDeviation(lk_StandarizedQuotient)
puts "mean: #{ld_Mean}, sd: #{ld_Sd}"
