# Copyright (c) 2010 Michael Specht
# 
# This file is part of Proteomatic.
# 
# Proteomatic is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# Proteomatic is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with Proteomatic.  If not, see <http://www.gnu.org/licenses/>.

require 'include/ruby/proteomatic'
require 'yaml'
require 'set'


class CheckMod < ProteomaticScript
	def run()
		lk_Masses = {'G' => 57.021464, 'A' => 71.037114, 'S' => 87.032029,
			'P' => 97.052764, 'V' => 99.068414, 'T' => 101.04768, 'C' => 103.00919,
			'L' => 113.08406, 'I' => 113.08406, 'N' => 114.04293, 'D' => 115.02694,
			'Q' => 128.05858, 'K' => 128.09496, 'E' => 129.04259, 'M' => 131.04048,
			'H' => 137.05891, 'F' => 147.06841, 'R' => 156.10111, 'Y' => 163.06333,
			'W' => 186.07931, '$' => 0.0, 'X' => 0.0}
		ld_Water = 18.01057
		# UNSURE ABOUT THIS VALUE BUT OK WITH BIANCAS EXAMPLES, should be 1.0078250
		ld_Hydrogen = 1.0073250
        ld_Phosphorylation = 79.966330408
        
        puts "Hallo Kerstin."
        peptide = @param[:peptide]
        puts "Hello, the peptide is #{peptide}"
        
        ions = Hash.new
        
        # collect b ions
        fragmentMass = 0.0
        (0...peptide.size).each do |i|
            aa = peptide[i, 1]
            fragmentMass += lk_Masses[aa.upcase]
            if aa =~ /[a-z]/
                fragmentMass += ld_Phosphorylation
            end
            ions[{:origin => "b#{i + 1}", :mods => Set.new, :score => 1.0}] = fragmentMass
        end
        
        # collect y ions
        fragmentMass = ld_Water
        (0...peptide.size).each do |i|
            aa = peptide[peptide.size - i - 1, 1]
            fragmentMass += lk_Masses[aa.upcase]
            if aa =~ /[a-z]/
                fragmentMass += ld_Phosphorylation
            end
            ions[{:origin => "y#{i + 1}", :mods => Set.new, :score => 1.0}] = fragmentMass
        end
        

        # add water loss
        newIons = Hash.new
        (0..5).each do |i|
            ions.each do |key, mass|
                newKey = YAML::load(key.to_yaml)
                newKey[:mods] << "-#{i}H20" if i > 0
                newKey[:score] *= 0.5 ** i
                newIons[newKey] = mass - ld_Water * i
            end
        end
        ions = YAML::load(newIons.to_yaml)
        
        # add PA loss
        newIons = Hash.new
        (0..1).each do |i|
            ions.each do |key, mass|
                newKey = YAML::load(key.to_yaml)
                newKey[:mods] << "-H3PO4" if i > 0
                newKey[:score] *= 0.5 if i > 0
                newIons[newKey] = mass - (ld_Phosphorylation + ld_Water) * i
            end
        end
        ions = YAML::load(newIons.to_yaml)
        
        # add charge states
        oldIons = ions.dup
        ions = Hash.new
        (1..@param[:charge]).each do |i|
            oldIons.each do |key, mass|
                newKey = key.dup
                newKey[:charge] = i
                ions[newKey] = (mass + i * ld_Hydrogen) / i
            end
        end
        
#         ions.keys.each do |key|
#             puts "#{key[:origin]}#{key[:mods].to_a.sort.join(' ')} (#{key[:charge]}+): #{ions[key]} / #{key[:score]}"
#         end
        peaks = Array.new
        DATA.each_line do |line|
            lineArray = line.split(',')
            mz = lineArray[0].to_f
            intensity = lineArray[1].to_f
            peaks << [mz, intensity]
        end
