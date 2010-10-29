<?php
/*
Copyright (c) 2010 Michael Specht and Sebastian Kuhlgert

This file is part of Proteomatic.

Proteomatic is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Proteomatic is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Proteomatic.  If not, see <http://www.gnu.org/licenses/>.
*/

abstract class ProteomaticScript
{
    abstract protected function run();
    
    protected $param;
    protected $input;
    protected $output;
    
    function __construct()
    {
        global $argv;
        
        $scriptPath = array_shift($argv);
        // chdir to script's directory
		$scriptDir = dirname($scriptPath);

        // check for user-defined Ruby
        $pathToRuby = "ruby";
        if (($index = array_search('--pathToRuby', $argv)) !== FALSE)
        {
            $chunk = array_splice($argv, $index, 2);
            $pathToRuby = $chunk[1];
        }
		
        // determine path to YAML description
        $scriptBasename = explode('.', basename($scriptPath));
		$scriptBasename = $scriptBasename[0];
        $pathToYamlDescription = implode(DIRECTORY_SEPARATOR, array($scriptDir, 'include', 'properties', $scriptBasename.'.yaml'));
        
        // now we have to allocate three temporary files:
        // - control 
        // - response
        // - output
        
        $controlFilePath = tempnam(sys_get_temp_dir(), 'p-php-c-');
        $controlFile = fopen($controlFilePath, 'w');
        fclose($controlFile);
        $responseFilePath = tempnam(sys_get_temp_dir(), 'p-php-r-');
        $responseFile = fopen($responseFilePath, 'w');
        fclose($responseFile);
        $outputFilePath = tempnam(sys_get_temp_dir(), 'p-php-o-');
        $outputFile = fopen($outputFilePath, 'w');
        fclose($outputFile);

        $argString = "";
        foreach ($argv as $arg)
        {
            // replace \n \t \r "
            $arg = str_replace("\n", "\\n", $arg);
            $arg = str_replace("\t", "\\t", $arg);
            $arg = str_replace("\r", "\\r", $arg);
            $arg = str_replace("\"", "\\\"", $arg);
            $argString .= "  - \"".$arg."\"\n";
        }
        
        $controlFile = fopen($controlFilePath, 'w');
        fwrite($controlFile, "action: query\n");
        fwrite($controlFile, "pathToYamlDescription: \"".str_replace("\\", "\\\\", $pathToYamlDescription)."\"\n");
        fwrite($controlFile, "responseFilePath: \"".str_replace("\\", "\\\\", $responseFilePath)."\"\n");
        fwrite($controlFile, "responseFormat: json\n");
        fwrite($controlFile, "arguments:\n".$argString);

        fclose($controlFile);
		
        // call Proteomatic's any language hub
        $hubPath = implode(DIRECTORY_SEPARATOR, array($scriptDir, 'helper', 'any-language-hub.rb'));
        $command = escapeshellarg($pathToRuby) . ' ' . escapeshellarg($hubPath) . ' ' . escapeshellarg($controlFilePath);
        system($command);
        // check if we're supposed to run this thing now
        $response = json_decode(file_get_contents($responseFilePath));
        
        if (isset($response->run) && ($response->run == "run"))
        {
            $this->param = $response->param;
            $this->input = $response->input;
            $this->output = $response->output;

            ob_start(array(&$this, "outputCatcher"), 8);
            $this->collectedOutput = "";
            $this->anyLanguageHubResponse = $response;
            $this->run();
            ob_end_clean();
            
            $outputFile = fopen($outputFilePath, 'w');
            fwrite($outputFile, $this->collectedOutput);
            fclose($outputFile);
            
            $startTime = $response->startTime;
            
            $controlFile = fopen($controlFilePath, 'w');
            fwrite($controlFile, "action: finish\n");
            fwrite($controlFile, "pathToYamlDescription: \"".str_replace("\\", "\\\\", $pathToYamlDescription)."\"\n");
            fwrite($controlFile, "responseFilePath: \"".str_replace("\\", "\\\\", $responseFilePath)."\"\n");
            fwrite($controlFile, "responseFormat: json\n");
            fwrite($controlFile, "arguments:\n".$argString);
            fwrite($controlFile, "outputFilePath: \"".str_replace("\\", "\\\\", $outputFilePath)."\"\n");
            fwrite($controlFile, "startTime: \"$startTime\"\n");
            fclose($controlFile);

			$command = escapeshellarg($pathToRuby) . ' ' . escapeshellarg($hubPath) . ' ' . escapeshellarg($controlFilePath);
			system($command);
        }
        
        unlink($controlFilePath);
        unlink($responseFilePath);
        unlink($outputFilePath);
    }
    
    function outputCatcher($buffer)
    {
        fwrite(STDOUT, $buffer);
        fflush(STDOUT);
        $this->collectedOutput .= $buffer;
        return "";
    }
    
    function binaryPath($tool)
    {
        return $this->anyLanguageHubResponse->binaryPath->$tool;
    }
}

?>
