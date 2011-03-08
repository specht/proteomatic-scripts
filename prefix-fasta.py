#!/usr/bin/env python
"""
Copyright (c) 2011 Michael Specht

This file is part of Proteomatic.

Proteomatic is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Proteomatic is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Proteomatic.  If not, see <http://www.gnu.org/licenses/>.
"""

import sys, os

sys.path.append('./include/python')
import proteomatic


class PrefixFasta(proteomatic.ProteomaticScript):
    def run(self):
        if self.output['prefixed']:
            with open(self.output['prefixed'], 'w') as fout:
                for inPath in self.input['fasta']:
                    with open(inPath, 'r') as fin:
                        for line in fin:
                            if line[0:1] == '>':
                                line = '>' + self.param['prefix'] + line[1:]
                            fout.write(line)
        
if __name__ == '__main__':
    script = PrefixFasta()
