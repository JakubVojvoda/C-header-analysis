#!/usr/bin/perl

#
# C Header Analysis
# by Jakub Vojvoda [vojvoda@swdeveloper.sk]
# 2013
#

## Modules
use IO::File;
use Cwd 'abs_path';
use File::Find;
use XML::Writer;

## Return values
my $EXIT_SUCCESS = 0;   # without error
my $WRONG_PARAMS = 1;   # wrong format/combination of parameters
my $IN_FILE_FAIL = 2;   # input file error
my $FILEOPEN_ERR = 3;   # cannot open output file
#my $WRONG_INFILE = 4;  # wrong output file format 
my $IN_SUBFILE_F = 21;  # error input file in file tree

## Help
my $help = <<END;
Perl script: C Header Analysis
Author: vojvoda\@swdeveloper.sk

Usage:
  --help                print this help
  --input=filename      input header file (ISO C99)
  --output=filename     output XML file in UTF-8 enconding
  --pretty-xml=k        add k spaces before next indent
  --no-inline           no inline functions in output
  --max-par=n           functions with max. n arguments in output
  --no-duplicates       no functions with same names in output
  --remove-whitespace   remove spare white spaces
All parameters are optional.
END

## Warnings > stderr
my @warning = (
    "Wrong parameters.\n", 
    "Error: cannot open file.\n",
    "Error: cannot open subfile.\n"
    );

## Definition of variables
my $no_params = scalar @ARGV;   # number of parameters
my $params;                     # command line arguments

my $in_stream = "./";           # --input=$in_stream
my $out_stream;                 # --output=$out_stream
my $k = -1;                     # --pretty-xml=$k
my $noinl = 0;                  # --no-inline
my $maxpar = -1;                # --max-par=$maxpar
my $nodupl = 0;                 # --no-duplicates
my $respace = 0;                # --remove-whitespace

my $in  = 0;
my $out = 0;
my $ods = 0;
my $ni  = 0;
my $mp  = 0;
my $nd  = 0;
my $rws = 0;

## XML output
my $dir = "./";
my @all_files;
my @name;

## find subroutine
my $counter = 0;
sub wanted
{
  if ((-f $_) && ($_ =~ m/^(.+)\.h$/)) {   # *.h file 
    @all_files[$counter] = abs_path($_);   # save absolute path of actual file
    $FILE = IO::File->new();               # open input file
    if ( !$FILE->open("<$_")) { 
        printf STDERR $warning[2];
        exit $IN_SUBFILE_F;     # value 21
    }
    
   while (<$FILE>) {                       # save file contents
        @all_lines[$counter] .= $_;             
    }
    $counter++;
    $FILE->close;                          # close file
  }
  elsif ((-d $_) && (!-r $_)) {            # cannot open directory
      printf STDERR $warning[2];
      exit $IN_SUBFILE_F;       # value 21
  }
}



## Script main #################################################################

## Processing of command line options
while ( @ARGV ) {
    $params = shift( @ARGV );
    # --help
    if ( $params eq "--help" ) {
        if ( $no_params == 1 ) {
            print $help;
            exit $EXIT_SUCCESS;
        }
        print STDERR $warning[0];
        exit $WRONG_PARAMS;     # value 1         
    }    
    # --input=filename
    elsif ($params =~ /^--input=(.+)$/  && $in++ == 0) {
        substr($params, 0, 8) = '';
        $in_stream = $params;
    }
    # --output=filename
    elsif ($params =~ /^--output=(.+)$/ && $out++ == 0) {
        substr($params, 0, 9) = '';
        $out_stream = $params;        
    }
    # --pretty-xml
    elsif ($params =~ /^--pretty-xml$/ && $ods++ == 0) {
        $k = 4;
    }
    # --pretty-xml=k
    elsif ($params =~ /^--pretty-xml=([0-9]+)$/ && $ods++ == 0) {
        substr($params, 0, 13) = '';
        $k = $params;
    }
    # --no-inline
    elsif ($params =~ /^--no-inline$/ && $ni++ == 0) {
        $noinl = 1;
    }
    # --maxpar=n
    elsif ( $params =~ /^--max-par=([0-9]+)$/ && $mp++ == 0) {
        substr($params, 0, 10) = '';
        $maxpar = $params;
    }
    # --no-duplicates
    elsif ( $params =~ /^--no-duplicates$/ && $nd++ == 0) {
        $nodupl = 1;
    }
    # --remove-whitespace
    elsif ( $params =~ /^--remove-whitespace$/ && $rws++ == 0) {
        $respace = 1;
    }
    # wrong parameter
    else {
        print STDERR $warning[0];
        exit $WRONG_PARAMS;     # value 1  
    }
}

