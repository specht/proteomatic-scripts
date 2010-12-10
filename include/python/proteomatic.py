#!/usr/bin/env python
# encoding: utf-8
"""proteomatic.py class template 
"""

import sys
import os
from copy import copy
import subprocess
import tempfile
import json
from pipes import quote


class ProteomaticScript(object):
    """DocString to come
    """
    def run(self):
        raise NotImplementedError( "Should have implemented this" )
    
    def binaryPath(self,tool):
        return self.anyLanguageHubResponse['binaryPath'][tool]
    
    def __init__(self):
        commands = copy(sys.argv)
        scriptDir,scriptFilename = os.path.split(commands.pop(0))
        #currentDir = os.path.abspath(currentDir)
        #completeScriptPath = os.path.join(currentDir,scriptFilename)
        
        #os.chdir(currentDir)
            
        pathToRuby = "ruby"
        if "--pathToRuby" in commands:
            pos = commands.index("--pathToRuby")
            commands.pop(pos)
            pathToRuby = commands.pop(pos)

        pathToYamlDescription = os.path.join(scriptDir,"include","properties","{0}.yaml".format(scriptFilename.split('.')[0]))
        
        controlFile  = tempfile.NamedTemporaryFile(mode='w',prefix='p-py-c-',delete=False)
        controlFilePath = controlFile.name
        #controlFile.write("action: query\npathToYamlDescription: \"{0}\"\nresponseFilePath: \"{1}\"\nresponseFormat: json\n".format(pathToYamlDescription,responseFilePath))
        controlFile.close()
        
        responseFile = tempfile.NamedTemporaryFile(mode='w',prefix='p-py-r-',delete=False)
        responseFilePath =responseFile.name
        responseFile.close()
        
        outputFile   = tempfile.NamedTemporaryFile(mode='w',prefix='p-py-o-',delete=False)
        outputFilePath= outputFile.name
        outputFile.close()
        
        argString = ''
        for cmd in commands:
            cmd = cmd.replace("\n", "\\n")
            cmd = cmd.replace("\t", "\\t")
            cmd = cmd.replace("\r", "\\r")
            cmd = cmd.replace("\"", "\\\"")
            argString += '  - "{0}"\n'.format(cmd)
            
        with open(controlFilePath,'w') as cf:
            cf.write('action: query\n')
            cf.write('pathToYamlDescription: "{0}"\n'.format(pathToYamlDescription.replace("\\","\\\\")))
            cf.write('responseFilePath: "{0}"\n'.format(responseFilePath.replace("\\","\\\\")))
            cf.write('responseFormat: json\n')
            cf.write('arguments:\n{0}'.format(argString))
        
        hubPath = os.path.join(scriptDir,'helper','any-language-hub.rb')
        command = "{0} {1} {2}".format(
            quote(pathToRuby),
            quote(hubPath),
            quote(controlFilePath)
        )
        
        os.system(command)
        
        responseFile = open(responseFilePath)
        self.anyLanguageHubResponse = {}
        try:
            self.anyLanguageHubResponse = json.load(responseFile)           
        except:
            pass
        if 'run' in self.anyLanguageHubResponse.keys():
            if self.anyLanguageHubResponse['run'] == 'run':
                outputFile = open(outputFilePath, 'w', 0)
                sys.stdout = os.fdopen(sys.stdout.fileno(), 'w', 0)
                os.dup2(sys.stdout.fileno(),outputFile.fileno())
            
                #sys.stdout = outputFile
                self.param  = self.anyLanguageHubResponse['param']
                self.input  = self.anyLanguageHubResponse['input']
                self.output = self.anyLanguageHubResponse['output']

                self.run()
                outputFile.close()
            
                with open(controlFilePath,'w') as cf:
                    cf.write('action: finish\n')
                    cf.write('pathToYamlDescription: "{0}"\n'.format(pathToYamlDescription.replace("\\","\\\\")))
                    cf.write('responseFilePath: "{0}"\n'.format(responseFilePath.replace("\\","\\\\")))
                    cf.write('responseFormat: json\n')
                    cf.write('arguments:\n{0}'.format(argString))
                    cf.write('outputFilePath: "{0}"\n'.format(outputFilePath.replace("\\","\\\\")))
                    cf.write('startTime: {0}\n'.format(self.anyLanguageHubResponse['startTime']))
                
                command = "{0} {1} {2}".format(
                    quote(pathToRuby),
                    quote(hubPath),
                    quote(controlFilePath)
                )
                
                os.system( command )
        else:
            pass
        
        responseFile.close()
        os.unlink(controlFilePath)
        os.unlink(responseFilePath)
        os.unlink(outputFilePath)

def main():
    pass


if __name__ == '__main__':
    main()

