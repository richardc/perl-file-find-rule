#       $Id$

package File::Find::Rule;
use strict;
use vars qw/$VERSION @ISA @EXPORT $AUTOLOAD/;
use Exporter;
use File::Spec;
use Text::Glob 'glob_to_regex';
use Number::Compare;
use Carp qw/croak/;
use File::Find (); # we're only wrapping for now
use Cwd;           # 5.00503s File::Find goes screwy with max_depth == 0

$VERSION = 0.08;
@ISA = 'Exporter';
@EXPORT = qw( find rule );

=head1 NAME

File::Find::Rule - Alternative interface to File::Find

=head1 SYNOPSIS

  use File::Find::Rule;
  # find all the subdirectories of a given directory
  my @subdirs = File::Find::Rule->directory->in( $directory );

  # find all the .pm files in @INC
  my @files = File::Find::Rule->file()
                              ->name( '*.pm' )
                              ->in( @INC );

  # as above, but without method chaining
  my $rule =  File::Find::Rule->new;
  $rule->file;
  $rule->name( '*.pm' );
  my @files = $rule->in( @INC );

  # all those arrows - circle the wagons! (the procedural interface)
  my @files = find(file => name => '*.pm', in => \@INC);

=head1 DESCRIPTION

File::Find::Rule is a friendlier interface to File::Find.  It allows
you to build rules which specify the desired files and directories.

=head2 Procedural interface

=over

=item C<find( @clauses )>

=item C<rule( @clauses )>

C<find> and C<rule> can be used to invoke any methods available to the
OO version.  C<rule> is a synonym for C<find>

Passing more than one value to a clause is done with an anonymous
array:

 my $finder = find( name => [ '*.mp3', '*.ogg' ] );

Returns an object, unless one of the arguments is C<in>, in which case
it returns a list of things that match the rule.

 my @files = find( name => [ '*.mp3', '*.ogg' ], in => $ENV{HOME} );

Please note that C<in> will be the last clause evaluated, and so this
code will search for mp3s regardless of size.

 my @files = find( name => '*.mp3', in => $ENV{HOME}, size => '<2k' );
                                                    ^
                                                    |
               Clause processing stopped here ------/

It is also possible to invert a single rule by prefixing it with C<!>
like so:

 # large files that aren't videos
 my @files = find( file    =>
                   '!name' => [ '*.avi', '*.mov' ],
                   size    => '>20M',
                   in      => $ENV{HOME} );

=cut

*rule = \&find;
sub find {
    my $object = __PACKAGE__->new();
    my $not = 0;

    while (@_) {
        my $method = shift;
        my @args;

        if ($method =~ s/^\!//) {
            # jinkies, we're really negating this
            unshift @_, $method;
            $not = 1;
            next;
        }
        unless (defined prototype $method) {
            my $args = shift;
            @args = ref $args eq 'ARRAY' ? @$args : $args;
        }
        if ($not) {
            $not = 0;
            @args = $object->new->$method(@args);
            $method = "not";
        }

        my @return = $object->$method(@args);
        return @return if $method eq 'in';
    }
    $object;
}

=back

=head1 METHODS

=over

=item C<new>

A constructor.  You need not invoke C<new> manually unless you wish
to, as each of the rule-making methods will auto-create a suitable
object if called as class methods.

=cut

sub new {
    my $referent = shift;
    my $class = ref $referent || $referent;
    bless { rules    => [],  # [0]
            iterator => [],
            maxdepth => undef,
            mindepth => undef,
            absolute => 0,
          }, $class;
}

sub _force_object {
    my $object = shift;
    $object = $object->new()
      unless ref $object;
    $object;
}

=back

=head2 Matching Rules

=over

=item C<name( @patterns )>

Specifies names that should match.  May be globs or regular
expressions.

 $set->name( '*.mp3', '*.ogg' ); # mp3s or oggs
 $set->name( qr/\.(mp3|ogg)$/ ); # the same as a regex
 $set->name( 'foo.bar' );        # just things named foo.bar

=cut

sub name {
    my $self = _force_object shift;
    my @names = map { ref $_ eq "Regexp" ? $_ : glob_to_regex $_ } @_;

    push @{ $self->{rules} },
      { rule => 'name',
        code =>
        sub {
            for my $name (@names) {
                return 1 if $_ =~ $name;
            }
            return 0;
        },
        args => \@_,
      };

    $self;
}

=item -X tests

