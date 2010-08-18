# Copyright (c) 2007-2008 Michael Specht
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
require 'include/ruby/evaluate-omssa-helper'
require 'include/ruby/ext/fastercsv'
require 'include/ruby/misc'
require 'set'
require 'yaml'

class AugustusCollect < ProteomaticScript

    def printDetails(ak_Peptides, as_Title = '(no name)')
        li_ModifiedOnlyCount = 0
        li_UnmodifiedOnlyCount = 0
        li_ModifiedAndUnmodifiedCount = 0
        li_MiscleavedCount = 0
        lk_AllModCounts = Hash.new
        ak_Peptides.each do |ls_Peptide|
            if @mk_AllPeptideModifications[ls_Peptide].keys.size == 1
                if @mk_AllPeptideModifications[ls_Peptide].include?(:modified)
                    li_ModifiedOnlyCount += 1
                else
                    li_UnmodifiedOnlyCount += 1
                end
            else
                li_ModifiedAndUnmodifiedCount += 1
            end
            li_MiscleavedCount += 1 if ls_Peptide.count('R') + ls_Peptide.count('K') > 1
            li_ModCount = 0
            li_ModCount = @mk_AllPeptideModifications[ls_Peptide][:modified].keys.sort.first if @mk_AllPeptideModifications[ls_Peptide][:modified]
            li_ModCount = 0 if @mk_AllPeptideModifications[ls_Peptide][:unmodified]
            lk_AllModCounts[li_ModCount] ||= 0
            lk_AllModCounts[li_ModCount] += 1
        end
        
        
