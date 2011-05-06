#! /usr/bin/env php
<?php

require_once ('include/php/proteomatic.php');

class TransposeDna extends ProteomaticScript
{
    function run()
    {
        // convert all characters to upper case
        $dna = strtoupper($this->param->nucleotides);
        // remove invalid characters
        $dna = preg_replace('/[^CGAT]/', '', $dna);
        // reverse sequence
        $dna = strrev($dna);
        // replace nucleotides
        $dna = strtr($dna, 'ACGT', 'TGCA');
        // output transposed DNA
        print($dna."\n");
        if (isset($this->output->result))
        {
            $f = fopen($this->output->result, 'w');
            fprintf($f, $dna."\n");
            fclose($f);
        }
    }
}

$script = new TransposeDna();
?>

