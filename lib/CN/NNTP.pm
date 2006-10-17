package CN::NNTP;
use strict;
use Net::NNTP;

my $nntp;
sub nntp {
    $nntp = undef unless $nntp and $nntp->date;

    my $SERVER = 'x6.dev';
    unless ($nntp) {
        $nntp = Net::NNTP->new($SERVER, Timeout => 10, Debug => 0 )
          or $nntp = Net::NNTP->new($SERVER, Timeout => 10, Debug => 0 )
          or return undef;  
    }
    
    $nntp;
}


1;
