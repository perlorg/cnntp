package CN::NNTP;
use strict;
use Net::NNTP;

my $nntp;
my $nntp_connected_at;

sub nntp {
    if ($nntp) {
        # Only check liveness if connection is >60s old
        if (time - $nntp_connected_at > 60) {
            my $alive = eval {
                local $SIG{ALRM} = sub { die "nntp date check timeout\n" };
                alarm(3);
                my $ok = $nntp->date;
                alarm(0);
                $ok;
            };
            alarm(0); # ensure alarm is cleared on exception
            unless ($alive) {
                warn "CN::NNTP: liveness check failed, disconnecting\n";
                $nntp = undef;
                $nntp_connected_at = undef;
            }
        }
    }

    my $SERVER = 'nntp.perl.org';
    unless ($nntp) {
        warn "CN::NNTP: connecting to $SERVER\n";
        $nntp = Net::NNTP->new($SERVER, Timeout => 5, Debug => 0);
        if ($nntp) {
            $nntp_connected_at = time;
            warn "CN::NNTP: connected to $SERVER\n";
        } else {
            warn "CN::NNTP: failed to connect to $SERVER\n";
            return undef;
        }
    }

    $nntp;
}

sub reset_connection {
    if ($nntp) {
        warn "CN::NNTP: resetting connection\n";
    }
    $nntp = undef;
    $nntp_connected_at = undef;
}


1;
