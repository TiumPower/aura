# Mã OTP đăng nhập. Hai cổng dùng hai kênh khác nhau:
#   scope "merchant" — nhân sự/chủ spa, định danh bằng email
#   scope "customer" — khách hàng, định danh bằng SỐ ĐIỆN THOẠI (khách spa
#                      không nhớ email, và SĐT chính là khoá hồ sơ CRM)
class OtpChallenge < ApplicationRecord
  TTL = 10.minutes
  MAX_ATTEMPTS = 5
  SCOPES   = %w[merchant customer].freeze
  CHANNELS = %w[email sms zalo].freeze

  belongs_to :workspace, optional: true

  validates :identifier, :code, presence: true
  validates :scope,   inclusion: { in: SCOPES }
  validates :channel, inclusion: { in: CHANNELS }

  scope :active, -> { where(consumed_at: nil).where("expires_at > ?", Time.current) }

  # Phát (hoặc phát lại) mã đăng nhập.
  def self.issue!(identifier:, scope: "merchant", workspace: nil, purpose: "login", channel: nil)
    ident = normalize(identifier, scope)
    channel ||= scope == "customer" ? "sms" : "email"
    code = format("%06d", SecureRandom.random_number(1_000_000))
    challenge = create!(identifier: ident, scope: scope, channel: channel,
                        workspace: workspace, purpose: purpose,
                        code: code, expires_at: TTL.from_now)
    challenge.deliver!
    challenge
  end

  def self.latest_for(identifier:, scope: "merchant", workspace: nil)
    where(identifier: normalize(identifier, scope), scope: scope, workspace_id: workspace&.id)
      .order(created_at: :desc).first
  end

  def self.normalize(identifier, scope)
    scope == "customer" ? Member.canonical_phone(identifier).to_s : identifier.to_s.strip.downcase
  end

  # Gửi mã. Email đi qua mailer khi đã cấu hình; SMS/Zalo chưa nối cổng gửi nên
  # mã hiện trên màn hình (dev) và ghi log — KHÔNG im lặng làm như đã gửi.
  def deliver!
    case channel
    when "email"
      if EmailOtp.configured?
        OtpMailer.login_code(self).deliver_later
        Rails.logger.info("[OTP] scope=#{scope} #{identifier} (đã gửi email)")
      else
        Rails.logger.info("[OTP] scope=#{scope} #{identifier} code=#{code} (hiện trên màn hình)")
      end
    else
      Rails.logger.info("[OTP] scope=#{scope} #{identifier} code=#{code} channel=#{channel} (chưa nối cổng SMS/Zalo → hiện trên màn hình)")
    end
  end

  # Mã có được phép hiện thẳng trên màn hình hay không (khi chưa có cổng gửi).
  def show_on_screen?
    channel != "email" || !EmailOtp.configured?
  end

  def verify(input)
    return :expired if expires_at < Time.current || consumed_at.present?
    increment!(:attempts)
    return :too_many if attempts > MAX_ATTEMPTS
    return :mismatch unless ActiveSupport::SecurityUtils.secure_compare(code, input.to_s)
    update!(consumed_at: Time.current)
    :ok
  end
end
