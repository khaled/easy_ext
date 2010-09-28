module EasyExt
  #
  #  Handles data rendering for an Ext JS grid.
  #
  class Grid

    #
    # Options:
    # * <tt>:scope</tt> - A proc that returns an ActiveRecord scope, or something that
    #   quacks like one.  The proc is evaluated with controller scope so that it can,
    #   for example, have access to controller params.
    #
    #   Example:
    #     :scope => lambda { Item.where(:value => params[:value]) }
    #
    def initialize(name, options={}, &config_proc)
      verify_options(options)
      @name = name
      @options = options
      @columns = []
      default_sort_table nil
      row_id { |item| item.id }
      instance_eval(&config_proc) if config_proc
    end

    #
    # Define a column. Example:
    #   renders_ext_grid :item do
    #     column :name, :option1 => "value1", :option2 => "value2"
    #     column { |record| compute_some_value_with(record) }
    #   end
    #
    # In the first form, the first argument is the name of a message that the records respond to.
    # 
    # In the second form, the block is handed a record at render time, and can return any value
    # for the grid cell.
    #   
    # Options:
    # * <tt>:label</tt> -
    #   (optional) a header label for the column; default is camelized version of column
    #   name when first form is used, and system generated name if second form is used.
    # * <tt>:sort</tt>  -
    #   (optional) column name to use for ordering purposes - only necessary in the second
    #   form OR if the sort field is different from the one used for display.
    # * <tt>:width</tt> - 
    #   (optional) width of the column.  Default is 100.
    #
    def column(*args, &block)
      column = {}    
      column[:message] = args[0] if (args[0].is_a? Symbol)
      @current_id ||= 0
      column[:id] = column[:message] || "col_#{@current_id += 1}".to_sym
      options = args[0].is_a?(Hash) ? args[0] : args[1]
      if options.is_a? Hash
        verify_column_options(options)
        column.merge!(options) if options.is_a? Hash
      end
      column[:label] ||= column[:message].to_s.humanize if column[:message]
      column[:proc] = block
      @columns << column
    end
    
    #
    # Define a proc to be used for computation of the id for each row
    #
    def row_id(&block)
      @row_id_proc = block
    end
  
    #
    # Delegate message sends to an association object
    # identified by sym.  For example, if you have 
    # delegate_to :foo and column :attr, the value for 
    # that column for a given record will be record.foo.attr
    #
    # Options:
    # * <tt>:exclude</tt> -
    #   An array of column names that should be exclude from delegation.
    #
    def delegate_to(message, options={})
      @delegate_to = message
      @delegate_to_options = options.dup
    end
  
    def default_sort_table(model)
      @sort_table = model ? "#{model.to_s.pluralize}." : ""
    end
  
    #
    # Returns Ext JS style metadata for the grid.  Example:
    #  { 
    #    'column_model' => [{"header"=>"Name", "sortable"=>true, "dataIndex"=>"name", "width"=>100}],
    #    'column_mappings' => [{"name"=>"name", "mapping"=>"name"}],
    #    'data_url' => "http://test.host/item/item_grid_data"
    #  }
    #
    def metadata(controller, id = nil)
      build_metadata(controller, id)
    end

    #
    # Return Ext JS style data for the grid.
    # 
    def data(controller)
      records, count = find_records(controller)
      return_data = { :total => count }
      return_data[:records] = records.map { |record| compute_row_for(record, controller) }
      return_data
    end
  
    #
    # Adds actions for this grid to the given controller class.
    #
    def add_controller_actions(controller_class)
      grid = self
      grid_method_name = "#{@name}_grid".to_sym
      controller_class.send(:define_method, grid_method_name) { grid }
      controller_class.send(:private, grid_method_name)
      controller_class.send(:define_method, metadata_method_name.to_sym) do
        render :text => grid.metadata(self).to_json, :layout => false
      end
      controller_class.send(:define_method, data_method_name.to_sym) do
        render :text => grid.data(self).to_json, :layout => false
      end
    end
  
    private
    
      def verify_options(options)
        options.each do |k, v|
          unless [:scope].include?(k)
            raise ArgumentError, "Unknown option: #{k}"
          end
        end
      end
    
      def verify_column_options(options)
        options.each do |k, v|
          unless [:label, :sort, :sortable, :width].include?(k)
            raise ArgumentError, "Unknown column option: #{k}"
          end
        end
      end

      def metadata_method_name
        "#{@name}_grid_metadata"
      end
    
      def data_method_name
        "#{@name.to_s}_grid_data"
      end
  
      def compute_row_for(record, controller)
        result = {}
        @columns.each do |column|
          result[column[:id]] = compute_column_value(column, record, controller)
        end
        result[:id] = row_id_for(record)
        result
      end

      def compute_column_value(column, record, controller)
        if column[:proc] 
          controller.instance_exec(record, &column[:proc])
        else
          if @delegate_to and not (@delegate_to_options[:except] || []).include?(column[:id])
            record = record.send(@delegate_to)
          end
          record.send(column[:message])
        end
      end
    
      def build_metadata(controller, id)
        result = { :data_url => data_url(controller, id) }
        result[:column_mappings] = @columns.map do |column|
          {:name => column[:id], :mapping => column[:id]}
        end
        meta_columns = @columns.reject { |c| c[:exclude] }
        result[:column_model] = meta_columns.map do |column|
          { :header => column[:label], :dataIndex => column[:id], :width => (column[:width] || 100), 
            :sortable => column[:sortable] != false }
        end
        result
      end
    
      def find_records(controller)
        scope = compute_initial_scope(controller)
        scope = scope_with_sort_options(scope, controller)
        scope = scope_with_paging_options(scope, controller)
        [scope, scope.count]
      end
    
      def compute_initial_scope(controller)
        if @options[:scope]
          if @options[:scope].is_a? Proc
            controller.instance_eval(&@options[:scope])
          else
            @options[:scope]
          end
        else
          @name.to_s.singularize.camelize.constantize.scoped
        end
      end
    
      def scope_with_sort_options(scope, controller)
        sort_options = sort_options(controller.params)
        if sort_options
          scope = scope.order("#{sort_options[:attribute]} #{sort_options[:direction]}")
        end
        scope
      end
    
      def scope_with_paging_options(scope, controller)
        params = controller.params
        scope = scope.offset(params[:start].to_i) if params[:start]
        scope = scope.limit(params[:limit].to_i) if params[:limit]
        scope
      end

      def strip_nil(val)
        val.nil? ? "" : val
      end

      def row_id_for(record)
        @row_id_proc ? @row_id_proc.call(record).to_s : ""
      end
    
      def find_sort_column(params)
        return nil unless params[:sort]
        @columns.find { |c| c[:id] == params[:sort].to_sym }
      end
    
      def sort_options(params)
        column = find_sort_column(params)
        return nil unless column
        attribute = if column[:sort]
          column[:sort]
        elsif column[:message]
          (@sort_table + column[:message].to_s)
        end
        if attribute
          direction = params[:dir] == "ASC" ? "ASC" : "DESC"
          { :attribute => attribute, :direction => direction }
        else
          nil
        end
      end
    
      def data_url(controller, id)
        controller.url_for(:controller => controller.class.controller_name,
          :action => data_method_name, :id => id)
      end
  end
end
