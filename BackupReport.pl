#!c:/perl/bin/perl

use strict;
use warnings;

use Time::Local;
use Win32;

our($APP_AUTH) = 'Sigmund Straumland';
our($APP_USER) = Win32::LoginName() || "Unknown";
our($APP_USER_MACHINE) = Win32::NodeName() || "Unknown";
our($APP_WEB) = 'https://www.straumland.com';
our($APP_DATETIME) = getDateTime();

our(@TASKS, @MODULES, %SYSPAR, @ROUTINES, @VARIABLES);
our($GLOBALSCORE, $SCORE_ROUTINE_SIZE, $SCORE_ROUTINE_COMMENTS, $SCORE_VARIABLE_PREFIXES, $SCORE_VARIABLE_SHARED, $SCORE_INSTRUCTIONS);
our($SCORE_IO_PREFIXES, $SCORE_IO_LABELCATEGORY, $SCORE_IO_ACCESS);

Find_All_Tasks();
Find_All_Modules();
Find_All_Syspar();
Find_All_ProcFuncTrap();
Find_All_Variables();

# Generate MD report to be synced to repo
Generate_Report();

print "\n".'DONE!'."\n";
sleep(3);

exit;



#



sub Generate_Report {
	my($report);
	
	# Start with a score of 100
	$GLOBALSCORE = 100;
	
	my($variables) = '## Variables'."\n\n";
	$variables .= '### Prefixes check'."\n\n";
	$variables .= ReportGen_VariablePrefixes()."\n\n";
	$variables .= '### Task shared'."\n\n";
	$variables .= ReportGen_TaskSharedVariables()."\n\n";	
	$variables .= '---'."\n\n";
	
	my($routines) = '## Routines'."\n\n";
	$routines .= '### Size'."\n\n";
	$routines .= ReportGen_RoutineSize()."\n\n";
	$routines .= '### Comments'."\n\n";
	$routines .= ReportGen_RoutineComments()."\n\n";
	$routines .= '---'."\n\n";

	my($io) = '## IO'."\n\n";
	$io .= '### Prefixes'."\n\n";
	$io .= ReportGen_IoPrefixes()."\n\n";
	$io .= '### Labels and category'."\n\n";
	$io .= ReportGen_LabelCategory()."\n\n";
	$io .= '### Access Level'."\n\n";
	$io .= ReportGen_AccessLevel()."\n\n";
	$io .= '---'."\n\n";

	my($instructions) = '## Instructions'."\n\n";
	$instructions .= '### Forbidden'."\n\n";
	$instructions .= ReportGen_InstructionsForbidden()."\n\n";
	$instructions .= '### Ok but consider alternative'."\n\n";
	$instructions .= ReportGen_InstructionsRatherNot()."\n\n";
	$instructions .= '---'."\n\n";

	my($summary) = '## Summary'."\n\n";
	$summary .= '***Overall score: '.$GLOBALSCORE.'%***'."\n\n";
	$summary .= 'Overall score will be the lowest achieved score in any section of this report.'."\n\n";
	$summary .= 'Tasks: '.($#TASKS + 1).'  '."\n";
	$summary .= 'Modules: '.($#MODULES + 1).'  '."\n";
	$summary .= 'SystemParameters: '.(scalar keys %SYSPAR).'  '."\n";
	$summary .= 'Routines: '.($#ROUTINES + 1).'  '."\n";
	$summary .= 'Variables: '.($#VARIABLES + 1).'  '."\n\n";
	$summary .= '---'."\n\n";
	
	my($MD);
	open($MD, '>RepoScore.md');
	print $MD '# Rapid quality report'."\n\n";
	print $MD $summary;
	print $MD '[Summary](#summary)  '."\n";
	print $MD '[Routine Size](#size) Score: '.$SCORE_ROUTINE_SIZE.'%  '."\n";
	print $MD '[Routine Comments](#comments) Score: '.$SCORE_ROUTINE_COMMENTS.'%  '."\n";
	print $MD '[IO Prefixes](#io) Score: '.$SCORE_IO_PREFIXES.'%  '."\n";
	print $MD '[IO Labels and category](#io) Score: '.$SCORE_IO_LABELCATEGORY.'%  '."\n";
	print $MD '[IO Access Level](#io)  '."\n";
	print $MD '[ProgramData prefixes](#prefixes-check) Score: '.$SCORE_VARIABLE_PREFIXES.'%  '."\n";
	print $MD '[Shared ProgramData](#task-shared) Score: '.$SCORE_VARIABLE_SHARED.'%  '."\n";
	print $MD '[Instruction-checks](#instructions) Score: '.$SCORE_INSTRUCTIONS.'%  '."\n\n";
	print $MD 'Generated by: '.$APP_USER.'/'.$APP_USER_MACHINE.' on '.$APP_DATETIME.'.  '."\n";
	print $MD '['.$APP_WEB.']('.$APP_WEB.')  '."\n\n";
	print $MD '---'."\n\n";
	print $MD $routines;
	print $MD $variables;
	print $MD $io;
	print $MD $instructions;
	close($MD);
}



sub ReportGen_AccessLevel {
	
	my($res);
	
	if (!($SYSPAR{eio})) {
		$res .= 'EIO.cfg not found. No check performed.'."\n\n";
		$SCORE_IO_ACCESS = 100;
	}

	my(@signals) = ReadSyspar($SYSPAR{eio},'EIO_SIGNAL');
	my(@access) = ReadSyspar($SYSPAR{eio},'EIO_ACCESS');

	my($line, $io_name, $io_label, $io_category, $io_access, $access_rapid, $access_localauto, $access_localmanual, $access_remoteauto, $access_remotemanual);
	foreach $line (@signals) {
		$io_name = getSysparValue($line,'name');
		$io_access = getSysparValue($line,'access');
		
		$access_rapid = getSysparValue(getSysparLine($io_access,'x',@access),'rapid');
		$access_localauto = getSysparValue(getSysparLine($io_access,'x',@access),'localauto');
		$access_localmanual = getSysparValue(getSysparLine($io_access,'x',@access),'localmanual');
		$access_remoteauto = getSysparValue(getSysparLine($io_access,'x',@access),'remoteauto');
		$access_remotemanual = getSysparValue(getSysparLine($io_access,'x',@access),'remotemanual');

		if (($access_localauto) || ($access_remoteauto) || ($access_remotemanual) || (lc($io_access) eq 'all')) {
			$res .= '``WARNING IO access in auto or from remote ('.$io_access.') '.$io_name.' Line '.getSysparValue($line,'fileline').'``'."\n\n";
		}
	}
	
	if (!($res)) {
		$res = 'No errors found! Good Job!'."\n\n";
		$SCORE_IO_ACCESS = 100;
	} else {
		$res = 'These IO can be toggled in auto or from remote, please consider limiting access due to safety.'."\n\n".$res;
		$res = 'No score will be given for this section. Specifications from customer or process may affect strategy when deciding on access configuration. However here you can get a quick overview of the current configuration.'."\n\n".$res;
		$SCORE_IO_ACCESS = 0;
	}

	return $res;
}



sub ReportGen_LabelCategory {
	
	my($res);
	my($error) = 0;
	
	if (!($SYSPAR{eio})) {
		$res .= 'EIO.cfg not found. No check performed.'."\n\n";
		$SCORE_IO_LABELCATEGORY = 100;
	}

	my(@signals) = ReadSyspar($SYSPAR{eio},'EIO_SIGNAL');

	my($line, $io_name, $io_label, $io_category);
	foreach $line (@signals) {
		$io_name = getSysparValue($line,'name');
		$io_label = getSysparValue($line,'label');
		$io_category = getSysparValue($line,'category');
		
		if ($io_label eq '') {
			$res .= '``ERROR Missing label for '.$io_name.' Line '.getSysparValue($line,'fileline').'``'."\n\n";
			$error++;
		}

		if ($io_category eq '') {
			$res .= '``ERROR Missing category for '.$io_name.' Line '.getSysparValue($line,'fileline').'``'."\n\n";
			$error++;
		}
	}
	
	if (!($res)) {
		$res = 'No errors found! Good Job!'."\n\n";
		$SCORE_IO_LABELCATEGORY = 100;
	} else {
		$res .= 'Requirements are to follow ABB documentation, Reference manual Naming convention 3HNA013447-001 en Rev.03. 70% - 95% ok variables will generate a score of 0% to 100%.'."\n";
		$SCORE_IO_LABELCATEGORY = CalcScore((($#signals+1)*2)-$error, (($#signals+1)*2), 70, 95);
		$res .= "\n".'**Score: '.$SCORE_IO_LABELCATEGORY.'% ('.((($#signals+1)*2)-$error).'/'.(($#signals+1)*2).')**  '."\n";
	}
	
	# Check and update Globalscore for summary
	if ($SCORE_IO_LABELCATEGORY < $GLOBALSCORE) {
		$GLOBALSCORE = $SCORE_IO_LABELCATEGORY;
	}

	return $res;
}



sub ReportGen_IoPrefixes {
	
	my($res);
	
	if (!($SYSPAR{eio})) {
		$res .= 'EIO.cfg not found. No check performed.'."\n\n";
		$SCORE_IO_PREFIXES = 100;
	}
	
	my(@signals) = ReadSyspar($SYSPAR{eio},'EIO_SIGNAL');
	my(@systemin) = ReadSyspar($SYSPAR{eio},'SYSSIG_IN');
	my(@systemout) = ReadSyspar($SYSPAR{eio},'SYSSIG_OUT');
	my(@cross) = ReadSyspar($SYSPAR{eio},'EIO_CROSS');
	my($error) = 0;

	my($line, $io_name, $io_prefix);
	foreach $line (@signals) {
		$io_name = getSysparValue($line,'name');
		$io_prefix = lc(getSysparValue($line,'signaltype'));
		if (getSysparLine('signal',$io_name,(@systemin,@systemout)) ne '') {
			$io_prefix = 's'.$io_prefix;
		} elsif (getSysparLine('res',$io_name,@cross) ne '') {
			$io_prefix = 'x'.$io_prefix;
		}
		if ($io_name !~ /^$io_prefix/) {
			$res .= '``ERROR Expected prefix '.$io_prefix.' for ';
			if ($io_prefix =~ /^x/) {
				$res .= 'cross-connected ';
			} elsif ($io_prefix =~ /^s/) {
				$res .= 'system-io ';
			}
			$res .= $io_name.' Line '.getSysparValue($line,'fileline').'``'."\n\n";
			$error++;
		}
	}
	
	if (!($res)) {
		$res = 'No errors found! Good Job!'."\n\n";
		$SCORE_IO_PREFIXES = 100;
	} else {
		$res .= 'Requirements are to follow ABB documentation, Reference manual Naming convention 3HNA013447-001 en Rev.03. 70% - 95% ok variables will generate a score of 0% to 100%.'."\n";
		$SCORE_IO_PREFIXES = CalcScore(($#signals+1)-$error, ($#signals+1), 70, 95);
		$res .= "\n".'**Score: '.$SCORE_IO_PREFIXES.'% ('.(($#signals+1)-$error).'/'.($#signals+1).')**  '."\n";
	}
	
	# Check and update Globalscore for summary
	if ($SCORE_IO_PREFIXES < $GLOBALSCORE) {
		$GLOBALSCORE = $SCORE_IO_PREFIXES;
	}

	return $res;
}



sub getSysparValue {
	my($line, $arg) = @_;

	my($name, $value);
	my(@pairs) = split(/;/,$line);
	foreach (@pairs) {
		($name, $value) = split(/=/, $_);
		if (lc($name) eq lc($arg)) {
			return $value;
		}
	}
}



sub getSysparLine {
	my($argname, $argval, @arr) = @_;
	
	my($line, $name, $value);
	my(@pairs);
	foreach $line (@arr) {
		@pairs = split(/;/,$line);
		foreach (@pairs) {
			($name, $value) = split(/=/, $_);
			if ((lc($name) eq lc($argname)) && (lc($value) eq lc($argval))) {
				return $line;
			}
		}
	}
	return '';
}



sub ReadSyspar {
	my($filepath, $section) = @_;

	my(@res);

	my($FILE, $line);
	my($fileline) = 0;
	my($section_signal) = 0;
	my($multiline) = '';
	
	open($FILE,'<'.$filepath);
	while ($line = <$FILE>) {
		$fileline++;
		
		# Register signal section of EIO.cfg
		if ($line =~ /^$section:/) {
			$section_signal = 1;
			next;
		}
		
		# No more signals
		if (($section_signal == 1) && ($line =~ /^#/)) {
			last;
		}
		
		# Next if we are in wrong section
		if ($section_signal == 0) {
			next;
		}
		
		if ($line =~ /\\$/) {
			# Multiline add and read next
			chomp($line);
			chop($line);
			$multiline .= $line;
			next;
		}
		
		$line = $multiline.$line;
		$multiline = '';
		
		$line =~ s/^[\s\t]+//;
		$line =~ s/[\s\t]+$//;
		$line =~ s/[\s\t]+/ /g;
		$line =~ s/-([\w\d_]+)\s+"([\w\d_\-,\s]+)"\s?/$1=$2;/gi;
		$line =~ s/-([\w\d_]+)\s+/$1=x;/gi;
		
		if (!($line)) {
			next;
		}
		
		push(@res,$line.'fileline='.$fileline);
	}
	close($FILE);
	
	return @res;
}



sub ReportGen_InstructionsForbidden {	
	my($module, $MOD, $line, $modname, $modpath, $modtask, $fileline);
	
	my($res);
	
	foreach $module (@MODULES) {
		($modname, $modpath, $modtask) = (undef, undef, undef);
		($modname, $modpath, $modtask) = split(/;/, $module);
	
		$fileline = 0;
		
		open($MOD,'<'.$modpath);
		while ($line = <$MOD>) {
			$fileline++;
			
			if ($line =~ /goto[\s\t]+[\w\d_]+[\s\t]*;/i) {
				$res .= '``ERROR Illegal instruction GOTO.`` '.$modtask.'/'.$modname.' Line '.$fileline."\n\n";
			}
		}
			close($MOD);			
	}
	
	if (!($res)) {
		$res = 'None found! Good Job!'."\n\n";
		$SCORE_INSTRUCTIONS = 100;
	} else {
		$res = 'These are a sign of lazy code and introduces technical debt. Rewrite to maintainable code, please.'."\n\n".$res;
		$SCORE_INSTRUCTIONS = 0;
	}
	
	$res .= "\n".'**Score: '.$SCORE_INSTRUCTIONS.'%**'."\n";
	
	return $res;
}



sub ReportGen_InstructionsRatherNot {	
	my($module, $MOD, $line, $modname, $modpath, $modtask, $fileline);
	
	my($res);
	
	foreach $module (@MODULES) {
		($modname, $modpath, $modtask) = (undef, undef, undef);
		($modname, $modpath, $modtask) = split(/;/, $module);
	
		$fileline = 0;
		
		open($MOD,'<'.$modpath);
		while ($line = <$MOD>) {
			$fileline++;
			
			if ($line =~ /^[\s\t]*callbyvar\W/i) {
				$res .= '``WARNING consider non-runtime-dependant CallByVar. '.$modtask.'/'.$modname.' Line '.$fileline.'``'."\n\n";
			} elsif ($line =~ /^[\s\t]*\%[^\%]/i) {
				$res .= '``WARNING consider non-runtime-dependant %<string>%. '.$modtask.'/'.$modname.' Line '.$fileline.'``'."\n\n";
			}
		}
		close($MOD);			
	}

	if (!($res)) {
		$res = 'None found! Good Job!'."\n\n";
	} else {
		$res = 'None of these will affect score. However they increase complexity, so please use sparingly.'."\n\n".$res;
	}
	
	return $res;
}



sub ReportGen_RoutineComments {
	my($commentcountlimitpercent) = 33;
	
	# Declare resultvariable
	my($res);
	
	my($error) = 0;

	# Loop through each routine
	my($MOD, $line, $routine, $routinename, $routinemodule, $routinetask, $routinepart, $linecount, $commentcount, $fileline);
	my($routineline);
	foreach $routine (@ROUTINES) {
		($routinename, $routinemodule, $routinetask) = split(/;/, $routine);
		
		$routinepart = 0;
		$linecount = 0;
		$commentcount = 0;
		$fileline = 0;

		# Open file for reading
		open($MOD,'<'.getRoutinePath($routinemodule, $routinetask));
		while ($line = <$MOD>) {
			$fileline++;
			
			# Read until we find the right routine
			if ($line =~ /^[\s\t]*(local\s+)?(proc|func\s+[\w_]+|trap)\s+([\w\d_]+)/i) {
				if ($3 eq $routinename) {
					# Routine start
					$routinepart = 1;
					$routineline = $fileline;
				}
			} elsif (($routinepart == 1) && ($line =~ /^[\s\t]*(end(proc|func|trap)|error|return|undo)/i)) {
				# Routine end, exit loop
				last;
			}

			# Count instruction lines
			if (($routinepart == 1) && ($line =~ /;[\s\t]*$/)) {
				$linecount++;
			}
			
			# Comments which looks like instructions will be skipped
			if ($line =~ /^[\s\t]*![\s\t]*(if|for|while|test|case|endif|endfor|endtest|default)\W/i) {
				# Comments which looks like if or loops are not counted
				next;
			} elsif ($line =~ /;[\s\t]*$/i) {
				# Anything ending with ; looks suspiciously like an instruction
				next;
			}
			
			if (($routinepart == 1) && ($line =~ /^[\s\t]*!.{10,}?$/)) {
				# Comments with at least 10 length are counted
				$commentcount++;
			}

		}
		close($MOD);
		
		if ($linecount > 6) {
			if ($commentcount < ($linecount * ($commentcountlimitpercent / 100))) {
				$res .= '``ERROR: Min comment count ratio not met ('.$commentcountlimitpercent.'%) '.$routinetask.'/'.$routinemodule.'/'.$routinename.' Line '.$routineline.' Linecount: '.$linecount.' Commentcount: '.$commentcount.'``'."\n\n";
				$error++;
			}
		}
		
	}

	$res .= "\n";
	$res .= 'Instructions are counted, not FOR/IF/WHILE etc. Errorlimit is set to '.$commentcountlimitpercent.'%.'."\n";
	$res .= '70% to 95% will generate a score of 0% - 100%.'."\n";
	$SCORE_ROUTINE_COMMENTS = CalcScore(($#ROUTINES+1)-$error, ($#ROUTINES+1), 70, 95);
	$res .= "\n".'**Score: '.$SCORE_ROUTINE_COMMENTS.'% ('.(($#ROUTINES+1)-$error).'/'.($#ROUTINES+1).')**'."\n";
	
	# Check and update Globalscore for summary
	if ($SCORE_ROUTINE_COMMENTS < $GLOBALSCORE) {
		$GLOBALSCORE = $SCORE_ROUTINE_COMMENTS;
	}
	
	return $res;
}



sub ReportGen_RoutineSize {
	my($linecountlimiterror) = 50;
	my($linecountlimitwarning) = 30;
	
	# Declare resultvariable
	my($res);
	
	my($error) = 0;

	my($MOD, $line, $routine, $routinename, $routinemodule, $routinetask, $routinepart, $linecount, $fileline);
	my($routineline);
	foreach $routine (@ROUTINES) {
		($routinename, $routinemodule, $routinetask) = split(/;/, $routine);
		
		$routinepart = 0;
		$linecount = 0;
		$fileline = 0;
		
		open($MOD,'<'.getRoutinePath($routinemodule, $routinetask));
		while ($line = <$MOD>) {
			$fileline++;
			
			if ($line =~ /^[\s\t]*(local\s+)?(proc|func\s+[\w_]+|trap)\s+([\w\d_]+)/i) {
				if ($3 eq $routinename) {
					# Routine start
					$routinepart = 1;
					$routineline = $fileline;
				}
			} elsif (($routinepart == 1) && ($line =~ /^[\s\t]*(end(proc|func|trap)|error|return|undo)/i)) {
				# Routine end
				last;
			}

			if (($routinepart == 1) && ($line =~ /;[\s\t]*(!|$)/)) {
				$linecount++;
			}
		}
		close($MOD);
		
		if ($linecount > $linecountlimiterror) {
			$res .= '``ERROR: Routine max line count ('.$linecountlimiterror.') exceeded. '.$routinetask.'/'.$routinemodule.'/'.$routinename.' Line '.$routineline.' Linecount: '.$linecount.'``'."\n\n";
			$error++;
		} elsif ($linecount > $linecountlimitwarning) {
			$res .= '``WARNING: Routine recommended max line count ('.$linecountlimitwarning.') exceeded. '.$routinetask.'/'.$routinemodule.'/'.$routinename.' Line '.$routineline.' Linecount: '.$linecount.'``'."\n\n";
			$error += 0.5;
		}
		
	}

	$res .= "\n";
	$res .= 'Instructions are counted, not comments or FOR/IF/WHILE etc. Errorlimit is set to '.$linecountlimiterror.', warninglimit is set to '.$linecountlimitwarning.'.  '."\n";
	$res .= '70% to 95% will generate a score of 0% - 100%.'."\n";
	$SCORE_ROUTINE_SIZE = CalcScore(($#ROUTINES+1)-$error, ($#ROUTINES+1), 70, 95);
	$res .= "\n".'**Score: '.$SCORE_ROUTINE_SIZE.'% ('.(($#ROUTINES+1)-$error).'/'.($#ROUTINES+1).')**'."\n";
	
	# Check and update Globalscore for summary
	if ($SCORE_ROUTINE_SIZE < $GLOBALSCORE) {
		$GLOBALSCORE = $SCORE_ROUTINE_SIZE;
	}
	
	return $res;
}



sub ReportGen_VariablePrefixes {
	# Variable prefixes are scored at 100% if error rate <5%
	# error rates below 50% gives 0%
	
	# Declare resultvariable
	my($res);
	
	my($error) = 0;
	
	# Reference manual Naming convention 3HNA013447-001 en Rev.03
	my(%prefix_def) = (
		'bool'=>'b',
		'clock'=>'ck',
		'confdata'=>'cf',
		'dionum'=>'i',
		'dir'=>'d',
		'eventdata'=>'ed',
		'errnum'=>'er;ERR_',
		'extjoint'=>'exj',
		'intnum'=>'ir',
		'iodev'=>'de',
		'jointtarget'=>'jpos;j',
		'loaddata'=>'lo',
		'loadsession'=>'loadid',
		'mecunit'=>'me',
		'motsetdata'=>'mo',
		'num'=>'n;reg',
		'orient'=>'or',
		'pos'=>'ps',
		'pose'=>'pe',
		'progdisp'=>'pd',
		'robtarget'=>'p',
		'shapedata'=>'shd',
		'speeddata'=>'v',
		'string'=>'st',
		'tooldata'=>'t',
		'triggdata'=>'tr',
		'wobjdata'=>'wobj',
		'wzstationary'=>'wzs',
		'wztemporary'=>'wzt',
		'zonedata'=>'z');
	
	my($var, $valid, $found_prefix, $localtype, $local, $vartype, $type, $name, $modname, $fileline, $taskname, $init_value);
	my(@valid_prefixes);
	foreach $var (@VARIABLES) {
		($localtype, $local, $vartype, $type, $name, $modname, $fileline, $taskname, $init_value) = split(/;/, $var);
		
		if (defined($prefix_def{$type})) {
			@valid_prefixes = split(/;/, $prefix_def{$type});
			
			$valid = 0;
			$found_prefix = 'NA';
			foreach (@valid_prefixes) {
				if ($name =~ /^($_)\u\w/) {
					$found_prefix = $1;
					$valid = 1;
					last;
				}
			}
			
			if (!($valid))  {
				$res .= '``ERROR: Invalid programdata prefix ('.$type.'/'.$prefix_def{$type}.'). '.$taskname.'/'.$modname.' Line '.$fileline.' '.$type.' '.$name.'``'."\n\n";
				$error++;
			} elsif ($name !~ /^$found_prefix\u\w\w{2}/) {
				$res .= '``ERROR: Missing programdata name. '.$taskname.'/'.$modname.' Line '.$fileline.' '.$type.' '.$name.'``'."\n\n";
				$error++;
			}
		} else {
			# Record type?
		}
	}
	
	if (!($res)) {
		$res = 'No errors found! Good job!'."\n\n";
	}
	
	$res .= 'Requirements are to follow ABB documentation, Reference manual Naming convention 3HNA013447-001 en Rev.03. 70% - 95% ok variables will generate a score of 0% to 100%.'."\n";
	$SCORE_VARIABLE_PREFIXES = CalcScore(($#VARIABLES+1)-$error, ($#VARIABLES+1), 70, 95);
	$res .= "\n".'**Score: '.$SCORE_VARIABLE_PREFIXES.'% ('.(($#VARIABLES+1)-$error).'/'.($#VARIABLES+1).')**  '."\n";
	
	
	# Check and update Globalscore for summary
	if ($SCORE_VARIABLE_PREFIXES < $GLOBALSCORE) {
		$GLOBALSCORE = $SCORE_VARIABLE_PREFIXES;
	}

	# Return results
	return $res;
}



sub ReportGen_TaskSharedVariables {
	
	if ($#TASKS <= 0) {
		$SCORE_VARIABLE_SHARED = 100;
		return 'Not applicable when only one task.'."\n\n";
	}

	# Declare resultvariable
	my($res_tasklist, $res_score);
	my($res_varlist);
	
	my(%tasksharedvariables);

	# First iteration, find variables declared as system global
	my($var, $localtype, $local, $vartype, $type, $name, $modname, $fileline, $taskname, $init_value);
	my($var_, $localtype_, $local_, $vartype_, $type_, $name_, $modname_, $fileline_, $taskname_, $init_value_);
	foreach $var (@VARIABLES) {
		($localtype, $local, $vartype, $type, $name, $modname, $fileline, $taskname) = split(/;/, $var);

		if ((lc($localtype) eq 'module') && ($local eq '') && (lc($vartype) eq 'pers')) {

			foreach $var_ (@VARIABLES) {
				($localtype_, $local_, $vartype_, $type_, $name_, $modname_, $fileline_, $taskname_, $init_value_) = split(/;/, $var_);

				if ((lc($localtype_) eq 'module') && ($local_ eq '') && (lc($vartype_) eq 'pers')) {
				
					if (($name eq $name_) && ($taskname ne $taskname_)) {
						$tasksharedvariables{$name} = $vartype.' '.$type.' '.$name;
						last;
					}
					
				}

			}

		}

	}
	
	# Second iteration, find each shared
	my(%taskcount);
	my($sharedname, $initvalue_found);
	foreach $sharedname (keys %tasksharedvariables) {

		$res_varlist .= '```'."\n".$tasksharedvariables{$sharedname}."\n";
		$initvalue_found = 0;

		foreach $var (@VARIABLES) {
			($localtype, $local, $vartype, $type, $name, $modname, $fileline, $taskname, $init_value) = split(/;/, $var);

			if (($tasksharedvariables{$name}) && ($sharedname eq $name)) {	
				$res_varlist .= '    '.$taskname.'/'.$modname;
				if ($init_value) {
					$res_varlist .= ' InitValue';
					if ($initvalue_found) {
						$res_varlist .= ' ERROR Multiple Initvalue declarations.';
					}
					$initvalue_found = 1;
				}
				$res_varlist .= ' Line '.$fileline.'  '."\n";
				$taskcount{$taskname}++;
			}
			
		}

		$res_varlist .= '```'."\n\n";

	}
	if (!($res_varlist)) {
		$res_varlist .= 'No task-shared programdata found.'."\n\n";
	} else {
		$res_varlist .= "\n";
	}


	my($task_i);
	my(@taskcountkeys) = sort { $taskcount{$b} <=> $taskcount{$a} } keys %taskcount;
	foreach $task_i (0..$#taskcountkeys) {
		$res_tasklist .= '``'.$taskcountkeys[$task_i].'``: '.$taskcount{$taskcountkeys[$task_i]};
		if ($task_i == 1) {
			$res_tasklist .= ' <-- Evaluated for score.';
		}
		$res_tasklist .= '  '."\n";
	}
	if (!($res_tasklist)) {
		$res_tasklist .= 'No task-shared programdata found.'."\n\n";
	} else {
		$res_tasklist .= "\n";
	}

	$SCORE_VARIABLE_SHARED = 100;
	if ($#taskcountkeys >= 1) {
		$SCORE_VARIABLE_SHARED = CalcScore($taskcount{$taskcountkeys[1]}, 4, 400, 100);
		$res_score .= '**Score: '.$SCORE_VARIABLE_SHARED.'% ('.$taskcount{$taskcountkeys[1]}.')**  '."\n\n";
	} else {
		$res_score .= '**Score: 100% (0)**  '."\n\n";
	}
	$res_score .= 'Full score will be 4 or less shared variables in any slave task. If any slave task exceed 16 shared variables score falls to 0%.'."\n\n";
	
	
	# Check and update Globalscore for summary
	if ($SCORE_VARIABLE_SHARED < $GLOBALSCORE) {
		$GLOBALSCORE = $SCORE_VARIABLE_SHARED;
	}

	# Return results
	return $res_score.'#### Tasklist and number of shared variables'."\n\n".$res_tasklist.'#### Variablelist and where they are shared'."\n\n".$res_varlist;
}



# getRoutinePath subroutine retrieves the path associated with a given module name.
# Parameters:
#   $modulename  - Module name for which the path is to be retrieved
# Returns:
#   Path associated with the module name or an error message if not found
sub getRoutinePath {
    my ($modulename,$moduletask) = @_;

    my ($module, $modname, $modpath, $taskname);

    # Loop through each module in the @MODULES array
    foreach $module (@MODULES) {
        # Split the module information into its components
        ($modname, $modpath, $taskname) = split(/;/, $module);

        # Check if the module name matches the provided $modulename
        if (($modname eq $modulename) && ($taskname eq $moduletask)) {
            # Return the path associated with the module name
            return $modpath;
        }
    }

    # If the module name is not found, return an error message
    return 'ERROR: Module name not found';
}



# CalcScore subroutine calculates a score based on given parameters.
# Parameters:
#   $count     - Actual count or value
#   $maxvalue  - Maximum possible count or value
#   $minscore  - Minimum score for a valid calculation
#   $maxscore  - Maximum score for a valid calculation
# Returns:
#   Calculated score between 0 and 100
sub CalcScore {
    my ($count, $maxvalue, $minscore, $maxscore) = @_;

    # Calculate the raw score using the provided formula
	# First calculate score from 0 to 100 from $count and $maxvalue
	# Then find new score from 0 to 100 based on min/max of the previous value.
    my ($score) = (($count / $maxvalue) * 100 - $minscore) / ($maxscore - $minscore) * 100;

    # Ensure the calculated score is within the valid range (0-100)
    if ($score <= 0) {
        return 0;
    } elsif ($score > 100) {
        return 100;
    } else {
        # Convert the score to an integer and return
        return int($score);
    }
}



sub Find_All_Tasks {
	
	# We will open 'ProjectFilesRobot' folder and look for any folders named '^TASK' or '^RAPID'
	# If we find any '^TASK' folder we will use 'ProjectFilesRobot' as task folder.
	# Otherwise we try the same for '^RAPID' folder. If none found we will assume only TASK0 present in 'ProjectFilesRobot'
	push(@TASKS, ListTaskFolders('RAPID'));
	
	print 'Found Tasks:'."\n";
	foreach (@TASKS) {
		print $_."\n";
	}
	print "\n";
	# Done
}



sub FolderInFolder {
	my($re_name, $foldername) = @_;
	
	# Declare resultvariable and init false value
	my($res) = 0;
	
	# open folder and loop through files
	my($DIR, $de);
	opendir($DIR, $foldername);
	foreach $de (readdir($DIR)) {
		if (-d $foldername.'/'.$de) {
			if ($de =~ /$re_name/) {
				# Found what we were looking for
				# Change resultvariable and exit loop
				$res = 1;
				last;
			}
		}
	}
	closedir($DIR);
	
	# Return results
	return $res;
}



sub ListTaskFolders {
	my($foldername) = @_;
	
	# Declare resultvariable and init false value
	my(@res) = ();
	
	# open folder and loop through files
	my($DIR, $de);
	opendir($DIR, $foldername);
	foreach $de (readdir($DIR)) {
		if (-d $foldername.'/'.$de) {
			if ($de =~ /(^TASK\d+)/) {
				# Found what we were looking for
				# Add to results and continue
				push(@res,$1.';'.$foldername.'/'.$de);
			}
		}
	}
	closedir($DIR);
	
	# Return results
	return @res;
}



sub Find_All_Modules {
	# Loop through each task, collect path info for each mod/sys file we find.
	my($task, $taskname, $taskpath);
	foreach $task (@TASKS) {
		($taskname, $taskpath) = split(/;/, $task);
		push(@MODULES, ModuleSearch($taskpath, $taskname));
	}
	
	print 'Found Modules:'."\n";
	foreach (@MODULES) {
		print $_."\n";
	}
	print "\n";
	# Done
}



sub ModuleSearch {
	my($foldername, $taskname) = @_;
	
	# Declare resultvariable and init false value
	my(@res) = ();
	
	# Open given folder, add any *.mod or *.sys files we find.
	# If we find any folders, use recursion by calling this routine again with new folder as target.
	my($DIR, $de);
	opendir($DIR, $foldername);	
	foreach $de (readdir($DIR)) {
		if (($de eq '.') || ($de eq '..')) {
			next;
		} elsif (-d $foldername.'/'.$de) {
			push(@res, ModuleSearch($foldername.'/'.$de, $taskname));
		} elsif ($de =~ /\.(mod|sys|modx|sysx)$/i) {
			push(@res, $de.';'.$foldername.'/'.$de.';'.$taskname);
		}
	}
	closedir($DIR);
	
	# Return results
	return @res;
}



sub Find_All_Syspar {
	SysparSearch('SYSPAR');

	print 'Found SysPar:'."\n";
	my(@syspar_keys) = sort keys %SYSPAR;
	foreach (@syspar_keys) {
		print $SYSPAR{$_}."\n";
	}
	print "\n";
	# Done
}



sub SysparSearch {
	my($foldername) = @_;
	
	# Open given folder, add EIO.CFG, early exit if found. 
	# If we find any folders, use recursion by calling this routine again with new folder as target.
	# Search function used for possible other syspar files added in the future.
	my($DIR, $de);
	opendir($DIR, $foldername);
	foreach $de (readdir($DIR)) {
		if (($de eq '.') || ($de eq '..')) {
			next;
		} elsif (-d $foldername.'/'.$de) {
			SysparSearch($foldername.'/'.$de);
		} elsif (lc($de) eq 'eio.cfg') {
			$SYSPAR{eio} = $foldername.'/'.$de;
		} elsif (lc($de) eq 'sys.cfg') {
			$SYSPAR{sys} = $foldername.'/'.$de;
		}
	}
	closedir($DIR);
}



sub Find_All_ProcFuncTrap {
	
	my($mod, $modulename, $modulepath, $taskname);
	foreach $mod (@MODULES) {
		($modulename, $modulepath, $taskname) = split(/;/, $mod);		
		push(@ROUTINES, ProcFuncTrapSearch($modulepath, $modulename, $taskname));
	}	
	
	print 'Found ProcFuncTrap:'."\n";
	foreach (@ROUTINES) {
		print $_."\n";
	}
	print "\n";
	# Done
}



sub ProcFuncTrapSearch {
	my($modpath, $modulename, $taskname) = @_;

	# Declare resultvariable and init false value
	my(@res) = ();
	
	my($FILE, $line);
	open($FILE,'<'.$modpath);
	while ($line = <$FILE>) {
		if ($line =~ /^[\s\t]*(local\s+)?(proc|func\s+[\w_]+|trap)\s+([\w\d_]+)/i) {
			# Routine start
			push(@res, $3.';'.$modulename.';'.$taskname);
		} elsif ($line =~ /^[\s\t]*end(proc|func|trap)/i) {
			# Routine end
		}
	}
	close($FILE);	
	
	# Return results
	return @res;
}



sub Find_All_Variables {
	
	my($mod, $modulename, $modulepath, $taskname);
	foreach $mod (@MODULES) {
		($modulename, $modulepath, $taskname) = split(/;/, $mod);		
		push(@VARIABLES, VariablesSearch($modulepath, $modulename, $taskname));
	}	
	
	print 'Found Variables:'."\n";
	foreach (@VARIABLES) {
		print $_."\n";
	}
	print "\n";
	# Done
}



# VariablesSearch subroutine searches for variable declarations in a given file.
# Parameters:
#   $modpath     - Path to the file to be searched
#   $modulename  - Module name associated with the file
#   $taskname    - Task name associated with the file
# Returns:
#   An array containing information about variables found in the format:
#   [variable_type;variable_name;module_name;line_number;task_name, ...]
sub VariablesSearch {
    my ($modpath, $modulename, $taskname) = @_;

    # Declare result variable and initialize with an empty array
    my (@res) = ();

    my ($FILE, $line, $local, $init_value);
	my ($routinedeclaration) = 'module';
    my ($fileline) = 0;

    # Open the file for reading
    open($FILE, '<', $modpath);

    # Loop through each line in the file
    while ($line = <$FILE>) {
        $fileline++;
		
		# If we reach routinedeclaration all remaining variable declarations are routine-local
		if ($line =~ /^[\s\t]*(local\s+)?(proc|func|trap)\s/i) {
			$routinedeclaration = 'routine';
		}

        # Check if the line contains a variable declaration (local? + pers, var, or const)
        if ($line =~ /^[\s\t]*((local)\s+)?(pers|var|const)\s+([\w\d_]+)\s+([\w\d_]+)\s*(:=)?/i) {
			if (defined($2)) {
				$local = $2;
			} else {
				$local = '';
			}
			if (defined($6)) {
				$init_value = 1;
			} else {
				$init_value = 0;
			}
            # Extracted information is pushed to the result array
			push(@res, "$routinedeclaration;$local;$3;$4;$5;$modulename;$fileline;$taskname;$init_value");
        }
    }

    # Close the file
    close($FILE);

    # Return the array containing variable information
    return @res;
}



sub getDateTime {
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	return sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec);
}