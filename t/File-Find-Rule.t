#!perl -w
#       $Id$

use strict;
use Test::More tests => 40;

my $class;
my $this = "t/File-Find-Rule.t";
BEGIN {
    $class = 'File::Find::Rule';
    use_ok($class)
}

my $f = $class->new;
isa_ok($f, $class);


# name
$f = $class->name( qr/\.t$/ );
is_deeply( [ $f->in('t') ],
           [ $this ],
           "name( qr/\\.t\$/ )" );

$f = $class->name( 'foobar' );
is_deeply( [ $f->in('t') ],
           [ 't/foobar' ],
           "name( 'foobar' )" );

$f = $class->name( '*.t' );
is_deeply( [ $f->in('t') ],
          [ $this ],
          "name( '*.t' )" );

# exec
$f = $class->exec(sub { length == 6 })->maxdepth(1);
is_deeply( [ $f->in('t') ],
           [ 't/foobar' ],
           "exec (short)" );

$f = $class->exec(sub { length > 10 })->maxdepth(1);
is_deeply( [ $f->in('t') ],
           [ $this ],
           "exec (long)" );

is_deeply( [ find( maxdepth => 1, exec => sub { $_[2] eq 't/foobar' }, in => 't' ) ],
           [ 't/foobar' ],
           "exec (check arg 2)" );

# name and exec, chained
$f = $class
  ->exec(sub { length > 10 })
  ->name( qr/\.t$/ );

is_deeply( [ $f->in('t') ],
           [ $this ],
           "exec(match) and name(match)" );

$f = $class
  ->exec(sub { length > 10 })
  ->name( qr/foo/ )
  ->maxdepth(1);

is_deeply( [ $f->in('t') ],
           [ ],
           "exec(match) and name(fail)" );


# directory
$f = $class
  ->directory
  ->maxdepth(1)
  ->exec(sub { $_ ne '.svn' }); # ignore .svn dir

is_deeply( [ $f->in('t') ],
           [ qw( t t/lib  ) ],
           "directory autostub" );


# any/or
$f = $class->any( $class->exec( sub { length == 6 } ),
                  $class->name( qr/\.t$/ )
                        ->exec( sub { length > 10 } )
                )->maxdepth(1);

is_deeply( [ sort $f->in('t') ],
           [ $this, 't/foobar' ],
           "any" );

$f = $class->or( $class->exec( sub { length == 6 } ),
                 $class->name( qr/\.t$/ )
                       ->exec( sub { length > 10 } )
               )->maxdepth(1);

is_deeply( [ sort $f->in('t') ],
           [ $this, 't/foobar' ],
           "or" );


# not/none
$f = $class
  ->file
  ->not( $class->name( qr/^[^.]{1,8}(\.[^.]{,3})?$/ ) )
  ->maxdepth(1)
  ->exec(sub { length == 6 || length > 10 });
is_deeply( [ $f->in('t') ],
           [ $this ],
           "not" );

# not as not_*
$f = $class
  ->file
  ->not_name( qr/^[^.]{1,8}(\.[^.]{,3})?$/ )
  ->maxdepth(1)
  ->exec(sub { length == 6 || length > 10 });
is_deeply( [ $f->in('t') ],
           [ $this ],
           "not_*" );

# prune/discard (.svn demo)
# this test may be a little meaningless for a cpan release, but it
# fires perfectly in my dev sandbox
$f = $class->or( $class->directory
                        ->name('.svn')
                        ->prune
                        ->discard,
                 $class->new->file );

is_deeply( [ sort $f->in('t') ],
           [ $this, 't/foobar', 't/lib/File/Find/Rule/Test/ATeam.pm' ],
           "prune/discard .svn"
         );


# procedural form of the CVS demo
$f = find(or => [ find( directory =>
                        name      => '.svn',
                        prune     =>
                        discard   => ),
                  find( file => ) ]);

is_deeply( [ sort $f->in('t') ],
           [ $this, 't/foobar', 't/lib/File/Find/Rule/Test/ATeam.pm' ],
           "procedural prune/discard .svn"
         );

# size (stat test)
is_deeply( [ find( maxdepth => 1, file => size => 10, in => 't' ) ],
           [ 't/foobar' ],
           "size 10 (stat)" );

is_deeply( [ find( maxdepth => 1, file => size => "<= 10", in => 't' ) ],
           [ 't/foobar' ],
           "size <= 10 (stat)" );

