class AddDoorkeeperClientTo<%= table_name.camelize %> < ActiveRecord::Migration
  def self.up
    change_table(:<%= table_name %>) do |t|
      t.string :name
      t.string :uid
      t.string :secret
      t.string :redirect_uri

<% attributes.each do |attribute| -%>
      t.<%= attribute.type %> :<%= attribute.name %>
<% end -%>

      # Uncomment below if timestamps were not included in your original model.
      # t.timestamps
    end

    add_index :<%= table_name %>, :uid, :unique => true
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
