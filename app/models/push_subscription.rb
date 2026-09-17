class PushSubscription < ApplicationRecord
  acts_as_tenant(:workspace)

  belongs_to :workspace
  belongs_to :member, optional: true
  belongs_to :user,   optional: true

  validates :endpoint, :p256dh, :auth, presence: true
end