#         puts "Details for #{as_Title} (#{ak_Peptides.size} peptides):"
#         puts "modified only: #{li_ModifiedOnlyCount}"
#         puts "unmodified only: #{li_UnmodifiedOnlyCount}"
#         puts "modified and unmodified: #{li_ModifiedAndUnmodifiedCount}"
#         puts "miscleaved: #{li_MiscleavedCount}"
         puts "#{as_Title} (#{ak_Peptides.size}): #{sprintf('%1.2f', (li_ModifiedOnlyCount).to_f * 360.0 / ak_Peptides.size)}, #{sprintf('%1.2f', (li_MiscleavedCount).to_f / ak_Peptides.size * 360.0)}, #{}"
        puts "#{lk_AllModCounts.keys.sort.collect { |x| "#{x}: #{lk_AllModCounts[x]}" }.join(', ')}"
        puts
    end
    
    def dumpGpfInfo(ak_GpfInfo, ak_GpfPeptides)
        lk_Result = Hash.new
        lk_ImmediatePeptides = Set.new
        lk_IntronSplitPeptides = Set.new
        lk_TripletSplitPeptides = Set.new
        lk_EvenSplitPeptides = Set.new
        lk_LostPeptides = Set.new
        ak_GpfPeptides.each do |ls_Peptide|
            ls_Key = ls_Peptide
            lk_Info = ak_GpfInfo[ls_Key]
            if (lk_Info == nil)
                lk_LostPeptides.add(ls_Peptide)
                next
            end
            lk_ImmediatePeptides.add(ls_Peptide) if lk_Info[:immediate] > 0
            lk_IntronSplitPeptides.add(ls_Peptide) if lk_Info[:intronSplit] > 0
            lk_TripletSplitPeptides.add(ls_Peptide) if lk_Info[:tripletSplit] > 0
            lk_EvenSplitPeptides.add(ls_Peptide) if lk_Info[:evenSplit] > 0
        end
        lk_Result[:immediateOnly] = (lk_ImmediatePeptides - lk_IntronSplitPeptides).size
        lk_Result[:immediateAndIntronSplit] = (lk_ImmediatePeptides & lk_IntronSplitPeptides).size
        lk_Result[:intronSplit] = (lk_IntronSplitPeptides - lk_ImmediatePeptides - (lk_TripletSplitPeptides - lk_EvenSplitPeptides)).size
        lk_Result[:intronTripletSplitOnly] = (lk_TripletSplitPeptides - lk_EvenSplitPeptides).to_a
        lk_Result[:lost] = lk_LostPeptides.size
        return lk_Result
    end
    
    def dumpSplitInfo(ak_Peptides, ak_Info)
        lk_ImmediatePeptides = Set.new()
        lk_IntronSplitPeptides = Set.new()
        lk_TripletSplitPeptides = Set.new()
        lk_EvenSplitPeptides = Set.new()
        ak_Peptides.each do |ls_Peptide|
            lk_ImmediatePeptides << ls_Peptide if ak_Info[ls_Peptide][:immediate]
            lk_IntronSplitPeptides << ls_Peptide if ak_Info[ls_Peptide][:intronSplit]
            lk_TripletSplitPeptides << ls_Peptide if ak_Info[ls_Peptide][:tripletSplit]
            lk_EvenSplitPeptides << ls_Peptide if ak_Info[ls_Peptide][:evenSplit]
        end
        puts "(#{(lk_ImmediatePeptides + lk_IntronSplitPeptides).size} total)"
        puts
        puts "immediate only peptides: #{(lk_ImmediatePeptides - lk_IntronSplitPeptides).size} (#{sprintf('%1.1f', (lk_ImmediatePeptides - lk_IntronSplitPeptides).size.to_f * 100.0 / (lk_ImmediatePeptides + lk_IntronSplitPeptides).size)}%)."
        puts "both peptides: #{(lk_ImmediatePeptides & lk_IntronSplitPeptides).size} (#{sprintf('%1.1f', (lk_ImmediatePeptides & lk_IntronSplitPeptides).size.to_f * 100.0 / (lk_ImmediatePeptides + lk_IntronSplitPeptides).size)}%)."
        lk_TripletSplitOnlyPeptides = lk_TripletSplitPeptides - lk_EvenSplitPeptides - lk_ImmediatePeptides
        puts "intron peptides (w/o triplet split only): #{(lk_IntronSplitPeptides - lk_ImmediatePeptides - lk_TripletSplitOnlyPeptides).size} (#{sprintf('%1.1f', (lk_IntronSplitPeptides - lk_ImmediatePeptides - lk_TripletSplitOnlyPeptides).size.to_f * 100.0 / (lk_ImmediatePeptides + lk_IntronSplitPeptides).size)}%)."
        puts "triplet split only peptides: #{lk_TripletSplitOnlyPeptides.size} (#{sprintf('%1.1f', lk_TripletSplitOnlyPeptides.size.to_f * 100.0 / (lk_ImmediatePeptides + lk_IntronSplitPeptides).size)}%)."
        puts 
    end
    
    
    def reduceSetAccordingToModifiedOnlyCount(ak_Peptides, ak_Reference)
        lk_Result = ak_Peptides.dup()
        li_ModifiedOnlyCount = 0
        ak_Reference.each do |ls_Peptide|
            li_ModifiedOnlyCount += 1 if @mk_AllPeptideModifications[ls_Peptide].keys == [:modified]
        end
        
        lf_RefModRatio = li_ModifiedOnlyCount.to_f / ak_Reference.size
        puts "Reference set has a modified only amount of #{lf_RefModRatio}."
        
        lk_SortedByScore = ak_Peptides.to_a.sort do |a, b|
            @mk_AllPeptideBestScore[a] <=> @mk_AllPeptideBestScore[b]
        end
        li_ModifiedOnlyCount = 0
        lk_SortedByScore.each do |ls_Peptide|
            li_ModifiedOnlyCount += 1 if @mk_AllPeptideModifications[ls_Peptide].keys == [:modified]
        end
        lf_ModRatio = li_ModifiedOnlyCount.to_f / lk_SortedByScore.size
        puts "Putative set has an initial modified only amount of #{lf_ModRatio}."

        while lf_ModRatio > lf_RefModRatio
            ls_Peptide = lk_SortedByScore.pop()
            li_ModifiedOnlyCount -= 1 if @mk_AllPeptideModifications[ls_Peptide].keys == [:modified]
            lf_ModRatio = li_ModifiedOnlyCount.to_f / lk_SortedByScore.size
        end
        return Set.new(lk_SortedByScore)
    end

    
    def run()
        lk_AllPeptides = Set.new
        lk_AllGpfPeptides = Set.new
        lk_AllSixFramesPeptides = Set.new
        lk_AllModelPeptides = Set.new
        lk_AllPeptideOccurences = Hash.new
        @mk_AllPeptideModifications = Hash.new
        @mk_AllPeptideBestScore = Hash.new
        @input[:psmFiles].each do |ls_Path|
        
            puts File::basename(ls_Path)
            #next unless ls_Path.index("MT_CPAN1")
            # merge OMSSA results
            lk_Result = loadPsm(ls_Path, :silent => true)#, :putativePrefix => '') # this is for the old runs
            
            lk_ScanHash = lk_Result[:scanHash]
            lk_PeptideHash = lk_Result[:peptideHash]
            lk_GpfPeptides = lk_Result[:gpfPeptides]
            lk_SixFramesPeptides = lk_Result[:sixFramesPeptides]
            lk_ModelPeptides = lk_Result[:modelPeptides]
            lk_ProteinIdentifyingModelPeptides = lk_Result[:proteinIdentifyingModelPeptides]
            lk_Proteins = lk_Result[:proteins]
            lk_ScoreThresholds = lk_Result[:scoreThresholds]
            lk_ActualFpr = lk_Result[:actualFpr]
            lk_SpectralCounts = lk_Result[:spectralCounts]
            
            lk_PeptideHash.keys.each do |ls_Peptide|
                lk_AllPeptideOccurences[ls_Peptide] ||= Set.new
                lk_AllPeptideOccurences[ls_Peptide] += Set.new(lk_PeptideHash[lk_PeptideHash.keys.first][:scans])
            end
            lk_PeptideHash.keys.each do |ls_Peptide|
                @mk_AllPeptideModifications[ls_Peptide] ||= Hash.new
                @mk_AllPeptideModifications[ls_Peptide][:modified] ||= Hash.new unless lk_PeptideHash[ls_Peptide][:mods].empty?
                lk_PeptideHash[ls_Peptide][:mods].each_pair do |ls_ModifiedPeptide, lk_Modifications|
                    lk_Modifications.keys.each do |ls_Description|
                        @mk_AllPeptideModifications[ls_Peptide][:modified][ls_Description.count(',') + 1] ||= 0
                        @mk_AllPeptideModifications[ls_Peptide][:modified][ls_Description.count(',') + 1] += 1
                    end
                end
                @mk_AllPeptideModifications[ls_Peptide][:unmodified] = true if lk_PeptideHash[ls_Peptide][:foundUnmodified]
                lk_PeptideHash[ls_Peptide][:scans].each do |ls_Scan|
                    lf_Score = lk_ScanHash[ls_Scan][:e]
                    @mk_AllPeptideBestScore[ls_Peptide] ||= lf_Score
                    @mk_AllPeptideBestScore[ls_Peptide] = lf_Score if lf_Score < @mk_AllPeptideBestScore[ls_Peptide]
                end
            end
            
            lk_ProteinsBySpectralCount = lk_Proteins.keys.sort { |a, b| lk_SpectralCounts[:proteins][b][:total] <=> lk_SpectralCounts[:proteins][a][:total]}
            lk_AmbiguousPeptides = (lk_ModelPeptides - lk_ProteinIdentifyingModelPeptides).to_a.sort! do |x, y|
                lk_PeptideHash[x][:scans].size == lk_PeptideHash[y][:scans].size ? x <=> y : lk_PeptideHash[y][:scans].size <=> lk_PeptideHash[x][:scans].size
            end
            
            lk_AllGpfPeptides += lk_GpfPeptides
            lk_AllSixFramesPeptides += lk_SixFramesPeptides
            lk_AllModelPeptides += lk_ModelPeptides
            lk_AllPeptides += Set.new(lk_PeptideHash.keys)
        end
        
        puts "Total peptides: #{lk_AllPeptides.size}"
        puts "models only: #{(lk_AllModelPeptides - lk_AllSixFramesPeptides - lk_AllGpfPeptides).size}"
        puts "GPF only: #{(lk_AllGpfPeptides - lk_AllSixFramesPeptides - lk_AllModelPeptides).size}"
        puts "six frames only: #{(lk_AllSixFramesPeptides - lk_AllModelPeptides - lk_AllGpfPeptides).size}"
        puts "GPF and model and six frames: #{(lk_AllModelPeptides & lk_AllGpfPeptides & lk_AllSixFramesPeptides).size}"
        puts "all but sixframes: #{(lk_AllModelPeptides + lk_AllGpfPeptides).size}"
        
        modelsOnly = lk_AllModelPeptides - lk_AllGpfPeptides - lk_AllSixFramesPeptides
        gpfOnly = lk_AllGpfPeptides - lk_AllModelPeptides - lk_AllSixFramesPeptides
        sixFramesOnly = lk_AllSixFramesPeptides - lk_AllModelPeptides - lk_AllGpfPeptides
        allThree = lk_AllSixFramesPeptides & lk_AllModelPeptides & lk_AllGpfPeptides
        
        File::open('/home/michael/Promotion/ak-hippler-alignments/collect-out/model-peptides.txt', 'w') { |f| f.puts lk_AllModelPeptides.to_a.sort.join("\n") }
        File::open('/home/michael/Promotion/ak-hippler-alignments/collect-out/gpf-peptides.txt', 'w') { |f| f.puts lk_AllGpfPeptides.to_a.sort.join("\n") }
        File::open('/home/michael/Promotion/ak-hippler-alignments/collect-out/sixframes-peptides.txt', 'w') { |f| f.puts lk_AllSixFramesPeptides.to_a.sort.join("\n") }
        
        printDetails(lk_AllModelPeptides, 'gene models')
        printDetails(lk_AllGpfPeptides, 'GPF')
        printDetails(lk_AllSixFramesPeptides, 'six frames')
