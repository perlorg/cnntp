#!/usr/bin/perl
# Diagnostic script for NNTP article fetching issues.
# Run in the production pod:
#   kubectl --context dala -n cnntp exec -it [pod] -- perl /app/debug_nntp.pl
#
# Tests: connectivity, group selection, article ranges, and article fetching.

use strict;
use warnings;
use Net::NNTP;
use Data::Dumper;

my $SERVER = 'nntp.perl.org';

print "=== NNTP Diagnostics ===\n\n";

# Step 1: Connectivity
print "--- Step 1: Connectivity to $SERVER ---\n";
my $nntp = Net::NNTP->new($SERVER, Timeout => 15, Debug => 0);
unless ($nntp) {
    print "FAIL: Cannot connect to $SERVER\n";
    print "Check DNS resolution and network from this pod.\n";
    exit 1;
}
print "OK: Connected to $SERVER\n";

my $date = $nntp->date;
if ($date) {
    print "OK: Server date: $date\n";
} else {
    print "WARN: date() returned undef (connection may be stale)\n";
}

# Step 2: List groups matching perl.*
print "\n--- Step 2: Group listing ---\n";
my $groups = $nntp->list;
if ($groups) {
    my @perl_groups = sort grep { /^perl\./ } keys %$groups;
    print "OK: Found ", scalar @perl_groups, " perl.* groups\n";
    for my $g (@perl_groups) {
        my ($est, $low, $high, $status) = @{$groups->{$g}};
        printf "  %-40s  articles: %d - %d  (est: %d, status: %s)\n",
            $g, $low, $high, $est, $status // 'n/a';
    }
} else {
    print "FAIL: list() returned undef: ", $nntp->message, "\n";
}

# Step 3: Test specific groups
print "\n--- Step 3: Group selection and article ranges ---\n";
my @test_groups = qw(perl.perl5.porters perl.beginners perl.cpan.testers);

for my $group_name (@test_groups) {
    print "\nGroup: $group_name\n";
    my ($article_count, $first, $last, $name) = $nntp->group($group_name);
    if (defined $article_count) {
        printf "  OK: articles=%d  first=%d  last=%d  name=%s\n",
            $article_count, $first, $last, $name;
    } else {
        print "  FAIL: group() returned undef: ", $nntp->message // 'no message', "\n";
        next;
    }

    # Fetch most recent article
    print "  Fetching last article (id=$last)...\n";
    my $article = $nntp->article($last);
    if ($article) {
        my $size = length(join "", @$article);
        print "  OK: Got article $last ($size bytes, ", scalar @$article, " lines)\n";
        # Show first few header lines
        for my $i (0 .. min(4, $#$article)) {
            my $line = $article->[$i];
            chomp $line;
            print "    $line\n";
        }
    } else {
        print "  FAIL: article($last) returned undef: ", $nntp->message // 'no message', "\n";
    }

    # Fetch first article
    print "  Fetching first article (id=$first)...\n";
    $article = $nntp->article($first);
    if ($article) {
        my $size = length(join "", @$article);
        print "  OK: Got article $first ($size bytes)\n";
    } else {
        print "  FAIL: article($first) returned undef: ", $nntp->message // 'no message', "\n";
        print "  (First article may have expired from server)\n";
    }
}

# Step 4: Test specific article IDs from error logs (if provided as args)
if (@ARGV) {
    print "\n--- Step 4: Test specific articles ---\n";
    my $group_name = shift @ARGV;
    my ($article_count, $first, $last, $name) = $nntp->group($group_name);
    unless (defined $article_count) {
        print "FAIL: Cannot select group $group_name\n";
    } else {
        printf "Group %s: range %d-%d\n", $group_name, $first, $last;
        for my $id (@ARGV) {
            print "  Article $id: ";
            if ($id < $first || $id > $last) {
                print "OUT OF RANGE (server range: $first-$last)\n";
            }
            my $article = $nntp->article($id);
            if ($article) {
                my $size = length(join "", @$article);
                print "OK ($size bytes)\n";
            } else {
                print "FAIL: ", $nntp->message // 'no message', "\n";
            }
        }
    }
} else {
    print "\n--- Step 4: Skipped (no specific articles given) ---\n";
    print "Usage: $0 [group_name article_id1 article_id2 ...]\n";
    print "Example: $0 perl.perl5.porters 12345 12346\n";
}

# Step 5: Test head/body separately (to check if article vs head/body differs)
print "\n--- Step 5: head() and body() tests ---\n";
{
    my ($article_count, $first, $last) = $nntp->group('perl.perl5.porters');
    if (defined $article_count && $last) {
        my $head = $nntp->head($last);
        if ($head) {
            print "OK: head($last) returned ", scalar @$head, " lines\n";
        } else {
            print "FAIL: head($last): ", $nntp->message // 'no message', "\n";
        }
        my $body = $nntp->body($last);
        if ($body) {
            print "OK: body($last) returned ", scalar @$body, " lines\n";
        } else {
            print "FAIL: body($last): ", $nntp->message // 'no message', "\n";
        }
    }
}

$nntp->quit;
print "\n=== Done ===\n";

sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
