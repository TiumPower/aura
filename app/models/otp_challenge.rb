# Mã OTP đăng nhập. Hai cổng dùng hai cách định danh khác nhau:
#   scope "merchant" — nhân sự/chủ spa, định danh bằng email
#   scope "customer" — khách hàng, định danh bằng SỐ ĐIỆN THOẠI (khách spa
#                      không nhớ email, và SĐT chính là khoá hồ sơ CRM)
#
# `channel` ghi lại mình đã gửi mã qua đường nào, và ba cột `delivery_*` ghi
# kết quả gửi — để khi khách bảo "không nhận được mã" thì có cái mà tra.
class OtpChallenge < ApplicationRecord
  TTL           = 10.minutes
  MAX_ATTEMPTS  = 5
  SCOPES        = %w[merchant customer].freeze
  DEFAULT_SCOPE = "merchant"
  CHANNELS      = %w[email sms zalo].freeze

  belongs_to :workspace, optional: true

  validates :identifier, :code, presence: true
  validates :scope,   inclusion: { in: SCOPES }
  validates :channel, inclusion: { in: CHANNELS }

  scope :active, -> { where(consumed_at: nil).where("expires_at > ?", Time.current) }

  # Phát (hoặc phát lại) mã đăng nhập. Cổng nhân sự ghim `channel: "email"`:
  # họ định danh bằng email và không có workspace để tra SĐT.
  def self.issue!(identifier:, scope: DEFAULT_SCOPE, workspace: nil,
                  purpose: "login", channel: nil)
    ident = normalize(identifier)
    challenge = create!(
      identifier: ident, scope: scope, workspace: workspace, purpose: purpose,
      channel: channel || pick_channel(identifier: ident, workspace: workspace),
      code: format("%06d", SecureRandom.random_number(1_000_000)),
      expires_at: TTL.from_now
    )
    challenge.deliver!
    challenge
  end

  def self.latest_for(identifier:, scope: DEFAULT_SCOPE, workspace: nil, purpose: "login")
    where(identifier: normalize(identifier), scope: scope,
          workspace_id: workspace&.id, purpose: purpose)
      .order(created_at: :desc).first
  end

  # Chuẩn hoá theo HÌNH DẠNG, không theo scope — để các app cùng dòng (nơi một
  # scope nhận cả email lẫn SĐT) dùng chung được đúng một hàm này.
  def self.normalize(identifier)
    raw = identifier.to_s.strip
    return raw.downcase if raw.include?("@")
    Member.canonical_phone(raw).presence || raw.downcase
  end

  # Email thì gửi email. SĐT thì gửi Zalo — nhưng CHỈ sau khi đã có một lần gửi
  # thật thành công (AppSetting "zns_verified_at"). Chưa chứng minh được thì ưu
  # tiên kênh đang chạy tốt, để việc set ENV không âm thầm lấy đi kênh email của
  # những khách đã khai email.
  def self.pick_channel(identifier:, workspace: nil)
    return "email" if identifier.to_s.include?("@")
    return "zalo"  if OtpSender.configured? && AppSetting.get("zns_verified_at").present?
    return "email" if EmailOtp.configured? && email_for_phone(identifier, workspace).present?
    "zalo"
  end

  def self.email_for_phone(phone, workspace)
    return nil if workspace.nil?
    Member.unscoped.where(workspace_id: workspace.id, phone: phone)
          .where.not(email: nil).pick(:email)
  end

  # Địa chỉ email nhận mã. Với khách, `identifier` là SĐT nên phải tra email
  # trong hồ sơ.
  def delivery_email
    return identifier if identifier.to_s.include?("@")
    return nil if workspace_id.blank?
    Member.unscoped.where(workspace_id: workspace_id, phone: identifier).pick(:email)
  end

  def deliver!
    if channel == "email"
      OtpMailer.login_code(self).deliver_later if deliverable?
    elsif OtpSender.configured?
      # Truyền id, KHÔNG truyền mã: mã nằm trong payload job là nằm luôn trong
      # Redis, trong retry set của Sidekiq và trong mọi báo lỗi của job đó.
      OtpDeliveryJob.perform_later(id)
    end
    Rails.logger.info(
      "[OTP] ws=#{workspace&.subdomain} scope=#{scope} channel=#{channel} " \
      "ident=#{log_identifier}#{" code=#{code}" if show_on_screen?}"
    )
  end

  # Có kênh nào gửi tới người này được hay không.
  def deliverable?
    if channel == "email"
      EmailOtp.configured? && delivery_email.present?
    else
      OtpSender.configured?
    end
  end

  # Mã chỉ được hiện thẳng trên màn hình khi người vận hành cố ý bật, hoặc khi
  # thật sự không có đường nào gửi.
  #
  # CỐ Ý không phụ thuộc `delivery_error`: nếu gửi lỗi mà lộ mã thì một lần nhà
  # cung cấp sập sẽ thành lỗ đăng nhập cho mọi tài khoản trên nền tảng.
  def show_on_screen?
    return true unless Rails.env.production?
    return true if operator_override?
    !deliverable?
  end

  def verify(input)
    return :expired if expires_at < Time.current || consumed_at.present?
    increment!(:attempts)
    return :too_many if attempts > MAX_ATTEMPTS
    return :mismatch unless ActiveSupport::SecurityUtils.secure_compare(code, input.to_s)
    update!(consumed_at: Time.current)
    :ok
  end

  private

  # Hai cờ RIÊNG, cố ý: bật cho cổng nhân sự là ai biết email một nhân viên
  # cũng vào được toàn bộ dữ liệu spa, còn khách chỉ thấy dữ liệu của chính họ.
  def operator_override?
    if scope == "customer"
      AppSetting.show_otp_customer? || ENV["SHOW_CUSTOMER_OTP"] == "true"
    else
      AppSetting.show_otp_staff? || ENV["SHOW_OTP"] == "true"
    end
  end

  # Chỉ log mã khi mã vốn đã hiện trên màn hình của người dùng; log được giữ
  # lại qua nhiều release, màn hình thì không.
  def log_identifier
    identifier.to_s.include?("@") ? identifier : PhoneFormat.mask(identifier)
  end
end
