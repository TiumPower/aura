# Hạng thành viên do từng spa tự định nghĩa. `auto_assign` = tự nâng hạng khi
# khách đạt ngưỡng chi tiêu / số lượt; tắt đi thì chỉ nâng tay.
class MemberTier < ApplicationRecord
  acts_as_tenant(:workspace)

  belongs_to :workspace
  has_many :members, dependent: :nullify

  validates :key, :name, presence: true
  validates :key, uniqueness: { scope: :workspace_id }
  validates :discount_percent, numericality: { in: 0..100 }

  scope :ordered, -> { order(:position, :min_spent) }
  scope :auto,    -> { where(auto_assign: true) }

  before_validation :default_key, on: :create

  PRESETS = [
    { key: "member",   name: "Thành viên", min_spent: 0,          discount_percent: 0,  points_multiplier: 1.0, color: "#9AA5A1", position: 0 },
    { key: "silver",   name: "Bạc",        min_spent: 5_000_000,   discount_percent: 5,  points_multiplier: 1.2, color: "#A9B0B5", position: 1 },
    { key: "gold",     name: "Vàng",       min_spent: 15_000_000,  discount_percent: 10, points_multiplier: 1.5, color: "#C9A96A", position: 2 },
    { key: "platinum", name: "Bạch kim",   min_spent: 40_000_000,  discount_percent: 15, points_multiplier: 2.0, color: "#6A4C93", position: 3 }
  ].freeze

  def discount_label = discount_percent.zero? ? "—" : "-#{discount_percent}%"

  # Hạng cao nhất mà khách đủ điều kiện.
  def self.best_for(workspace, spent:, visits:)
    ordered.auto.where("min_spent <= ? AND min_visits <= ?", spent.to_i, visits.to_i).last
  end

  private

  def default_key
    self.key ||= name.to_s.parameterize(separator: "_").presence || SecureRandom.hex(3)
  end
end
