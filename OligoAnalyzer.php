<?php
// a proteomatic-enabled script

$yamlInfo = <<<EOD
title: DNA OligoAnalyzer
description: Calculate melting temperature (Tm) GC-Content (%) and Base count from a DNA oligo sequence.
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
	/// Return given sequence
	print("\nSequence:\n".$argv[2]." (".strlen($argv[2])." bp)\n\n");
	
	//// Get sequence lenght
	$z = strlen($argv[2]);
	
	//// Calculate and return Tm
	if($z < "14")
		$tm = (substr_count($argv[2],"A") + substr_count($argv[2],"T")) * 2 + (substr_count($argv[2],"G") + substr_count($argv[2],"C")) * 4 - 16.6 * log10(0.05) + 16.6 * log10(0.05);
	if($z >= "14")
		$tm = 100.5 + (41 * (substr_count($argv[2],"G") + substr_count($argv[2],"C")) / (substr_count($argv[2],"G") + substr_count($argv[2],"C") + substr_count($argv[2],"A") + substr_count($argv[2],"T"))) - (820 / (substr_count($argv[2],"G") + substr_count($argv[2],"C") + substr_count($argv[2],"A") + substr_count($argv[2],"T"))) + 16.6 * log10(0.05);
	if($z >= "50")
		$tm = 81.5 + (41 * (substr_count($argv[2],"G") + substr_count($argv[2],"C")) / (substr_count($argv[2],"G") + substr_count($argv[2],"C") + substr_count($argv[2],"A") + substr_count($argv[2],"T"))) - (500 / (substr_count($argv[2],"G") + substr_count($argv[2],"C") + substr_count($argv[2],"A") + substr_count($argv[2],"T"))) + 16.6 * log10(0.05) - 0.62;
	print("Melting Temperature:\nTm: ". round($tm,2)." °C\n\n");


	/// Calculate and return GC content
	$gc = (((substr_count($argv[2],"G") + substr_count($argv[2],"C")) / $z) *100);
	$at = (((substr_count($argv[2],"A") + substr_count($argv[2],"T")) / $z) *100);
	print ("GC-Content:\nGC = ". round($gc,1)." %\t AT = ". round($at,1)." %\n\n");

	/// Calculate and return Bass count
	print("Bases($z bp):\nG: ".substr_count($argv[2],"G")."\tA: ".substr_count($argv[2],"A")."\nC: ".substr_count($argv[2],"C")."\tT: ".substr_count($argv[2],"T"));
exit(0);
}

?>
