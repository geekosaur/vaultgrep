#! /usr/bin/env perl
#
# Grep Crawl vault files for some string and output the match preceded by
# vault name. Don't search things like SUBST lines or the MAP.
#

use File::Find;

my $myname = $0;
$myname =~ s,.*/,,;
$myname =~ s/(.)\..*$/$1/;

# probably pointless extensibility...
my @path = ($ENV{HOME} . '/Sources/crawl/crawl-ref/source/dat/des');
my @sfx = ('des');
my %sel = (monster  => [qr/^MONS:/, qr/^KMONS:/]
	  ,item     => [qr/^ITEM:/, qr/^KITEM:/]
	  ,feature  => [qr/^FEAT:/, qr/^KFEAT:/]
	  );
my %extra = (property => [qr/^PROP:/, qr/^KPROP:/, qr/^TAGS:/, qr/^LTAGS:/]
	    ,branch   => [qr/^PLACE:/]
	    );

my (%which, %also);
my $err = 0;
my $and = 1;
while (@ARGV) {
  my $arg = shift @ARGV;
  if ($arg eq '--all') {
    %which = map {$_ => 1} keys %sel;
  }
  elsif ($arg =~ /^--(\w+)$/ and exists $sel{$1}) {
    $which{$1} = 1;
  }
  elsif ($arg =~ /^--no-(\w+)$/ and exists $sel{$1}) {
    if (!keys %which) {
      %which = map {$_ => 1} keys %sel;
    }
    delete $which{$1};
  }
  elsif ($arg =~ /^--(\w+)$/ and exists $extra{$1}) {
    push @{$also{$1}}, shift @ARGV;
  }
  elsif ($arg =~ /^--(\w+)=(.*)$/ and exists $extra{$1}) {
    push @{$also{$1}}, $2;
  }
  # @@@ should perhaps accept --any|--all, except see above...
  elsif ($arg eq '--and' or $arg eq '-a') {
    $and = 1;
  }
  elsif ($arg eq '--or' or $arg eq '-o') {
    $and = 0;
  }
  elsif ($arg eq '--help' or $arg eq '-h') {
    $err = 1;
    last;
  }
  # @@@ do this via mapping somehow instead of breaking abstraction :/
  elsif ($arg =~ /^-b(.*)$/) {
    push @{$also{branch}}, $1;
  }
  elsif ($arg eq '-b') {
    push @{$also{branch}}, shift @ARGV;
  }
  elsif ($arg eq '-m') {
    $which{monster} = 1;
  }
  elsif ($arg eq '-i') {
    $which{item} = 1;
  }
  elsif ($arg eq '-f') {
    $which{feature} = 1;
  }
  elsif ($arg eq '--') {
    last;
  }
  elsif ($arg =~ /^-/) {
    print STDERR "$myname: unknown switch $arg\n";
    $err = 1;
  }
  else {
    unshift @ARGV, $arg;
    last;
  }
}
if ($err or !@ARGV) {
  print STDERR "usage: $myname [--and|--or] [--all";
  for (keys %sel) {
    print STDERR "|--[no-]$_";
  }
  print STDERR "] [";
  $err = 0;
  for (keys %extra) {
    $err and print STDERR '|';
    print STDERR "--$_=pattern";
    $err = 1;
  }
  print STDERR "] pattern...\n";
  exit 1;
}
keys %which or %which = map {$_ => 1} keys %sel;

find(sub {vgrep(clean($File::Find::dir, @path), $_)}
    ,@path
    );

###############################################################################

sub clean {
  my ($dir, @pfx) = @_;
  # @@@ after allowing for multiple paths, we make it useless...
  for my $pfx (@pfx) {
    $dir =~ s,^$pfx($|/),, and return $dir;
  }
  return $dir;
}

