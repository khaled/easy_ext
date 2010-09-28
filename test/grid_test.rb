require 'test_helper'

class ItemController < ActionController::Base
  renders_ext_grid :item do
    column :name
  end
  
  renders_ext_grid :item_custom_scope, :scope => lambda { Item.where(:value => 5) } do
    column :name
    column :description
  end
  
  renders_ext_grid :order, :scope => lambda { Order.includes(:item) } do
    delegate_to :item, :except => [:quantity]
    column :name
    column :quantity
  end
  
  renders_ext_grid :item_with_custom_column, :scope => lambda { Item.scoped } do
    column { |x| "#{x.name} (#{x.value.to_i})" }
  end
  
  renders_ext_grid :item_with_custom_sort, :scope => lambda { Item.scoped } do
    column :name, :sort => "value"
  end
  
end

class GridTest < ActionController::TestCase
  
  tests ItemController

  test "renders_ext_grid should add actions to controller" do
    assert @controller.respond_to?(:item_grid_data)
    assert @controller.respond_to?(:item_grid_metadata)
    assert @controller.send(:item_grid).is_a? EasyExt::Grid
  end

  test "Grid should return empty metadata given appropriate config" do
    grid = EasyExt::Grid.new(:item)
    md = grid.metadata(@controller)
    assert_equal({ :column_model => [],
                   :data_url => "http://test.host/item/item_grid_data", 
                   :column_mappings => [] }, md)
  end
  
  test "Grid should return single column metadata given appropriate config" do
    response = get_json :item_grid_metadata
    assert_equal({
      'column_model' => [{"header"=>"Name", "sortable"=>true, "dataIndex"=>"name", "width"=>100}],
      'column_mappings' => [{"name"=>"name", "mapping"=>"name"}],
      'data_url' => "http://test.host/item/item_grid_data"
    }, response)
  end
  
  test "Grid data action should return zero rows with there's no data" do
    response = get_json :item_grid_data
    assert_equal({ 'records' => [], 'total' => 0 }, response)
  end

  test "Grid data action should return data in simple case" do
    Item.create! :name => "Hello1"
    Item.create! :name => "Hello2"
    response = get :item_grid_data
    assert_equal({:records=>[{:name=>"Hello1", :id=>"1"},{:name=>"Hello2", :id=>"2"}], :total=>2}.to_json,
      response.body)
  end
  
  test "Grid returns records in default case" do
    grid = EasyExt::Grid.new(:item)
    data = grid.data(@controller)
    assert_equal({ :records => [], :total => 0 }, data)
  end
      
  test "Columns should not be sortable when sortable option is false" do
    grid = EasyExt::Grid.new(:item) do
      column :name, :sortable => false
    end
    md = grid.metadata(@controller)
    assert_equal md[:column_model][0][:sortable], false
  end

  test "Grid should obey start / limit params" do
    1.upto(5) { |idx| Item.create! :name => "Item#{idx}" }
    response = get_json :item_grid_data, :start => 2, :limit => 2
    assert_equal 2, response['total']
    assert_equal ["Item3", "Item4"], response['records'].map { |x| x['name'] }
  end
  
  test "Grid should obey sort params" do
    Item.create! :name => "Item1"
    Item.create! :name => "Item2"
    response = get_json :item_grid_data, :sort => "name", :dir => "ASC"
    assert_equal ["Item1", "Item2"], response['records'].map { |x| x['name'] }
    response = get_json :item_grid_data, :sort => "name", :dir => "DESC"
    assert_equal ["Item2", "Item1"], response['records'].map { |x| x['name'] }
  end
  
  test "Grid should obey custom scope specified in config" do
    Item.create! :name => "Item1", :value => 5
    Item.create! :name => "Item2", :value => 6
    response = get_json :item_custom_scope_grid_data
    assert_equal ["Item1"], response['records'].map { |x| x['name'] }
  end
  
  test "Should render data from models delegated to" do
    item = Item.create! :name => "Item1"
    Order.create! :item => item, :quantity => 2
    Order.create! :item => item, :quantity => 3
    response = get_json :order_grid_data
    assert_equal response, {"total"=>2, "records"=>[{"name"=>"Item1", "quantity"=>2, "id"=>"1"}, {"name"=>"Item1", "quantity"=>3, "id"=>"2"}]}
  end
  
  test "Should render data from custom column" do
    Item.create! :name => "Hello", :value => 7
    response = get_json :item_with_custom_column_grid_data
    assert_equal "Hello (7)", response['records'][0]['col_1']
  end

  test "Should use custom sort column if specified" do
    Item.create! :name => "Item1", :value => 7
    Item.create! :name => "Item2", :value => 5
    response = get_json :item_with_custom_sort_grid_data, :sort => "name", :dir => "ASC"
    assert_equal ["Item2", "Item1"], response['records'].map { |x| x['name'] }
  end
  
  test "Should fail when invalid options are passed to renders_ext_grid" do
    failed = false
    begin
      ItemController.renders_ext_grid :bad_options, :foo => 22 do
      end
    rescue ArgumentError
      failed = true
    end
    assert failed
  end

  test "Should fail when invalid column options are passed" do
    failed = false
    begin
      ItemController.renders_ext_grid :bad_column_options, :scope => lambda { Item.scoped } do
        column :bad, :bad => 4
      end
    rescue ArgumentError
      failed = true
    end
    assert failed
  end
  
  test "Should not fail if sort param specified on unknown column" do
    Item.create! :name => "Hello"
    get_json :item_grid_data, :sort => "foo"
  end
  
  test "Should not fail if sort field for column is unknown" do
    get :item_with_custom_column_grid_data, :sort => "col_1"
  end
  
private
  def get_json(*args)
    response = get(*args)
    assert_response :success
    ActiveSupport::JSON::decode(response.body)
  end
end