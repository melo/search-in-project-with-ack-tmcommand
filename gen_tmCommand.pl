#!/usr/bin/env perl

use strict;
use warnings;

my $base = 'SearchInProjectWithAck.tmCommand';
my $tmpl = slurp("$base.tmpl");
my $script = slurp('search_with_ack.rb');

# very basic XML Encode
$script =~ s/&/&amp;/go;
$script =~ s/</&lt;/go;
$script =~ s/>/&gt;/go;
$script =~ s/'/&apos;/go;
$script =~ s/"/&quot;/go;

$tmpl =~ s/##CONTENT##/$script/;

print $tmpl;

### Slurp a file
sub slurp {
  my $filename = shift;
  
  if (open(my $fh, '<', $filename)) {
    local $/;
    my $content = <$fh>;
    close($fh);
    
    return $content;
  }
  die $!;
}

