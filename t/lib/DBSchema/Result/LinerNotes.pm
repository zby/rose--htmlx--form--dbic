package # hide from PAUSE 
    DBSchema::Result::LinerNotes;

use base qw/DBIx::Class::Core/;

__PACKAGE__->table('liner_notes');
__PACKAGE__->add_columns(
  'liner_id' => {
    data_type => 'integer',
  },
  'notes' => {
    data_type => 'varchar',
    size      => 100,
  },
);
__PACKAGE__->set_primary_key('liner_id');
__PACKAGE__->belongs_to(
  'dvd', 'DBSchema::Result::Dvd', 'liner_id'
);

1;
