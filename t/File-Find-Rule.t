#!perl -w
#       $Id$

use strict;
use Test::More tests => 30;

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
           [ 't' ],
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


# prune/discard (.svn demo)
# this test may be a little meaningless for a cpan release, but it
# fires perfectly in my dev sandbox
$f = $class->or( $class->directory
                        ->name('.svn')
                        ->prune
                        ->discard,
                 $class->new );

is_deeply( [ sort $f->in('t') ],
           [ 't', $this, 't/foobar' ],
           "prune/discard .svn"
         );


# procedural form of the CVS demo
$f = find(or => [ find( directory =>
                        name      => '.svn',
                        prune     =>
                        discard   => ),
                  find() ]);

is_deeply( [ sort $f->in('t') ],
           [ 't', $this, 't/foobar' ],
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
           [ 't', $this, 't/foobar' ],
           "maxdepth == 1" );


is_deeply( [ sort +find( or => [ find( name => '.svn',
                                       prune =>
                                       discard =>),
                                 find(),
                               ],
                         mindepth => 1,
                         in => 't' ) ],
           [ $this, 't/foobar' ],
           "mindepth == 1" );


is_deeply( [ sort +find( or => [ find( name => '.svn',
                                       discard =>),
                                 find(),
                               ],
                         maxdepth => 1,
                         mindepth => 1,
                         in => 't' ) ],
           [ $this, 't/foobar' ],
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
is_deeply( [ sort @found ], [ 't', $this, 't/foobar' ], "iterator" );
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
