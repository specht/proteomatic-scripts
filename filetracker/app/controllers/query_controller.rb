class QueryController < ApplicationController
	def index()
		@entryCount = Run.count
		@entries = Run.find(:all).to_yaml
		@files = ProteomaticFile.find(:all).to_yaml
	end
end
