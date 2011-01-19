#!/usr/bin/env python
"""
Copyright (c) 2010 Christian Fufezan

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


class unwrapFastaSeqs(proteomatic.ProteomaticScript):
    def run(self):
        for inf,outf in self.output.items():
            inf = open(inf)
            outf = open(outf,"w")
            outf.write(inf.readline())
            for line in inf:
                outf.write( line.strip() if line[0] != '>' else "\n"+line )
            print("Done...")
        
if __name__ == '__main__':
    script = unwrapFastaSeqs()