#         printDetails(modelsOnly, 'models only')
#         printDetails(gpfOnly, 'gpf only')
#         printDetails(sixFramesOnly, 'six frames only')
#         printDetails(allThree, 'all three')
#         printDetails((lk_AllModelPeptides & lk_AllGpfPeptides) - allThree, 'gpf model overlap')
#         printDetails((lk_AllSixFramesPeptides & lk_AllGpfPeptides) - allThree, 'gpf sixframes overlap')
#         printDetails((lk_AllSixFramesPeptides & lk_AllModelPeptides) - allThree, 'sixframes model overlap')
        
        # now we have lk_AllPeptides, lk_AllModelPeptides, lk_AllGpfPeptides, lk_AllSixFramesPeptides
        # now cut down lk_AllGpfPeptides and lk_AllSixFramesPeptides so that the amount of
        # modified only peptides is less or equal than the amount in lk_AllModelPeptides

        puts "Cropping GPF peptides..."
        lk_AllGpfPeptides = reduceSetAccordingToModifiedOnlyCount(lk_AllGpfPeptides, lk_AllModelPeptides)
        
        puts "Cropping six frames peptides..."
        lk_AllSixFramesPeptides = reduceSetAccordingToModifiedOnlyCount(lk_AllSixFramesPeptides, lk_AllModelPeptides)
        
        printDetails(lk_AllModelPeptides, 'gene models')
        printDetails(lk_AllGpfPeptides, 'GPF')
        printDetails(lk_AllSixFramesPeptides, 'six frames')
        
        # update lk_AllPeptides
        lk_AllPeptides = lk_AllModelPeptides + lk_AllGpfPeptides + lk_AllSixFramesPeptides
        
        File::open('/home/michael/Promotion/ak-hippler-alignments/collect-out/cut-down-gpf-peptides.txt', 'w') { |f| f.puts lk_AllGpfPeptides.to_a.sort.join("\n") }
        File::open('/home/michael/Promotion/ak-hippler-alignments/collect-out/cut-down-sixframes-peptides.txt', 'w') { |f| f.puts lk_AllSixFramesPeptides.to_a.sort.join("\n") }
        
        
