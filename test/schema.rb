ActiveRecord::Schema.define(:version => 0) do
  create_table :items, :force => true do |t|
    t.string :name
    t.text :description
    t.float :value
    t.datetime :created_at
  end
  create_table :orders, :force => true do |t|
    t.references :item
    t.integer :quantity
    t.datetime :created_at
  end
end