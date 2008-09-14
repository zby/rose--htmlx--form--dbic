package Rose::HTMLx::Form::DBIC;
use strict;
use Rose::HTML::Form;
use Carp;


BEGIN {
    use Exporter ();
    use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
    $VERSION     = '0.01';
    @ISA         = qw(Exporter);
    #Give a hoot don't pollute, do not export more than needed by default
    @EXPORT      = qw( );
    @EXPORT_OK   = qw( options_from_resultset init_with_dbic dbic_from_form save_updates values_hash );
    %EXPORT_TAGS = ();
}


sub options_from_resultset {
    my( $form, $rs ) = @_;
    for my $field ( $form->fields ){
        if ( $field->isa( 'Rose::HTML::Form::Field::SelectBox' ) ){
            my $name = $field->local_name;
            my $related_source = _get_related_source( $rs, $name );
            if( $related_source ){
                my ( $pk ) = $related_source->primary_columns;
                my $related_rs = $related_source->resultset;
                while( my $related_row = $related_rs->next ){
                    $field->add_option( $related_row->$pk => $related_row->$pk );
                }
            }
        }
    }
    for my $sub_form ( $form->forms ){
        my $name = $sub_form->name;
        my $related_source = _get_related_source( $rs, $name );
        if( $related_source ){
            my $related_rs = $related_source->resultset;
            if( $sub_form->isa( 'Rose::HTML::Form::Repeatable' ) ){
                for my $sub_sub_form ( $sub_form->forms ){
                    options_from_resultset( $sub_sub_form, $related_rs );
                }
            }
            else {
                options_from_resultset( $sub_form, $related_rs );
            }
        }
    }
}

sub _get_related_source {
    my ( $rs, $name ) = @_;
    if( $rs->result_source->has_relationship( $name ) ){
        return $rs->result_source->related_source( $name );
    }
    # many to many case
    my $row = $rs->new({});
    if ( $row->can( $name ) and $row->can( 'add_to_' . $name ) and $row->can( 'set_' . $name ) ){
        return $row->$name->new({})->result_source;
    }
    return;
}

sub init_with_dbic {
    my($form, $object) = @_;

    croak "Missing required object argument"  unless($object);

    $form->clear();

    foreach my $field ($form->local_fields) {
        my $name = $field->local_name;

        if($object->can($name)) {
            # many to many case
            if( $object->can( 'add_to_' . $name ) and $object->can( 'set_' . $name ) ){
                my ( $pk ) = _get_pk_for_related( $object, $name );
                $field->add_values( map{ $_->$pk } $object->$name());
            }
            else{
                $field->input_value(scalar $object->$name());
            }
        }
    }
    foreach my $sub_form ($form->forms ) {
        my $name = $sub_form->form_name;
        my $info = $object->result_source->relationship_info( $name );
        if( $info->{attrs}{accessor} eq 'multi' ){
            my @sub_objects = $object->$name;
            my $i = 1;
            for my $sub_object ( @sub_objects ){
                my $sub_sub_form = $sub_form->make_form( $i++ );
                init_with_dbic( $sub_sub_form, $sub_object );
            }
        }
        elsif( $info ){
            my $sub_object = $object->$name;
            init_with_dbic( $sub_form, $sub_object );
        }
    }
}
sub _get_pk_for_related {
    my ( $object, $relation ) = @_;

    my $rs = $object->result_source->resultset;
    my $result_source = _get_related_source( $rs, $relation );
    return $result_source->primary_columns;
}

sub _delete_empty_auto_increment {
    my ( $object ) = @_;
    for my $col ( keys %{$object->{_column_data}}){
        if( $object->result_source->column_info( $col )->{is_auto_increment} 
                and 
            ( ! defined $object->{_column_data}{$col} or $object->{_column_data}{$col} eq '' )
        ){
            delete $object->{_column_data}{$col}
        }
    }
}

sub values_hash {
    my $form = shift;
    
    my %hash; 
    foreach my $field ($form->local_fields) {
        $hash{$field->local_name} = $field->internal_value;
    }
    foreach my $sub_form ($form->forms ) {
        if( $sub_form->isa( 'Rose::HTML::Form::Repeatable' ) ){
            for my $sub_sub_form ( $sub_form->forms ) {
                push @{$hash{$sub_form->form_name}}, values_hash( $sub_sub_form );
            }
        }
        else{
            $hash{$sub_form->form_name} = values_hash( $sub_form );
        }
    }
    return \%hash;
}

sub dbic_from_form { 
    my( $form, $object ) = @_;

    my $updates = values_hash( $form );
    return save_updates( $object, $updates );
}

sub _master_relation_cond {
    my ( $object, $cond, @foreign_ids ) = @_;
    my $foreign_ids_re = join '|', @foreign_ids;
    if ( ref $cond eq 'HASH' ){
        for my $f_key ( keys %{$cond} ) {
            # might_have is not master
            my $col = $cond->{$f_key};
            $col =~ s/self\.//;
            if( $object->column_info( $col )->{is_auto_increment} ){
                return 0;
            }
            if( $f_key =~ /^foreign\.$foreign_ids_re/ ){
                return 1;
            }
        }
    }elsif ( ref $cond eq 'ARRAY' ){
        for my $new_cond ( @$cond ) {
            return 1 if _master_relation_cond( $object, $new_cond, @foreign_ids );
        }
    }
    return;
}