Synonyms are provided for each of the -X tests. See L<perlfunc/-X> for
details.  None of these methods take arguments.

  Test | Method               Test |  Method
 ------|-------------        ------|----------------
   -r  |  readable             -R  |  r_readable
   -w  |  writeable            -W  |  r_writeable
   -w  |  writable             -W  |  r_writable
   -x  |  executable           -X  |  r_executable
   -o  |  owned                -O  |  r_owned
       |                           |
   -e  |  exists               -f  |  file
   -z  |  empty                -d  |  directory
   -s  |  nonempty             -l  |  symlink
       |                       -p  |  fifo
   -u  |  setuid               -S  |  socket
   -g  |  setgid               -b  |  block
   -k  |  sticky               -c  |  character
       |                       -t  |  tty
   -M  |  modified                 |
   -A  |  accessed             -T  |  ascii
   -C  |  changed              -B  |  binary

Though some tests are fairly meaningless as binary flags (C<modified>,
C<accessed>, C<changed>), they have been included for completeness.

 # find nonempty files
 $rule->file,
      ->nonempty;

=cut

{
    my %tests = (
                 -r  =>  readable           =>  -R  =>  r_readable      =>
                 -w  =>  writeable          =>  -W  =>  r_writeable     =>
                 -w  =>  writable           =>  -W  =>  r_writable      =>
                 -x  =>  executable         =>  -X  =>  r_executable    =>
                 -o  =>  owned              =>  -O  =>  r_owned         =>

                 -e  =>  exists             =>  -f  =>  file            =>
                 -z  =>  empty              =>  -d  =>  directory       =>
                 -s  =>  nonempty           =>  -l  =>  symlink         =>
                                            =>  -p  =>  fifo            =>
                 -u  =>  setuid             =>  -S  =>  socket          =>
                 -g  =>  setgid             =>  -b  =>  block           =>
                 -k  =>  sticky             =>  -c  =>  character       =>
                                            =>  -t  =>  tty             =>
                 -M  =>  modified                                       =>
                 -A  =>  accessed           =>  -T  =>  ascii           =>
                 -C  =>  changed            =>  -B  =>  binary          =>
                );

    # XXX - this may be better done lazily via AUTOLOAD
    for my $test (keys %tests) {
        my $sub = eval ' sub () {
            my $self = _force_object shift;
            push @{ $self->{rules} },
              {
                code => sub { ' . $test . ' $_ ? 1 : 0 },
                rule => "'.$tests{$test}.'",
               };
            $self;
        } ';
        no strict 'refs';
        *{ $tests{$test} } = $sub;
    }
}

=item stat tests

The following C<stat> based methods are provided: C<dev>, C<ino>,
C<mode>, C<nlink>, C<uid>, C<gid>, C<rdev>, C<size>, C<atime>,
C<mtime>, C<ctime>, C<blksize>, and C<blocks>.  See L<perlfunc/stat>
for details.

Each of these can take a number of targets, which will follow
L<Number::Compare> semantics.

 $rule->size( 7 );         # exactly 7
 $rule->size( ">7Ki" );    # larger than 7 * 1024 * 1024 bytes
 $rule->size( ">=7" )
      ->size( "<=90" );    # between 7 and 90, inclusive
 $rule->size( 7, 9, 42 );  # 7, 9 or 42

=cut

{
    my @tests = qw( dev ino mode nlink uid gid rdev
                    size atime mtime ctime blksize blocks );

    my $i = 0;
    for my $t (@tests) {
        my $index = $i; # needs to be here so it can be closed over
        my $sub = sub {
            my $self = _force_object shift;

            my @tests = map { Number::Compare->new($_) } @_;

            push @{ $self->{rules} },
              { rule => $t,
                args => \@_,
                code => sub {
                    my $value = (stat $_)[$index];
                    for my $test (@tests) {
                        return 1 if $test->($value);
                    }
                    return 0;
                },
              }
          };
        ++$i;
        no strict 'refs';
        *$t = $sub;
    }
}

=item C<any( @rules )>

=item C<or( @rules )>

Allows shortcircuiting boolean evaluation as an alternative to the
default and-like nature of combined rules.  C<any> and C<or> are
interchangeable.

 # find avis, movs, things over 200M and empty files
 $rule->any( find( name => [ '*.avi', '*.mov' ] ),
             find( size => '>200M' ),
             find( file => empty => ),
           );

=cut

sub any {
    my $self = _force_object shift;
    my @rulesets = @_;

    push @{ $self->{rules} },
      { rule => 'any',
        code => sub {
            for my $ruleset (@rulesets) {
                my $match = $ruleset->test(@_);
                return $match if $match || !defined $match;
            }
            return 0;
        },
        args => \@_,
      };
    $self;
}

*or = \&any;

=item C<none( @rules )>

=item C<not( @rules )>

