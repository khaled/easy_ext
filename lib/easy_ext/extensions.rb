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
    end
  end
end

ActionController::Base.send :include, EasyExt::ControllerExtensions