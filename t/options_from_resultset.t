# -*- perl -*-

use Test::More tests => 3;
use lib 't/lib';
use DBSchema;
use YAML::Syck qw( Load );
use Data::Dumper;
use DvdForm;
use UserForm2;
use Rose::HTMLx::Form::DBIC 'options_from_resultset';

my $schema = DBSchema::get_test_schema();
my $dvd_rs = $schema->resultset( 'Dvd' );

$form = DvdForm->new;
options_from_resultset($form, $dvd_rs );
my @values = $form->field( 'tags' )->options;
is ( scalar @values, 3, 'Tags loaded' );
@values = $form->field( 'owner' )->options;
is ( scalar @values, 3, 'Owners loaded' );

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
options_from_resultset( $form, $schema->resultset( 'User' ));
my @options = $form->form('owned_dvds')->form(1)->field('tags')->options;
is( scalar @options, 3, 'Options in Repeatable loaded' );

