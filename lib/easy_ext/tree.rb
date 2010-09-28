module EasyExt
  #
  # Handles data rendering for an Ext JS tree.
  #
  class Tree

    #
    # Options:
    # * <tt>:root_scope</tt> -
    #   (optional) A scope or a lambda that returns a scope
    # * <tt>:stable_ids</tt> -
    #  
    def initialize(name, options, &config_proc)
      @name = name
      @options = options
      instance_eval(&config_proc) if config_proc
    end
    
    #
    # Specify a tree node for a particular object type.  <tt>name</tt> should be
    # a symbol representing the model to query for data.
    #
    # Options:
    # * <tt>:text</tt> -
    #   (optional, sort of) Text to display for the node.  Can be a symbol identifying
    #   an attribute to use for the node label, or a proc that is evaluated with controller
    #   context.  Defaults to the class name of the 
    # * <tt>:children</tt> -
    #   (optional)
    # * <tt>:qtip</tt> -
    #   (optional)
    # * <tt>:icon</tt> -
    #   (optional)
    #
    def node(name, options={})
      @nodes ||= {}
      @nodes[name] = options
    end
    
    def get_data(controller, params)
      records = compute_records(controller, params)
      records.map do |x|
        underscore_name = x.class.name.underscore
        node_options = @nodes[underscore_name.to_sym]
        # default node text to class name
        node_options ||= { :text => Proc.new { |x| x.class.name } }
        id_prefix = @options[:stable_ids] ? x.id : x.object_id.abs
        node = { 
          :id => "#{id_prefix}-#{underscore_name}-#{x.id}", 
          :object_id => x.id, 
          :object_type => underscore_name 
        }
        node[:leaf] = true unless node_options[:children]
        [:qtip, :text, :icon].each do |attribute|
          value = invoke_or_send(controller, x, node_options[attribute]) if node_options[attribute]
          node[attribute] = value.to_s
        end
        data = node_options[:data] || {}
        data.each do |key, val|
          node[key] = invoke_or_send(controller, x, val) 
        end
        node
      end
    end
    
    def add_controller_action(controller_class)
      tree = self
      controller_class.send(:define_method, "#{@name}_tree_data".to_sym) do
        render :text => tree.get_data(self, params).to_json
      end
    end
    
    private

    def invoke_or_send(controller, x, proc_or_symbol)
      case proc_or_symbol
        when Proc then controller.instance_exec(x, &proc_or_symbol)
        when Method then proc_or_symbol.call(x)
        when Symbol then x.send(proc_or_symbol)
        else proc_or_symbol
      end
    end
  
    def compute_records(controller, params)
      node_id = params[:node]
      return [] unless node_id
      if (node_id == "root")
        compute_root_records
      else
        id_prefix, model_name, id = node_id.split("-")
        model_class = model_name.to_s.camelize.constantize
        children_method = @nodes[model_name.to_sym][:children]
        children_method ? 
          invoke_or_send(controller, model_class.find(id.to_i), children_method) :
          []
      end
    end
    
    def compute_root_records
      roots = @options[:roots]
      if roots
        if roots.is_a?(Proc) 
          controller.instance_eval(&roots) 
        else
          roots.to_s.camelize.constantize.all
        end
      else
        @name.to_s.camelize.constantize.all
      end
    end
    
  end
end