sub save_updates { 
    my( $object, $updates ) = @_;

    defined $object or croak 'No object';

    for my $name ( keys %$updates ){
        if($object->can($name)){
            my $value = $updates->{$name};
            # updating relations that that should be done before the row is inserted into the database
            # like belongs_to
            if( $object->result_source->has_relationship($name) 
                    and 
                ref $value
            ){
                my $info = $object->result_source->relationship_info( $name );
                if( $info and not $info->{attrs}{accessor} eq 'multi'
                        and 
                    _master_relation_cond( $object, $info->{cond}, _get_pk_for_related( $object, $name ) )
                ){
                    my $sub_object = $object->$name;
                    if( not defined $sub_object ){
                        $sub_object = $object->new_related( $name, {} );
                        # fix for DBIC bug 
                        delete $object->{_inflated_column}{$name};
                    }
                    save_updates( $sub_object, $value );
                    $object->set_from_related( $name, $sub_object );
                }
            }
            # columns and other accessors
            elsif( $object->result_source->has_column($name) 
                    or 
                !$object->can( 'set_' . $name ) 
            ) {
                $object->$name($value);
            }
        }
        #warn Dumper($object->{_column_data}); use Data::Dumper;
    }
    _delete_empty_auto_increment($object);
    $object->update_or_insert;

    # updating relations that can be done only after the row is inserted into the database
    # like has_many and many_to_many
    for my $name ( keys %$updates ){
        my $value = $updates->{$name};
        # many to many case
        if($object->can($name) and 
            !$object->result_source->has_relationship($name) and 
            $object->can( 'set_' . $name )
        ) {
                my ( $pk ) = _get_pk_for_related( $object, $name );
                my @values = @{$updates->{$name}};
                my @rows;
                my $result_source = $object->$name->result_source;
                @rows = $result_source->resultset->search({ $pk => [ @values ] } ) if @values; 
                my $set_meth = 'set_' . $name;
                $object->$set_meth( \@rows );
        }
        elsif( $object->result_source->has_relationship($name) ){
            my $info = $object->result_source->relationship_info( $name );
            # has many case
            if( ref $updates->{$name} eq 'ARRAY' ){
                for my $sub_updates ( @{$updates->{$name}} ) {
                    my ( @pks ) = _get_pk_for_related( $object, $name );
                    my %pks;
                    for my $pk ( @pks ){
                        $pks{$pk} = $sub_updates->{$pk};
                    }
                    my $sub_object = $object->$name->search( \%pks )->first || $object->$name->new({}); 
                    save_updates ( $sub_object, $sub_updates );
                }
            }
            # might_have and has_one case
            elsif ( ! _master_relation_cond( $object, $info->{cond}, _get_pk_for_related( $object, $name ) ) ){
                my $sub_object = $object->$name;
                if( not defined $sub_object ){
                    $sub_object = $object->new_related( $name, {} );
                    # fix for DBIC bug 
                    delete $object->{_inflated_column}{$name};
                }
                warn "sub id: " . $sub_object->id;
                save_updates( $sub_object, $value );
                warn "sub id: " . $sub_object->id;
                #$object->set_from_related( $name, $sub_object );
            }
        }
    }
    return $object;
}

#################### main pod documentation begin ###################
## Below is the stub of documentation for your module. 
## You better edit it!


=head1 NAME

Rose::HTML::Form::DBIC - Module abstract (<= 44 characters) goes here

=head1 SYNOPSIS

  use Rose::HTML::Form::DBIC qw(options_from_resultset init_with_dbic dbic_from_form );
  use DvdForm;
  use DBSchema;
.
.
.
  $form = DvdForm->new;
  options_from_resultset( $form, $schema->resultset( 'Dvd' ) );
  $form->params( { ... } );
  $form->init_fields();
  if( $form->was_submitted ){
    if ( $form->validate ){ 
      dbic_from_form($form, $schema->resultset( 'Dvd' )->find(1));
    }
  }
  else {
    init_with_dbic($form, $schema->resultset( 'Dvd' )->find(1));
  }

=head1 DESCRIPTION

This module exports functions integrating Rose::HTML::Form with DBIx::Class.

=head1 USAGE

=head2 options_from_resultset

 Usage     : options_from_resultset( $form, $result_set )
 Purpose   : loads options for SELECT boxes from database tables
 Returns   :
 Argument  : $form - Rose::HTML::Form, $result_set - DBIx::Class::ResultSet
 Throws    : 
 Comment   : 
           : 


=head1 BUGS



=head1 SUPPORT
#rdbo at irc.perl.org


=head1 AUTHOR

    Zbigniew Lukasiak
    CPAN ID: ZBY
    http://perlalchemy.blogspot.com

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.


=head1 SEE ALSO

perl(1).

=cut

#################### main pod documentation end ###################


1;
# The preceding line will help the module return a true value

