<?php

require_once ('include/php/ext/spyc.php');

abstract class ProteomaticScript
{
    abstract protected function run();
	
	protected $parameters;
    
    function __construct()
    {
        global $yamlInfo;
        global $argv;
        
        $scriptInfo = Spyc::YAMLLoad($yamlInfo);
		
		/*
		parameters:
		  key: value
		*/
		$this->parameters = Array();
		$this->parameters['outfileformat'] = 'NEXUS';
		
		/*
		inputFiles:
		  groupKey: [path 1, path 2]
		*/
		$this->inputFiles = Array();
		
		/*
		outputFiles:
		  aln: path
		*/
		$this->inputFiles = Array();
        // handle ---yamlInfo switch
        if ($argv[1] == '---yamlInfo')
        {
            echo "---yamlInfo\n";
            echo $yamlInfo;
            exit(0);
        }
        
        $this->run();
    }
}
?>