#         File::open('/home/michael/Promotion/ak-hippler-alignments/all-gpf-peptides.fasta', 'w') do |f|
#             lk_AllGpfPeptides.to_a.sort.each do |ls_Peptide|
#                 f.puts "#{ls_Peptide}"
#             end
#         end
        
        File::open('/home/michael/Promotion/ak-hippler-alignments/redo-gpf-peptides.fasta', 'w') do |f|
            lk_AllPeptides.to_a.sort.each do |ls_Peptide|
                f.puts ">#{ls_Peptide}"
                f.puts "#{ls_Peptide}"
            end
        end
        
        exit
        
        print 'Loading GPF details...'
        lk_GpfDetails = YAML::load_file('/home/michael/Promotion/ak-hippler-alignments/gpf-results.yaml')
        puts ''
        
        puts "GPF details: #{lk_GpfDetails.keys.size}"
        lk_GpfDetails.reject! { |x, y| (!y) || y.empty?}
        puts "GPF details (non empty): #{lk_GpfDetails.keys.size}"
        
        lk_PeptidesWithDetails = Set.new(lk_GpfDetails.keys.collect do |x|
            x.sub('peptide=', '').sub('"', '')
        end)
        
        lk_LostPeptides = lk_AllPeptides - lk_PeptidesWithDetails
        
        puts "lost & GPF only: #{(lk_LostPeptides & (lk_AllGpfPeptides - lk_AllModelPeptides)).size}"
        puts "lost & both: #{(lk_LostPeptides & (lk_AllGpfPeptides & lk_AllModelPeptides)).size}"
        puts "lost & models: #{(lk_LostPeptides & (lk_AllModelPeptides - lk_AllGpfPeptides)).size}"
        
        puts "Attention, from now on lost peptides are ignored!"
        
        lk_ModelPeptideDetails = YAML::load_file('/home/michael/Promotion/ak-hippler-alignments/model-peptides-details.yaml')
        lk_ModelPeptideDetails.reject! { |x, y| (!y) || y.empty? }
        
        lk_AllPeptides &= lk_PeptidesWithDetails
        lk_AllGpfPeptides &= lk_PeptidesWithDetails
        lk_AllModelPeptides &= lk_PeptidesWithDetails
        
