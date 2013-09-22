#!/usr/bin/env perl
use warnings;
use strict;

my (@globalfunc,@functions,@imports,@members,@defines,@linebuffer) = ();
my ($superclass,$classname,$fn) = "";

my %aspat = ( 		sig => {method => qr/[\w\s\n]*function[\s\n]+[\s\w+]*[\w\d]+[\s\n]*\([^\)]*\)([\s\n]*:[\s\n]*[\w\d]+)?/,
						argcontent => qr/\(([^\)]+)\)/,
						arg => qr/([\w\d]+)[\s\n]*:[\s\n]*([\w\d]+)/,
						type => qr/\)[\s\n]*:[\s\n]*([\w\d]+)/,
						name => qr/([\w\d]*)[\s\n]*\(/,
						public => qr/public/,
						private => qr/private/,
						protected => qr/protected/,
						static => qr/static/,
						get => qr/get/,
						set => qr/set/,
						reverseargtype => 0,
						parseheader => 0},
						
				header => {
						var => qr/((\w+)[\s\n])var[\s\n]+([\w\d]+)[\s\n]*:[\s\n]*([\w\d]+)[\s\n]*(=[^;]+)?;/,
						varname => qr/([\w\d]+)[\s\n]*:[\s\n]*[\w\d]+/,
						vartype => qr/[\w\d]+[\s\n]*:[\s\n]*([\w\d]+)/ },
						
				content => { extendedFrom => qr/class[\s\n]+([\w\d]+)([\s\n]+extends[\s\n]+([\w\d]+))?/,
						singlecomm => qr/\/\/[^\n]*/,
						multicomm => qr/((?:\/\*(?:[^*]|(?:\*+[^*\/]))*\*+\/)|(?:\/\/.*))/ });

