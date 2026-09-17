# `orders.booking_id` là liên kết duy nhất giữa bill và lịch hẹn. Cột
# `bookings.order_id` là bản sao của cùng một sự thật — hai nguồn cho một sự
# thật thì sớm muộn lệch nhau, nên bỏ đi và đọc qua quan hệ has_one.
class DropBookingOrderId < ActiveRecord::Migration[7.2]
  def change
    remove_column :bookings, :order_id, :bigint
  end
end