Negates a rule.  (The inverse of C<any>.)  C<none> and C<not> are
interchangeable.

  # files that aren't 8.3 safe
  $rule->file
       ->not( $rule->new->name( qr/^[^.]{1,8}(\.[^.]{,3})?$/ ) );

=cut

sub not {
    my $self = _force_object shift;
    my @rulesets = @_;

    push @{ $self->{rules} },
      {
       rule => 'not',
       args => \@rulesets,
       code => sub {
           for my $ruleset (@rulesets) {
               my $match = $ruleset->test(@_);
               return 0 if $match || !defined $match;
           }
           return 1;
       },
      };
    $self;
}

*none = \&not;

=item C<prune>

Traverse no further.  This rule always matches.

=cut

sub prune () {
    my $self = _force_object shift;

    push @{ $self->{rules} },
      {
       rule => 'prune',
       code => sub { $File::Find::prune = 1 }
      };
    $self;
}

=item C<discard>

Don't keep this file.  This rule always matches.

=cut

sub discard () {
    my $self = _force_object shift;

    push @{ $self->{rules} },
      { rule => 'discard',
        code => sub {
            return;
        }
      };
    $self;
}

=item C<exec( \&subroutine( $shortname, $path, $fullname ) )>

Allows user-defined rules.  Your subroutine will be invoked with C<$_>
set to the current short name, and with parameters of the name, the
path you're in, and the full relative filename.

Return a true value if your rule matched.

 # get things with long names
 $rules->exec( sub { length > 20 } );

=cut

sub exec {
    my $self = _force_object shift;
    my $code = shift;

    push @{ $self->{rules} },
      { name => 'exec',
        code => sub { $code->(@_) ? 1 : 0 } };
    $self;
}

=item ->grep( @specifiers );

Opens a file and tests it each line at a time.

For each line it evaluates each of the specifiers, stopping at the
first successful match.  A specifier may be a regular expression or a
subroutine.  The subroutine will be invoked with the same parameters
as an ->exec subroutine.