my %javapat = (		sig => {method => qr/(\w+[\s\n]+)*[\w\d\[\]\<\>\.]+[\s\n]+[\w\d]+[\s\n]*\([^\)^{]*\)[\s\n]*{/,
						argcontent => qr/\(([^\)]+)\)/,
						arg => qr/([\w\d]+)[\s\n]+([\w\d]+)/,
						type => qr/([\w\d]+)[\s\n]+[\w\d]+[\s\n]*\(/,
						name => qr/([\w\d]+)[\s\n]*\(/,
						public => qr/public/,
						private => qr/private/,
						protected => qr/protected/,
						static => qr/static/,
						get => qr/get/,
						set => qr/set/,
						reverseargtype => 1,
						parseheader => 0},

				header => {
						var => qr/(\w+[\s\n]+)*([\w\d\[\]\<\>\.]+)[\s\n]+([\w\d]+)[\s\n]*(=[^;]+)?;/,
						varname => qr/[\w\d\[\]\<\>\.]+[\s\n]+([\w\d]+)[\s\n]*(=[^;]+)?;/,
						vartype => qr/([\w\d\[\]\<\>\.]+)[\s\n]+[\w\d]+[\s\n]*(=[^;]+)?;/ },
						
				content => { extendedFrom => qr/class[\s\n]+([\w\d]+)([\s\n]+extends[\s\n]+([\w\d]+))?/,
						singlecomm => qr/\/\/[^\n]*/,
						multicomm => qr/((?:\/\*(?:[^*]|(?:\*+[^*\/]))*\*+\/)|(?:\/\/.*))/ });

my %objcpat = ( 	sig => {method => qr/[-+][\s\n]*\([\w\d\s\n\*]+\)([\s\n]*[\w\d]+[\s\n]*(:[\s\n]*\([\w\d\s\n\*]+\)[\s\n]*[\w\d]+)?)+[\s\n]*{/,
						argcontent => qr/[-+][\s\n]*\([\w\d\s\n\*]+\)(.+)+/,
						arg => qr/\(([\w\d\s\n\*]+)\)[\s\n]*([\w\d]+)/,
						type => qr/[-+][\s\n]*\(([\w\d\s\n\*]+)\)/,
						name => qr/[-+][\s\n]*\([\w\d\s\n\*]+\)[\s\n]*([\w\d]+)/,
						static => qr/^\+/,
						reverseargtype => 1,
						parseheader => 1},

				header => {
						var => qr/([\w\d]+)[\s\n]+\*?[\s\n]*([\w\d\[\]]+)[\s\n]*;/,
						sig => qr/[-+][\s\n]*\([\w\d\s\n\*]+\)([\s\n]*[\w\d]+[\s\n]*(:[\s\n]*\([\w\d\s\n\*]+\)[\s\n]*[\w\d]+)?)+[\s\n]*;/,
						define => qr/#define\s+([\w\d]+)\s+(.+)/,
						import => qr/#import\s+((\<.+\>)|(".+"))/ },

				content => { extendedFrom => qr/\@interface[\n\s]+([\w\d]+)[\n\s]*:[\n\s]*([\w\d]+)/,
						singlecomm => qr/\/\/[^\n]*/,
						multicomm => qr/((?:\/\*(?:[^*]|(?:\*+[^*\/]))*\*+\/)|(?:\/\/.*))/ });

my %lang;

sub trim($) { my $string = shift; $string =~ s/^\s+//; $string =~ s/\s+$//; return $string; }
sub GetSigName($) { return trim($1) unless !($_[0] =~ /$lang{sig}{name}/); }
sub GetSigType($) { return trim($1) unless !($_[0] =~ /$lang{sig}{type}/); return "void"; }
sub GetSigStatic($) { if($_[0] =~ /$lang{sig}{static}/) { return 1; } return 0;  }
sub GetVarName($) { if( $_[0] =~ /$lang{header}{varname}/ ) { return trim($1); } return ""; }
sub GetVarType($) { if( $_[0] =~ /$lang{header}{vartype}/ ) { return trim($1); } return ""; }
sub GetVarValue($) { if( $_[0] =~ /=([^;]+);/ ) { return trim($1); } return ""; }
sub isStatement($) { if( $_[0] =~ /(\bif\b)|(\belse\b)|(\breturn\b)/ ) { return 1; } return 0; };
sub GetSigArgs($)
{
	my ($content, $argcontent, $i, @funcargs) = (shift,"",0,());
	my $index = 0;
	if( $content =~ /$lang{sig}{argcontent}/ )
	{
		my $argcontent = trim($1);
		while( $argcontent =~ /$lang{sig}{arg}/g ) { push (@{$funcargs[$index++]},($lang{sig}{reverseargtype}) ? (trim($2),trim($1)) : (trim($1),trim($2))); }
	}
	
	return @funcargs;
}

sub RemoveComments($)
{
	my $content = shift;
	$content =~ s/$lang{content}{singlecomm}//g;
	$content =~ s/$lang{content}{multicomm}//g;
	return $content;
}

sub ParseMethods($)
{
	my $content = shift;
	$content = RemoveComments($content);
	
	# Search content for method signatures
	my @rawfunc = ();
	while ( $content =~ /$lang{sig}{method}/g ) { my $m = $&; if(!isStatement($m)) { push @rawfunc, trim((substr($m,length($m)-1,1) eq '{') ? substr($m,0,length($m)-1) : $m); } }
	
	# Parse header file (Obj-C only)
	if($lang{sig}{parseheader})
	{
		# Open and join header file lines
		my @ext = split /\./, $fn;
		@linebuffer = ();
		open my $h, "<".$ext[0].".h" or die ("Could not open header!\n");
		while(my $hline = <$h>) { push @linebuffer, $hline; }
		my ($memindex,$memfound,$lines) = (0,0,join "",@linebuffer);
		my (@gfunc,@gmem) = ();
		
		# Remove all the comments in the header
		$lines = RemoveComments($lines);
		
		# Find classname and superclass
		if($lines =~ /$lang{content}{extendedFrom}/ ) { $classname = $1; $superclass = $2; }
		
		# Handle imports
		while ( $lines =~ /$lang{header}{import}/g ) { push @imports, $1; }
		
		# Find, save and remove defines in header file
		my $i = 0; 
		while ( $lines =~ /$lang{header}{define}/g ) { push @{$defines[$i++]}, ($1,$2); $lines =~ s/$&//; }
		
		# Replace all defines in header and source file
		for my $def (@defines) { my ( $source, $target ) = ( ${$def}[0], ${$def}[1] ); $lines =~ s/$source/$target/g; $content =~ s/$source/$target/g; }
		
		# Reset list for scope
		@defines = ();
		
		# Find and remove defines in source file
		while ( $content =~ /$lang{header}{define}/g ) { push @{$defines[$i++]}, ($1,$2); $content =~ s/$&//; }
		
		# Replace all defines in source file
		for my $def (@defines) { my ( $source, $target ) = ( ${$def}[0], ${$def}[1] ); $content =~ s/$source/$target/g; }
		
		# Parse global members (name, class, value, public, static)
		while ( $lines =~ /$lang{header}{var}/g ) 
		{
			my ( $memname, $memclass ) = ($2,$1);
			$memfound = 0;
			for my $memb (@members) { if(${$memb}[0] eq $memname) { ${$memb}[3] = 1; $memfound = 1; } }
			if(!$memfound) { push @{$members[$memindex++]}, ($memname,$memclass,"",0,GetSigStatic($&)); }
		}

		# Parse global methods
		while ( $lines =~ /$lang{header}{sig}/g ) { push @gfunc, trim((substr($&,length($&)-1,1) eq ';') ? substr($&,0,length($&)-1) : $&); }
		for (my $i=0; $i<@gfunc; $i++) { push(@{$globalfunc[$i]},(GetSigName($gfunc[$i]),GetSigType($gfunc[$i]))); push(@{$globalfunc[$i][2]},GetSigArgs($gfunc[$i])); }
		
		# Close the file
		close $h;
	}
	
	# If we're only using one source file, search for classname and superclass
	if(!$lang{sig}{parseheader} && $content =~ /$lang{content}{extendedFrom}/ ) { $classname = $1; $superclass = $2; }
	my $tmpcontent = $content;
	
	# Parse methods
	for (my $i=0; $i<@rawfunc; $i++)
	{
		my @args = GetSigArgs($rawfunc[$i]);
		my ($depth,$oldind,$search,$contlength) = (0,index($content,$rawfunc[$i])+length($rawfunc[$i]),0,length($content));
		my $ind = $oldind;
		my $curchar = substr($content,$ind,1);
		
		# Find end of the method
		while($depth > 0 || $search == 0)
		{
			if($search == 0 && $curchar eq '{') { $search = 1; }
			$curchar = substr($content,$ind++,1);
			$depth = ($curchar eq '{') ? $depth+1 : ($curchar eq '}') ? $depth-1 : $depth;
		}
		
		my $mcontent = substr($content,$oldind,$ind-$oldind);
		my $end = index($tmpcontent,$rawfunc[$i]);
		my $start2 = $end+length($mcontent)+length($rawfunc[$i]);
		my $end2 = length($tmpcontent)-$start2;
		$tmpcontent = trim(substr($tmpcontent,0,$end)).trim(substr($tmpcontent,$start2,$end2));
		my $methodname = GetSigName($rawfunc[$i]);
		my ($access,$getset,$constructor) = (0,0,($classname eq $methodname) ? 1 : 0);
		
		# Parse accessor (public, private) and get/set property
		if($lang{sig}{parseheader})
		{
			my ($mname,$mtype) = (GetSigName($rawfunc[$i]),GetSigType($rawfunc[$i]));
			
			# Evaluate constructor (better version plz)
			$constructor = ($mtype eq "id" && $mcontent =~ /return[\s\n]+self[\s\n]*;/) ? 1 : 0;
			
			# Find accessor type
			my $found = 0;
			for my $gfun (@globalfunc) 
			{
				if(${$gfun}[0] eq $mname && ${$gfun}[1] eq $mtype)
				{ $access = 1; $found = 1; }
			}
			
			if(!$found) { $access = 0; }
			
			# Find get/set methods
			$found = 0;
			for my $mem (@members)
			{
				if(!$found)
				{
					my $memTitle = ${$mem}[0];
					$memTitle =~ s/(\w+)/\u$1/g;
					if($mname eq "set".$memTitle || $mname eq "get".$memTitle) { $access = 1; $getset = ($mname eq "set".$memTitle) ? 2 : 1; $methodname = ${$mem}[0]; $found = 1; }
				}
			}
			
			if(!$found) { $getset = 0; }
		}
		else
		{
			my $properties = substr($rawfunc[$i],0,index($rawfunc[$i],$methodname));
			$access = ($properties =~ /$lang{sig}{public}/) ? 1 : ($properties =~ /$lang{sig}{private}/) ? 0 : ($properties =~ /$lang{sig}{protected}/) ? 2 : 1; 
			$getset = ($properties =~ /$lang{sig}{get}/) ? 1 : ($properties =~ /$lang{sig}{set}/) ? 2 : 0;
		}
		
		push @{$functions[$i]},($methodname,($constructor) ? "void" : GetSigType($rawfunc[$i]),[],$oldind,trim($mcontent),$access,$getset,GetSigStatic($rawfunc[$i]),$constructor);
		@{$functions[$i][2]} = GetSigArgs($rawfunc[$i]);
	}

	# If there's no header file (Java/AS3), locate local members
	if(!$lang{sig}{parseheader})
	{
		my $memindex = @members*1;
		while ( $tmpcontent =~ /$lang{header}{var}/g )
		{
			if(!isStatement($&))
			{
				my $var = $&;
				my $memprops = substr($var,0,index($var,GetVarName($var)));
				my $memaccess = ($memprops =~ /$lang{sig}{public}/) ? 1 : ($memprops =~ /$lang{sig}{private}/) ? 0 : ($memprops =~ /$lang{sig}{protected}/) ? 2 : 1; 
				push(@{$members[$memindex++]},(GetVarName($var),GetVarType($var),GetVarValue($var),$memaccess,GetSigStatic($memprops)));
			}
		}
	}
}

sub ProcessFile($)
{
	$fn = $_[0];
	open my $c, "<".$fn or die ("File could not be opened!\n");
	while(my $line = <$c>) { push @linebuffer, $line; }
	close($c);
	my @ext = split(/\./,$fn);
	
	# Switch languages based on extension
	%lang = ($ext[1] eq "as") ? %aspat : ($ext[1] eq "java") ? %javapat : %objcpat;
	ParseMethods join("",@linebuffer);
	
	print "\nClass: ".$classname."\n";
	
	for my $mem (@members)
	{
		print ${$mem}[0]." (".${$mem}[1].")\n";
		print ${$mem}[2]."\n------------------------------\n";
	}

	for my $f (@functions)
	{
		print ${$f}[0]." (".${$f}[1].")\n";
		
		if(${$f}[8]) { print "Constructor\n"; }
		print "Public: ".${$f}[5]."\n";
		my @argarray = @{${$f}[2]};
		if(@argarray)
		{
			print "\nArgs:\n";
			for my $ar (@argarray)
			{
				print ${$ar}[0]." (".${$ar}[1].")\n";
			}
		}
		
		#print "\nContent:\n";
		#print ${$f}[4]."\n";
		print "------------------------------\n";
	}
}

#ProcessFile("PhysConvexObject.as");
#ProcessFile("BoucheBee.java");
#ProcessFile("AnimThread.java");
ProcessFile("Sprite.m");
#ProcessFile("AngelCodeFont.m");
#ProcessFile("AIEntity.as");