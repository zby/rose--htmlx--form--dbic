# -*- perl -*-
use strict;
use warnings;
use Test::More tests => 7;
use lib 't/lib';
use DBSchema;
use Data::Dumper;
use Rose::HTMLx::Form::DBIC::FormGenerator;

my $schema = DBSchema::get_test_schema();
my $generator = Rose::HTMLx::Form::DBIC::FormGenerator->new( schema => $schema );
my $output = $generator->generate_form( 'User' );
ok( $output =~ /UserForm/, 'Some form code generated' );
$output = $generator->generate_form( 'Dvd' );
eval $output;
my $user_form = DvdForm->new;
ok( $user_form, 'Some form code for Dvd generated' );
is( ref $user_form->field( 'id' ), 'Rose::HTML::Form::Field::Hidden', 'PK field generated' );
my @owner_fields = ( $output =~ /owner =>/g );
is( scalar( @owner_fields ), 1, 'No field generated for column in relation' );
$generator = Rose::HTMLx::Form::DBIC::FormGenerator->new( 
    schema => $schema, 
    class_prefix => 'Controller',  
);
$output = $generator->generate_form( 'Dvd' );
ok( $output =~ /Controller::DvdtagForm/, 'Class prefix added' );

$generator = Rose::HTMLx::Form::DBIC::FormGenerator->new( 
    schema => $schema, 
    m2m    => { Dvd => [[ 'tags', 'dvdtags', 'tag' ]] }
);
$output = $generator->generate_form( 'Dvd' );
ok( $output !~ /dvdtags /, 'bridge rel not included' );
ok( $output =~ /tags/, 'many to many included' );

$output = $generator->generate_form( 'Tag' );

