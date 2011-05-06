#! /usr/bin/env python

import sys, os
sys.path.append('./include/python')
import proteomatic
import string
import re

class TransposeDna(proteomatic.ProteomaticScript):
    def run(self):
        # convert all characters to upper case
        # Attention: parameters are Unicode because of the JSON parser 
        # used behind the scenes, convert nucleotides to ASCII string
        dna = str(self.param['nucleotides']).upper()
        # remove invalid characters
        dna = re.sub('[^ACGT]', '', dna)
        # reverse sequence
        dna = dna[::-1]
        # replace nucleotides
        dna = dna.translate(string.maketrans('ACGT', 'TGCA'))
        # output transposed DNA
        print(dna)
        
        if 'result' in self.output:
            with open(self.output['result'], 'w') as f:
                f.write(dna + "\n")
                
if __name__ == '__main__':
    script = TransposeDna()
