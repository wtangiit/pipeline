#!/usr/bin/env perl 

#input: .fna or .fastq 
#outputs:  ${out_prefix}.passed.fna and ${out_prefix}.removed.fna

use strict;
use warnings;
no warnings('once');

use Getopt::Long;
use File::Copy;
use File::Basename;
use POSIX qw(strftime);
umask 000;

my $runcmd   = "filter_sequences";

# options
my $input_file = "";
my $out_prefix = "prep";
my $filter_options = "";
my $out_file = "";
my $help = "";
my $options = GetOptions ("input=s"   => \$input_file,
			  "out_prefix=s"  => \$out_prefix,
			  "filter_options=s" => \$filter_options,
			  "output=s" => \$out_file, #deprecated
			  "help!" => \$help
			 );

if ($help){
    print_usage();
    exit 0;
}elsif (length($input_file)==0){
    print "ERROR: An input file was not specified.\n";
    print_usage();
    exit __LINE__;  #use line number as exit code
}elsif (! -e $input_file){
    print "ERROR: The input sequence file [$input_file] does not exist.\n";
    print_usage();
    exit __LINE__;
}elsif ($input_file !~ /\.(fna|fasta|fq|fastq)$/i) {
    print "ERROR: The input sequence file must be fasta or fastq format.\n";
    print_usage();
    exit __LINE__;
}

my $passed_seq = $out_prefix.".passed.fna";
my $removed_seq = $out_prefix.".removed.fna";
if (length($out_file)>0) { #for compatibility with old pipeline templates (-output is deprecated)
    $passed_seq = $out_file;
}

# get filter options
# default => filter_ln:min_ln=<MIN>:max_ln=<MAX>:filter_ambig:max_ambig=5:dynamic_trim:min_qual=15:max_lqb=5
unless ($filter_options) {
  if ( $input_file =~ /\.(fna|fasta)$/i ) {
    my @out = `seq_length_stats.py -i $input_file -t fasta -f | cut -f2`;
    chomp @out;
    my $mean = $out[2];
    my $stdv = $out[3];
    my $min  = int( $mean - (2 * $stdv) );
    my $max  = int( $mean + (2 * $stdv) );
    if ($min < 0) { $min = 0; }
    $filter_options = "filter_ln:min_ln=".$min.":max_ln=".$max.":filter_ambig:max_ambig=5";
  }
  elsif ( $input_file =~ /\.(fq|fastq)$/i ) {
    $filter_options = "dynamic_trim:min_qual=15:max_lqb=5";
  }
  else {
    $filter_options = "skip";
  }
}

# do not skip
unless ( $filter_options =~ /^skip$/i ) {
  my $cmd_options = "";
  for my $ov (split ":", $filter_options) {
    if ($ov =~ /=/) {
      my ($option, $value) = split "=", $ov;
      $cmd_options .= "-".$option." ".$value." ";
    } else {
      $cmd_options .= "-".$ov." ";
    }
  }

  # run cmd
  print "$runcmd -i $input_file -o $passed_seq -r $removed_seq $cmd_options";
  run_cmd("$runcmd -i $input_file -o $passed_seq -r $removed_seq $cmd_options");
}
# skip it
else {
  if ( $input_file =~ /\.(fna|fasta)$/i ) {
    run_cmd("cp $input_file $passed_seq");
  } elsif ( $input_file =~ /\.(fq|fastq)$/i ) {
    run_cmd("seqUtil --fastq2fasta -i $input_file -o $passed_seq");
  }
  run_cmd("touch $removed_seq");
}

exit(0);

sub print_usage{
    print "USAGE: awe_preprocess.pl -input=<input fasta or fastq> [-out_prefix=<output prefix> -filter_options=<string_filter_options>]\n";
    print "outputs: \${out_prefix}.passed.fna and \${out_prefix}.removed.fna\n"; 
}

sub run_cmd{
    my ($cmd) = @_;
    my $run = (split(/ /, $cmd))[0];
    system($cmd);
    if ($? != 0) {
        print "ERROR: $run returns value $?\n";
        exit $?;
    }
}
