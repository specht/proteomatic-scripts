<?php

require_once ('include/php/proteomatic.php');

$yamlInfo = <<<EOD
title: ClustalW2
description: ClustalW2 for Proteomatic.
group: Genomics

parameters:
  - choices:
    - R: heavy arginine
    - RP: heavy arginin
    - N15: N15
    default: RP
    type: enum
    value: RP
    key: label
    label: Label
	group: Parameters
  - choices:
    - GCG: GCG
    - GDR: GDE
    - PHYLIP: PHYLIP
    - PIR: PIR
    - NEXUS: NEXUS
    default: GCG
    type: enum
    key: outfileformat
    group: Output
    label: File Format
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


class Script extends ProteomaticScript
{
    protected function run()
    {
        echo "hello\n";
		echo "outfileformat is ".$this->parameters['outfileformat']."\n";
    }
}

$object = new Script();

exit(1);


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

/// Get Parameters and files
$parameters = parameterArray($argv);

echo $parameters['files'][0];
/// c:\\Dokumente und Einstellungen\\Besitzer\\Desktop\\sequence_alignment_PC_and_optPC.fasta
passthru ("C:\\Programme\\ClustalW2\\clustalw2.exe \"\" -INFILE=\"".$parameters['files'][0]."\"");
exit(0);

$data = <<<TEST

Data
Verbs
Parameters


                VERBS (do things)

-OPTIONS            :list the command line parameters
-HELP  or -CHECK    :outline the command line params.
-FULLHELP           :output full help content.
-ALIGN              :do full multiple alignment.
-TREE               :calculate NJ tree.
-BOOTSTRAP(=n)      :bootstrap a NJ tree (n= number of bootstraps; def. = 1000).
-CONVERT            :output the input sequences in a different file format.


                PARAMETERS (set things)

***General settings:****
-INTERACTIVE :read command line, then enter normal interactive menus
-QUICKTREE   :use FAST algorithm for the alignment guide tree
-TYPE=       :PROTEIN or DNA sequences
-NEGATIVE    :protein alignment with negative values in matrix
-OUTFILE=    :sequence alignment file name
-OUTPUT=     :GCG, GDE, PHYLIP, PIR or NEXUS
-OUTORDER=   :INPUT or ALIGNED
-CASE        :LOWER or UPPER (for GDE output only)
-SEQNOS=     :OFF or ON (for Clustal output only)
-SEQNO_RANGE=:OFF or ON (NEW: for all output formats)
-RANGE=m,n   :sequence range to write starting m to m+n
-MAXSEQLEN=n :maximum allowed input sequence length

***Fast Pairwise Alignments:***
-KTUPLE=n    :word size
-TOPDIAGS=n  :number of best diags.
-WINDOW=n    :window around best diags.
-PAIRGAP=n   :gap penalty
-SCORE       :PERCENT or ABSOLUTE


***Slow Pairwise Alignments:***
-PWMATRIX=    :Protein weight matrix=BLOSUM, PAM, GONNET, ID or filename
-PWDNAMATRIX= :DNA weight matrix=IUB, CLUSTALW or filename
-PWGAPOPEN=f  :gap opening penalty        
-PWGAPEXT=f   :gap opening penalty


***Multiple Alignments:***
-NEWTREE=      :file for new guide tree
-USETREE=      :file for old guide tree
-MATRIX=       :Protein weight matrix=BLOSUM, PAM, GONNET, ID or filename
-DNAMATRIX=    :DNA weight matrix=IUB, CLUSTALW or filename
-GAPOPEN=f     :gap opening penalty        
-GAPEXT=f      :gap extension penalty
-ENDGAPS       :no end gap separation pen. 
-GAPDIST=n     :gap separation pen. range
-NOPGAP        :residue-specific gaps off  
-NOHGAP        :hydrophilic gaps off
-HGAPRESIDUES= :list hydrophilic res.    
-MAXDIV=n      :% ident. for delay
-TYPE=         :PROTEIN or DNA
-TRANSWEIGHT=f :transitions weighting
-ITERATION=    :NONE or TREE or ALIGNMENT
-NUMITER=n     :maximum number of iterations to perform


***Profile Alignments:***
-PROFILE      :Merge two alignments by profile alignment
-NEWTREE1=    :file for new guide tree for profile1
-NEWTREE2=    :file for new guide tree for profile2
-USETREE1=    :file for old guide tree for profile1
-USETREE2=    :file for old guide tree for profile2


***Sequence to Profile Alignments:***
-SEQUENCES   :Sequentially add profile2 sequences to profile1 alignment
-NEWTREE=    :file for new guide tree
-USETREE=    :file for old guide tree


***Structure Alignments:***
-NOSECSTR1     :do not use secondary structure-gap penalty mask for profile 1 
-NOSECSTR2     :do not use secondary structure-gap penalty mask for profile 2
-SECSTROUT=STRUCTURE or MASK or BOTH or NONE   :output in alignment file
-HELIXGAP=n    :gap penalty for helix core residues 
-STRANDGAP=n   :gap penalty for strand core residues
-LOOPGAP=n     :gap penalty for loop regions
-TERMINALGAP=n :gap penalty for structure termini
-HELIXENDIN=n  :number of residues inside helix to be treated as terminal
-HELIXENDOUT=n :number of residues outside helix to be treated as terminal
-STRANDENDIN=n :number of residues inside strand to be treated as terminal
-STRANDENDOUT=n:number of residues outside strand to be treated as terminal 


***Trees:***
-OUTPUTTREE=nj OR phylip OR dist OR nexus
-SEED=n        :seed number for bootstraps.
-KIMURA        :use Kimura's correction.   
-TOSSGAPS      :ignore positions with gaps.
-BOOTLABELS=node OR branch :position of bootstrap values in tree display
-CLUSTERING=   :NJ or UPGMA



TEST;
?>