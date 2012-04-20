package Act::Middleware::Language;
use strict;
use warnings;

use parent qw(Plack::Middleware);
use Plack::Request;
use Act::Config ();

sub call {
    my $self = shift;
    my $env = shift;
    my $req = Plack::Request->new($env);

    my $config = $env->{'act.config'};
    my $langs = $config->languages;

    my $language;

    # failsafe
    $env->{'psgix.session'}->{'act'} = {} unless exists $env->{'psgix.session'}->{'act'};

    # check session
    my $s = $env->{'psgix.session'}{'act'};
    if ($s && $s->{language} && $langs->{$s->{language}}) {
        $language = $s->{language};
    }

    # override in query string
    # redirect the user to remove the language query param
    my $force_language = $req->param('language');
    if ($force_language && $langs->{$force_language} ) {
        $language = $s->{language} = $force_language;

        my $uri = $req->uri;
        my @query = $uri->query_form;
        for (my $i; $i < @query; $i+=2 ) {
            if ($query[$i] eq 'language') {
                splice @query, $i, 2;
            }
        }
        $uri->query_form(\@query);
        my $resp = Plack::Response->new;
        $resp->redirect($uri->as_string);
        return $resp->finalize;
    }

    # otherwise try one of the browser's languages
    unless ($language) {
        eval {
            $req->headers->scan(sub {
                my ($k, $v) = @_;
                return
                    unless $k eq 'Accept-Language';
                $v =~ s/;.*$//;
                $v =~ s/-.*$//;
                if ($v && $langs->{$v}) {
                    $language = $s->{language} = $v;
                    die [];
                }
            });
        };
    }

    # last resort, use our default language
    $language ||= $config->general_default_language;

    # use optional variant
    $language = $config->language_variants->{$language} || $language;

    # remember it for this request
    $env->{'act.language'} = $language;

    # make sure whatever was picked last, it stays in the session
    $s->{'language'} = $language;

    # fetch localization handle
    $env->{'act.loc'} = Act::I18N->get_handle($language);

    # finalize the config now that we have the language
    Act::Config::finalize_config($config, $language);

    $self->app->($env);
}

1;
