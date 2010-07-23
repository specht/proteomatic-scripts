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

sys.path.append('include/python')
import proteomatic


class DecoyFasta(proteomatic.ProteomaticScript):
	def run(self):
		if 'outputDatabase' in self.output.keys():
			print("Creating taget/decoy database ... \n")
			#print(self.output)
			databases = " ".join(["\"{0}\"".format(x) for x in self.input['databases']])
			opts = {
			'--output': 		self.output['outputDatabase'],
			'--method': 		self.param['targetDecoyMethod'],
			'--decoyFormat':	self.param['decoyEntryPrefix'],
			'--targetFormat':	self.param['targetEntryPrefix'], 
			'--keepStart': 		self.param['targetDecoyKeepStart'],
			'--keepEnd': 		self.param['targetDecoyKeepEnd']
			}
			command = self.binaryPath('ptb.decoyfasta')+' '
			for fl,fi in opts.items():
				command += fl+' "'+str(fi)+'" '
			command += databases
			os.system(command)
			#print(command)
			print("Done...")
			
if __name__ == '__main__':
	script = DecoyFasta()


"""
{
    function run()
    {
        if (isset($this->output->outputDatabase))
        {
            echo "Creating target/decoy database...\n";
            $databases = "";
            foreach ($this->input->databases as $path)
                $databases .= ' "'.$path.'"';
            $command = "{$this->binaryPath('ptb.decoyfasta')} --output \"{$this->output->outputDatabase}\" --method \"{$this->param->targetDecoyMethod}\" --keepStart {$this->param->targetDecoyKeepStart} --keepEnd {$this->param->targetDecoyKeepEnd} --targetFormat \"{$this->param->targetEntryPrefix}\" --decoyFormat \"{$this->param->decoyEntryPrefix}\" $databases";
            passthru($command);
            echo "done.\n";
        }
    }
}

$script = new DecoyFasta();
"""