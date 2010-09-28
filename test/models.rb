class Item < ActiveRecord::Base
  has_many :orders
end

class Order < ActiveRecord::Base
  belongs_to :item
end
