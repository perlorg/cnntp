#!/usr/bin/perl
# Diagnostic script for NNTP article fetching and memcached issues.
# Run in the production pod:
#   kubectl --context dala -n cnntp exec -it [pod] -- perl /cnntp/debug_nntp.pl
#
# Tests: NNTP connectivity, group selection, article ranges, article
# fetching, and memcached connectivity/caching.

use strict;
use warnings;
use Net::NNTP;
use Data::Dumper;

# Set up lib paths for Combust/CN framework (same as production)
BEGIN {
    unshift @INC, "$ENV{CBROOT}/lib"      if $ENV{CBROOT};
    unshift @INC, "$ENV{CBROOTLOCAL}/lib" if $ENV{CBROOTLOCAL};
}

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

# Step 6: Memcached connectivity and article cache
print "\n--- Step 6: Memcached ---\n";

my $memcached_ok = 0;
eval {
    require Combust;
    require Combust::Cache;

    my $config = Combust->config;
    my @servers = $config->memcached_servers;
    print "Configured servers: ", join(", ", map { ref $_ ? "$_->[0] (weight $_->[1])" : $_ } @servers), "\n";

    # Test basic connectivity with a store/fetch round-trip
    my $test_cache = Combust::Cache->new(type => 'debug_test', backend => 'memcached');
    my $test_key = "debug_nntp_" . $$;
    my $test_val = "test_value_" . time;

    my $stored = $test_cache->store(id => $test_key, data => $test_val, expires => 60);
    if ($stored) {
        print "OK: store() succeeded\n";
    } else {
        print "FAIL: store() returned false -- memcached may be unreachable\n";
    }

    my $fetched = $test_cache->fetch(id => $test_key);
    if ($fetched && $fetched->{data} eq $test_val) {
        print "OK: fetch() round-trip succeeded\n";
        $memcached_ok = 1;
    } elsif ($fetched) {
        print "FAIL: fetch() returned wrong data: got '$fetched->{data}', expected '$test_val'\n";
    } else {
        print "FAIL: fetch() returned undef -- memcached not working\n";
    }

    # Clean up test key
    $test_cache->delete(id => $test_key);
};
if ($@) {
    print "FAIL: Could not load Combust::Cache: $@\n";
    print "  (Is CBROOT set? Is combust.conf available?)\n";
}

# Step 7: Article cache in memcached
print "\n--- Step 7: Article cache (cn_art_em) ---\n";
if ($memcached_ok) {
    eval {
        my $art_cache = Combust::Cache->new(type => 'cn_art_em', backend => 'memcached');

        # Try fetching a few known article cache keys
        # Cache key format: "1;{group_id};{article_id}"
        # We don't know group_ids without DB access, so test with
        # a sample key and report whether the cache has entries.
        print "Testing article cache lookups...\n";

        # Try to use the CN::Model if available to look up real articles
        my $have_db = 0;
        eval {
            require CN::Model;
            $have_db = 1;
        };

        if ($have_db) {
            my $groups = CN::Model->group->get_groups(sort_by => 'name');
            if ($groups && @$groups) {
                for my $group (@$groups[0 .. min(2, $#$groups)]) {
                    my $articles = CN::Model->article->get_articles(
                        query   => [group_id => $group->id],
                        sort_by => 'id DESC',
                        limit   => 3,
                    );
                    next unless $articles && @$articles;
                    printf "  Group: %s (id=%d)\n", $group->name, $group->id;
                    for my $art (@$articles) {
                        my $cache_id = join(";", 1, $group->id, $art->id);
                        my $cached = $art_cache->fetch(id => $cache_id);
                        if ($cached && $cached->{data}) {
                            my $age = time - ($cached->{created_timestamp} || 0);
                            printf "    Article %d: CACHED (age: %dd %dh, class: %s)\n",
                                $art->id, int($age/86400), int(($age%86400)/3600),
                                ref($cached->{data}) || 'scalar';
                        } else {
                            printf "    Article %d: NOT in cache\n", $art->id;
                        }
                    }
                }
            } else {
                print "  No groups found in database\n";
            }
        } else {
            print "  Database not available ($@), testing with synthetic keys...\n";
            # Test a few synthetic keys to see if cache responds at all
            for my $key ("1;1;1", "1;1;100", "1;2;1") {
                my $cached = $art_cache->fetch(id => $key);
                if ($cached) {
                    print "  Key '$key': HIT\n";
                } else {
                    print "  Key '$key': MISS (expected if no articles cached)\n";
                }
            }
        }
    };
    if ($@) {
        print "FAIL: Error testing article cache: $@\n";
    }
} else {
    print "Skipped -- memcached not working (see step 6)\n";
}

print "\n=== Done ===\n";

sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
