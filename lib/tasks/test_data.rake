# Dựng lại toàn bộ dữ liệu test của Aura.
#
#   bin/rails aura:test_data PASSWORD='...'            # dev
#   cap production deploy:test_data PASSWORD='...'     # production (cần CONFIRM=yes)
#
# Phá huỷ: mọi workspace (spa) và toàn bộ dữ liệu bên trong bị xoá rồi dựng lại
# từ db/seeds.rb, cộng thêm tài khoản cho MỌI vai trò nhân sự. AdminUser được
# GIỮ — chỉ đặt lại mật khẩu để tài khoản còn dùng được.
namespace :aura do
  desc "Xoá mọi spa rồi dựng bộ dữ liệu test đầy đủ. ENV: PASSWORD, CONFIRM"
  task test_data: :environment do
    password = ENV["PASSWORD"].to_s.dup.force_encoding("UTF-8").presence ||
               abort("✗ Cần PASSWORD='<mật khẩu ≥12 ký tự>'.")
    abort("✗ PASSWORD phải dài ít nhất 12 ký tự (đang #{password.length}).") if password.length < 12
    if Rails.env.production? && ENV["CONFIRM"] != "yes"
      abort("✗ Production: chạy lại với CONFIRM=yes để xác nhận XOÁ toàn bộ spa hiện có.")
    end

    ADMIN_EMAIL = "quocvietlee@gmail.com".freeze

    # Thứ tự xoá đi từ lá lên gốc: bảng nào trỏ tới bảng khác thì đứng trước.
    CHILD_TABLES = %w[
      PackageCreditUse PackageCredit MemberPackage PackageLine
      OrderPayment OrderItem Order CommissionEntry WalletTransaction PointTransaction
      BookingItem BookingHold Booking
      StaffService StaffShift ShiftTemplate StaffBranch
      ServicePrice ServiceVariant Service ServiceCategory Package
      Message Conversation Notification Broadcast PushSubscription Expense AuditLog
      Room BranchHour BranchClosure
      Invoice OtpChallenge
    ].freeze

    ActsAsTenant.without_tenant do
      puts "⚠  Xoá toàn bộ spa hiện có…"
      Workspace.find_each do |ws|
        ActsAsTenant.with_tenant(ws) do
          CHILD_TABLES.each do |name|
            klass = name.safe_constantize or next
            next unless klass.column_names.include?("workspace_id")
            klass.where(workspace_id: ws.id).delete_all
          end
          # members.preferred_staff_id trỏ tới staff_members → gỡ trước khi xoá.
          Member.where(workspace_id: ws.id).delete_all
          StaffMember.where(workspace_id: ws.id).delete_all
          Membership.where(workspace_id: ws.id).delete_all
          Branch.where(workspace_id: ws.id).delete_all
          ws.destroy!
        end
      end
      User.left_joins(:memberships).where(memberships: { id: nil }).destroy_all
      puts "   ✓ Đã xoá. Còn #{Workspace.count} spa, #{User.count} tài khoản, #{Member.count} khách."

      admin = AdminUser.find_or_initialize_by(email: ADMIN_EMAIL)
      admin.assign_attributes(name: "Quốc Việt", role: "superadmin",
                              password: password, password_confirmation: password)
      admin.save!
      puts "   ✓ Super Admin #{ADMIN_EMAIL} (đặt lại mật khẩu)"
    end

    # ---- Dựng lại spa demo bằng chính db/seeds.rb --------------------------
    ENV["SEED_PASSWORD"] = password
    load Rails.root.join("db/seeds.rb")

    ActsAsTenant.without_tenant do
      ws = Workspace.find_by(subdomain: "auraspa")
      abort("✗ Seed không tạo được spa demo.") unless ws

      ActsAsTenant.with_tenant(ws) do
        # ---- Tài khoản cho MỌI vai trò còn thiếu ---------------------------
        # Seed đã tạo chủ spa (owner) và lễ tân (receptionist).
        main = ws.branches.order(:id).first
        [{ email: "quanly@aura.local",  name: "Vũ Thị Quản Lý", role: "manager" },
         { email: "ketoan@aura.local",  name: "Đỗ Văn Kế Toán", role: "accountant" },
         { email: "ktv@aura.local",     name: "Nguyễn Thị Lan (KTV)", role: "therapist" }].each do |spec|
          u = User.find_or_initialize_by(email: spec[:email])
          u.assign_attributes(name: spec[:name], locale: "vi",
                              password: password, password_confirmation: password)
          u.save!
          ws.memberships.find_or_create_by!(user: u) { |m| m.role = spec[:role]; m.branch = main }
        end

        # Đặt lại mật khẩu cho hai tài khoản seed đã tạo từ trước (nếu có).
        %w[chu@aura.local letan@aura.local].each do |email|
          u = User.find_by(email: email) or next
          u.update!(password: password, password_confirmation: password)
        end

        puts "   ✓ #{ws.name} (#{ws.subdomain}) — #{ws.branches.count} cơ sở · #{ws.rooms.count} phòng · " \
             "#{ws.memberships.count} tài khoản nhân sự · #{ws.staff_members.count} nhân sự · " \
             "#{ws.members.count} khách · #{ws.bookings.count} lịch hẹn · #{ws.orders.count} bill"
      end

      AppSetting.set_flag(AppSetting::SHOW_OTP_CUSTOMER_KEY, true)
      AppSetting.set_flag(AppSetting::SHOW_OTP_STAFF_KEY, true)
      puts "   ✓ Đã BẬT hiện mã OTP (khách + nhân sự) — tắt tại /admin/settings"
      puts "\n✅ Xong: #{Workspace.count} spa · #{User.count} tài khoản nhân sự · #{Member.count} khách."
    end
  end
end
