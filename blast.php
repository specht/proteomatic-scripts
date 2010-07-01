<?php
require_once ('include/php/proteomatic.php');
require_once ('include/php/proteomatic_functions.php');
require_once ('include/php/ext/spyc.php');

class BlastScript extends ProteomaticScript
{
    function run()
    {
        echo "Hello, this is the BLAST script!\n";
        echo "I have parameters:\n";
        var_dump($this->param);
        echo "I have input files:\n";
        var_dump($this->input);
    }
}

$script = new BlastScript();
?>
