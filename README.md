# fish-lib-perl

Version: 1.0.5

Lots of perl modules -- e.g. Fish::Utility (utilities), Fish::Class ('class' and 'o' keywords), Fish::Opt (option processing), Fish::Iter (iterate through data structures), and more.

Author: Allen Haim <allen@netherrealm.net>, © 2015.
Source: github.com/misterfish/fish-lib-perl
Licence: GPL 2.0

INSTALLATION
------------

You will need a recent perl (>=5.18), and most or all of the following
modules. 

Some come with perl, but it's sometimes distro-dependent.
To check if you have e.g. DBI: 

% perl -MDBI -e1        # should return with no output.

«widely used»

Class::XSAccessor       
 debian: libclass-xsaccessor-perl
List::MoreUtils
 debian: liblist-moreutils-perl
IPC::Signal
 debian: libipc-signal-perl

«occasionally used»

DBI
 debian: libdbi-perl
 only for: Fish::Sq
Config::IniFiles
 debian: libconfig-inifiles-perl
 only for: Fish::Conf
Curses
 debian: libcurses-perl
 only for: Fish::Curses
HTML::TreeBuilder
 debian: libhtml-treebuilder-libxml-perl 
 only for: Fish::Utility_m::find_children, Fish::Utility_m::find_children_r
LWP::UserAgent
 debian: ?
 only for: Fish::Utility_m::get_url
Moose
 debian: libmoose-perl
 only for: Fish::Sq
Moo, MooX::Types::MooseLike::Base
 debian: libmoox-types-mooselike-numeric-perl, libmoox-types-mooselike-perl
 only for: Fish::Conf
Term::ReadKey
 only for: Fish::Curses
 only for: Fish::Utility_m::term_echo_off, Fish::Utility_m::term_restore

                                                        