#         lk_AllPeptides &= Set.new(lk_ModelPeptideDetails.keys)
#         lk_AllGpfPeptides &= Set.new(lk_ModelPeptideDetails.keys)
#         lk_AllModelPeptides &= Set.new(lk_ModelPeptideDetails.keys)
        
        puts "got #{lk_AllPeptides.size} peptides."
        puts "GPF only: #{(lk_AllGpfPeptides - lk_AllModelPeptides).size}."
        puts "both: #{(lk_AllGpfPeptides & lk_AllModelPeptides).size}."
        puts "models only: #{(lk_AllModelPeptides - lk_AllGpfPeptides).size}."
        
        lk_GpfSplitInfo = Hash.new
        lk_AllPeptides.each do |ls_Peptide|
            lb_Immediate = false
            lb_IntronSplit = false
            lb_TripletSplit = false
            lb_EvenSplit = false
            ls_Key = "peptide=#{ls_Peptide}"
            lk_GpfDetails[ls_Key].each do |lk_Hit|
                if (lk_Hit['partScores'].size == 1)
                    lb_Immediate = true
                else
                    lb_IntronSplit = true
                    lb_TripletSplit = true if ((lk_Hit['details']['parts'][0]['length'] % 3) != 0)
                    lb_EvenSplit = true if ((lk_Hit['details']['parts'][0]['length'] % 3) == 0)
                end 
            end
            lk_GpfSplitInfo[ls_Peptide] = Hash.new
            lk_GpfSplitInfo[ls_Peptide][:immediate] = lb_Immediate
            lk_GpfSplitInfo[ls_Peptide][:intronSplit] = lb_IntronSplit
            lk_GpfSplitInfo[ls_Peptide][:tripletSplit] = lb_TripletSplit
            lk_GpfSplitInfo[ls_Peptide][:evenSplit] = lb_EvenSplit
        end
        
        puts
        puts 'gpf only peptides:'
        dumpSplitInfo(lk_AllGpfPeptides - lk_AllModelPeptides, lk_GpfSplitInfo);
        
        lk_ModelPeptideSplitDetails = Hash.new
        
        (lk_AllModelPeptides & lk_AllGpfPeptides).each do |ls_Peptide|
            li_LeftSize = 5
            li_RightSize = 5
            li_CrossOut = -1
            lb_Immediate = false
            lb_IntronSplit = false
            lb_TripletSplit = false
            lb_EvenSplit = false
            while !lb_Immediate && !lb_IntronSplit
                lk_Surroundings = Set.new
                lk_ModelPeptideDetails[ls_Peptide].each do |ls_Protein, lk_Hits|
                    lk_Hits.each do |lk_Hit|
                        x = [lk_Hit['left'], lk_Hit['right']]
                        x[0].gsub!('*', '$')
                        x[1].gsub!('*', '$')