## Open file or *.h files and save contents
if (-f $in_stream) {                       # is file
    $dir = "";                             # XML item dir
    $FILE = IO::File->new();
    if ( !$FILE->open("<$in_stream")) { 
        printf STDERR $warning[1];
        exit $IN_FILE_FAIL;     # value 2
    }
    
    @all_files[0] = $in_stream;
    while (<$FILE>) {                      # save file contents
        @all_lines[0] .= $_; 
    }
}
elsif (-d $in_stream) {                    # is directory
    $dir = $in_stream;                     # XML item dir
    $directory = abs_path($in_stream);
    if (-r $directory) {
      find(\&wanted, $directory);          # find *.h files in directory
    }                                         
    else {
      printf STDERR $warning[1];
      exit $IN_FILE_FAIL;       # value 2
    }
}
else {
    printf STDERR $warning[1];
    exit $IN_FILE_FAIL;         # value 2
}


## Modify content of files
my $i;
my $j;
for ($j = 0; $j < scalar @all_files; $j++) {
  
  ## Remove line comments 
  @all_lines[$j] =~ s/\/\/.*\n//g;

  ## Remove block comments
  @all_lines[$j] =~ s/\/\*([^\*]|\n|(\*+([^\*\/]|\n)))*\*+\///g;
  
  ## Remove strings, '{' and '}'
  @all_lines[$j] =~ s/'{'//g;
  @all_lines[$j] =~ s/'}'//g;
  @all_lines[$j] =~ s/"[^"]*"//g;
  
  ## Remove definitions
  @word = split('',@all_lines[$j]);
  @all_lines[$j] = ' ';

  while (@word) {
    $db = shift(@word);
  
    if ($db eq '{') {
      $z = 1;
      while ($z != 0) {
        $db = shift(@word);
        if ($db eq '{') {$z++;}         # '{' '}' counter
        if ($db eq '}') {$z--;}
      }
      @all_lines[$j] .= ';';
    }
    else {
      @all_lines[$j] .= $db;
    }
  }  
  
  ## Remove #define, #include, #ifndef, ...
  @all_lines[$j] =~ s/#.*\n//g;
  
  ## Remove everything except declarations
  @all = split(';',@all_lines[$j]);
  $i = 0;

  while (@all) {
    $dk = shift(@all);
    if ($dk =~ /^(.|\n)*\((.|\n)*\)\s*$/) {
      @decl[$i] = $dk;
      $i++;
    }
  }

  ## Remove typedefs and whitespaces
  $i = 0;  

  while (@decl) {
    $notypedef = shift(@decl);  
    $notypedef =~ s/^\s*typedef\s+//g;
    $notypedef =~ s/^\s*//g;
    $notypedef =~ s/\s*$//g;
    @declarations[$j] .= $notypedef;
    @declarations[$j] .= ";";
  }
}

## Modify declarations according to arguments
my $m;
my $d = abs_path($dir) . "/";

for ($m = 0; $m < scalar @all_files; $m++) {
  
  ## XML item file
  if ($dir) {
    $all_files[$m] =~ s/^\Q$d//g;
  }
  
  ## Remove whitespaces if --remove-whitespace
  if ($respace) {
    @declarations[$m] =~ s/\s+/ /g;
    @declarations[$m] =~ s/\s+\*\s*/\*/g;
  }
}

## Remove inline functions if --no-inline
my @rminline;
my $m2;
if ($noinl) {
  for ($m = 0; $m < scalar @declarations; $m++) {
    if (@declarations[$m] =~ /(^|;)[^;]*inline[^;]*;/) {
      @rminline = split (';',@declarations[$m]);
      for ($m2 = 0; $m2 < scalar @rminline; $m2++) {
        if (@rminline[$m2] !~ /(.|\n)*inline(.|\n)*/) {
          @declarations[$m] = @rminline[$m2] . ";";
        }
      }
    }
  }
}

## Open output file
if ($out_stream) {
  $FILE = IO::File->new();
  if ( !$FILE->open(">$out_stream")) { 
    printf STDERR $warning[1];
    exit $FILEOPEN_ERR;         # value 3
  }
}
else {
  $FILE = STDOUT;
}

## XML output
my $count1;     
my $count2;
my $count3;
my $look_for;
my $find_same_name = 0;
$m = 0;
my @all_names;
my $indent;
  

