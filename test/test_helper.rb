ENV['RAILS_ENV'] = 'test'

require 'rubygems'
require 'redgreen'
require 'rails_app/config/environment'
require 'rails/test_help'
require 'easy_ext'

def load_schema
  ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + "/debug.log")
  load(File.dirname(__FILE__) + "/schema.rb")
  load(File.dirname(__FILE__) + "/models.rb")
end

load_schema

class ActionController::TestCase
  private
    def get_json(*args)
      response = get(*args)
      assert_response :success
      ActiveSupport::JSON::decode(response.body)
    end
end