is_deeply( [ find( maxdepth => 1, file => size => "<11", in => 't' ) ],
           [ 't/foobar' ],
           "size <11 (stat)" );

is_deeply( [ find( maxdepth => 1, file => size => "<1K",
                   exec => sub { length == 6 },
                   in => 't' ) ],
           [ 't/foobar' ],
           "size <1K (stat)" );

is_deeply( [ find( maxdepth => 1, file => size => ">3K", in => 't' ) ],
           [ $this ],
           "size >3K (stat)" );

# these next two should never fail.  if they do then the testing fairy
# went mad
is_deeply( [ find( file => size => ">3M", in => 't' ) ],
           [ ],
           "size >3M (stat)" );

is_deeply( [ find( file => size => ">3G", in => 't' ) ],
           [ ],
           "size >3G (stat)" );


#min/maxdepth

is_deeply( [ find( maxdepth => 0, in => 't' ) ],
           [ 't' ],
           "maxdepth == 0" );


is_deeply( [ sort +find( or => [ find( name => '.svn',
                                       discard =>),
                                 find(),
                               ],
                         maxdepth => 1,
                         in => 't' ) ],
           [ 't', $this, 't/foobar', 't/lib' ],
           "maxdepth == 1" );


my @ateam_path = qw( t/lib
                     t/lib/File
                     t/lib/File/Find
                     t/lib/File/Find/Rule
                     t/lib/File/Find/Rule/Test
                     t/lib/File/Find/Rule/Test/ATeam.pm );

is_deeply( [ sort +find( or => [ find( name => '.svn',
                                       prune =>
                                       discard =>),
                                 find( ),
                               ],
                         mindepth => 1,
                         in => 't' ) ],
           [ $this, 't/foobar', @ateam_path ],
           "mindepth == 1" );


is_deeply( [ sort +find( or => [ find( name => '.svn',
                                       discard =>),
                                 find(),
                               ],
                         maxdepth => 1,
                         mindepth => 1,
                         in => 't' ) ],
           [ $this, 't/foobar', 't/lib' ],
           "maxdepth = 1 mindepth == 1" );

#iterator
$f = find( or => [ find( name => '.svn',
                         prune =>
                         discard =>),
                   find(),
                 ],
           start => 't' );

{
my @found;
while ($_ = $f->match) { push @found, $_ }
is_deeply( [ sort @found ], [ 't', $this, 't/foobar', @ateam_path ], "iterator" );
}

# negating in the procedural interface
is_deeply( [ find( file => '!name' => qr/^[^.]{1,8}(\.[^.]{,3})?$/,
                   maxdepth => 1,
                   in => 't' ) ],
           [ $this ],
           "negating in the procedural interface" );

# grep
is_deeply( [ find( maxdepth => 1, file => grep => [ qr/bytes./, [ qr/.?/ ] ], in => 't' ) ],
           [ 't/foobar' ],
           "grep" );

# bootstrapping extensions via import

use lib qw(t/lib);

eval { $class->import(':Test::Elusive') };
like( $@, qr/^couldn't bootstrap File::Find::Rule::Test::Elusive/,
      "couldn't find the Elusive extension" );

eval { $class->import(':Test::ATeam') };
is ($@, "",  "if you can find them, maybe you can hire the A-Team" );
can_ok( $class, 'ba' );


# extra tests for findrule.  these are more for testing the parsing code.

sub run ($) {
    my $expr = shift;
    # dosish systems don't treat \ as special, so lose it
    $expr =~ s~\\~~g if ($^O eq 'Win32' || $^O eq 'dos');

    [ sort split /\n/, `$^X -Iblib/lib -Iblib/arch findrule $expr 2>&1` ];
}

is_deeply(run 't -file -name foobar', [ 't/foobar' ],
          '-file -name foobar');

is_deeply(run 't -maxdepth 0 -directory',
          [ 't' ], 'last clause has no args');


is_deeply(run 't -file -name \( foobar \*.t \)',
          [ $this, 't/foobar' ], 'grouping ()');

is_deeply(run 't -name \( -foo foobar \)',
          [ 't/foobar' ], 'grouping ( -literal )');

is_deeply(run 't -file -name foobar baz',
          [ "unknown option 'baz'" ], 'no implicit grouping');

is_deeply(run 't -maxdepth 0 -name -file',
          [], 'terminate at next -');
