# -*- perl -*-

use Test::More tests => 2;
use lib 't/lib';
use DBSchema;
use YAML::Syck qw( Load );
use Data::Dumper;
use DvdForm;
use Rose::HTMLx::Form::DBIC 'options_from_resultset';

my $schema = DBSchema::get_test_schema();
my $dvd_rs = $schema->resultset( 'Dvd' );

$form = DvdForm->new;
options_from_resultset($form, $dvd_rs );
my @values = $form->field( 'tags' )->options;
is ( scalar @values, 3, 'Tags loaded' );
@values = $form->field( 'owner' )->options;
is ( scalar @values, 3, 'Owners loaded' );

