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

require 'include/misc'
require 'open-uri'
require 'uri'
require 'yaml'
require 'fileutils'
require 'net/ftp'


class ExternalTools
	@@ms_Platform = determinePlatform()
	
	def initialize()
	end
	
	def self.unpack(as_Path)
		# note: we are already in the correct directory, I guess.
		if (@@ms_Platform == 'linux' || @@ms_Platform == 'macx')
			if stringEndsWith(as_Path, '.tar.gz', false)
				system("gzip -dc #{as_Path} | tar xf -")
				return
			elsif stringEndsWith(as_Path, '.tar.bz2', false)
				system("bzip2 -dc #{as_Path} | tar xf -")
				return
			end
		elsif (@@ms_Platform == 'win32')
			system("#{binaryPath('7zip.7zip')} x #{as_Path}")
			return
		end
		puts "Internal error: Unable to unpack #{as_Path} (file extension handling not implemented for this system)."
		exit 1
	end
	
	def self.install(as_Package, ak_Description = nil, as_ResultFilePath = nil, ak_PackageDescription = nil)
		ls_Package = as_Package.sub('ext.', '')
		ak_PackageDescription = YAML::load_file("include/properties/ext.#{ls_Package}.yaml") unless ak_PackageDescription
		unless ak_PackageDescription['path'][@@ms_Platform] && !ak_PackageDescription['path'][@@ms_Platform].empty?
			puts "Error: This package is not available for this platform (#{@@ms_Platform})."
			return
		end
		as_ResultFilePath = File::join('ext', ls_Package, ak_PackageDescription['path'][@@ms_Platform]) unless as_ResultFilePath
		puts "Installing #{ak_PackageDescription['title']}..."
		ls_Uri = ak_PackageDescription['download'][@@ms_Platform]
		lk_Uri = URI::parse(ls_Uri)
		ls_OutFile = File::basename(lk_Uri.path)
		
		FileUtils::rm_rf(File.join('ext', ls_Package))
		FileUtils::mkpath(File.join('ext', ls_Package))
		ls_OutPath = File.join('ext', ls_Package, ls_OutFile)
		
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
		FileUtils::chdir(File.join('ext', ls_Package))
		unpack(ls_OutFile)
		FileUtils::chdir(File.join('..', '..'))
		FileUtils::remove_file(ls_OutPath, true)
		unless File::exists?(as_ResultFilePath)
			puts "Installation of #{ak_PackageDescription['title']} failed."
			puts "Please try again or download and unpack the tool manually:"
			puts "Source: #{ls_Uri}"
			puts "Destination path: #{ls_OutPath}"
			puts "This directory has to exist after installation: #{as_ResultFilePath}"
			exit 1
		end
		puts "#{ak_PackageDescription['title']} successfully installed."
	end
	
	def self.binaryPath(as_Tool)
		lk_ToolDescription = YAML::load_file("include/properties/ext.#{as_Tool}.yaml")
		ls_Package = as_Tool.split('.').first
		lk_PackageDescription = YAML::load_file("include/properties/ext.#{ls_Package}.yaml")
		ls_Path = File::join('ext', ls_Package, lk_PackageDescription['path'][@@ms_Platform], lk_ToolDescription['binary'][@@ms_Platform])
		install(ls_Package, lk_ToolDescription, ls_Path, lk_PackageDescription) unless File::exists?(ls_Path)
		return ls_Path
	end
	
	def self.installed?(as_Package)
		lb_Ok = true
		lk_PackageDescription = YAML::load_file("include/properties/#{as_Package}.yaml")
		ls_Package = as_Package.sub('ext.', '')
		begin
			return File::directory?(File::join('ext', ls_Package, lk_PackageDescription['path'][@@ms_Platform]))
		rescue 
			return false
		end
	end
	
	def self.packageTitle(as_Package)
		ls_Package = as_Package.sub('ext.', '')
		lk_PackageDescription = YAML::load_file("include/properties/ext.#{ls_Package}.yaml")
		return "#{lk_PackageDescription['title']} #{lk_PackageDescription['version']}"
	end
end
