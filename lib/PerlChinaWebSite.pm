package PerlChinaWebSite;
use Dancer ':syntax';
use Dancer::Plugin::Database;
use Dancer::Plugin::Ajax;
use List::MoreUtils qw(natatime);
use Web::Query;
use Data::Dumper;
use File::Temp qw(tempfile);
use IPC::Run qw(run timeout);
use Encode qw(decode encode);

our $VERSION = '0.1';

get '/' => sub {
    template 'index', {
        lq => latest_question(),
        lw => latest_weekly(),
        lb => latest_blog(),
    };
};

ajax '/run' => sub {
    my ($in, $out, $err);
    my $code = param('code');
    my @cmd = qw(docker run -v /tmp/:/tmp:ro ubuntu:perl-tour perl);
    my ($fh, $temp) = tempfile();
    binmode($fh, ':utf8');
    print $fh $code;
    push @cmd, $temp;
    run \@cmd, \$in, \$out, \$err, timeout(10) or debug($?);
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
#        $q->find('#'.$want)->parent->find('a')->each(sub {
#            my ($k, $v) = @_;
#            push @ret, {
#                text => $v->text,
#                href => $v->attr('href'),
#                desc => $v->parent->parent->find('p')->last->text,
#            };
#        });
        push @ret, $q->find("#$want")->parent->as_html;
    };
    return \@ret;
};

true;
