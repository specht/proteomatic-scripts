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

        // call Proteomatic's any language hub
        $lines = Array();
        $commandLine = "\"$pathToRuby\" helper/any-language-hub.rb \"$pathToYamlDescription\" $argString";
//         echo $commandLine."\n";
        $process = popen($commandLine, 'r');
        while (!feof($process))
        {
            $a = Array($process);
            $b = NULL;
            $c = NULL;
            if (false === ($changedStreamCount = stream_select($a, $b, $c, 30)))
            {
                echo "Error!\n";
            }
            else
            {
//                 echo $changedStreamCount."\n";
//                 echo fgets($process);
                echo fread($process, 10);
            }
        }
        pclose($process);

        /*
		$this->param = Array();
		$this->input = Array();
		$this->output = Array();

        $this->param['decoyEntryPrefix'] = '__putative__';

        $this->run();
        */
    }
}

?>
