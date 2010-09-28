require "test_helper"

class ItemController < ActionController::Base
  renders_ext_tree :item do
    node :item, :text => :name, :children => :orders
      node :order, :text => :quantity
  end
end

class TreeTest < ActionController::TestCase
  
  tests ItemController
  
  setup do
    item1 = Item.create! :name => "Hello"
      Order.create! :item => item1, :quantity => 3
    item2 = Item.create! :name => "Howdy"
      Order.create! :item => item2, :quantity => 2
  end

  test "renders_ext_grid should add action to controller" do
    assert @controller.respond_to?(:item_tree_data)
  end
  
  test "Should not fail without params" do
    get_json :item_tree_data
  end
  
  test "Should return correct root nodes" do
    response = get_json :item_tree_data, :node => "root"
    assert_equal ["Hello", "Howdy"], response.map { |x| x['text'] }
  end
  
  test "Should return correct second level nodes" do
    roots = get_json :item_tree_data, :node => "root"
    secondaries = roots.map do |node|
      get_json :item_tree_data, :node => node['id']
    end.flatten
    assert_equal ["3", "2"], secondaries.map { |x| x['text'] }
  end
end
