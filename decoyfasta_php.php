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

class BlastScript extends ProteomaticScript
{
    function run()
    {
        $a = $this->param->decoyEntryPrefix;
        echo "Using $a as a decoy entry prefix.\n";
        echo "I want a sailship!\n";
        echo "I say, a sailship!\n";
        echo "Look, I'm creating the target/decoy database!\n";
        for ($i = 0; $i <= 100; $i++)
        {
            echo "\rProcessing... $i% done.";
            usleep(10000);
        }
        echo "\n";
    }
}

$script = new BlastScript();

// require 'include/php/proteomatic'
// require 'include/ruby/externaltools'
// require 'yaml'
// require 'set'
// 
// 
// class DecoyFasta < ProteomaticScript
//  def run()
//      if @output[:outputDatabase]
//          print 'Creating target/decoy database...'
//          ls_Command = "#{ExternalTools::binaryPath('ptb.decoyfasta')} --output \"#{@output[:outputDatabase]}\" --method \"#{@param[:targetDecoyMethod]}\" --keepStart #{@param[:targetDecoyKeepStart]} --keepEnd #{@param[:targetDecoyKeepEnd]} --targetFormat \"#{@param[:targetEntryPrefix]}\" --decoyFormat \"#{@param[:decoyEntryPrefix]}\" #{@input[:databases].collect { |x| '"' + x + '"'}.join(' ')}"
//          runCommand(ls_Command, true)
//          puts 'done.'
//      end
//  end
// end
// 
// lk_Object = DecoyFasta.new

?>

