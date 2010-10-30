<?php
/*
Copyright (c) 2010 Sebastian Kuhlgert and Michael Specht

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
        if (isset($this->output->archive))
        {
            $s = ''.count($this->input->files).' input file';
            if (count($this->input->files) > 1)
                $s .= 's';
            echo "Creating an archive from $s...\n";
            $inputfiles = "";
            foreach ($this->input->files as $path)
                $inputfiles .= "\"".$path. "\" ";
            $targetPath = $this->output->archive;
            $tempTarPath = '';
            $type = $this->param->type;
            if (substr($this->param->type, 0, 4) == 'tar.')
            {
                // this is a tar.gz or tar.bz2 archive, so we have to create a tar archive
                // first and then compress that using -tgzip or -tbzip2
                $targetPath = $this->output->archive.'.tar.temp';
                $tempTarPath = $targetPath;
                $type = 'tar';
            }
            $command = "{$this->binaryPath('7zip.7zip')} a -t{$type} -mx{$this->param->level} \"{$targetPath}\" ".$inputfiles;
            passthru($command);
            if (substr($this->param->type, 0, 4) == 'tar.')
            {
                // now finish this by compressing the tar archive
                $targetPath = $this->output->archive;
                $type = $this->param->type;
                if ($type == 'tar.gz')
                    $type = 'gzip';
                if ($type == 'tar.bz2')
                    $type = 'bzip2';
                $command = "{$this->binaryPath('7zip.7zip')} a -t{$type} -mx{$this->param->level} \"{$targetPath}\" \"{$tempTarPath}\"";
                passthru($command);
                // ... and clean up after ourselves...
                if ($tempTarPath != '')
                    unlink($tempTarPath);
            }
            echo "done.\n";
        }
    }
}

$script = new CreateArchive();
