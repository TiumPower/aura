# "n buổi dịch vụ X" trong một gói.
class PackageLine < ApplicationRecord
  acts_as_tenant(:workspace)

  belongs_to :workspace
  belongs_to :package
  belongs_to :service
  belongs_to :service_variant, optional: true

  validates :sessions, numericality: { greater_than: 0 }

  def unit_price = service.price_for(service_variant)
  def label = "#{sessions} buổi #{service.name}#{service_variant ? " #{service_variant.name}" : ''}"
end
