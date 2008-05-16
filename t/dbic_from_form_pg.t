# -*- perl -*-

use Test::More;
use lib 't/lib';
use lib '../Rose-HTMLx-Form-Field-DateTimeSelect/lib/';
use DBSchema;
use YAML::Syck qw( Load );
use Data::Dumper;
use DvdForm;
use UserForm2;
use Rose::HTMLx::Form::DBIC qw( options_from_resultset init_with_dbic dbic_from_form );

my ($dsn, $user, $pass) = @ENV{map { "DBICTEST_PG_${_}" } qw/DSN USER PASS/};

plan skip_all => 'Set $ENV{DBICTEST_PG_DSN}, _USER and _PASS to run this test'
 . ' (note: creates and tables!)' unless ($dsn && $user);

plan tests => 11;

my $schema = DBSchema::get_test_schema( $dsn, $user, $pass );
my $dvd_rs = $schema->resultset( 'Dvd' );

$form = DvdForm->new;
options_from_resultset( $form, $dvd_rs );

my $dvd = $schema->resultset( 'Dvd' )->new( {} );
my $owner = $schema->resultset( 'User' )->first;

$form->params( {
        tags => [ '2', '3' ], 
        name => 'Test name',
#        'creation_date.year' => 2002,
#        'creation_date.month' => 1,
#        'creation_date.day' => 3,
#        'creation_date.hour' => 4,
#        'creation_date.minute' => 33,
#        'creation_date.pm' => 1,
        'owner' => $owner->id,
        'current_borrower.name' => 'temp name',
        'current_borrower.username' => 'temp name',
        'current_borrower.password' => 'temp name',
    }
);
$form->init_fields();
$form->validate;
dbic_from_form($form, $dvd);

is ( $dvd->name, 'Test name', 'Dvd name set' );
is_deeply ( [ map {$_->id} $dvd->tags ], [ '2', '3' ], 'Tags set' );
#my $value = $dvd->creation_date;
#is( "$value", '2002-01-03T16:33:00', 'Date set');
is ( $dvd->owner->id, $owner->id, 'Owner set' );

is ( $dvd->current_borrower->name, 'temp name', 'Related record created' );

# changing existing records

$form->clear;
$form->form( 'current_borrower' )->delete_field( 'username' );
$form->form( 'current_borrower' )->delete_field( 'password' );
$dvd = $schema->resultset( 'Dvd' )->find( 2 );
$form->params( {
        name => 'Test name',
        tags => [ ], 
        'owner' => $owner->id,
        'current_borrower.name' => 'temp name',
    }
);
$form->init_fields();
dbic_from_form($form, $dvd);

is ( $dvd->name, 'Test name', 'Dvd name set' );
is ( $dvd->owner->id, $owner->id, 'Owner set' );
is ( $dvd->current_borrower->name, 'temp name', 'Related record modified' );

# repeatable

$form = UserForm2->new;
$form->params( {
       name  => 'temp name',
       username => 'temp username',
       password => 'temp username',
       'owned_dvds.1.id' => undef,
       'owned_dvds.1.name' => 'temp name 1',
       'owned_dvds.1.tags' => [ 1, 2 ],
       'owned_dvds.2.id' => undef,
       'owned_dvds.2.name' => 'temp name 2',
       'owned_dvds.2.tags' => [ 2, 3 ],
   }
);
$form->prepare();
my $user = $schema->resultset( 'User' )->new( {} );
options_from_resultset( $form, $schema->resultset( 'User' ));
$form->init_fields();

dbic_from_form($form, $user);
my @owned_dvds = $user->owned_dvds;
is( scalar @owned_dvds, 2, 'Has many relations created' );
is( $owned_dvds[0]->name, 'temp name 1', 'Name in a has_many related record saved' );
@tags = $owned_dvds[1]->tags;
is( scalar @tags, 2, 'Tags in has_many related record saved' );
is( $owned_dvds[1]->name, 'temp name 2', 'Second name in a has_many related record saved' );

