<?php
/*
Copyright (c) 2010 Michael Specht

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
*/

require_once ('include/php/proteomatic.php');

class CreateArchive extends ProteomaticScript
{
    function run()
    {
        if (isset($this->output->outputArchive))
        {
            echo "Creating an archive from filelist...\n";
            $inputfiles = "";
            foreach ($this->input->files as $path)
                $inputfiles .= "\"".$path. "\" ";
			$command = "{$this->binaryPath('7zip.7zip')} a -t{$this->param->compressioswitch} {$this->output->outputArchive} ".$inputfiles;
            passthru($command);
            echo "done.\n";
        }
    }
}

$script = new CreateArchive();
