package PerlChinaWebSite;
use Dancer ':syntax';
use Dancer::Plugin::Ajax;
use Dancer::Plugin::Database;
use Dancer::Plugin::Deferred;
use Net::OAuth2::Client;
use List::MoreUtils qw(natatime);
use Web::Query;
use Data::Dumper;
use File::Temp qw(tempfile);
use IPC::Run qw(start harness timeout);
use Encode qw(decode encode);
use JSON qw(decode_json);

our $VERSION = '0.1';

Dancer::Session::Abstract->attributes( qw/user/ );

get '/' => sub {
    template 'index', {
        lq => latest_question(),
        lw => latest_weekly(),
        lb => latest_blog(),
    };
};

get '/user/login' => sub {
    redirect &client->authorize;
};

get '/user/profile' => sub {
    my $user;
    my $session = &client->get_access_token(params->{code});
    deferred error => $session->error_description if $session->error;
    my $uid_res = $session->get('/2/account/get_uid.json');
    if ( $uid_res->is_success ) {
        my $uid = (decode_json $uid_res->decoded_content)->{'uid'};
        my $ushow_res = $session->get("/2/users/show.json?uid=${uid}");
        if ( $ushow_res->is_success ) {
            $user = decode_json $ushow_res->decoded_content;
            session user => { name => $user->{'name'}, hdimg => $user->{'profile_image_url'} };
            deferred success => sprintf "Welcome back, %s", session('user')->{name};
            template 'profile', { user => $user };
        } else {
            deferred error => $ushow_res->status_line . "uid $uid show";
            redirect '/';
        }
    } else {
        deferred error => $uid_res->status_line . 'get_uid';
        redirect '/';
    };
};

get '/user/logout' => sub {
    my $user= session('user')->{name};
    session user => undef;
    deferred success => sprintf "Goodbye, %s", $user;
    redirect '/';
};

ajax '/run' => sub {
    my ($in, $out, $err);
    my $code = param('code');
    my @cmd = qw(docker run -m 128m -v /tmp/:/tmp:ro -u www pcws /run.sh);
    my ($fh, $temp) = tempfile();
    binmode($fh, ':utf8');
    print $fh $code;
    chmod '0644', $temp;
    push @cmd, $temp;
    my $h;
    eval {
        $h = harness \@cmd, \$in, \$out, \$err, ( my $t = timeout 10 );
        start $h;
        $h->finish;
    };
    if ($@) {
        my $x = $@;
        $h->kill_kill;
        return $x;
    };
    unlink $temp;
    return to_json({
        Errors => [ split(/\n/, decode('utf8', $err)) ],
        Events => [ split(/\n/, decode('utf8', $out)) ],
    });
};

sub latest_blog {
    my $sql = "select post_title,id from wp_posts where post_type='post' order by id desc limit 9";
    my $dbh = database('blog');
    my $sth = $dbh->prepare($sql);
    $sth->execute();
    my (@res, @ret);
    while (my $ref = $sth->fetchrow_hashref) {
        push @res, $ref;
    };
    my $it = natatime 3, @res;
    while ( my @vals = $it->() ) {
        push @ret, \@vals;
    }
    return \@ret;
};

sub latest_question {
    my $sql = "select t.id,u.nickname,t.title,t.created_at,t.comments_count from topics t join users u on t.user_id=u.id order by t.id desc limit 10";
    my $sth = database('rabel_production')->prepare($sql);
    $sth->execute();
    my @ret;
    while (my $ref = $sth->fetchrow_hashref) {
        push @ret, $ref;
    };
    return \@ret;
};

sub latest_weekly {
    my $q = wq('http://perlweekly.com/latest.html');
    my @ret;
    for my $want ( qw(announcements articles code fun videos) ) {
        eval { push @ret, $q->find("#$want")->parent->as_html };
    };
    return \@ret;
};

sub client {
    Net::OAuth2::Profile::WebServer->new(
        name                => 'weibo',
        site                => 'https://api.weibo.com',
        client_id           => config->{app_key},
        client_secret       => config->{app_secret},
        authorize_path      => '/oauth2/authorize',
        access_token_path   => '/oauth2/access_token',
        access_token_method => 'POST',
        token_scheme        => 'uri-query:access_token',
        redirect_uri        => uri_for('/user/profile'),
    );
};

true;
