package POE::Devel::Top;

use strict;
use warnings;

use Carp;
use POE qw< API::Peek Session >;
use Term::ANSIColor qw< :constants >;


our $VERSION = "0.001";


#
# import()
# ------
sub import {
    my ($class) = @_;

    # if caller line is zero, it means the module was loaded from the
    # command line, in which case we automatically spawn the session
    my (undef, undef, $line) = caller;
    $class->spawn if $line == 0;
}


#
# spawn()
# -----
sub spawn {
    my ($class, @args) = @_;

    croak "Odd number of argument" if @args % 2 == 1;
    my %param = @args;

    POE::Session->create(
        inline_states => {
            _start => sub {
                $_[KERNEL]->alias_set("[$class]");
                $_[KERNEL]->delay(poe_devel_top => 2);
            },
            poe_devel_top => \&render,
        },
    );
}


#
# render()
# ------
sub render {
    my $kernel = $_[KERNEL];
    my $poe_api = POE::API::Peek->new;
    my $now = time;

    $kernel->delay(poe_devel_top => 2);

    local $Term::ANSIColor::AUTORESET = 1;

    my $session_head    = REVERSE(BOLD "%5s  %6s  %8s  %6s  %8s  %-40s").$/;
    my $session_row     = "%5d  %6s  %8d  %6d  %8d  %-40s\n";
    my @session_cols    = qw< ID Memory Refcount EvtsTo EvtsFrom Aliases >;

    my $event_head      = REVERSE(BOLD "%5s  %-17s %4s %5s %5s  %-40s").$/;
    my $event_row       = "%5d  %-17s %4d %5d %5d  %-40s\n";
    my @event_cols      = qw< ID Type Pri Src Dest Name >;

    my @times = times;
    my @pwent = getpwuid(int $>);
    my $egid  = (split / /, $))[0];
    my @grent = getgrgid(int $egid);

    print "\e[2J";
    print "Process ID: $$,  UID: $> ($pwent[0]),  GID: $egid ($grent[0])\n",
          "Resource usage:  user: $times[0] sec (+$times[2] sec),  ",
                        "system: $times[1] sec (+$times[3] sec)\n",
          "Sessions: ", $poe_api->session_count, " total,  ",
          "Handles: ", $poe_api->handle_count, " total,  ",
          "Loop: ", $poe_api->which_loop, "\n\n";

    my $kernel_id   = $kernel->ID;
    my $kernel_name = "[POE::Kernel]";

    if ($kernel_id !~ /^\d/) {
        $kernel_name .= " id=$kernel_id";
        $kernel_id   = 0;
    }

    print BOLD " Sessions", $/;
    printf $session_head, @session_cols;
    printf $session_row,
        $kernel_id,
        human_size( $poe_api->kernel_memory_size ),
        $poe_api->get_session_refcount($kernel), 
        $poe_api->event_count_to($kernel), 
        $poe_api->event_count_from($kernel),
        $kernel_name;
    printf $session_row,
        $_->ID,
        human_size( $poe_api->session_memory_size($_) ),
        $poe_api->get_session_refcount($_),
        $poe_api->event_count_to($_),
        $poe_api->event_count_from($_),
        join(",", $poe_api->session_alias_list($_))
        for sort { $a->ID <=> $b->ID } $poe_api->session_list;

    print $/;

    print BOLD " Events", $/;
    printf $event_head, @event_cols;
    printf $event_row, $_->{ID}, $_->{type},
        $_->{priority} > $now ? $_->{priority}-$now : $_->{priority},
        $_->{source}->ID,
        $_->{destination}->ID, $_->{event}
        for $poe_api->event_queue_dump;

    print $/;
}


#
# human_size()
# ----------
sub human_size {
    my ($size) = @_;

    return $size if $size < 100_000;

    my $unit;
    for (qw< K M G >) {
        $size = int($size / 1024);
        $unit = $_;
        last if $size < 1024;
    }

    return $size.$unit;
}


__END__

=head1 NAME

POE::Devel::Top - Display information about POE sessions and events

=head1 VERSION

Version 0.001

=head1 SYNOPSIS

Load the module as any other POE plugin:

    use POE qw< Devel::Top >;

    POE::Devel::Top->spawn;

Load the module from the command line:

    perl -MPOE::Devel::Top ...


=head1 DESCRIPTION

This module displays information about the sessions and events handled
by the current POE kernel, mimicking the well-known B<top(1)> system
utility.

In this early version, it only prints the information on C<STDOUT>.


=head1 METHODS

=head2 spawn()

Create the internal session that prints the information on screen.


=head1 AUTHOR

SE<eacute>bastien Aperghis-Tramoni C<< <sebastien at aperghis.net> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-poe-devel-top at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=POE-Devel-Top>.
I will be notified, and then you'll automatically be notified of
progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc POE::Devel::Top

You can also look for information at:

=over

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/Public/Dist/Display.html?Dist=POE-Devel-Top>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/POE-Devel-Top>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/POE-Devel-Top>

=item * Search CPAN

L<http://search.cpan.org/dist/POE-Devel-Top>

=back


=head1 ACKNOWLEDGEMENTS

Rocco Caputo and the numerous people who contributed to POE.

Matt Cashner (sungo) for C<POE::API::Peek>.

Apocalypse and Chris Williams (BinGOs) for helping me on the C<#poe>
IRC channel.


=head1 COPYRIGHT & LICENSE

Copyright 2010 SE<eacute>bastien Aperghis-Tramoni, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
