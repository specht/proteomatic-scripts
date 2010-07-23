#!/usr/bin/env python2.6
# encoding: utf-8
"""proteomatic.py class template 
"""

import sys
import os
from copy import copy
import subprocess
import tempfile
import json



class ProteomaticScript(object):
	"""DocString to come
	"""
	def run(self):
		raise NotImplementedError( "Should have implemented this" )
	
	def binaryPath(self,tool):
		return self.anyLanguageHubResponse['binaryPath'][tool]
	
	def __init__(self):
		commands = copy(sys.argv)
		currentDir,scriptFilename = os.path.split(commands.pop(0))
		currentDir = os.path.abspath(currentDir)
		
		completeScriptPath = os.path.join(currentDir,scriptFilename)
		
		os.chdir(currentDir)
			
		pathToRuby = "ruby"
		if "--pathToRuby" in commands:
			pos = commands.index("--pathToRuby")
			commands.pop(pos)
			pathToRuby = commands.pop(pos)

		pathToYamlDescription = os.path.abspath(os.path.join("include","properties","{0}.yaml".format(scriptFilename.split('.')[0])))
		
		controlFile  = tempfile.NamedTemporaryFile(mode='w',prefix='p-py-c-',delete=False)
		controlFilePath = os.path.abspath(controlFile.name)
		responseFile = tempfile.NamedTemporaryFile(mode='w',prefix='p-py-r-',delete=False)
		responseFilePath =os.path.abspath(responseFile.name)
		outputFile   = tempfile.NamedTemporaryFile(mode='w',prefix='p-py-o-',delete=False)
		outputFilePath= os.path.abspath(outputFile.name)
		controlFile.write("action: query\npathToYamlDescription: \"{0}\"\nresponseFilePath: \"{1}\"\nresponseFormat: json\n".format(pathToYamlDescription,responseFilePath))
		controlFile.close()
		responseFile.close()
		outputFile.close()

		os.system( "\"{0}\" helper/any-language-hub.rb \"{1}\" {2} ".format(pathToRuby,controlFilePath, " ".join(["\"{0}\"".format(x) for x in commands])) )
		
		responseFile = open(responseFilePath)
		try:
			self.anyLanguageHubResponse = json.load(responseFile)			
			if 'run' in self.anyLanguageHubResponse.keys():
				if self.anyLanguageHubResponse['run'] == 'run':
					outputFile = open(outputFilePath,'w',0)
					sys.stdout = os.fdopen(sys.stdout.fileno(), 'w', 0)
					os.dup2(sys.stdout.fileno(),outputFile.fileno())
				
					#sys.stdout = outputFile
					self.param = self.anyLanguageHubResponse['param']
					self.input = self.anyLanguageHubResponse['input']
					self.output = self.anyLanguageHubResponse['output']

					self.run()
					outputFile.close()
				
					controlFile = open(controlFilePath, 'w')
					controlFile.write("action: finish\npathToYamlDescription: \"{0}\"\nresponseFilePath: \"{1}\"\nresponseFormat: json\noutputFilePath: \"{2}\"\nstartTime: \"{3}\"\n".format(pathToYamlDescription,responseFilePath,outputFilePath,self.anyLanguageHubResponse['startTime']))
					controlFile.close()
				
					os.system( "\"{0}\" helper/any-language-hub.rb \"{1}\" {2} ".format(pathToRuby,controlFilePath, " ".join(["\"{0}\"".format(x) for x in commands])) )
		except:
			pass #print("Something went senf-py-bogo ...")
		responseFile.close()
		os.unlink(controlFilePath)
		os.unlink(responseFilePath)
		os.unlink(outputFilePath)

def main():
	pass


if __name__ == '__main__':
	main()

