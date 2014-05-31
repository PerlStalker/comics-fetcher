#!/usr/bin/perl
use warnings;
use strict;

use Module::Build;

my $build = Module::Build->new(
    module_name => 'Comics::Fetcher',
    author => [ 'Randall Smith <perlstalker@vuser.org>' ],
    dist_abstract => 'Daily image fetcher',
    license     => 'perl',
    requires => {
	'perl'                       => '5.10.0',
	'Config::IniFiles'           => '0',
	'Log::Dispatch'              => '0',
	'Log::Dispatch::Screen'      => '0',
	'Log::Dispatch::Syslog'      => '0',
	'Try::Tiny'                  => '0',
	'XML::FeedPP'                => '0',
	'Data::Dumper'               => '0',
	'Time::Local'                => '0',
	'DateTime'                   => '0',
	'Template'                   => '0',
	'LWP::UserAgent'             => '0',
	'URI'                        => '0',
	'Moose'                      => '0',
	'MooseX::Object::Pluggable'  => '0',
	'MooseX::Method::Signatures' => '0',
    },
    resources => {
	homepage    => 'http://comics-fetcher.googlecode.com/',
	bugtracker  => {
	    web => 'http://code.google.com/p/comics-fetcher/issues/list',
	},
	repository  => {
	    web  => 'http://code.google.com/p/comics-fetcher/source/checkout',
	    url  => 'https://comics-fetcher.googlecode.com/hg/',
	    type => 'hg',
	},
    },
    );

$build->create_build_script;
