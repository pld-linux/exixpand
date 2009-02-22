#!/usr/bin/perl

# SET THIS TO THE PATH TO YOUR EXIM BINARY!
my $exim  = '/usr/bin/exim';

# wrap 'exim -be' string expansion:
#   up and down arrows for history and history editing
#   ability to substitute certain variables so whole expansions can be tested

use strict;
use Term::ReadLine;

my($p_name)   = $0 =~ m|/?([^/]+)$|;
my $p_version = "20050922.1";
my $p_usage   = "Usage: $p_name [--help|--version] (see --help for details)";
my $p_cp      = <<EOM;
        Copyright (c) 2004-2005 John Jetmore <jj33\@pobox.com>

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
EOM
ext_usage(); # before we do anything else, check for --help

my $term  = Term::ReadLine->new('Exim Expansion Tester');
my $OUT   = $term->OUT() || *STDOUT;
my %track = ();
my $pr1   = 'expand> ';
my $pr2   = '> ';
my $cpr   = $pr1;
my $clear = 1;
my $wstr;
my $istr;

#$SIG{INT} = sub { $wstr = ''; $istr = ''; $clear = 1};
#$SIG{INT} = sub { $clear = 1; print STDERR "foo!\n"; };

while (defined ($istr = $term->readline($cpr, ""))) {
  #if ($clear) {
  #  $clear = 0;
  #  $wstr = '';
  #  $istr = '';
  #}
  next if (!$istr);
  if ($istr =~ /^\./) {
    if ($istr =~ /^\.(quit|exit)\b/) {
      exit;
    } elsif ($istr =~ /^\.clear\b/) {
      $wstr = '';
      $cpr  = $pr1;
      next;
    } elsif ($istr =~ /^\.track (\S+)(?: (.*))?$/) {
      my $var = $1;
      my $val = $2;
      $track{$var}{on} = 1;
      if (!$val && !$track{$var}{val}) {
        $track{$var}{val} = "";
      } else {
        $track{$var}{val} = $val;
      }
    } elsif ($istr =~ /^\.untrack (\S+)/) {
      $track{$1}{on} = 0;
    } elsif ($istr =~ /^\.unset (\S+)/) {
      delete($track{$1});
    } elsif ($istr =~ /^\.showvar(?: (\S+))?/) {
      my $var = $1;
      if ($var && !$track{$var}) {
        print $OUT "The variable $var is not set\n";
      } elsif (!scalar(keys(%track))) {
        print $OUT "No variables are being tracked\n";
      } else {
        printf $OUT "%3s %-20s \"%s\"\n", "On?", "Name", "Value";
        my @keys = $var ? ($var) : (sort keys %track);
        foreach my $k (@keys) {
          printf $OUT "%3s %-20s \"%s\"\n", $track{$k}{on} ? 'Y' : 'N',
                                           $k, $track{$k}{val};
        }
      }
    } else {
      print $OUT "command unrecognized\n";
    }
    next;
  }
  $wstr .= $istr;
  if ($istr =~ m|\\$| && $istr !~ m|^\\\\| && $istr !~ m|[^\\]\\\\|) {
    $cpr = $pr2;
    #$wstr =~ s|\\$|\\\n|g;
    $wstr =~ s|\\$||g;
  } else {
    $cpr = $pr1;
    my $eval = $wstr;
    # XXX header expansion (ending in :) is missing here
    foreach my $var (keys %track) {
      next if (!$track{$var}{on});
      if ($var =~ /^r?h(eader)?_/) {
        #print STDERR "header hit on $var\n";
        $eval =~ s|\$$var:|$track{$var}{val}|g;
      }
      $eval =~ s|\$$var\b|$track{$var}{val}|g;
      $eval =~ s|\${$var}|$track{$var}{val}|g;
    }
    print $OUT "Evaluating: $eval\n";
    system($exim, '-be', $eval);
    $term->addhistory($wstr);
    $wstr = '';
  }
}

print "\n";

exit;

sub ext_usage {
  if ($ARGV[0] =~ /^--help$/i) {
    require Config;
    $ENV{PATH} .= ":" unless $ENV{PATH} eq "";
    $ENV{PATH} = "$ENV{PATH}$Config::Config{'installscript'}";
    #exec("perldoc", "-F", "-U", $0) || exit 1;
    $< = $> = 1 if ($> == 0 || $< == 0);
    exec("perldoc", $0) || exit 1;
    # make parser happy
    %Config::Config = ();
  } elsif ($ARGV[0] =~ /^--version$/i) {
    print "$p_name version $p_version\n\n$p_cp\n";
  } else {
    return;
  }

  exit(0);
}

