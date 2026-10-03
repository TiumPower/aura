# Ghi lại việc gửi OTP: nhà cung cấp nào đã gửi, gửi được lúc nào, lỗi gì nếu
# không gửi được. Trước đây mã OTP chỉ được log, nên khi khách bảo "không nhận
# được mã" thì không có cách nào biết là do đâu.
#
# Bảng này đã đúng shape `identifier` + `channel` (hai app kia vừa được đưa về
# theo nó), nên chỉ cần thêm ba cột theo dõi.
class AddDeliveryTrackingToOtpChallenges < ActiveRecord::Migration[7.2]
  def change
    add_column :otp_challenges, :delivered_at,      :datetime
    add_column :otp_challenges, :delivery_provider, :string
    add_column :otp_challenges, :delivery_error,    :string
  end
end
