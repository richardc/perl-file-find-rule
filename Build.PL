use strict;
use Module::Build;

Module::Build->new(
    module_name => "File::Find::Rule",
    license     => 'perl',
    script_files => [ 'findrule' ],
    requires    => {
        'Test::More'      => 0,
        'Number::Compare' => 0,
        'Text::Glob'      => 0,
        'File::Find'      => 0,
        'File::Spec'      => 0,
        'Cwd'             => 0,
    },
    create_makefile_pl => 'traditional',
   )
  ->create_build_script;
