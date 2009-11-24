<?php
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

//// Additional files needed to run this script
require_once ('include/php/ext/spyc.php');
require_once ('include/php/ext/parsecsv.php');

$yamlInfo = Spyc::YAMLLoad($yamlInfoString);
if(isset($argv[1]))
	$argument = $argv[1];
else
	$argument = "";
if(isset($argv[2]))
	$short = $argv[2];
else
	$short = "";
	

if ($argument == '---yamlInfo' && $short == '')
{
    echo "---yamlInfo\n";
	echo "---\n";
	echo $yamlInfoString;
	exit(0);
}

if ($argument == '---yamlInfo' && $short == '--short')
{
    echo "---yamlInfo\n";
	echo "---\n";
	echo "title: ".$yamlInfo['title']."\n";
	echo "description: ".$yamlInfo['description']."\n";
	echo "group: ".$yamlInfo['group']."\n";
	exit(0);
}

function parameterArray($parameters)
{
	$parameter[] = array();
	for($i=1; $i<count($parameters); $i++)
	{
		if(is_file($parameters[$i]))
			$parameter['files'][] = $parameters[$i];
		else{
			$parameter['parameters'][$parameters[$i]] = $parameters[$i+1];
			$i++;
		}
	}
return $parameter;
}

/// Get Parameters and files
$parameters = parameterArray($argv);

$csv = new parseCSV();
foreach($parameters['files'] as $file){
	$csv->auto($file);
	$dir = $parameters['parameters']['-outputDirectory'];
	if($parameters['parameters']['-outputDirectory'] == "")
		$dir = dirname($file);
	$outfile = fopen($dir."/".$parameters['parameters']['-outputPrefix']."html-table.html", "w");
	$content ="
	<html>
	<head>
	<title>".basename($file)." | CSV-Viewer</title>
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
	print("\nHTML table successfully generated from ".basename($file).".\n");
	unset($content);
}
exit(0);
?>
