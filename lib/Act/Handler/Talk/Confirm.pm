package Act::Handler::Talk::Confirm;

use strict;
use parent 'Act::Handler';
use Act::Handler::Talk::Edit;

use Act::Config;
use Act::Talk;

sub handler {
    if (exists $Request{args}{talk_id}) {
        my $talk = Act::Talk->new(
            talk_id   => $Request{args}{talk_id},
            conf_id   => $Request{conference},
        );
        unless ($talk) {
            # cannot edit non-existent talk
            $Request{status} = 404;
            return;
        }
        $talk->update( confirmed => 1 )
	    if $talk->user_id == $Request{user}->user_id;
    }

    return Act::Handler::Talk::Edit::handler(@_);
}

1;

=head1 NAME

Act::Handler::Talk::Confirm - Confirm a talk in the Act database

=head1 SYNOPSIS

setup submit data with confirm = 1; forward to ..::Talk::Edit

=head1 DESCRIPTION

See F<DEVDOC> for a complete discussion on handlers.

=cut
