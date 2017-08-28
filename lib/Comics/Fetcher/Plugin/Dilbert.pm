package Comics::Fetcher::Plugin::Dilbert;
use Moose::Role;
use MooseX::Method::Signatures;

use POSIX qw(strftime);

method dilbert (Str :$name) {
    my $url = URI->new($self->config->val($name, 'page'));

    my $req = HTTP::Request->new;
    $req->method('GET');
    $req->uri($url);

    $self->log->debug('Fetching from: '.$self->config->val($name, 'page')."\n");

    my $page = $self->ua->request($req);
    my $content = $page->content;

    #<div class="comic-item-container js_comic_container_2017-08-27" itemType="http://schema.org/CreativeWork" accountablePerson="Universal Uclick" creator="Scott Adams" data-itemtype="" data-id="2017-08-27" data-url="http://dilbert.com/strip/2017-08-27" data-image="http://assets.amuniversal.com/950edc6043ff0135d84c005056a9545d"
    
    my $date = sprintf("%04d-%02d-%02d",
		       $self->_date->year,
		       $self->_date->month,
		       $self->_date->day
	);
    
    my $img_src = '';
    if ($page->is_success and $content) {
	my $pattern = qr{<div class="comic-item-container js_comic_container_$date" itemType="http://schema.org/CreativeWork" accountablePerson="Universal Uclick" creator="Scott Adams" data-itemtype="" data-id="([^"]+)" data-url="([^"]+)" data-image="([^"]+)"};
	$self->log->debug("pattern: $pattern\n");
	if ($content =~ m|$pattern|ix) {
	    $img_src = $3;
	}
	else {
	    die "image_src not found: ".($page->is_success? 1 : 0)."\n";	
	}
    }  

    $self->log->debug("Dilbert img_src: '$img_src'\n");

    my $image_file = $self->_gen_output_file(
	name => $name,
	ext  => $self->config->val($name, 'img_ext') || 'jpg',
	);

    $self->_fetch_image(
	image_url   => $img_src,
	referer     => $self->config->val($name, 'page'),
	output_file => $image_file,
	);

    return { url => $img_src, output_file => $image_file };

}

1;
