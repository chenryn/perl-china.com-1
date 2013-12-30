use DBI;
use DBD::mysql;
use Template;
use List::MoreUtils qw/natatime/;
use Data::Dumper;

my $tokens = { lb => latest_blog() };
my $tt = Template->new(
    START_TAG => '<%',
    END_TAG => '%>',
);
$tt->process('t/new.tt', $tokens) or die $tt->error;


sub latest_blog {
    my $sql = "select post_title,id from wp_posts where post_type='post' order by id desc limit 9";
    my $dbh = DBI->connect("DBI:mysql:database=blog;socket=/var/run/mysqld/mysqld.sock","root","",{'RaiseError'=>1});
    $dbh->do('SET NAMES utf8');
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


__DATA__
<% FOREACH tr IN lb %>
      <tr>
<% FOREACH td IN tr %>
        <td><span class="glyphicon glyphicon-pencil"></span> <a href="http://blogs.perl-china.com/?p=<% td.id %>"><% td.post_title %></a></td>
<% END %>
      </tr>
<% END %>
