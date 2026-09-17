# Dấu của mỗi lần trừ (hoặc hoàn) buổi trong thẻ.
class PackageCreditUse < ApplicationRecord
  acts_as_tenant(:workspace)

  belongs_to :workspace
  belongs_to :package_credit

  scope :recent, -> { order(used_at: :desc) }

  def restored? = sessions.to_i.negative?
end
