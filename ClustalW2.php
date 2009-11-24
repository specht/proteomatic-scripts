<?php
// a proteomatic-enabled script

$yamlInfoString = <<<EOD
title: ClustalW2
description: ClustalW2 for Proteomatic.
group: Genomics

parameters:
  - choices:
    - ALIGN: do full multiple alignment
    - TREE: calculate NK tree
    default: ALIGN
    type: enum
    key: type
    label: Type
    group: Alignment 
  - choices:
    - auto: auto
    - 1: 1
    - 2: 2
    - 3: 3
    - 4: 4
    - 5: 5
    default: auto
    type: enum
    key: ktup
    label: Word size (KTUP)
    group: Parameters
  - choices:
    - auto: auto
    - 0: 0
    - 1: 1
    - 2: 2
    - 3: 3
    - 4: 4
    - 5: 5
    - 6: 6
    - 7: 7
    - 8: 8
    - 9: 9
    - 10: 10
    default: auto
    type: enum
    key: windowlen
    label: Window length
    group: Parameters
  - choices:
    - percent: percent
    - absolute: absolute
    default: percent
    type: enum
    key: scoretype
    label: Score type
    group: Parameters
  - choices:
    - auto: auto
    - 1: 1
    - 2: 2
    - 3: 3
    - 4: 4
    - 5: 5
    - 6: 6
    - 7: 7
    - 8: 8
    - 9: 9
    - 10: 10
    default: auto
    type: enum
    key: topdiag
    label: Top diag
    group: Parameters
  - choices:
    - auto: auto
    - 1: 1
    - 2: 2
    - 3: 3
    - 4: 4
    - 5: 5
    - 10: 10
    - 25: 25
    - 50: 50
    - 100: 100
    - 250: 250
    - 500: 500
    default: auto
    type: enum
    key: pairgap
    label: Pair gap
    group: Parameters
  - choices:
    - auto: auto
    - BLOSUM: BLOSUM
    - PAM: PAM
    - GONNET: GONNET
    - ID: ID
    default: auto
    type: enum
    key: matrix
    label: Protein weight matrix
    group: Parameters
  - choices:
    - auto: auto
    - 100: 100
    - 50: 50
    - 25: 25
    - 10: 10
    - 5: 5
    - 2: 2
    - 1: 1
    default: auto
    type: enum
    key: gapopen
    label: Gap opening penalty
    group: Parameters
  - choices:
    - auto: auto
    - 100: 100
    - 50: 50
    - 25: 25
    - 10: 10
    - 5: 5
    - 2: 2
    - 1: 1
    default: auto
    type: enum
    key: gapopen
    label: Gap opening penalty
    group: Parameters
  - choices:
    - auto: auto
    - 0.05: 0.05
    - 0.5: 0.5
    - 1.0: 1.0
    - 2.5: 2.5
    - 5: 5
    - 7.5: 7.5
    - 10.0: 10.0
    default: auto
    type: enum
    key: gapextension
    label: Gap opening penalty (gap extension)
    group: Parameters
  - choices:
    - auto: auto
    - 1: 1
    - 2: 2
    - 3: 3
    - 4: 4
    - 5: 5
    - 6: 6
    - 7: 7
    - 8: 8
    - 9: 9
    - 10: 10
    default: auto
    type: enum
    key: gapdistance
    label: Gap distance
    group: Parameters
  - choices:
    - none: none
    - TREE: tree
    - ALIGMENT: alignment
    default: none
    type: enum
    key: iteration
    label: Iteration
    group: Parameters
  - choices:
    - 1: 1
    - 2: 2
    - 3: 3
    - 4: 4
    - 5: 5
    - 6: 6
    - 7: 7
    - 8: 8
    - 9: 9
    - 10: 10
    default: 1
    type: enum
    key: numiter
    label: Numiter
    group: Parameters
  - choices:
    - nj: nj
    - phylip: phylip
    - dist: dist
    - nexus: nexus
    - none: none
    default: none
    type: enum
    key: treetype
    label: Tree Type
    group: Phylogenetic tree
  - choices:
    - on: on
    - off: off
    default: off
    type: enum
    key: correctdistance
    label: Correct Distance
    group: Phylogenetic tree
    description: use Kimura's correction
  - choices:
    - on: on
    - off: off
    default: off
    type: enum
    key: ignoregaps
    label: Ignore Gaps
    group: Phylogenetic tree
    description: ignore positions with gaps
  - choices:
    - nj: nj
    - UPGMA: UPGMA
    default: nj
    type: enum
    key: clustering
    label: Clustering
    group: Phylogenetic tree
  - choices:
    - INPUT: Input
    - ALIGNED: Aligned
    default: INPUT
    type: enum
    key: outorder
    label: Order of Output
    group: Output files
  - choices:
    - aln w/numbers: aln w/numbers
    - aln wo/numbers: aln wo/numbers
    - GCG: GCG
    - GDE: GDE
    - PHYLIP: PHYLIP
    - PIR: PIR
    - NEXUS: NEXUS
    default: aln w/numbers
    type: enum
    key: outformat
    label: Output format
    group: Output files
  - key: outputDirectory
    type: string
    group: Output files
    label: Output directory
  - key: outputPrefix
    type: string
    group: Output files
    label: Output file prefix
  - key: outputWriteAln
    type: flag
    group: Output files
    label: Alignment File
    filename: alignment.aln
    description: Write aln file (alignment.aln)
    default: yes
defaultOutputDirectory: fastaFile
proposePrefixList: [fastaFile]
input:
  - key: fastaFile
    label: fasta
    extensions: .fasta/.fas/.txt
    description: at least one fasta file (.fasta | .fas | .txt)
    max: 10
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

//echo $parameters['files'][0];
include('c:/Dokumente und Einstellungen/Besitzer/Desktop/proteomatic_functions.php');

filemerge($parameters['files'], 'c:/Dokumente und Einstellungen/Besitzer/Desktop/');
/// c:\\Dokumente und Einstellungen\\Besitzer\\Desktop\\sequence_alignment_PC_and_optPC.fasta
//passthru ("C:\\Programme\\ClustalW2\\clustalw2.exe \"\" -INFILE=\"".$parameters['files'][0]."\"");
exit(0);

$used = <<<USED
***General settings:****
-OUTPUT=     :GCG, GDE, PHYLIP, PIR or NEXUS
-OUTORDER=   :INPUT or ALIGNED

***Fast Pairwise Alignments:***
-KTUPLE=n    :word size
-TOPDIAGS=n  :number of best diags.
-WINDOW=n    :window around best diags.
-PAIRGAP=n   :gap penalty
-SCORE       :PERCENT or ABSOLUTE


***Multiple Alignments:***
-MATRIX=       :Protein weight matrix=BLOSUM, PAM, GONNET, ID or filename
-GAPOPEN=f     :gap opening penalty        
-GAPEXT=f      :gap extension penalty
-ENDGAPS       :no end gap separation pen. 
-GAPDIST=n     :gap separation pen. range
-ITERATION=    :NONE or TREE or ALIGNMENT
-NUMITER=n     :maximum number of iterations to perform

***Trees:***
-KIMURA        :use Kimura's correction.   
-TOSSGAPS      :ignore positions with gaps.
-BOOTLABELS=node OR branch :position of bootstrap values in tree display
USED;
?>