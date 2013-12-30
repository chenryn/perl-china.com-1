use Web::Query;
use Data::Dumper;
use warnings;
use strict;

latest_weekly();

sub latest_weekly {
    my $q = wq('http://perlweekly.com/latest.html');
    my @ret;
    for my $want ( qw/announcements articles code videos/ ) {
#        $q->find('#'.$want)->parent->find('a')->each(sub {
#            my ($k, $v) = @_;
#            push @ret, {
#                text => $v->text,
#                href => $v->attr('href'),
#                desc => $v->parent->parent->find('p')->last->text,
#            };
#        });
        #push @ret, $q->first("#$want")->parent->html;
        print $q->find("#$want")->parent->as_html;
        exit
    };
    return \@ret;
};
