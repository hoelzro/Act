use strict;
package Act::Dispatcher;

use Encode qw(decode_utf8);
use Plack::Builder;
use Plack::Request;
use Plack::App::Cascade;
use Plack::App::File;

use Act::Config;
use Act::Handler::Static;
use Act::Util;
use Act::Middleware::Language;

# main dispatch table
my %public_handlers = (
    api             => 'Act::Handler::WebAPI',
    atom            => 'Act::Handler::News::Atom',
    auth_methods    => 'Act::Handler::AuthMethods',
    changepwd       => 'Act::Handler::User::ChangePassword',
    event           => 'Act::Handler::Event::Show',
    events          => 'Act::Handler::Event::List',
    faces           => 'Act::Handler::User::Faces',
    favtalks        => 'Act::Handler::Talk::Favorites',
    list_by_room    => 'Act::Handler::Talk::ListByRoom',
    login           => 'Act::Handler::Login',
    news            => 'Act::Handler::News::List',
    openid          => 'Act::Handler::OpenID',
    proceedings     => 'Act::Handler::Talk::Proceedings',
    register        => 'Act::Handler::User::Register',
    schedule        => 'Act::Handler::Talk::Schedule',
    search          => 'Act::Handler::User::Search',
    stats           => 'Act::Handler::User::Stats',
    talk            => 'Act::Handler::Talk::Show',
    talks           => 'Act::Handler::Talk::List',
    'timetable.ics' => 'Act::Handler::Talk::ExportIcal',
    user            => 'Act::Handler::User::Show',
    wiki            => 'Act::Handler::Wiki',
);
my %private_handlers = (
    change          => 'Act::Handler::User::Change',
    create          => 'Act::Handler::User::Create',
    csv             => 'Act::Handler::CSV',
    confirm_attend  => 'Act::Handler::User::ConfirmAttendance',
    editevent       => 'Act::Handler::Event::Edit',
    edittalk        => 'Act::Handler::Talk::Edit',
    confirmtalk     => 'Act::Handler::Talk::Confirm',
    export          => 'Act::Handler::User::Export',
    export_talks    => 'Act::Handler::Talk::ExportCSV',
    ical_import     => 'Act::Handler::Talk::Import',
    invoice         => 'Act::Handler::Payment::Invoice',
    logout          => 'Act::Handler::Logout',
    main            => 'Act::Handler::User::Main',
    myschedule      => 'Act::Handler::Talk::MySchedule',
    'myschedule.ics'=> 'Act::Handler::Talk::ExportMyIcal',
    newevent        => 'Act::Handler::Event::Edit',
    newsadmin       => 'Act::Handler::News::Admin',
    newsedit        => 'Act::Handler::News::Edit',
    newtalk         => 'Act::Handler::Talk::Edit',
    orders          => 'Act::Handler::User::Orders',
    openid_trust    => 'Act::Handler::OpenID::Trust',
    payment         => 'Act::Handler::Payment::Edit',
    payments        => 'Act::Handler::Payment::List',
    photo           => 'Act::Handler::User::Photo',
    punregister     => 'Act::Handler::Payment::Unregister',
    purchase        => 'Act::Handler::User::Purchase',
    rights          => 'Act::Handler::User::Rights',
    trackedit       => 'Act::Handler::Track::Edit',
    tracks          => 'Act::Handler::Track::List',
    updatemytalks   => 'Act::Handler::User::UpdateMyTalks',
    updatemytalks_a => 'Act::Handler::User::UpdateMyTalks::ajax_handler',
    unregister      => 'Act::Handler::User::Unregister',
    wikiedit        => 'Act::Handler::WikiEdit',
);

sub to_app {
    Act::Config::reload_configs();
    my $app = builder {
        enable sub {
            my $app = shift;
            sub {
                my $env = shift;
                my $req = Plack::Request->new($env);
                $env->{'act.base_url'} = $req->base->as_string;
                $env->{'act.base_url'} =~ s/\/$//;
                $app->($env);
            };
        };
        my $first_conf;
        my %confr = %{ $Config->uris }, map { $_ => $_ } %{ $Config->conferences };
        for my $uri ( sort keys %confr ) {
            my $conf_app = conference_app($confr{$uri});
            $first_conf ||= $conf_app;
            mount "/$uri/" => $conf_app;
        }
        mount '/' => $first_conf
            || sub { [404, ['Content-Type' => 'text/plain'], ['no conferences configured']] };
    };
    return $app;
}

sub conference_app {
    my $conference = shift;
    my $config = Act::Config::get_config($conference);

    my $static_app = Act::Handler::Static->new;

    my $app = Plack::App::Cascade->new( catch => [99], apps => [
        sub {
            $_[0]->{'PATH_INFO'} =~ /\.html?$/ && goto &$static_app;
            return [99, [], []];
        },
        builder {
            enable '+Act::Middleware::Auth';
            for my $uri ( keys %public_handlers ) {
                mount "/$uri" => _handler_app($public_handlers{$uri});
            }
            mount '/' => sub { [99, [], []] };
        },
        builder {
            enable '+Act::Middleware::Auth', private => 1;
            for my $uri ( keys %private_handlers ) {
                mount "/$uri" => _handler_app($private_handlers{$uri});
            }
            mount '/' => sub { [99, [], []] };
        },
        Plack::App::File->new(root => $config->general_root)->to_app,
    ] );
    $app = Act::Middleware::Language->wrap($app);
    return sub {
        $_[0]->{'act.conference'} = $conference;
        $_[0]->{'act.config'} = my $config = Act::Config::get_config($conference);
        $_[0]->{'act.dbh'} = Act::Util::db_connect();
        $_[0]->{'act.conf_base_url'} = $_[0]->{'SCRIPT_NAME'};
        $_[0]->{'PATH_INFO'} =~ s{^/?$}{ '/' . $config->general_default_page }e;
        goto &$app;
    };
}

sub _handler_app {
    my $handler = shift;
    my $subhandler;
    if ($handler =~ s/::(\w*handler)$//) {
        $subhandler = $1;
    }
    _load($handler);
    my $app = $handler->new(subhandler => $subhandler);

    if($ENV{'ACTDEBUG'}) {
        return sub {
            my ( $env ) = @_;

            my $errors = $env->{'psgi.errors'};
            $errors->print("Dispatching to $handler\n");

            return $app->($env);
        };
    } else {
        return $app;
    }
}

sub _load {
    my $package = shift;
    (my $module = "$package.pm") =~ s{::|'}{/}g;
    require $module;
}

1;
__END__

=head1 NAME

Act::Dispatcher - Dispatch web request

=head1 SYNOPSIS

No user-serviceable parts. Warranty void if open.

=cut