# XML writer initialization
my $writer = XML::Writer->new(OUTPUT=>$FILE, ENCONDING=>'utf-8',UNSAFE => 1);

# XML header
if ($k >= 0) {
  $writer->raw("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n");
}
else {
  $writer->raw("<?xml version=\"1.0\" encoding=\"utf-8\"?>");
}

# set XML header tag
$writer->raw("<functions dir=\"$dir\">");
if ($k >= 0) {
  $writer->raw("\n");
}

# for each file with declarations
for ($count1 = 0; $count1 < scalar @declarations; $count1++) {
  # choose declarations from variable
  @fnames = split(';', @declarations[$count1]);
  @all_names = ();
  $m = 0;

  for ($count2 = 0; $count2 < scalar @fnames; $count2++) {
    if (@fnames[$count2]) {
      # choose return type from declarations
      $rettype = @fnames[$count2];
      $rettype =~ s/\s*[a-zA-Z0-9|_]+\s*\((.|\n)*\)\s*//g;
      # choose name of function
      $name = @fnames[$count2];
      $name =~ s/\((.|\n)*\)\s*//g;
      $name =~ s/\Q$rettype\E//g;
      $name =~ s/\s*//g;
      
      # if --no-duplicates, save names and compare
      if ($nodupl) {
        $find_same_name = 0;
        for ($look_for = 0; $look_for < scalar @all_names; $look_for++) {
          if ($name eq @all_names[$look_for]) {
            $find_same_name = 1;
          }
        }
        @all_names[$m] = $name;
        $m++;
      }
      
      # XML item varargs
      $varargs = @fnames[$count2];      
      if ($varargs =~ m/\((.|\n)*\.\.\.(.|\n)*\)/) { 
        $varargs = "yes";
        $odp = 1;
      }
      else {
        $varargs = "no"; 
        $odp = 0;
      }
      
      # choose function argument types
      $par = @fnames[$count2];
      $par =~ s/^(.|\n)*\(//g;
      $par =~ s/\)\s*$//g;
      @types = split(',', $par);
      
      # generate output only for functions: 
      #   if --no-duplicates 
      #   if --max-par=n
      if (!$nodupl || ($nodupl && $find_same_name == 0)) {
        if (($maxpar == -1) || ($maxpar && $maxpar >= (scalar @types - $odp))) {
          
          # generate XML function start tag
          if ($k >= 0) {
            # put indent before sub-element
            for ($indent = 0; $indent < $k; $indent++) {
              $writer->raw(" ");
            }
            $writer->raw("<function file=\"@all_files[$count1]\" name=\"$name\" varargs=\"$varargs\" rettype=\"$rettype\">\n");
          }
          else {
            $writer->raw("<function file=\"@all_files[$count1]\" name=\"$name\" varargs=\"$varargs\" rettype=\"$rettype\">");
          }
            
          # for each function argument
          for ($count3 = 0; $count3 < scalar @types; $count3++) {
            # XML item number of function parameter
            $number = $count3 + 1;
            
            # choose types, remove argument names
            if (@types[$count3] =~ m/\s*[a-zA-Z0-9|_]+\s*(\[[^\[\n]*\])+\s*$/) {
              @types[$count3] =~ s/\s*[a-zA-Z0-9|_]+\s*\[/\[/g;
              @types[$count3] =~ s/\s*$//g;
            }
            else {
              @types[$count3] =~ s/\s*[a-zA-Z0-9|_]+\s*$//g;
            }
            @types[$count3] =~ s/^\s*//g;
            
            # generate parameter tag without item
            if (@types[$count3] && (@types[$count3] !~ m/(.|\n)*\.\.\.(.|\n)*/g)) {
              if ($k >= 0) {
                # put double indent before sub-sub-element
                for ($indent = 0; $indent < 2*$k; $indent++) {
                  $writer->raw(" ");
                }
                $writer->raw("<param number=\"$number\" type=\"@types[$count3]\" />\n");  
              }
              else {
                $writer->raw("<param number=\"$number\" type=\"@types[$count3]\" />"); 
              }
            }
          }
          
          # generate XML function end tag
          if ($k >= 0) {
            # put indent before sub-element
            for ($indent = 0; $indent < $k; $indent++) {
              $writer->raw(" ");
            }
            $writer->endTag('function');
            $writer->raw("\n");
          }
          else {
            $writer->endTag('function');
          }
        }
      }
    }
  }
}

# set XML header end tag 
$writer->endTag('functions');

# close XML writer and output file
$writer->end();
$FILE->close();

exit $EXIT_SUCCESS;
