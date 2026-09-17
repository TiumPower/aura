# Giữ chỗ tạm trong lúc khách còn đang chọn trên app. Hết hạn thì tự hết hiệu
# lực — không có bảng này thì hai khách bấm cùng một slot trong cùng 30 giây
# đều được xác nhận và spa phải gọi điện xin lỗi một người.
class BookingHold < ApplicationRecord
  acts_as_tenant(:workspace)

  TTL = 8.minutes

  belongs_to :workspace
  belongs_to :branch
  belongs_to :room, optional: true
  belongs_to :staff_member, optional: true

  validates :token, :starts_at, :ends_at, :expires_at, presence: true

  scope :alive, -> { where("expires_at > ?", Time.current) }
  scope :room_busy, ->(room_id, from, to) {
    alive.where(room_id: room_id).where("starts_at < :to AND ends_at > :from", from: from, to: to)
  }
  scope :staff_busy, ->(staff_id, from, to) {
    alive.where(staff_member_id: staff_id).where("starts_at < :to AND ends_at > :from", from: from, to: to)
  }

  def self.place!(workspace:, branch:, room:, staff:, starts_at:, ends_at:)
    create!(workspace: workspace, branch: branch, room: room, staff_member: staff,
            starts_at: starts_at, ends_at: ends_at,
            token: SecureRandom.urlsafe_base64(16), expires_at: TTL.from_now)
  end

  def self.sweep!
    where("expires_at < ?", 1.hour.ago).delete_all
  end

  def expired? = expires_at < Time.current
end
