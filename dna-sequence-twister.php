<?php
// a proteomatic-enabled script

$yamlInfo = <<<EOD
title: DNA Sequence Twister
description: Returns the reverse, complement and revers-complement sequence for a given DNA sequence.
group: Genomics

parameters:
- key: nucleotides
  label: DNA Sequence
  type: string
  default: GATC
  group: Parameters

EOD;

$argument = $argv[1];

if ($argument == '---yamlInfo')
{
    echo "---yamlInfo\n";
	echo $yamlInfo;
	exit(0);
}

if(preg_match('/[BDEFHIJKLMNOPQRSUVWXYZ0-9]/',$argv[2])){
	print("Please enter a valid DNA sequence");
	exit(0);
}else{
	//// Return original Sequence
	print("\nOriginal sequence:\n".$argv[2]." (".strlen($argv[2])." bp)\n");

	print("\nReverse sequence:\n".strrev($argv[2])."\n");

	$z = strlen($argv[2]);
		$sequence_new = array();
		for($i=0; $i<$z; $i++){
			if($argv[2][$i] == "G")
				$sequence_new[$i] = str_replace("G","C",$argv[2][$i]);
			if($argv[2][$i] == "C")
				$sequence_new[$i] = str_replace("C","G",$argv[2][$i]);
			if($argv[2][$i] == "T")
				$sequence_new[$i] = str_replace("T","A",$argv[2][$i]);
			if($argv[2][$i] == "A")
				$sequence_new[$i] = str_replace("A","T",$argv[2][$i]);
		}
	$sequence_new = implode($sequence_new);
	print("\nComplement sequence:\n".$sequence_new."\n");

	print("\nReverse-Complement sequence:\n".strrev($sequence_new)."");	
exit(0);
}
?>
