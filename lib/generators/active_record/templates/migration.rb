class CreateDoorkeeperClientAs<%= table_name.camelize %> < ActiveRecord::Migration
  def change
    create_table(:<%= table_name %>) do |t|
      t.string :name
      t.string :uid
      t.string :secret
      t.string :redirect_uri

<% attributes.each do |attribute| -%>
      t.<%= attribute.type %> :<%= attribute.name %>
<% end -%>

      t.timestamps
    end

    add_index :<%= table_name %>, :uid, :unique => true
  end
end
