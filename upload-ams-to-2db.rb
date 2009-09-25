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

require 'include/proteomatic'
require 'yaml'
require 'uri'


class UploadAMSto2DB < ProteomaticScript
	def run()
=begin
	  File.open('c:\dev\proteomatic\test_neu.txt', 'w+') do |file|
      file.puts 'Halloechen'
	  file.puts 'Du bist ' + @param[:User]
	  file.puts 'Dein Passwort lautet: ' + @param[:Password]
	  file.puts 'Du willst in die Datenbank ' + @param[:databaseTarget] 
	  file.puts 'Du hast den Organismus ' + @param[:Organism] + ' gewaehlt.'
	  file.puts 'Viel Spass noch!'
---------------------------------------

		parameters =
		{
			'username' => @param[:user], 
			'password' => @param[:password],
			'organism' => @param[:organism]
		}

		uri = @param[:databaseTarget] + "/admin/AMSUpload.php"
		uri = @param[:databaseTarget] + "/admin/AMSUpload.php?password=#{@param[:password]}&username=#{@param[:user]}&organism=#{@param[:organism]}&software=blabla"
		urio = URI.parse(uri)
		io = File.open(@input[:amsFile].first, 'r')
		post = Net::HTTP::Post::Multipart.new(uri, :file => io)
		res = Net::HTTP.new(urio.host, urio.port).start {|http| http.request(post) }
		puts res.to_yaml
		
		exit
		multiPart = Multipart.new({'file' => @input[:amsFile].first})
		


		puts multiPart.post(@param[:databaseTarget] + "/admin/AMSUpload.php?password=#{@param[:password]}&username=#{@param[:user]}&organism=#{@param[:organism]}&software=blabla")
		exit

#------------------------------------------------------
		h = Net::HTTP.new('localhost', 80)
		content = File::read(@input[:amsFile].first)
		#      resp, body = h.post((@param[:databaseTarget]),{'password'=>@param[:Password],'username'=>@param[:User],'filepath'=>@input[:amsFile],'organism'=>@param[:Organism]}, 'content')

		puts @param.to_yaml
		uri = @param[:databaseTarget] + "/admin/AMSUpload.php?password=#{@param[:password]}&username=#{@param[:user]}&organism=#{@param[:organism]}&filepath=#{@input[:amsFile]}, content"
		
		puts uri
		resp, body = h.post(uri, content)
	
		puts "#{resp.code}"
		puts body
#---------------------------------------------------------
=end

    h = Net::HTTP.new('localhost', 80)
	resp, body = h.post(@param[:databaseTarget] + "/admin/AMSUpload.php?password=#{@param[:password]}&username=#{@param[:user]}")
	puts "#{resp.code}"
	puts body

	end
end

lk_Object = UploadAMSto2DB.new


__END__
POST #{2DB_URI} HTTP/1.1

Content-Type: multipart/form-data; boundary=---------------------------eaqrp1w4wpp1-1ximw0fz8t2mq1j2e2vq3yxnv1
User-Agent: Java/1.6.0_13
Host: localhost:19810
Accept: text/html, image/gif, image/jpeg, *; q=.2, */*; q=.2
Connection: keep-alive

Content-Length: #{CONTENT_LENGTH}

-----------------------------eaqrp1w4wpp1-1ximw0fz8t2mq1j2e2vq3yxnv1

Content-Disposition: form-data; name="file"; filename="#{FILE_NAME}"
Content-Type: application/octet-stream

#{FILE_CONTENT}

-----------------------------eaqrp1w4wpp1-1ximw0fz8t2mq1j2e2vq3yxnv1

Content-Disposition: form-data; name="username"

#{USER_NAME}

-----------------------------eaqrp1w4wpp1-1ximw0fz8t2mq1j2e2vq3yxnv1

Content-Disposition: form-data; name="password"

#{ENCODED_PASSWORD}

-----------------------------eaqrp1w4wpp1-1ximw0fz8t2mq1j2e2vq3yxnv1--
