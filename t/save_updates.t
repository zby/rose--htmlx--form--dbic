# -*- perl -*-

use Test::More tests => 12;
use lib 't/lib';
use lib '../Rose-HTMLx-Form-Field-DateTimeSelect/lib/';
use DBSchema;
use YAML::Syck qw( Load );
use Data::Dumper;
use Rose::HTMLx::Form::DBIC qw( save_updates);

my $schema = DBSchema::get_test_schema();
my $dvd_rs = $schema->resultset( 'Dvd' );

my $owner = $schema->resultset( 'User' )->first;

# creating new records

$updates = {
    id => undef,
        aaaa => undef,
        tags => [ '2', '3' ], 
        name => 'Test name',
#        'creation_date.year' => 2002,
#        'creation_date.month' => 1,
#        'creation_date.day' => 3,
#        'creation_date.hour' => 4,
#        'creation_date.minute' => 33,
#        'creation_date.pm' => 1,
        owner => $owner->id,
        current_borrower => {
            name => 'temp name',
            username => 'temp name',
            password => 'temp name',
        },
        liner_notes => {
            notes => 'test note'
        }
};

my $dvd = save_updates( $dvd_rs, $updates );

is ( $dvd->name, 'Test name', 'Dvd name set' );
is_deeply ( [ map {$_->id} $dvd->tags ], [ '2', '3' ], 'Tags set' );
#my $value = $dvd->creation_date;
#is( "$value", '2002-01-03T16:33:00', 'Date set');
is ( $dvd->owner->id, $owner->id, 'Owner set' );

is ( $dvd->current_borrower->name, 'temp name', 'Related record created' );
is ( $dvd->liner_notes->notes, 'test note', 'might_have record created' );

# changing existing records

$updates = {
    id => $dvd->id,
        aaaa => undef,
        name => 'Test name',
        tags => [ ], 
        'owner' => $owner->id,
        current_borrower => {
            name => 'temp name',
        }
};
$dvd = save_updates( $dvd_rs, $updates );

is ( $dvd->name, 'Test name', 'Dvd name set' );
is ( $dvd->owner->id, $owner->id, 'Owner set' );
is ( $dvd->current_borrower->name, 'temp name', 'Related record modified' );

# repeatable

$updates = {
    id => undef,
    name  => 'temp name',
    username => 'temp username',
    password => 'temp username',
    owned_dvds =>[
    {
        'id' => undef,
        'name' => 'temp name 1',
        'tags' => [ 1, 2 ],
    },
    {
        'id' => undef,
        'name' => 'temp name 2',
        'tags' => [ 2, 3 ],
    }
    ]
};

my $user = save_updates( $schema->resultset( 'User' ), $updates );
my @owned_dvds = $user->owned_dvds;
is( scalar @owned_dvds, 2, 'Has many relations created' );
is( $owned_dvds[0]->name, 'temp name 1', 'Name in a has_many related record saved' );
@tags = $owned_dvds[1]->tags;
is( scalar @tags, 2, 'Tags in has_many related record saved' );
is( $owned_dvds[1]->name, 'temp name 2', 'Second name in a has_many related record saved' );


