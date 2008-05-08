package DBSchema;

# Created by DBIx::Class::Schema::Loader v0.03000 @ 2006-10-02 08:24:09

use strict;
use warnings;

use base 'DBIx::Class::Schema';
use DateTime;

__PACKAGE__->load_classes;

my $dsn    = 'dbi:SQLite:dbname=t/var/dvdzbr.db';
sub get_test_schema {
    my $schema = __PACKAGE__->connect( $dsn, '', '', {} );
    $schema->deploy({ add_drop_table => 1, });
    $schema->populate('User', [
        [ qw/id username name password / ],
        [ 1, 'jgda', 'Jonas Alves', ''],
        [ 2, 'isa' , 'Isa', '', ],
        [ 3, 'zby' , 'Zbyszek Lukasiak', ''],
        ]
    );
    $schema->populate('Tag', [
        [ qw/id name file / ],
        [ 1, 'comedy', '' ],
        [ 2, 'dramat', '' ],
        [ 3, 'australian', '' ],
        ]
    );
    $schema->populate('Dvd', [
        [ qw/id name imdb_id owner current_borrower creation_date alter_date / ],
        [ 1, 'Picnick under the Hanging Rock', 123, 1, 3, '2003-01-16 23:12:01', undef ],
        [ 2, 'The Deerhunter', 1234, 1, 1, undef, undef ],
        [ 3, 'Rejs', 1235, 3, 1, undef, undef ],
        [ 4, 'Seksmisja', 1236, 3, 1, undef, undef ],
        ]
    ); 
    $schema->populate( 'Dvdtag', [
        [ qw/ dvd tag / ],
        [ 1, 2 ],
        [ 1, 3 ],
        [ 3, 1 ],
        [ 4, 1 ],
        ]
    );
    return $schema;
}
    
    
1;

