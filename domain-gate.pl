#!/usr/bin/env perl
# Fails on any hostname or email domain that is not on .domain-allowlist.
# Reads NUL-separated file paths on stdin; prints file:line: host per hit.
#
# Three contexts count as a domain: a URL host, the host of user@host, and a
# bare dotted name ending in a common public TLD or an internal-looking one.
# Other dotted tokens (vim.api.nvim, bootstrap.sh) are code, not hosts.
use strict;
use warnings;

my $allowfile = shift // '.domain-allowlist';
open my $af, '<', $allowfile or die "cannot read $allowfile: $!\n";
my @allow;
while (<$af>) {
    s/#.*//;
    s/^\s+|\s+$//g;
    push @allow, lc $_ if length;
}
close $af;

sub allowed {
    my ($host) = @_;
    return 1 if $host =~ /^(localhost|127\.\d+\.\d+\.\d+|0\.0\.0\.0)$/;
    for my $a (@allow) {
        return 1 if $host eq $a || substr($host, -length($a) - 1) eq ".$a";
    }
    return 0;
}

my $bare_tld = qr/com|org|net|io|dev|co|cloud|internal|corp|intra|lan/;
my $hits = 0;
local $/ = "\0";
while (my $file = <STDIN>) {
    chomp $file;
    next unless -f $file && -T $file;
    open my $fh, '<', $file or next;
    local $/ = "\n";
    while (my $line = <$fh>) {
        my @hosts;
        push @hosts, $1 while $line =~ m{\b[a-z][a-z0-9+.-]*://(?:[^\s/@"'<>]*@)?([a-z0-9.-]+)}gi;
        push @hosts, $1 while $line =~ m{\b[a-z0-9._%+-]+@([a-z0-9-]+(?:\.[a-z0-9-]+)+)}gi;
        push @hosts, $1 while $line =~ m{(?<![\w.-])((?:[a-z0-9-]+\.)+(?:$bare_tld))(?![\w-])}gi;
        my %seen;
        for my $host (map { my $h = lc $_; $h =~ s/\.+$//; $h } @hosts) {
            next if $seen{$host}++ || allowed($host);
            # Version strings (pkg@1.2.3) and punctuation are not hostnames.
            next unless $host =~ /^(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$/;
            print "$file:$.: $host\n";
            $hits++;
        }
    }
    close $fh;
}
exit($hits ? 1 : 0);
