use ExtUtils::MakeMaker;
my $module = 'Rule.pm';
WriteMakefile(
              NAME         => 'File::Find::Rule',
              VERSION_FROM => $module,
              PREREQ_PM    => {
                               'Test::More'      => 0,
                               'Number::Compare' => 0,
                               'Text::Glob'      => 0,
                               'File::Find'      => 0,
                               'File::Spec'      => 0,
                               'Cwd'             => 0,
                              },
              PM           => {
                               'Rule.pm'       => '$(INST_LIBDIR)/Rule.pm',
                               'Extending.pod' => '$(INST_LIBDIR)/Rule/Extending.pod',
                              },
              AUTHOR       => 'Richard Clamp <richardc@unixbeard.net>',
             );

sub MY::postamble {
    return <<EOF
README: $module
\tpod2text $module > README

cover:
\trm -rf cover_db
\tPERL5OPT=-MDevel::Cover \$(MAKE) test || true
\tcover cover_db
EOF
}
