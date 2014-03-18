#!/usr/bin/env perl
use JSON;
use 5.010;
use Data::Dumper;
use HTTP::Request;
use LWP::UserAgent;
use URI::Escape qw(uri_escape);

my $session = LWP::UserAgent->new;
my $token = get_token();
my $api_base = 'https://api.weibo.com';

#my $update_res = $session->get("${api_base}/2/statuses/update.json?status=${token}");

sub get_mention {
    my $mention_res = $session->get("${api_base}/2/statuses/mentions.json?access_token=${token}");
    if ( $mention_res->is_success ) {
        my $statuses = ( decode_json $mention_res->decoded_content )->{'statuses'};
        my $regexstr = q(#cpan#);
        for my $status ( @{ $statuses } ) {
            my $mid = $status->{'id'};
            my $msg = $status->{'text'};
            if ( $msg =~ s{$regexstr}{}i ) {
                my $ret = uri_escape(mcpan_query($msg));
                my $create_res = $session->get("${api_base}/2/comments/create.json?access_token=${token}&id=${mid}&comment=${ret}");
                if ( $create_res->is_success and ! ( decode_json $create_res->decoded_content )->{'error'} ) {
                    say "Create Comments OK!";
                } elsif ( ( decode_json $create_res->decoded_content )->{'error_code'} > 10000 ) {
                    say $create_res->decoded_content;
                } else {
                    say "Create Comments ", $create_res->status_line;
                }
            }
        }
    }
    else {
        say 'status mention ', $mention_res->status_line;
    };
}

sub get_token {
    # expires_at 1552837654
    return '2.00kSQGIB1Q6J9C3d32741bbe0nTc2Q';
}

sub mcpan_query {
    my $modulename = shift;
    my $ua = LWP::UserAgent->new;
    my $req = HTTP::Request->new( 'POST', "http://api.metacpan.org/v0/module/_search" );
    $req->header( 'Content-Type' => 'application/json' );
    $req->content(encode_json({
        query => {
            query_string => { query => $modulename, }
        },
        filter => {
            term => { status => 'latest', }
        },
        fields => [ 'release', 'author' ],
    }));
    my $res = $ua->request( $req );
    return $res->status_line unless $res->is_success;
    my $json = $res->decoded_content;
    my $hits = decode_json $json;
    my @url = keys { map { 'https://metacpan.org/release/' . $_->{fields}->{author} . '/' . $_->{fields}->{release} => 1 } @{ $hits->{hits}->{hits} } };
    say "get $#url result from mcpan\n";
    my $short_url = shorten(\@url);
    return join ' ', @$short_url;
}

sub shorten {
    my $url = shift;
    my $shorten_res = $session->get( "${api_base}/2/short_url/shorten.json?access_token=${token}&url_long=" . join('&url_long=', @{$url}) );
    if ( $shorten_res->is_success ) {
        my $urls = ( decode_json $shorten_res->decoded_content )->{'urls'};
        my @short_url = map { $_->{url_short} } @{$urls};
        return \@short_url;
    } else {
        say $shorten_res->status_line;
    }
}

say for mcpan_query('dancer');
