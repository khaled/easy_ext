module EasyExt
  module ControllerExtensions
    def self.included(base)
      base.extend ClassMethods
    end
  
    module ClassMethods
      def renders_ext_grid(name, options={}, &proc)
        table = EasyExt::Grid.new(name, options, &proc)
        table.add_controller_actions(self)
      end
      
      def renders_ext_tree(name, options={}, &proc)
        tree = EasyExt::Tree.new(name, options, &proc)
        tree.add_controller_action(self)
      end
    end
  end
end

ActionController::Base.send :include, EasyExt::ControllerExtensions