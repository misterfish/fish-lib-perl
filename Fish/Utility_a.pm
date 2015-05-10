package Fish::Utility_a;

=head

Author: Allen Haim <allen@netherrealm.net>, © 2015.
Source: github.com/misterfish/fish-lib-perl
Licence: GPL 2.0
Version: 1.0

=cut


# Umbrella package: bring in Utility, Utility_l, and Utility_m.
# use Fish::Utility_a will import everything from every module.
# use Fish::Utility_a 'a', 'b', 'c' to only take what you want.

BEGIN {
    use base 'Exporter';

    use Fish::Utility;
    use Fish::Utility_l;
    use Fish::Utility_m;

    import_export_ok for qw, Fish::Utility Fish::Utility_l Fish::Utility_m ,;

    @EXPORT = (
        @Fish::Utility::EXPORT,
        @Fish::Utility_l::EXPORT,
        @Fish::Utility_m::EXPORT,
    );

    @EXPORT_OK = (
        @Fish::Utility::EXPORT_OK,
        @Fish::Utility_l::EXPORT_OK,
        @Fish::Utility_m::EXPORT_OK,
    );
}

1;
