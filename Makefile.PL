use ExtUtils::MakeMaker;
$module = 'Rule.pm';
%depends = ( 'Test::More'      => 0,
                'Number::Compare' => 0,
                'Text::Glob'      => 0,
                'File::Find'      => 0,
                'File::Spec'      => 0,
                'Cwd'             => 0,
              );

WriteMakefile(
              NAME         => 'File::Find::Rule',
              VERSION_FROM => $module,
              PREREQ_PM    => \%depends,
              PM           => {
                               'Rule.pm'       => '$(INST_LIBDIR)/Rule.pm',
                               'Extending.pod' => '$(INST_LIBDIR)/Rule/Extending.pod',
                              },
              EXE_FILES    => [ 'findrule' ],
              AUTHOR       => 'Richard Clamp <richardc@unixbeard.net>',
             )
  if $0 =~ m/makefile.pl/i;

sub MY::postamble {
    return <<EOF
README: $module Changes ../makereadme
\t../makereadme $module \$(NAME) \$(VERSION) > README

dist: README

cover:
\trm -rf cover_db
\tPERL5OPT=-MDevel::Cover \$(MAKE) test || true
\tcover cover_db
EOF
}

1;