#         puts peaks.to_yaml
        minMz = peaks.collect { |x| x.first}.min
        maxMz = peaks.collect { |x| x.first}.max
        maxIntensity = peaks.collect { |x| x[1]}.max
        puts "m/z range is #{minMz} - #{maxMz}, max intensity is #{maxIntensity}"
        
        puts "There are #{peaks.size} peaks in the scan."
        peaks.reject! do |x|
            x[1] / maxIntensity < 0.10
        end
        puts "After filtering out the low peaks, there are #{peaks.size} peaks left."
        
        errors = Array.new
        intensities = Array.new
        ids = Array.new
        scores = Array.new
        
        ions.each do |key, mz|
            next unless (minMz..maxMz).include?(mz)
            matches = Array.new
            # :TODO: do a binary search here, it's faster
            peaks.each do |peak|
                error = ((mz - peak[0]) / mz * 1000000.0).abs
                matches << peak if error <= 700.0
            end
            next if matches.empty?
            # select higher peak if multiple matches
            if matches.size > 1
                matches.sort! { |x, y| y[1] <=> x[1] }
            end
            match = matches.first
            error = ((mz - match[0]) / mz * 1000000.0).abs
            errors << error
            intensities << match[1] / maxIntensity
            ids << "#{key[:origin]}#{key[:mods].to_a.sort.join('')} (#{key[:charge]}+)"
            scores << key[:score] * (match[1] / maxIntensity)
        end
        
        puts "Matching peaks: #{errors.size}."
        averageIntensity = intensities.inject { |x, y| x + y } / intensities.size
        puts "Average intensity is #{averageIntensity * 100.0}."
        medianIntensity = intensities[intensities.size / 2]
        puts "Median intensity is #{medianIntensity * 100.0}."
        averageError = errors.inject { |x, y| x + y } / errors.size
        puts "Average error is #{averageError} ppm."
        medianError = errors[errors.size / 2]
        puts "Median error is #{medianError} ppm."
        averageScore = scores.inject { |x, y| x + y }
        puts "Score is #{averageScore}."
        
#         puts ids.join("\n")
        
#         (0...peaks.size - 1).each do |i|
#             puts peaks[i + 1][0] - peaks[i][0]
#         end
    end		
end

lk_Object = CheckMod.new

