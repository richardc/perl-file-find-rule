# dummy package for benching
use strict;
package File::Find::Rule::Tweaked;
use base 'File::Find::Rule';

sub size {
    my $self = File::Find::Rule::_force_object shift;

    my @tests = map { Number::Compare->new($_) } @_;

    my $index = 7;
    push @{ $self->{rules} }, {
        rule => 'size',
        args => \@_,
        code => sub {
            my $value = (stat $_)[$index] || 0;
            for my $test (@tests) {
                return 1 if $test->($value);
            }
            return 0;
        },
    };

#    print "foo\n";
    $self;
}

1;
