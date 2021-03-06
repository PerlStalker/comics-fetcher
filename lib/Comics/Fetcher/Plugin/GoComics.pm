package Comics::Fetcher::Plugin::GoComics;
use Moose::Role;
use MooseX::Method::Signatures;

method gocomics (Str :$name) {
    my $today_url = sprintf(
	"%s/%04d/%02d/%02d",
	$self->config->val($name, 'page'),
	$self->_date->year,
	$self->_date->month,
	$self->_date->day
	);
			    
    my $url = URI->new($today_url);

    my $req = HTTP::Request->new;
    $req->method('GET');
    $req->uri($url);

    $self->log->debug('Fetching from: '.$self->config->val($name, 'page')."\n");

    my $page = $self->ua->request($req);
    my $content = $page->content;

    # $self->log->debug('Success: '.($page->is_success ? 1: 0)." content: $content\n");

    my $img_src = '';
    if ($page->is_success and $content) {
	#if ($content =~ m!<img.*?class="strip".*?src="([^"]+)"!is) {
	if ($content =~ m!<picture.*?class="[^"]*item-comic-image".*?src="([^"]+)".*?</picture>!is) {
	    $img_src = $1;
	}
    }
    else {
	die "image_src not found: ".($page->is_success ? 1: 0)." $content\n";
    }

    $self->log->debug("GoComics img_src: '$img_src'\n");

    my $image_file = $self->_gen_output_file(
	name => $name,
	ext  => $self->config->val($name, 'img_ext') || 'gif',
	);

    $self->_fetch_image(
	image_url   => $img_src,
	referer     => $self->config->val($name, 'page'),
	output_file => $image_file,
	);

    return { url => $img_src, output_file => $image_file };
}

1;
