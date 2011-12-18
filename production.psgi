#!/usr/bin/env perl

use strict;
use warnings;
use lib 'lib';

use Act::Dispatcher;
use Plack::Builder;
use Plack::App::Directory;

builder {
    enable 'Session::Cookie';
    enable "SimpleLogger", level => "warn";
    enable 'ReverseProxy';
    Act::Dispatcher->to_app;
};
