require 'yaml'

class SubmitController < ApplicationController
	#protect_from_forgery :only => [:index] 
	def index()
		lk_Run = Run.new(YAML::load(params['run']))
		lk_Run.save
		li_RunId = lk_Run.id
		lk_FileInfo = YAML::load(params['files'])
		if (lk_FileInfo.class == Array)
			lk_FileInfo.each do |lk_File|
				lk_File = ProteomaticFile.new(lk_File)
				lk_File.run_id = li_RunId
				lk_File.save
			end
		end
		@run = lk_Run.to_yaml
		@entryCount = Run.count
	end
end