It is possible to provide a set of negative specifiers by enclosing
them in anonymous arrays.  Should a negative specifier match the
iteration is aborted and the clause is failed.  For example:

 $rule->grep( qr/^#!.*\bperl/, [ sub { 1 } ] );

Is a passing clause if the first line of a file looks like a perl
shebang line.

=cut

sub grep {
    my $self = _force_object shift;
    my @pattern = map {
        ref $_
          ? ref $_ eq 'ARRAY'
            ? map { [ ( ref $_ ? $_ : qr/$_/ ) => 0 ] } @$_
            : [ $_ => 1 ]
          : [ qr/$_/ => 1 ]
      } @_;

    $self->exec( sub {
                     local *FILE;
                     open FILE, $_ or return;
                     local ($_, $.);
                     while (<FILE>) {
                         for my $p (@pattern) {
                             my ($rule, $ret) = @$p;
                             return $ret
                               if ref $rule eq 'Regexp'
                                 ? /$rule/
                                 : $rule->(@_);
                         }
                     }
                     return;
                 } );
}

=item C<maxdepth( $level )>

Descend at most C<$level> (a non-negative integer) levels of directories
below the starting point.

May be invoked many times per rule, but only the most recent value is
used.

=item C<mindepth( $level )>

Do not apply any tests at levels less than C<$level> (a non-negative
integer).

May be invoked many times per rule, but only the most recent value is
used.

=cut

for my $setter (qw( maxdepth mindepth )) {
    my $sub = sub {
        my $self = _force_object shift;
        $self->{$setter} = shift;
        $self;
    };
    no strict 'refs';
    *$setter = $sub;
}

=item C<not_*>

Negated version of the rule.  An effective shortand related to ! in
the procedural interface.

 $foo->not_name('*.pl');

 $foo->not( $foo->new->name('*.pl' ) );

=cut

sub DESTROY {}
sub AUTOLOAD {
    $AUTOLOAD =~ /::not_([^:]*)$/
      or croak "Can't locate method $AUTOLOAD";
    my $method = $1;

    my $sub = sub {
        my $self = _force_object shift;
        $self->not( $self->new->$method(@_) );
    };
    {
        no strict 'refs';
        *$AUTOLOAD = $sub;
    }
    &$sub;
}

=back

=head2 Query Methods

=over

=item C<test( $shortname, $path, $fullname )>

Invoked in the same way as callbacks invoked for L</exec> rules.

Returns true or undef if the rule matches (undef indicates that
although the rule was succesful, a C<discard> clause fired)

 my $rule = File::Find::Rule->name( '*.mp3' );
 print $rule->test( 'foo.ogg' ) ? "matches\n" : "no match\n";
                                       # prints "no match";

=cut

sub test {
    my $self = shift;

    my $return = 1;
    for my $rule (@{ $self->{rules} }) { # [0]
        my $match = $rule->{code}->(@_);
        $return = $match if !defined $match;
        return $match unless $match || !defined $match;
    }
    $return;
}

=item C<in( @directories )>

Evaluates the rule, returns a list of paths to matching files and
directories.

=cut

sub in {
    my $self = _force_object shift;

    my $cwd = getcwd;
    my @found;
    File::Find::find
        (
         sub {
             (my $path = $File::Find::name) =~ s#^\./##;
             my $depth = scalar File::Spec->splitdir($File::Find::name);
             my $maxdepth = $self->{maxdepth};
             my $mindepth = $self->{mindepth};

             defined $maxdepth && $depth > $maxdepth
               and $File::Find::prune = 1;

             defined $mindepth && $depth <= $mindepth
               and return;

             push @found, $path
               if $self->test($_,
                              $File::Find::dir,
                              $path);
         }, @_);
    chdir $cwd;

    return @found;
}

=item C<start( @directories )>

Starts a find across the specified directories.  Matching items may
then be queried using L</match>.  This allows you to use a rule as an
iterator.

 my $rule = find( file => name => "*.jpeg", start => "/web" );
 while ( my $image = $rule->match ) {
     ...
 }

=cut

sub start {
    my $self = _force_object shift;

    $self->{iterator} = [ $self->in( @_ ) ];
    $self;
}

=item C<match>

Returns the next file which matches, false if there are no more.

=cut

sub match {
    my $self = _force_object shift;

    return shift @{ $self->{iterator} };
}

1;

__END__

=back

=head2 Further examples

=over

=item Finding perl scripts

 my $finder = File::Find::Rule->or
  (
   File::Find::Rule->name( '*.pl' ),
   File::Find::Rule->exec(
                          sub {
                              if (open my $fh, $_) {
                                  my $shebang = <$fh>;
                                  close $fh;
                                  return $shebang =~ /^#!.*\bperl/;
                              }
                              return 0;
                          } ),
  );

Based upon this message http://use.perl.org/comments.pl?sid=7052&cid=10842

=item ignore CVS directories

 my $rule = File::Find::Rule->new;
 $rule->or($rule->new
                ->directory
                ->name('CVS')
                ->prune
                ->discard,
           $rule->new);

Note here the use of a null rule.  Null rules match anything they see,
so the effect is to match (and discard) directories called 'CVS' or to
match anything.

Another way to express this would be

 rule( not => rule( directory => name 'CVS', => prune => ) )

Though this is entirely a stylistic choice dependant on how complex
your rule needs to be.

=back

=head1 EXPORTS

L</find>, L</rule>

=head1 BUGS

The code relies on qr// compiled regexes, therefore this module
requires perl version 5.005_03 or newer.

Currently it isn't possible to remove a clause from a rule object.  If
this becomes a significant issue it will be addressed.

=head1 AUTHOR

Richard Clamp <richardc@unixbeard.net> with input gained from this
use.perl discussion: http://use.perl.org/~richardc/journal/6467

Additional proofreading and input provided by Kake, Greg McCarroll,
and Andy Lester andy@petdance.com.

=head1 COPYRIGHT

Copyright (C) 2002 Richard Clamp.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<File::Find>, L<Text::Glob>, L<Number::Compare>, find(1)

And if you have an idea for a neat extension
L<File::Find::Rule::Extending>

=cut

Implementation notes:

[0] Currently we use an array of anonymous subs, and call those
repeatedly from match.  It'll probably be way more effecient to
instead eval-string compile a dedicated matching sub, and call that to
avoid the repeated sub dispatch.

[1] This hash is filled close to the source, which is especially
useful as half of our methods are auto-generated.

[*] There's probably a win to be made with the current model in making
stat calls use C<_>.  For

  find( file => size => "> 20M" => size => "< 400M" );

up to 3 stats will happen for each candidate.  Adding a priming _
would be a bit blind if the first operation was C< name => 'foo' >,
since that can be tested by a single regex.  Simply checking what the
next type of operation doesn't work since any arbritary exec sub may
or may not stat.  Potentially worse, they could stat something else
like so:

  # extract from the worlds stupidest make(1)
  find( exec => sub { my $f = $_; $f =~ s/\.c$/.o/ && !-e $f } );

Maybe the best way is to treat C<_> as invalid after calling an exec,
and doc that C<_> will only be meaningful after stat and -X tests if
they're wanted in exec blocks.