sub vgrep {
  my ($dir, $name) = @_;
  -f $_ or return;
  my $ok = 0;
  for my $sfx (@sfx) {
    if (/\.$sfx$/i) {
      $ok = 1;
      last;
    }
  }
  $ok or return;
  # it's presumably a .des file; munch it
  open($f, $_) or return;
  my $ln;
  my $map = 0;
  my $lua = 0;
  my $cur = undef;
  my $lno = 0;
  my $doing = -1;
  my $dd = undef;
  my $ldd = undef;
  while (defined ($ln = <$f>)) {
    $lno++;
    chomp $ln;
    $ln =~ /^\s*($|#)/ and next;
    while ($ln =~ s/\\$//) {
      my $l2 = <$f>;
      unless (defined $l2) {
	print STDERR "$dir/$_:$lno: warning: end of file in continued line\n";
	$l2 = '';
      }
      $lno++;
      chomp $l2;
      $l2 =~ s/^\s+//;
      $ln .= $l2;
    }
    if (defined $cur and !$map and !$lua and $ln =~ /^MAP$/) {
      $map = 1;
      next;
    }
    elsif (!$map and !$lua and $ln =~ /^:/) {
      # one-liner lua
      next;
    }
    elsif (!$map and !$lua and $ln =~ /^(?:lua\s*)?\{\{$/) {
      $lua = 1;
      next;
    }
    elsif ($lua and $ln =~ /^\}\}$/) {
      $lua = 0;
      next;
    }
    elsif ($map and $ln =~ /^ENDMAP$/) {
      $cur = undef;
      $map = 0;
      next;
    }
    elsif ($map or $lua) {
      next;
    }
    elsif ($ln =~ /^NAME:\s*(\S+)\s*$/) {
      # @@@ serial vaults don't have maps in the main vaults
      # @@@ check default depth vs. branch here to set $doing!
      # @@@@ except that's wrong if it sets DEPTH:
#      if (defined $cur) {
#	print STDERR "$dir/$_:$lno: warning: already in $cur: $ln\n";
#      }
      $cur = $1;
      $doing = -1;
      $ldd = undef;
      next;
    }
    # this is allowed outside of any definition
    elsif (!defined $cur and $ln =~ /^default-depth:\s*(.*)$/) {
      $dd = $1;
      next;
    }
    elsif (!defined $cur) {
      print STDERR "$dir/$_:$lno: warning: not in a definition: $ln\n";
      next;
    }
    elsif ($ln =~ /^DEPTH:\s*(.*)$/) {
      $ldd = $1;
    }
    else {
      # look for extras matches
      $ok = 0;
      my $rok = 0;
      for my $extra (keys %also) {
	next if $extra eq 'branch'; # @@@@@@@@@@
	# does this line match a selector?
	for my $kw (@{$extra{$extra}}) {
	  if ($ln =~ $kw) {
	    $rok = 1;
	    for my $pat (@{$also{$extra}}) {
	      if ($ln =~ /$pat/) {
		$ok = 1;
		last;
	      }
	    }
	    $ok or $doing = 0;
	    last;
	  }
	}
      }
      # if we matched any extra keyword then it can't be a section keyword
      $rok and next;
      # is section enabled?
      for my $sect (keys %which) {
	# does the line match a selector?
	for my $kw (@{$sel{$sect}}) {
	  if ($ln =~ $kw) {
	    $ok = 1;
	    last;
	  }
	}
	$ok or next;
	# figure out if we are in a selected branch
	# @@@ and pray DEPTH: doesn't occur *after* MONS etc.
	if ($doing == -1) {
	  if (!exists $also{branch}) {
	    $doing = 1;
	  }
	  elsif (defined $dd or defined $ldd) {
	    defined $ldd or $ldd = $dd;
	    $doing = 0;
	    for my $pat (map {split(',', $_)} @{$also{branch}}) {
	      if ($ldd =~ /(?:^|,\s*)$pat(?:,|:|$)/i) {
		$doing = 1;
	      }
	    }
	  }
	}
	$doing or next;
	# try matching against all the patterns.
	# @@@ AND / OR expressions?
	# @@@ for that matter, and/or sections... right now always OR
	$ok = $and ? @ARGV : 0;
	for my $pat (@ARGV) {
	  # @@@ might want to delete prefixes for those keywords that have them
	  if ($ln =~ /$pat/) {
	    if ($and) {
	      $ok--;
	    } else {
	      $ok = 1;
	    }
	  }
	}
	if (($and and !$ok) or (!$and and $ok)) {
	  print "$dir/$_:${lno}: [$cur] $ln\n";
	}
      }
    }
  }
}
