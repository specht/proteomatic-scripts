<?php

abstract class ProteomaticScript
{
    abstract protected function run();
	
	protected $param;
    protected $input;
    protected $output;
    
    function __construct()
    {
        global $argv;
        
        // remove script name from arg list
        $scriptFilename = array_shift($argv);
        $currentDir = getcwd();
        
        // remove $currentDir from $scriptFilename if it's a prefix
        if ((count($currentDir) > 0) && (strpos($scriptFilename, $currentDir) == 0))
        {
            $scriptFilename = str_replace($currentDir, "", $scriptFilename);
        }
        
        // change working directory to script's directory
        $completeScriptPath = realpath($currentDir."/".$scriptFilename);
        
        chdir(dirname($completeScriptPath));
        $scriptFilename = basename($scriptFilename);
        
        // check for user-defined Ruby
        $pathToRuby = "ruby";
        if (($index = array_search('--pathToRuby', $argv)) != FALSE)
        {
            $chunk = array_splice($argv, $index, 2);
            $pathToRuby = $chunk[1];
        }

        // determine path to YAML description
        $parts = explode('.', $scriptFilename);
        $scriptBasename = implode('.', array_slice($parts, 0, count($parts) - 1));
        $pathToYamlDescription = realpath("include/properties/$scriptBasename.yaml");

        // create parameter string
        $argString = "";
        foreach ($argv as $arg)
            $argString .= " \"$arg\"";
        
        // now we have to allocate three temporary files:
        // - control 
        // - response
        // - output
        
        $controlFilePath = realpath(tempnam(sys_get_temp_dir(), 'p-php-c-'));
        $controlFile = fopen($controlFilePath, 'w');
        fclose($controlFile);
        $responseFilePath = realpath(tempnam(sys_get_temp_dir(), 'p-php-r-'));
        $responseFile = fopen($responseFilePath, 'w');
        fclose($responseFile);
        $outputFilePath = realpath(tempnam(sys_get_temp_dir(), 'p-php-o-'));
        $outputFile = fopen($outputFilePath, 'w');
        fclose($outputFile);
        
        $controlFile = fopen($controlFilePath, 'w');
        fwrite($controlFile, "action: query\n");
        fwrite($controlFile, "pathToYamlDescription: \"$pathToYamlDescription\"\n");
        fwrite($controlFile, "responseFilePath: \"$responseFilePath\"\n");
        fwrite($controlFile, "responseFormat: json\n");
        fclose($controlFile);
        
        // call Proteomatic's any language hub
        $this->call("\"$pathToRuby\" helper/any-language-hub.rb \"$controlFilePath\" $argString");
        
        // check if we're supposed to run this thing now
        $response = json_decode(file_get_contents($responseFilePath));
        
        if (isset($response->run) && ($response->run == "run"))
        {
            $this->param = $response->param;
            $this->input = $response->input;
            $this->output = $response->output;

            ob_start(array(&$this, "outputCatcher"), 8);
            $this->collectedOutput = "";
            $this->run();
            ob_end_clean();
            
            $outputFile = fopen($outputFilePath, 'w');
            fwrite($outputFile, $this->collectedOutput);
            fclose($outputFile);
            
            $startTime = $response->startTime;
            
            $controlFile = fopen($controlFilePath, 'w');
            fwrite($controlFile, "action: finish\n");
            fwrite($controlFile, "pathToYamlDescription: \"$pathToYamlDescription\"\n");
            fwrite($controlFile, "responseFilePath: \"$responseFilePath\"\n");
            fwrite($controlFile, "responseFormat: json\n");
            fwrite($controlFile, "outputFilePath: \"$outputFilePath\"\n");
            fwrite($controlFile, "startTime: \"$startTime\"\n");
            fclose($controlFile);
            
            $this->call("\"$pathToRuby\" helper/any-language-hub.rb \"$controlFilePath\" $argString");
        }
        
        unlink($controlFilePath);
        unlink($responseFilePath);
        unlink($outputFilePath);
    }
    
    function call($commandLine)
    {
        $descriptorSpec = array(
            1 => array('pipe', 'w'),
            2 => array('pipe', 'a')
        );

        $process = proc_open($commandLine, $descriptorSpec, $pipes);
        $exitCode = false;

        if (is_resource($process)) {
            $read_output = $read_error = false;
            $buffer_len  = $prev_buffer_len = 0;
            $ms          = 10;
            $output      = '';
            $read_output = true;
            $error       = '';
            $read_error  = true;
            stream_set_blocking($pipes[1], 0);
            stream_set_blocking($pipes[2], 0);
            while ($read_error != false and $read_output != false)
            {
                if ($read_output != false)
                {
                    if(feof($pipes[1]))
                    {
                        fclose($pipes[1]);
                        $read_output = false;
                    }
                    else
                    {
                        $str = fgets($pipes[1], 1024);
                        $len = strlen($str);
                        if ($len)
                        {
                            $output .= $str;
                            echo $str;
                            $buffer_len += $len;
                        }
                    }
                }
            
                if ($read_error != false)
                {
                    if(feof($pipes[2]))
                    {
                        fclose($pipes[2]);
                        $read_error = false;
                    }
                    else
                    {
                        $str = fgets($pipes[2], 1024);
                        $len = strlen($str);
                        if ($len)
                        {
                            $error .= $str;
                            $buffer_len += $len;
                        }
                    }
                }
            
                if ($buffer_len > $prev_buffer_len)
                {
                    $prev_buffer_len = $buffer_len;
                    $ms = 10;
                }
                else
                {
                    usleep($ms * 1000); // sleep for $ms milliseconds
                    if ($ms < 160)
                        $ms = $ms * 2;
                }
            }
            proc_close($process);
        }
    }
    
    function outputCatcher($buffer)
    {
        fwrite(STDOUT, $buffer);
        fflush(STDOUT);
        $this->collectedOutput .= $buffer;
        return "";
    }
}

?>
