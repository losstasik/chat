#!/usr/bin/perl
use strict;
use warnings;
use Socket;
use threads;
use threads::shared;

my $port = shift || 8080;
my $proto = getprotobyname('tcp');
my $server = "localhost"; 
our @clients : shared;

# create a socket, make it reusable
socket(SOCKET, PF_INET, SOCK_STREAM, $proto)
   or die "Can't open socket $!\n";

# bind to a port, then listen
bind( SOCKET, pack_sockaddr_in($port, inet_aton($server)))
   or die "Can't bind to port $port! \n";

listen(SOCKET, 5) or die "listen: $!";
print "SERVER started on port $port\n";

# accepting a connection
while (my $client_addr = accept(my $client_socket, SOCKET)) {
    create_client_thread($client_socket);
    #thread should have it's wown copy of client socket.
    close $client_socket; 
}
close SOCKET;

sub broadcast  {
    my $msg = shift;
    my $sfn = shift;

    for my $fn (@clients) {
        next if $fn eq $sfn;

        open my $fh, ">&=$fn" || warn $!;
        print $fh "$msg\n";
    }
}

sub create_client_thread {
    my $socket = shift;
  
    #print welcome message
    my $ofh = select $socket;
    $| = 1; #make socket hot
	select $ofh;

    print $socket "\nWelcome to Chart Room\nWhats you name?";
    my $name = <$socket>;

    #string end with lfcr. remove two last carecters
    chop $name; 
    chop $name;

    my $sfn = fileno $socket;
    push @clients, $sfn;

    threads->create(sub { 
        my $thr_id = threads->self->tid;
        print "Starting thread $thr_id\n";
        
        print $socket "$name > ";
        while (<$socket>) {
            chop; #remove /LFCR
            chop; 
            last if $_ eq "quit";

            if ($_ eq "help" or $_ eq "?") {
                show_help($socket);
            }
            else {
                broadcast("$name > $_", $sfn);
            }
            print $socket "$name > ";
        }
        close $socket;

        print "Ending thread $thr_id\n";
        threads->detach(); #End thread.
    });
}

sub show_help {
    my $fh = shift;
    print $fh "\nquit\tquit chart room";
    print $fh "\nhelp\tprint help information";
    print $fh "\n\n";
}