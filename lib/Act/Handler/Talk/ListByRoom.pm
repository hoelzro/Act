package Act::Handler::Talk::ListByRoom;
use strict;
use parent 'Act::Handler';
use Act::Config;
use Act::Template::HTML;
use Act::Tag;
use Act::Talk;
use Act::Track;
use Act::Util;
use Act::Handler::Talk::Util;

sub handler
{
    my ($talks, $date_raw, $room, $date);

    # searching by date/room
    if ($Request{path_info}) {
        ($date_raw, $room) = split '/', $Request{path_info};

        if( my ($year, $month, $day) = $date_raw
            =~ /\A (\d{4}) (\d{2}) (\d{2}) \z/x ){
            $date = DateTime->new(
                day   => $day,
                month => $month,
                year  => $year,
            );

            $talks = Act::Talk->get_talks(
                date     => $date,
                room     => $room,
                accepted => 1,
                type     => 'talk',
                conf_id  => $Request{conference},
            );
        }
    }
    # retrieve talks and speaker info
    $talks ||= Act::Talk->get_talks( conf_id => $Request{conference} );
    my $talks_total = scalar @$talks;
    $_->{user} = Act::User->new( user_id => $_->user_id ) for @$talks;

    # sort talks
    $talks = [
        map  { $$_[0] }
        sort { DateTime->compare( $$a[1], $$b[1] ) }
        map  {[ $_, $_->datetime ]}
        @$talks
    ];

    # process the template
    my $template = Act::Template::HTML->new();
    $template->variables(
        talks          => $talks,
        talks_total    => $talks_total,
        talks_accepted => $talks_total,
        room           => $room,
        date           => $date,
    ); 
    $template->process('talk/list_by_room');
    return;
}

1;
__END__

=head1 NAME

Act::Handler::User::ListByRoom - show talks for a room

=head1 DESCRIPTION

See F<DEVDOC> for a complete discussion on handlers.

=cut
