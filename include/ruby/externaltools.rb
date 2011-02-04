# Copyright (c) 2007-2010 Michael Specht
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

require './include/ruby/misc'
require 'open-uri'
require 'uri'
require 'yaml'
require 'fileutils'
require 'net/ftp'


class ExternalTools
	@@ms_Platform = determinePlatform()
	@@ms_RootPath = Dir::pwd()
    @@ms_ExtToolsPath = File::join(@@ms_RootPath, 'ext')
    @@ms_Win7ZipHelperPath = File::join(@@ms_RootPath, 'helper', '7zip', '7za457', '7za.exe')
    
    def self.setExtToolsPath(as_Path)
        @@ms_ExtToolsPath = as_Path
    end
	
    def self.itemPath(as_Tool)
        as_Tool = as_Tool.split('.')[0, 2].join('.')
        if as_Tool[0, 4] == 'ext.'
            return 'include/cli-tools-atlas/packages/'
        elsif as_Tool[0, 5] == 'lang.'
            return 'helper/languages/'
        else
            raise "Internal error: Invalid item requested in ExternalTools (#{as_Tool})"
        end
    end
    
    def self.itemPathPrefix(as_Tool)
        as_Tool = as_Tool.split('.')[0, 2].join('.')
        if as_Tool[0, 4] == 'ext.'
            return 'include/cli-tools-atlas/packages/ext.'
        elsif as_Tool[0, 5] == 'lang.'
            return 'helper/languages/lang.'
        else
            puts "Internal error: Invalid item requested in ExternalTools (#{as_Tool})"
            exit 1
        end
    end

    # removes .lang or .ext prefix
    def self.stripItem(as_Tool)
        if as_Tool[0, 4] == 'ext.'
            return as_Tool.sub('ext.', '')
        elsif as_Tool[0, 5] == 'lang.'
            return as_Tool.sub('lang.', '')
        else
            puts "Internal error: Invalid item requested in ExternalTools (#{as_Tool})"
            exit 1
        end
    end
	
	def self.unpack(as_Path)
		# Note: we should already be in the correct directory.
		if (@@ms_Platform == 'linux' || @@ms_Platform == 'macx')
			if stringEndsWith(as_Path, '.tar.gz', false)
				system("gzip -dc \"#{as_Path}\" | tar xf -")
				return
			elsif stringEndsWith(as_Path, '.tar.bz2', false)
				system("bzip2 -dc \"#{as_Path}\" | tar xf -")
				return
            elsif stringEndsWith(as_Path, '.zip', false)
                system("unzip -qq \"#{as_Path}\"")
                FileUtils::rm(as_Path)
				return
			end
		elsif (@@ms_Platform == 'win32')
            if stringEndsWith(as_Path, '.tar.gz', false)
                ls_Command = "\"#{@@ms_Win7ZipHelperPath}\" x \"#{as_Path}\""
                %x{#{ls_Command}}
                unless $? == 0
                    puts 'Error: There was an error while executing 7-Zip.'
                    exit 1
                end
                as_Path = as_Path[0, as_Path.size - '.gz'.size]
                ls_Command = "\"#{@@ms_Win7ZipHelperPath}\" x \"#{as_Path}\""
                %x{#{ls_Command}}
                unless $? == 0
                    puts 'Error: There was an error while executing 7-Zip.'
                    exit 1
                end
                FileUtils::rm(as_Path)
                return
            elsif stringEndsWith(as_Path, '.tar.bz2', false)
                ls_Command = "\"#{@@ms_Win7ZipHelperPath}\" x \"#{as_Path}\""
                %x{#{ls_Command}}
                unless $? == 0
                    puts 'Error: There was an error while executing 7-Zip.'
                    exit 1
                end
                FileUtils::rm(as_Path)
                as_Path = as_Path[0, as_Path.size - '.bz2'.size]
                ls_Command = "\"#{@@ms_Win7ZipHelperPath}\" x \"#{as_Path}\""
                %x{#{ls_Command}}
                unless $? == 0
                    puts 'Error: There was an error while executing 7-Zip.'
                    exit 1
                end
                FileUtils::rm(as_Path)
                return
            else
                # this might be ZIP or EXE
                ls_Command = "\"#{@@ms_Win7ZipHelperPath}\" x \"#{as_Path}\""
                %x{#{ls_Command}}
                unless $? == 0
                    puts 'Error: There was an error while executing 7-Zip.'
                    exit 1
                end
                FileUtils::rm(as_Path)
                return
            end
		end
		puts "Internal error: Unable to unpack #{as_Path} (file extension handling not implemented for this system)."
		exit 1
	end
	
    # as_Package is for example:
    # - lang.python
    # - ext.omssa
	def self.install(as_Package)
        # don't install again if it's already installed
        return if self.installed?(as_Package)
        
        ls_PackageStripped = stripItem(as_Package)
		ak_PackageDescription = YAML::load_file(File::join(@@ms_RootPath, "#{itemPath(as_Package)}#{as_Package}.yaml")) unless ak_PackageDescription
        puts "Installing #{ak_PackageDescription['title']} #{ak_PackageDescription['version']}..."
        
        if ak_PackageDescription['download'][@@ms_Platform].class == String && ak_PackageDescription['download'][@@ms_Platform].strip.empty?
            ak_PackageDescription['download'][@@ms_Platform] = nil
        end
		unless ak_PackageDescription['download'][@@ms_Platform]
			puts "Error: #{ak_PackageDescription['title']} is not available for this platform (#{@@ms_Platform})."
            puts "Please try to install #{ak_PackageDescription['title']} manually."
            puts ak_PackageDescription['help'][@@ms_Platform] if ak_PackageDescription['help'][@@ms_Platform]
			return
		end
		ls_ResultFilePath = File::join(@@ms_ExtToolsPath, ls_PackageStripped, @@ms_Platform, ak_PackageDescription['version'], ak_PackageDescription['path'][@@ms_Platform])
		ls_Uri = ak_PackageDescription['download'][@@ms_Platform].strip
        ls_Uri = nil if ls_Uri.class != String || ls_Uri.empty?
        unless ls_Uri
            puts "Error: This program is not available for your platform (#{@@ms_Platform})."
        end
		lk_Uri = URI::parse(ls_Uri)
		ls_OutFile = File::basename(lk_Uri.path)
		
		FileUtils::rm_rf(File.join(@@ms_ExtToolsPath, ls_PackageStripped, @@ms_Platform))
		FileUtils::mkpath(File.join(@@ms_ExtToolsPath, ls_PackageStripped, @@ms_Platform, ak_PackageDescription['version']))
		ls_OutPath = File.join(@@ms_ExtToolsPath, ls_PackageStripped, @@ms_Platform, ak_PackageDescription['version'], ls_OutFile)
		
		puts "Downloading #{ls_OutFile}..."

		li_BlockSize = 16384
		if (ls_Uri[0, 6] == 'ftp://')
			Net::FTP.open(lk_Uri.host) do |lk_Ftp|
				lk_Ftp.passive = true 
				lk_Ftp.login
				li_Size = lk_Ftp.size(lk_Uri.path)
				li_Received = 0
				lk_Ftp.getbinaryfile(lk_Uri.path, ls_OutPath + '.proteomatic.part', li_BlockSize) do |lk_Data|
					li_Received += lk_Data.size
					print "\rDownloaded #{bytesToString(li_Received)} of #{bytesToString(li_Size)}    "
				end
			end
		else
			li_Size = 0
			open(ls_Uri, 
			  :content_length_proc => lambda { |t| li_Size = t }, 
			  :progress_proc => lambda { |t| print "\rDownloaded #{bytesToString(t)} of #{bytesToString(li_Size)}    " }) do |lk_RemoteFile|
				File::open(ls_OutPath + '.proteomatic.part', 'wb') { |lk_Out| lk_Out.write(lk_RemoteFile.read) }
			end
		end
		
		FileUtils::mv(ls_OutPath + '.proteomatic.part', ls_OutPath)
		puts 
		
		puts "Unpacking..."
		FileUtils::chdir(File.join(@@ms_ExtToolsPath, ls_PackageStripped, @@ms_Platform, ak_PackageDescription['version']))
		unpack(ls_OutFile)
		FileUtils::chdir(File.join('..', '..', '..'))
		FileUtils::remove_file(ls_OutPath, true)
		unless File::exists?(ls_ResultFilePath)
			puts "Installation of #{ak_PackageDescription['title']} failed."
			puts "Please try again or download and unpack the tool manually:"
			puts "Source: #{ls_Uri}"
			puts "Destination path: #{ls_OutPath}"
			puts "This directory has to exist after installation: #{as_ResultFilePath}"
			exit 1
		end
		puts "#{ak_PackageDescription['title']} #{ak_PackageDescription['version']} successfully installed."
	end
	
    # as_Tool is for example:
    # - lang.perl.perl
    # - ext.omssa.omssacl
	def self.binaryPath(as_Tool, installIfNotThere = true)
        unless as_Tool[0, 4] == 'ext.' || as_Tool[0, 5] == 'lang.'
            # if not given, prepend 'ext.' by default
            as_Tool = 'ext.' + as_Tool
        end
		lk_ToolDescription = YAML::load_file(File::join(@@ms_RootPath, "#{itemPath(as_Tool)}#{as_Tool}.yaml"))
		ls_Package = as_Tool.split('.')[1]
		lk_PackageDescription = YAML::load_file(File::join(@@ms_RootPath, "#{itemPathPrefix(as_Tool)}#{ls_Package}.yaml"))
		ls_Path = File::join(@@ms_ExtToolsPath, ls_Package, @@ms_Platform, lk_PackageDescription['version'], lk_PackageDescription['path'][@@ms_Platform], lk_ToolDescription['binary'][@@ms_Platform])
        unless File::exists?(ls_Path)
            if (installIfNotThere)
                install(as_Tool.split('.')[0, 2].join('.'))
                if (!File::exists?(ls_Path)) && (as_Tool[0, 5] == 'lang.')
                    return languageBinary(as_Tool.split('.')[1])
                end
            else
                return nil
            end
        end
		return ls_Path
	end

    def self.toolsForPackage(as_Package)
        return Dir[File::join(@@ms_RootPath, "#{itemPath(as_Package)}#{as_Package}.*.yaml")].collect do |x|
            File::basename(x).sub('ext.', '').sub('.yaml', '')
        end
    end

    # as_Package is for example:
    # - lang.python
    # - ext.omssa
	def self.installed?(as_Package)
		lb_Ok = true
		lk_PackageDescription = YAML::load_file(File::join(@@ms_RootPath, "#{itemPath(as_Package)}#{as_Package}.yaml"))
        lb_Result = false
		begin
			lb_Result = File::directory?(File::join(@@ms_ExtToolsPath, stripItem(as_Package), @@ms_Platform, lk_PackageDescription['version'], lk_PackageDescription['path'][@@ms_Platform]))
		rescue 
			lb_Result = false
		end
        # if it's not installed, see whether it's a language which might be globally available
        if (!lb_Result) && (as_Package[0, 5] == 'lang.')
            language = stripItem(as_Package)
            binaryName = languageBinary(language)
            version = `\"#{binaryName}\" --version 2>&1`
            version.strip!
            version.downcase!
            if language == 'perl'
                version.gsub!('this is', '')
                version.strip!
            end
            if version.index(language.downcase) == 0
                # we cannot install the language, but it's already installed on the computer!
                lb_Result = true 
            end
        end
        return lb_Result
	end
    
    def self.languageBinary(language)
        # :ATTENTION: SECURITY CHECK HERE, WE DON'T WANT TO CALL SOMETHING ELSE ALRIGHT
        unless ['perl', 'python', 'php'].include?(language)
            raise "Invalid language binary requested (#{language})."
        end
        binaryName = YAML::load_file(File::join(@@ms_RootPath, "#{itemPathPrefix('lang.' + language)}#{language}.#{language}.yaml"))['binary'][@@ms_Platform]
    end
	
	def self.packageTitle(as_Package)
		ls_PackageStripped = stripItem(as_Package)
		lk_PackageDescription = YAML::load_file(File::join(@@ms_RootPath, "#{itemPathPrefix(as_Package)}#{ls_PackageStripped}.yaml"))
		return "#{lk_PackageDescription['title']} #{lk_PackageDescription['version']}"
	end
end
