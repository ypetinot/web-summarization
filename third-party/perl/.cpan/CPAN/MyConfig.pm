use Config;

$CPAN_BUILD_ROOT = "$ENV{CPAN_BUILD_ROOT}/";
$INSTALL_ROOT = "$ENV{THIRD_PARTY_PERL_ROOT}/";
$INSTALL_ARCH = $Config{archname};

$CPAN::Config = {
  'auto_commit' => q[1],
  'build_cache' => q[10],
  'build_dir' => "$CPAN_BUILD_ROOT",
  'cache_metadata' => q[1],
  'commandnumber_in_prompt' => q[1],
  'cpan_home' => "$INSTALL_ROOT/.cpan",
  'dontload_hash' => {  },
  'ftp' => q[/usr/bin/ftp],
  'ftp_passive' => q[1],
  'ftp_proxy' => q[],
  'getcwd' => q[cwd],
  'gzip' => q[/bin/gzip],
  'http_proxy' => q[],
  'inactivity_timeout' => q[0],
  'index_expire' => q[1],
  'inhibit_startup_message' => q[0],
  'keep_source_where' => "$INSTALL_ROOT/.cpan/sources",
  'lynx' => q[/usr/bin/lynx],

  # make configuration
  # exporting PERL5LIB can only be a quickfix, what is the right solution ??
  #'make' => "export PERL5LIB=$INSTALL_ROOT/lib && /usr/bin/make",
  'make' => q[/usr/bin/make],
  'make_arg' => q[],
  'make_install_arg' => q[],
  'make_install_make_command' => q[/usr/bin/make],
#  'makepl_arg' => "PREFIX=$INSTALL_ROOT",
# CCFLAGS='-I${INSTALL_ROOT}/include/' LDFROM='-L${INSTALL_ROOT}/lib/'
  'makepl_arg' => "SITELIBEXP=$INSTALL_ROOT/lib SITEARCHEXP=$INSTALL_ROOT/lib VENDORARCHEXP=$INSTALL_ROOT/lib VENDORLIBEXP=$INSTALL_ROOT/lib INSTALLDIRS=perl INSTALLARCHLIB=$INSTALL_ROOT/lib INSTALLPRIVLIB=$INSTALL_ROOT/lib INSTALLBIN=$INSTALL_ROOT/bin INSTALLSCRIPT=$INSTALL_ROOT/script INSTALLMAN1DIR=$INSTALL_ROOT/share/man/man1 INSTALLMAN3DIR=$INSTALL_ROOT/share/man/man3",

  # build configuration
  #'mbuild_arg' => "--installdirs core --install_base $INSTALL_ROOT --install_path lib=$INSTALL_ROOT/lib/ --prefix $INSTALL_ROOT",
  'mbuild_arg' => "--install_path lib=$INSTALL_ROOT/lib/ --install_path installprivlib=$INSTALL_ROOT/lib/ --install_path installarchlib=$INSTALL_ROOT/lib/",
  #'mbuildpl_arg' => "--installdirs core --install_base $INSTALL_ROOT --install_path lib=$INSTALL_ROOT/lib/ --prefix $INSTALL_ROOT",
  'mbuildpl_arg' => "--install_path lib=$INSTALL_ROOT/lib/ --install_path installprivlib=$INSTALL_ROOT/lib/ --install_path installarchlib=$INSTALL_ROOT/lib/",
  #'mbuild_install_arg' => "--installdirs core --install_base $INSTALL_ROOT --install_path lib=$INSTALL_ROOT/lib/ --prefix $INSTALL_ROOT",
  'mbuild_install_arg' => "--install_path lib=$INSTALL_ROOT/lib/ --install_path arch=${INSTALL_ROOT}/lib/${INSTALL_ARCH}/ --install_path sitelib=$INSTALL_ROOT/lib --install_path sitearch=$INSTALL_ROOT/lib --install_path vendorarch=$INSTALL_ROOT/lib --install_path vendorlib=$INSTALL_ROOT/lib --install_path installarchlib=$INSTALL_ROOT/lib --install_path installprivlib=$INSTALL_ROOT/lib --install_path installbin=$INSTALL_ROOT/bin --install_path installscript=$INSTALL_ROOT/script --install_path installman1dir=$INSTALL_ROOT/share/man/man1 --install_path installman3dir=$INSTALL_ROOT/share/man/man3",
  #'mbuild_install_build_command' => "./Build install --installdirs core --destdir $INSTALL_ROOT",
  'mbuild_install_build_command' => "./Build install --installdirs core --install_base $INSTALL_ROOT --install_path lib=$INSTALL_ROOT/lib/ --install_path installprivlib=$INSTALL_ROOT/lib/ --install_path installarchlib=$INSTALL_ROOT/lib/",

  'build_requires_install_policy' => "yes",

  'ncftpget' => q[/usr/bin/ncftpget],
  'no_proxy' => q[],
  'pager' => q[/usr/bin/less],
  
  # do not ask for user permission
  'prerequisites_policy' => q[follow],

  'scan_cache' => q[atstart],
  'shell' => q[/bin/bash],
  'show_upload_date' => q[0],
  'tar' => q[/bin/tar],
  'term_is_latin' => q[1],
  'term_ornaments' => q[1],
  'unzip' => q[/usr/bin/unzip],
  'urllist' => [q[http://www.cpan.org/]],
  'use_sqlite' => q[0],
  'wait_list' => [q[wait://ls6.informatik.uni-dortmund.de:1404]],
  'wget' => q[/usr/bin/wget],
};
1;
__END__
