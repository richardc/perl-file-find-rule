# dummy package for benching
use strict;
package File::Find::Rule::Tweaked;
use base 'File::Find::Rule';

my @testnames = qw( dev ino mode nlink uid gid rdev
                      size atime mtime ctime blksize blocks );

sub size {
    my $self = File::Find::Rule::_force_object shift;

    my @tests = map { Number::Compare->new($_) } @_;

    my $index = 7;
    push @{ $self->{rules} }, {
        rule => 'size',
        args => \@_,
        code => sub {
            unless ($self->{_data}{stat}) {
                @{$self->{_data}{stat}}{@testnames} = stat $_;
            }
            my $value = $self->{_data}{stat}{'size'} || 0;
            for my $test (@tests) {
                return 1 if $test->($value);
            }
            return 0;
        },
    };

#    print "foo\n";
    $self;
}

sub in {
    my $self = shift;

    delete $self->{_data};
    $self->SUPER::in(@_);
}

1;