__END__

=head1 NAME

exixpand - Wrap exim -be, providing readline and variable substitution

=head1 USAGE

exixpand [--help|--version]

=head1 DESCRIPTION

exixpand (pronounced exi-spand) is a wrapper for exim's expansion testing function (-be).  It provides readline support via perl's Term::ReadLine module and also provides variable interpolations.  The main intention of being able to track variables is to be able to test different values for variables without modifying the expansion string.  The idea is to be able to test expansion strings that can be copied verbatim into a config file with different variable values.

Any text that starts with a "." is a command that is handled by exixpand itself.  These commands are explained in more detail below.  Any other text is passed to 'exim -be' and the result is displayed.

=head1 COMMANDS

=over 4

=item .track <variable> [<value>]

This causes exixpand to mark <variable> for interpolation in passed in strings.  <variable> should not contain any spaces and should not start with a dollar sign (though it should when used in an expansion string).  <variable> does not need to be the same as an internal exim expansion variable.

<value> is optional.  Leaving it blank will either set an empty variable or cause a previously set but untracked variable to be tracked (see .untrack below for details).

=item .untrack <variable>

.untrack causes exixpand to save the value for <variable> but stop interpolating it in strings.  It can be reactivated using .track.  This functionality is provided so that interpolation can be turned off without having to lose potentially complex or lengthy values.

=item .unset <variable>

.unset causes exixpand to completely forget about <variable>.

=item .showvar [<variable>]

.showvar shows the value of a tracked variable and whether it is currently active or not.  If no <variable> is provided all variables are displayed.

=item .exit, .quit, ^D

Exit exixpand.  Note that some bug seems to cause EOF not to be received properly in some perl versions.  I've tried multiple versions of perl on Linux, Solaris, and Darwin, and 5.6.1 consistantly fails to recognize EOF.

=item .clear, ^C

Reset internal state (empty multiline buffers).

=back

=head1 EXAMPLES

Test an ${if test against $sender_helo_name.  Use of $GOODHELO and $BADHELO is done to demonstrate nested variable interpolation.

  expand> .track BADHELO host_name.domain.com
  expand> .track GOODHELO hostname.domain.com
  expand> .track sender_helo_name $GOODHELO
  expand> $sender_helo_name
  Evaluating: hostname.domain.com
  hostname.domain.com
  expand> ${if match{$sender_helo_name}{^.*_}{yes}fail}
  Evaluating: ${if match{hostname.domain.com}{^.*_}{yes}fail}
  Failed: "if" failed and "fail" requested
  expand> .track sender_helo_name $BADHELO
  expand> ${if match{$sender_helo_name}{^.*_}{yes}fail}
  Evaluating: ${if match{host_name.domain.com}{^.*_}{yes}fail}
  yes
  expand> 

This is a contrived example showing how you can use variable interpolation to make complicated expansions more simple.  It uses small pieces to build up to a failry complicated expansion string which can be paste directly into a configuration file.  (This specific example finds the number of seconds since midnight localtime.)

  expand> .track HOUR ${substr{11}{2}{$tod_log}}
  expand> $HOUR
  Evaluating: ${substr{11}{2}{$tod_log}}
  21
  expand> .track SECS_IN_HOUR ${eval:$HOUR*3600}
  expand> $SECS_IN_HOUR
  Evaluating: ${eval:${substr{11}{2}{$tod_log}}*3600}
  75600
  expand> .track BASE_SECS ${eval:3600*${eval:$tod_epoch/3600}}
  expand> $BASE_SECS
  Evaluating: ${eval:3600*${eval:$tod_epoch/3600}}
  1101438000
  expand> .track REMAINING_SECS ${eval:$tod_epoch-$BASE_SECS}
  expand> .showvar
  On? Name                 "Value"
    Y BASE_SECS            "${eval:3600*${eval:$tod_epoch/3600}}"
    Y HOUR                 "${substr{11}{2}{$tod_log}}"
    Y REMAINING_SECS       "${eval:$tod_epoch-$BASE_SECS}"
    Y SECS_IN_HOUR         "${eval:$HOUR*3600}"
  expand> ${eval:$SECS_IN_HOUR + $REMAINING_SECS}
  Evaluating: ${eval:${eval:${substr{11}{2}{$tod_log}}*3600} + ${eval:$tod_epoch-${eval:3600*${eval:$tod_epoch/3600}}}}
  77742
  expand>

=cut