#                         x[0] = x[0].reverse[0, li_LeftSize].reverse
#                         x[1] = x[1][0, li_RightSize]
                        x[0][li_CrossOut] = '!' if (0..4).include?(li_CrossOut) && x[0].size > li_CrossOut
                        x[1][li_CrossOut - 5] = '!' if (5..9).include?(li_CrossOut) && x[1].size > (li_CrossOut - 5)
                        lk_Surroundings.add(x)
                    end
                end
                lk_GpfDetails['peptide=' + ls_Peptide].each do |lk_Hit|
                    lk_GpfSurroundings = [lk_Hit['left'], lk_Hit['right']]
                    lk_GpfSurroundings[0].gsub!('*', '$')
                    lk_GpfSurroundings[1].gsub!('*', '$')
                    lk_Surroundings.each do |x|
                        z = lk_GpfSurroundings.dup
                        z[0][li_CrossOut] = '!' if (0..4).include?(li_CrossOut) && z[0].size > li_CrossOut
                        z[1][li_CrossOut - 5] = '!' if (5..9).include?(li_CrossOut) && z[1].size > (li_CrossOut - 5)
                        # cut down z
                        z[0] = z[0].reverse[0, x[0].size].reverse
                        z[1] = z[1][0, x[1].size]
#                         z[0] = z[0].reverse[0, li_LeftSize].reverse
#                         z[1] = z[1][0, li_RightSize]
                        if (z == x)
                            if (lk_Hit['partScores'].size == 1)
                                lb_Immediate = true
                            else
                                lb_IntronSplit = true
                                lb_EvenSplit = true if (lk_Hit['details']['parts'][0]['length'] % 3) == 0
                                lb_TripletSplit = true if (lk_Hit['details']['parts'][0]['length'] % 3) != 0
                            end
                        end
                    end
                end
#                 li_LeftSize -= 1
#                 li_RightSize -= 1
#                 break if (li_LeftSize == 0 || li_RightSize == 0)
                li_CrossOut += 1
                break if li_CrossOut > 9
            end
            lk_ModelPeptideSplitDetails[ls_Peptide] = Hash.new
            lk_ModelPeptideSplitDetails[ls_Peptide][:immediate] = lb_Immediate
            lk_ModelPeptideSplitDetails[ls_Peptide][:intronSplit] = lb_IntronSplit
            lk_ModelPeptideSplitDetails[ls_Peptide][:evenSplit] = lb_EvenSplit
            lk_ModelPeptideSplitDetails[ls_Peptide][:tripletSplit] = lb_TripletSplit
#              if !lb_Immediate && !lb_IntronSplit && !lb_EvenSplit && !lb_TripletSplit
#                  puts lk_Surroundings.to_a.join(' / ')
#                  puts lk_GpfDetails['peptide=' + ls_Peptide].to_yaml
#             end
        end

        puts 'model and GPF peptides with OMSSA:'
        dumpSplitInfo(lk_AllModelPeptides & lk_AllGpfPeptides, lk_ModelPeptideSplitDetails);

=begin        
        gpfPeptides = Set.new

        File.open('/home/michael/ak-hippler-alignments/gpf-results.yaml') do |file|
            file.each_line do |line|
                next unless line.index('"') == 0
                line.strip!
                line.gsub!('peptide=', '')
                line.gsub!('"', '')
                line.gsub!(':', '')
                gpfPeptides.add(line)
            end
        end
        
        puts "got #{(lk_AllPeptides - gpfPeptides).size} new peptides."
        puts "#{(lk_AllPeptides - gpfPeptides).collect { |x| '>' + x + "\n" + x + "\n" }.join('')}"
=end
        
#         lk_GpfOnlyPeptides = lk_AllGpfPeptides - lk_AllModelPeptides
#         puts "got #{lk_GpfOnlyPeptides.size} GPF only peptides."
#         lk_GpfOnlyPeptides.to_a.sort.each { |x| puts ">gpf__#{x}\n#{x}" }

=begin        
        lk_PeptideSet = Set.new
        File::open('/home/michael/ak-hippler-alignments/collected-gpf-alignments-keys.txt', 'r') do |lk_File|
            lk_PeptideSet += Set.new(lk_File.read().split("\n").reject { |x| x.empty? })
        end
        (lk_AllPeptides - lk_PeptideSet).to_a.sort.each do |ls_Peptide|
            puts ">#{ls_Peptide}\n#{ls_Peptide}\n"
        end
=end        

=begin        
        lk_PeptideSet.to_a.each do |ls_Peptide|
            if !lk_AllPeptides.include?(ls_Peptide)
                puts ls_Peptide
            end
        end
=end

    end
end

lk_Object = AugustusCollect.new
