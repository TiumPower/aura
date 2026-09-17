# Giá riêng của một dịch vụ tại một cơ sở (chi nhánh trung tâm bán cao hơn).
class ServicePrice < ApplicationRecord
  acts_as_tenant(:workspace)

  belongs_to :workspace
  belongs_to :service
  belongs_to :branch
  belongs_to :service_variant, optional: true

  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :service_id, uniqueness: { scope: [:branch_id, :service_variant_id] }
end
