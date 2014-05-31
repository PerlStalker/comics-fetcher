package Comics::Fetcher;
use Moose;
use MooseX::Method::Signatures;

use LWP::UserAgent;
use URI;
use DateTime;
use Try::Tiny;

with 'MooseX::Object::Pluggable';

our $VERSION = '0.03';

has 'feed_dir' => (
    documentation => 'Directory to save generated pages and feeds',
    is            => 'rw',
    isa           => 'Str',
    lazy_build    => 1,
    );

has 'base_uri' => (
    documentation => 'Base URI of generated pages and feeds',
    is            => 'rw',
    isa           => 'Str',
    lazy_build    => 1,
    );

has 'image_dir' => (
    documentation => 'Directory to save fetched images',
    is            => 'rw',
    isa           => 'Str',
    lazy_build    => 1,
    );

has 'log' => (
    documentation => 'Log dispatch',
    is            => 'rw',
    isa           => 'Log::Dispatch',
    required      => 1,
    );

has 'config' => (
    documentation => 'Configuration',
    is            => 'rw',
    isa           => 'Config::IniFiles',
    required      => 1,
    );

has 'ua' => (
    documentation => 'User agent',
    is            => 'rw',
    isa           => 'LWP::UserAgent',
    lazy_build    => 1,
    );

has '_date' => (
    documentation => 'Date',
    is            => 'rw',
    isa           => 'DateTime',
    lazy_build    => 1,
    );

method _build_feed_dir {
    if ($self->config->val('_config', 'feed_dir')) {
	return $self->config->val('_config', 'feed_dir');
    }
    else {
	die "feed_dir not set\n";
    }
}

method _build_base_uri {
    if ($self->config->val('_config', 'base_uri')) {
	return $self->config->val('_config', 'base_uri');
    }
    # backwards compatability with early versions
    elsif ($self->config->val('_config', 'feed_uri')) {
	return $self->config->val('_config', 'feed_uri');
    }
    else {
	die "base_uri not set\n";
    }
}

method _build_image_dir {
    if ($self->config->val('_config', 'image_dir')) {
	return $self->config->val('_config', 'image_dir');
    }
    else {
	die "image_dir not set\n";
    }
}

method _build_ua {
    my $ua = LWP::UserAgent->new;
    $ua->agent($self->config->val('_config', 'agent') || "fetcher/$VERSION");
    # TODO: set useragent, etc.
    return $ua;
}

method _build__date {
    my $zone = $self->config->val('_config', 'timezone') || 'UTC';
    return DateTime->now(time_zone => $zone);
}

method generic (Str :$name!) {

    # if (-e $self->image_dir."/$image_file") {
    # 	$self->log->info($self->image_dir."/$image_file exists. Skipping");
    # 	return undef;
    # }

    my $img_url;

    if (defined $self->config->val($name, 'img_uri')) {
	$img_url = $self->config->val($name, 'img_host') if $self->config->val($name, 'img_host');
	try {
	    my $date = $self->_date;
	    my $uri = $self->config->val($name, 'img_uri');
	    $img_url .= eval "$uri";
	}
	catch {
	    die "Unable to generate img_url for $name: $_\n";
	};
	$self->log->debug("img_url: '$img_url'\n");
    }
    elsif (defined $self->config->val($name, 'page')
	   and defined $self->config->val($name, 'img_pattern')) {
	my $url = URI->new($self->config->val($name, 'page'));

	my $req = HTTP::Request->new;
	$req->method('GET');
	$req->uri($url);

	my $page = $self->ua->request($req);
	my $content = $page->content;

	my $pattern = $self->config->val($name, 'img_pattern');
	if ($page->is_success
	    and $content
	    ) {
	    my $img_src = '';
	    if ($self->config->val($name, 'get_title')) {
		if ($content =~ m!<img[^>]*src\s*=\s*['"]?.*($pattern)["']?.*title=['"](.*?)['"]!is) {
		    $img_src  = $1;

		    my $title = $2;
		    if ($title) {
			my $title_file = $self->_gen_output_file(
			    name => $name,
			    ext  => 'title'
			    );
			open (my $file, '>',
			      $self->config->val('_config', 'image_dir').$title_file)
			    or die "Unable to open $title_file: $!\n";
			print $file $title;
			close $file;
		    }
		}
	    }
	    else {
		if ($content =~ m!<img[^>]*src\s*=\s*['"]?.*($pattern)["']?!is) {
		    $img_src = $1;
		}
	    }

	    if ($self->config->val($name, 'img_host')) {
		$img_url = $self->config->val($name, 'img_host').$img_src;
	    }
	    else {
		$img_url = $img_src;
	    }
	}
    }

    if (not defined $img_url) {
	die "Couldn't get img url for $name\n";
    }

    $self->log->debug("img url: $img_url\n");

    my $ext;
    if ($self->config->val($name, 'img_ext')) {
	$ext = $self->config->val($name, 'img_ext');
    } else {
	$img_url =~ /\.(\w+)$/;
	$ext = $1;
    }

    my $image_file = $self->_gen_output_file(
	name => $name,
	ext  => $ext,
	);

    $self->_fetch_image(
	image_url   => $img_url,
	referer     => $self->config->val($name, 'page'),
	output_file => $image_file,
	);

    return { url => $img_url, output_file => $image_file };
}

method _fetch_image (
    Str :$image_url,
    Str :$referer,
    Str :$output_file
    ) {

    my $url = URI->new($image_url);
    my $req = HTTP::Request->new;
    $req->header('Referer' => $referer);
    $req->method('GET');
    $req->uri($url);

    my $tmp_file = $self->config->val('_config', 'image_dir')."/tmp-$output_file";

    my $image = $self->ua->request($req);
    my $content = $image->content;
    if ($content and open (IMG, '>', $tmp_file)) {
	print IMG $content;
	close IMG;
    }

    rename $tmp_file, $self->config->val('_config', 'image_dir')."/$output_file";
}

method _gen_output_file (
    Str :$name!,
    Str :$ext!
    ) {
    my $image_file = sprintf(
	"%s%04d%02d%02d.%s",
	$name,
	$self->_date->year,
	$self->_date->month,
	$self->_date->day,
	$ext,
	);
};

__PACKAGE__->meta->make_immutable;
1;