__END__
325.0997,4.3515
325.9591,9.2619
337.9499,10.1572
340.8347,12.3582
356.1327,17.2171
360.0736,10.0357
368.8688,9.0567
372.2350,2.4063
384.8211,1.7869
389.1370,29.3872
390.9561,20.3907
395.9570,3.4721
408.2866,6.8932
409.9566,8.8263
416.9640,13.1687
423.2391,9.8188
426.1980,17.0617
429.7797,11.8973
431.8961,4.1321
434.7139,11.4337
438.0282,9.5028
440.0391,4.4945
443.7283,2.3951
451.0290,3.2631
453.2498,13.8643
454.9400,5.0025
463.1439,5.6512
467.3625,8.4120
468.2342,4.9272
474.8707,2.1768
495.3923,11.3699
499.7698,11.5501
506.6467,5.0006
507.3790,8.1645
517.9809,2.6228
519.2370,2.1891
525.0071,20.1581
531.1530,6.7429
537.0419,3.0377
539.1774,27.4956
540.9533,4.2774
545.1689,4.7260
552.4549,12.7097
557.0847,4.1707
564.7441,3.5190
572.2523,9.1976
573.0529,7.3060
580.1658,8.7682
581.2065,16.8786
582.0505,10.8600
583.4121,9.1992
590.7462,15.7446
594.1215,16.7491
594.8542,12.8417
597.5923,27.3329
598.6650,18.3001
602.2863,8.4172
609.9911,2.8344
612.0870,14.4482
612.9052,12.0849
614.0491,10.5523
616.2421,14.7271
624.0911,6.3100
629.0464,7.3528
632.8885,4.4221
636.0180,3.9162
637.1652,8.3305
638.0712,8.8256
638.9118,4.7242
641.9489,9.9385
644.4457,20.4986
647.0018,17.1918
648.1281,25.9715
648.8130,3.2743
650.3590,15.7190
656.8625,1.7453
659.5222,10.8010
664.2299,4.3593
665.0226,14.7864
665.9260,5.6577
673.0695,6.3385
674.8420,6.9607
678.8809,3.7485
682.3833,4.2607
683.1128,6.2562
692.2619,31.3478
694.9429,19.6614
696.1387,6.5179
699.4473,12.6480
700.7388,78.1229
701.3462,2.4860
711.7984,12.0855
715.8788,14.4467
716.9937,10.9676
718.0673,5.0052
721.8834,17.2936
728.5919,19.2748
730.2239,21.8658
733.8297,34.7282
734.7312,4.1331
738.2923,2.8203
740.7375,11.7967
741.5674,5.0413
744.6855,3.9175
749.7669,3.4822
757.1063,19.8953
757.8851,29.2001
762.8564,6.6718
764.2628,67.5515
765.1955,21.7143
767.0464,11.8669
769.9412,24.4264
770.6979,12.7264
774.4216,2.8315
775.3413,10.9926
782.0290,12.3279
782.8880,33.1177
792.6769,17.0230
803.9837,3.7377
806.1603,30.0923
806.8591,44.7297
809.7574,6.9600
811.2260,17.0219
812.3078,21.8062
814.1691,18.6861
815.3402,32.1936
816.1003,4.1345
819.9627,5.7852
821.2567,2.1812
822.9869,16.3640
824.5181,9.4938
825.5352,23.6653
826.7576,3.7012
828.7867,27.5859
830.1889,7.7394
831.6263,49.1044
832.9664,18.3963
834.1600,6.8994
834.7872,3.8514
836.0711,48.8931
836.7571,10.9120
840.1608,31.9404
840.7990,65.0288
842.8531,5.6554
851.8120,8.4741
852.9228,20.2874
853.5772,2.5853
855.1378,25.8558
855.8187,17.2919
869.6263,76.1633
871.5739,56.9678
873.3074,39.2968
874.2589,20.2055
875.8322,40.6176
876.4484,14.0618
877.1469,61.9717
879.7885,45.6435
880.7827,38.3140
881.8401,20.4422
882.4855,62.6452
883.4852,17.0638
885.9148,183.9465
886.7584,63.1268
889.0347,52.6780
889.8096,24.0807
891.2197,6.9175
895.8752,3.6912
904.9808,8.1898
906.2286,5.6517
908.0427,10.3524
910.3124,13.8099
911.2093,2.7570
912.4081,19.5452
913.1606,6.1494
916.0498,39.6510
921.4604,22.9171
923.3395,16.0448
931.3069,7.7498
934.0666,147.8096
935.3229,19.2330
940.4022,6.7373
943.1702,5.0074
945.8859,3.6961
949.0555,5.2844
956.3145,15.9178
961.1710,8.9064
962.9152,5.9283
964.6306,11.4400
968.2422,3.1131
969.0473,3.7601
974.0135,38.5044
974.7932,6.8866
979.7745,23.8103
981.1290,7.5365
981.7899,9.5019
990.9662,11.5822
1000.3011,9.2669
1001.7722,6.7387
1002.7036,17.5811
1007.4736,13.3196
1013.4774,18.8258
1016.3484,21.9561
1021.5054,22.1136
1024.3501,14.0262
1029.3341,24.6145
1030.1962,8.6373
1030.8977,3.2644
1032.3345,12.3099
1033.2455,12.4896
1033.9998,4.3493
1039.5005,8.8514
1042.0432,9.3007
1047.6898,11.7100
1051.4082,4.3457
1052.2695,16.0140
1058.2058,16.8664
1062.1274,15.6265
1066.4025,82.6769
1067.0291,24.8654
1068.0946,4.1340
1069.5409,11.2805
1072.0820,10.1056
1078.5491,7.1338
1079.8888,6.2900
1080.9005,10.1560
1082.7584,19.5645
1084.7544,5.8959
1088.5742,3.7081
1093.3550,21.4490
1094.1565,5.4022
1104.0708,99.2834
1105.0051,38.5918
1105.6439,14.4764
1106.8900,14.0782
1110.4218,1.9653
1128.8015,13.3574
1134.9760,7.8213
1137.2063,14.1863
1138.2483,9.2036
1142.2748,18.0837
1143.3179,16.1459
1152.8712,13.1858
1158.4387,21.6415
1161.0552,4.7822
1169.4254,5.4306
1170.0654,12.0192
1171.8101,8.2869
1173.1066,89.6032
1182.5023,8.5223
1184.3813,7.9597
1191.5227,32.1805
1201.2119,20.1866
1210.2380,4.5760
1211.3860,34.6247
1212.0920,3.4107
1215.6882,17.7805
1220.2712,75.6271
1221.0226,3.9410
1222.3655,7.1076
1226.3440,4.5817
1227.3850,8.3969
1231.2477,9.9996
1233.4576,7.0980
1236.3285,5.6672
1238.6050,16.4403
1239.7504,16.4767
1246.2981,9.9164
1250.7183,7.9655
1252.9753,11.4922
1254.3899,6.3013
1260.4479,2.6134
1271.0319,38.2319
1272.1794,132.5941
1273.1501,38.6936
1275.1288,2.1728
1278.2950,3.3984
1278.9471,15.7553
1293.1892,7.3914
1309.4503,14.3642
1333.2667,8.9464
1361.1869,4.5666
1370.1740,37.6650
1371.3162,25.6430
1382.4442,7.1701
1389.0020,6.5514
1400.1832,14.2564
1401.4633,2.7542
1402.4385,7.8251
1405.2708,9.6135
1407.3270,2.6422
1408.6093,6.0846
1412.3342,13.2619
1416.1295,4.9382
1418.4384,6.7361
1425.3351,6.8834
1438.1812,17.1871
1439.2043,4.0640
1440.4803,11.1579
1442.2131,4.0624
1452.3656,9.2531
1466.3126,3.0474
1473.0067,18.7112
1493.3770,6.6628
1496.1071,11.7351
1537.0496,4.4904
1550.7667,9.3704
1551.7039,21.1470
1552.5736,4.1344
1641.3055,12.9577
1650.3793,13.2390
1654.9631,3.0409
1667.0651,3.2641
1754.7513,9.1676
