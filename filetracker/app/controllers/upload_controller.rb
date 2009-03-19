class UploadController < ApplicationController
	protect_from_forgery :only => [:create, :update, :destroy] 
	
	def index()
		filename = File.join('upload', sprintf('%1.4f.yaml', Time.now.to_f))
		File.open(filename, 'w') { |f| f.puts(params[:info]) }
	end
end
