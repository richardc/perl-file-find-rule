use strict;
use Test::More tests => 4;

my $class = 'File::Find::Rule';
require_ok( $class );

my $name_first = $class->name('pie')->file;
my $stat_first = $class->file->name('pie');

is( $name_first->_compile, $stat_first->_compile,
    "should treat name('foo')->file and file->name('foo') as equivalent" );

like( $name_first->_compile, qr/^.*# name/,
   "name should be the first test" );

# discard shouldn't be sorted - it's cheap it shouldn't be jumped up the
# order first
my $discard = $class->file->discard->name;
like( $discard->_compile, qr/^.*# file/,
  "use of 'discard' disables cost sorting" );
