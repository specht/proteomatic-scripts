<?php
// a proteomatic-enabled script

$yamlInfoString = <<<EOD
title: 2DB File Uploader
description: Upload MS/MS results into 2DB Proteomics Database (ams fileformat)
group: Proteomics/2DB Proteomics Database

parameters:
  - key: email
    type: string
    label: Email
    group: Parameters
    default: sebastian-kuhlgert@web.de
  - key: password
    type: string
    label: Password
    group: Parameters
    default: test1

EOD;
$yamlInfoString .= file_get_contents('http://www.uni-muenster.de/hippler/WWUPepProtDB_II/admin/proteomatic_parameters.php');
$yamlInfoString .= <<<EOD
  - key: samplenaming
    type: string
    label: Sample-Name
    group: Parameters
    default: initials_experiment_spot_date
input:
  - key: amsFile
    label: ams
    extensions: .ams
    description: at least one ams file (.ams)
    max: 10
    min: 1

EOD;

//// Additional files needed to run this script
require_once ('include/php/ext/spyc.php');

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

$parameters = parameterArray($argv);
$renaming = false;
$email = $parameters['parameters']['-email'];
$password = sha1($parameters['parameters']['-password']);
$host = "www.uni-muenster.de";
$hostpath = "/hippler/WWUPepProtDB_II/admin/AMSUpload.php";
//$hostpath = "/hippler/WWUPepProtDB_II/admin/request.php";
$filename = basename($parameters['files'][0]);
$organism = $parameters['parameters']['-organism'];
$method = $parameters['parameters']['-sepmethod'];
/*
if($argv[8] != "initials_experiment_spot_date"){
	$namestring = explode("_", $argv[8]);
	foreach($namestring as $key => $value){
		$sortname[$value] = $key;
	}
	$renaming = true;
}
*/
if(!$parameters['files'][0]){
    echo "No file selected!";
    die();
    exit(1);
}
/*
$file = fopen($parameters['files'][0], "r");
$filecontent = "";
while(!feof($file)){
	if($renaming == false){
		$filecontent .= fgets($file);
	}
	if($renaming == true){
		$zeile = explode("!", trim(fgets($file)),2);
		$templatepart = explode(".", $zeile[0], 2);
		$template = explode("_", $templatepart[0], 4);
		if($zeile[0] == "spectrum_id")
			$filecontent .= $zeile[0]."!".$zeile[1]."\n";
		else
			$filecontent .= $template[$sortname['initials']]."_".$template[$sortname['experiment']]."_".$template[$sortname['spot']]."_".$template[$sortname['date']].".".$templatepart[1]."!".$zeile[1]."\n";
	}
}
fclose($file);
*/
$httppostA = <<<REQUEST
POST #{2DB_URI} HTTP/1.1
Host: localhost:19810
Content-Type: multipart/form-data; boundary=---------------------------eaqrp1w4wpp1-1ximw0fz8t2mq1j2e2vq3yxnv1
User-Agent: Java/1.6.0_13
Accept: text/html, image/gif, image/jpeg, *; q=.2, */*; q=.2
Content-Length: #{CONTENT_LENGTH}
Connection: keep-alive

-----------------------------eaqrp1w4wpp1-1ximw0fz8t2mq1j2e2vq3yxnv1
Content-Disposition: form-data; name="file"; filename="#{FILE_NAME}"
Content-Type: application/octet-stream


REQUEST;

$httppostB = <<<REQUEST

-----------------------------eaqrp1w4wpp1-1ximw0fz8t2mq1j2e2vq3yxnv1
Content-Disposition: form-data; name="username"

#{USER_NAME}
-----------------------------eaqrp1w4wpp1-1ximw0fz8t2mq1j2e2vq3yxnv1
Content-Disposition: form-data; name="password"

#{ENCODED_PASSWORD}
-----------------------------eaqrp1w4wpp1-1ximw0fz8t2mq1j2e2vq3yxnv1
Content-Disposition: form-data; name="organism"

#{ORGANISM}
-----------------------------eaqrp1w4wpp1-1ximw0fz8t2mq1j2e2vq3yxnv1
Content-Disposition: form-data; name="method"

#{METHOD}
-----------------------------eaqrp1w4wpp1-1ximw0fz8t2mq1j2e2vq3yxnv1--
REQUEST;

/// Replace all parameters
$httppostA = str_replace("#{2DB_URI}", $hostpath, $httppostA);
$httppostA = str_replace("#{FILE_NAME}", $filename, $httppostA);
$httppostB = str_replace("#{USER_NAME}", $email, $httppostB);
$httppostB = str_replace("#{ENCODED_PASSWORD}", $password, $httppostB);
$httppostB = str_replace("#{ORGANISM}", $organism, $httppostB);
$httppostB = str_replace("#{METHOD}", $method, $httppostB);

/// Calculate the content lenght
$contentlenghtA = (strlen($httppostA) - (strpos($httppostA, "keep-alive")+14));
$contentlenghtB = strlen($httppostB);
$filelength = filesize($parameters['files'][0]);
$contentlenght = $contentlenghtA + $filelength + $contentlenghtB;

/// Write content lenght to header ($httppostA)
$httppostA = str_replace("#{CONTENT_LENGTH}", $contentlenght, $httppostA);

/// Connect to socket
$adress = gethostbyname($host);
$socket = socket_create(AF_INET, SOCK_STREAM, SOL_TCP);
socket_connect($socket, $adress, 80);


/// Loop through file and send to socket

socket_write($socket, $httppostA, strlen($httppostA));

$file = fopen($parameters['files'][0], "r");
while(!feof($file)){
	if($renaming == false){
		$filecontent = fgets($file);
        socket_write($socket, $filecontent, strlen($filecontent));
    }
}
fclose($file);

socket_write($socket, $httppostB, strlen($httppostB));

while($out = socket_read($socket, 2048)){
        echo $out;
}

/// Close socket connection
socket_close($socket);

exit(0);
?>
