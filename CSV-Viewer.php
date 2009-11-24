<?php

require_once 'include/php/ext/spyc.php';

// a proteomatic-enabled script

$yamlInfoString = <<<EOD
title: CSV File Viewer
description: Makes an easily readable table out of a given csv-file, that can be displayed by every browser (html).
group: Miscellaneous

parameters:
  - key: outputDirectory
    type: string
    group: Output files
    label: Output directory
  - key: outputPrefix
    type: string
    group: Output files
    label: Output file prefix
  - key: outputWriteHtml
    type: flag
    group: Output files
    label: HTML Table
    filename: html-table.html
    description: Write HTML Table (html-table.html)
    default: yes
defaultOutputDirectory: csvFile
proposePrefixList: [csvFile]
input:
  - key: csvFile
    label: CSV
    extensions: .csv/.txt
    description: exactly one CSV file (.csv | .txt)
    max: 1
    min: 1

EOD;

$yamlInfo = Spyc::YAMLLoad($yamlInfoString);

$argument = $argv[1];

if ($argument == '---yamlInfo')
{
    echo "---yamlInfo\n";
	echo $yamlInfoString;
	exit(0);
}

// random comment
//var_dump($argv);

require_once('lib/parsecsv.lib.php');
$csv = new parseCSV();
for($i=5; $i<$argc; $i++){
	if(!is_file($argv[$i]))
		exit(1);
	$csv->auto($argv[$i]);
	$inputfilename = basename($argv[$i]);
	$outfile = fopen($argv[4]."/".$argv[2].$inputfilename."-csv-viewer.html", "w");
	$content .="
	<html>
	<head>
	<title>".$inputfilename." | CSV-Viewer</title>
	<style type=\"text/css\" media=\"screen\">
		body table {font-family:arial; font-size:12px;}
		table { background-color: #BBB; }
		th { background-color: #EEE; }
		td { background-color: #FFF; }
	</style>
	</head>
	<body>
	<table border=\"0\" cellspacing=\"1\" cellpadding=\"3\">
	";	
		$content .="<tr>\n";
			foreach ($csv->titles as $value):
				$content .="<th>".$value."</th>\n";
			endforeach;
		$content .="</tr>\n";
		foreach ($csv->data as $key => $row):
		$content .="<tr>\n";
			foreach ($row as $value):
				$content .="<td>\n".$value."</td>\n";
			endforeach;
		$content .="</tr>\n";
		endforeach;
	$content .="</table>\n";
	$content .="<a href=\"javascript:print();\">[print]</a>";
	$content .="</body>\n";
	$content .="</html>\n";
	fwrite($outfile, $content);
	fclose($outfile);
	print("\n".($i - 4)."/".($argc -5)." - html successfully generated for ".$inputfilename.".\n");
	unset($content);
}
exit(0);

?>
