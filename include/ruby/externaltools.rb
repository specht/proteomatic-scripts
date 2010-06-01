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

require 'include/ruby/misc'
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
	
	def initialize()
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
				return
			end
		elsif (@@ms_Platform == 'win32')
			ls_Command = "\"#{@@ms_Win7ZipHelperPath}\" x \"#{as_Path}\""
			%x{#{ls_Command}}
			unless $? == 0
				puts 'Error: There was an error while executing 7-Zip.'
				exit 1
			end
			return
		end
		puts "Internal error: Unable to unpack #{as_Path} (file extension handling not implemented for this system)."
		exit 1
	end
	
	def self.install(as_Package, ak_Description = nil, as_ResultFilePath = nil, ak_PackageDescription = nil)
		ls_Package = as_Package.sub('ext.', '')
		ak_PackageDescription = YAML::load_file(File::join(@@ms_RootPath, "include/cli-tools-atlas/packages/ext.#{ls_Package}.yaml")) unless ak_PackageDescription
		unless ak_PackageDescription['download'][@@ms_Platform]
			puts "Error: This package (#{ak_PackageDescription['title']}) is not available for this platform (#{@@ms_Platform})."
			return
		end
		as_ResultFilePath = File::join(@@ms_ExtToolsPath, ls_Package, @@ms_Platform, ak_PackageDescription['path'][@@ms_Platform]) unless as_ResultFilePath
		puts "Installing #{ak_PackageDescription['title']} #{ak_PackageDescription['version']}..."
		ls_Uri = ak_PackageDescription['download'][@@ms_Platform]
		lk_Uri = URI::parse(ls_Uri)
		ls_OutFile = File::basename(lk_Uri.path)
		
		FileUtils::rm_rf(File.join(@@ms_ExtToolsPath, ls_Package, @@ms_Platform))
		FileUtils::mkpath(File.join(@@ms_ExtToolsPath, ls_Package, @@ms_Platform))
		ls_OutPath = File.join(@@ms_ExtToolsPath, ls_Package, @@ms_Platform, ls_OutFile)
		
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
		FileUtils::chdir(File.join(@@ms_ExtToolsPath, ls_Package, @@ms_Platform))
		unpack(ls_OutFile)
		FileUtils::chdir(File.join('..', '..', '..'))
		FileUtils::remove_file(ls_OutPath, true)
		unless File::exists?(as_ResultFilePath)
			puts "Installation of #{ak_PackageDescription['title']} failed."
			puts "Please try again or download and unpack the tool manually:"
			puts "Source: #{ls_Uri}"
			puts "Destination path: #{ls_OutPath}"
			puts "This directory has to exist after installation: #{as_ResultFilePath}"
			exit 1
		end
		puts "#{ak_PackageDescription['title']} #{ak_PackageDescription['version']} successfully installed."
	end
	
	def self.binaryPath(as_Tool)
		lk_ToolDescription = YAML::load_file(File::join(@@ms_RootPath, "include/cli-tools-atlas/packages/ext.#{as_Tool}.yaml"))
		ls_Package = as_Tool.split('.').first
		lk_PackageDescription = YAML::load_file(File::join(@@ms_RootPath, "include/cli-tools-atlas/packages/ext.#{ls_Package}.yaml"))
		ls_Path = File::join(@@ms_ExtToolsPath, ls_Package, @@ms_Platform, lk_PackageDescription['path'][@@ms_Platform], lk_ToolDescription['binary'][@@ms_Platform])
		install(ls_Package, lk_ToolDescription, ls_Path, lk_PackageDescription) unless File::exists?(ls_Path)
		return ls_Path
	end
	
	def self.installed?(as_Package)
		lb_Ok = true
		lk_PackageDescription = YAML::load_file(File::join(@@ms_RootPath, "include/cli-tools-atlas/packages/#{as_Package}.yaml"))
		ls_Package = as_Package.sub('ext.', '')
		begin
			return File::directory?(File::join(@@ms_ExtToolsPath, ls_Package, @@ms_Platform, lk_PackageDescription['path'][@@ms_Platform]))
		rescue 
			return false
		end
	end
	
	def self.packageTitle(as_Package)
		ls_Package = as_Package.sub('ext.', '')
		lk_PackageDescription = YAML::load_file(File::join(@@ms_RootPath, "include/cli-tools-atlas/packages/ext.#{ls_Package}.yaml"))
		return "#{lk_PackageDescription['title']} #{lk_PackageDescription['version']}"
	end
end
