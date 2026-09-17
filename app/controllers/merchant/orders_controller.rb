module Merchant
  # Quầy thu ngân. Mọi thay đổi về tiền đi qua `Checkout` — controller chỉ nhận
  # tham số và báo lỗi, không tự cộng trừ.
  class OrdersController < BaseController
    before_action :require_front_desk!, except: [:index, :show, :receipt]
    before_action :set_order, only: [:show, :update, :add_item, :remove_item, :discount,
                                     :pay, :close, :void, :receipt, :qr]

    def index
      @date = parse_date(params[:date]) || Date.current
      scope = by_branch(current_workspace.orders.includes(:member, :branch, :order_items))
      @open_orders = scope.open.recent.to_a
      @closed = scope.where(status: %w[paid void refunded])
                     .closed_between(@date.beginning_of_day, @date.end_of_day)
                     .recent.to_a
      paid = @closed.select(&:paid?)
      @totals = {
        count: paid.size,
        revenue: paid.sum(&:total),
        tips: paid.sum(&:tip_total),
        by_method: OrderPayment.where(order_id: paid.map(&:id)).group(:method).sum(:amount),
        atv: paid.any? ? (paid.sum(&:total) / paid.size) : 0
      }
      @branches = current_workspace.branches.ordered.to_a
    end

    def show
      load_pos_options
    end

    # Mở bill từ một lịch hẹn (nút "Thu tiền" ở quầy).
    def open_for_booking
      booking = current_workspace.bookings.find(params[:booking_id])
      result = Checkout.open_for_booking(booking: booking, actor: current_user)
      if result.ok?
        audit!("order.open", target: result.order, summary: "#{result.order.code} ← hẹn #{booking.code}")
        redirect_to merchant_order_path(result.order)
      else
        redirect_to merchant_booking_path(booking), alert: result.error
      end
    end

    # Bill trắng: khách chỉ mua thẻ / nạp ví / mua hàng.
    def open_blank
      branch = current_workspace.branches.find(params[:branch_id].presence || current_branch&.id ||
                                               current_workspace.branches.active.first&.id)
      member = current_workspace.members.find_by(id: params[:member_id])
      result = Checkout.open_blank(branch: branch, member: member, actor: current_user)
      audit!("order.open_blank", target: result.order, summary: result.order.code)
      redirect_to merchant_order_path(result.order)
    end

    def add_item
      return reject("Bill đã đóng.") unless @order.open?
      case params[:kind]
      when "service"
        service = current_workspace.services.find(params[:service_id])
        variant = service.service_variants.find_by(id: params[:service_variant_id])
        staff   = current_workspace.staff_members.find_by(id: params[:staff_member_id])
        Checkout.add_service(order: @order, service: service, variant: variant, staff: staff,
                             use_package: params[:use_package] != "0")
      when "package"
        pkg = current_workspace.packages.find(params[:package_id])
        consultant = current_workspace.staff_members.find_by(id: params[:consultant_id])
        return reject("Bán thẻ cần gắn bill với một khách.") if @order.member.nil?
        Checkout.add_package(order: @order, package: pkg, consultant: consultant)
      when "topup"
        return reject("Nạp ví cần gắn bill với một khách.") if @order.member.nil?
        amount = params[:amount].to_i
        min = @order.branch.setting_i("wallet_min_topup")
        if min.positive? && amount < min
          return reject("Nạp ví tối thiểu #{helpers.number_with_delimiter(min)}đ.")
        end
        Checkout.add_topup(order: @order, amount: amount,
                           consultant: current_workspace.staff_members.find_by(id: params[:consultant_id]))
      when "tip"
        staff = current_workspace.staff_members.find_by(id: params[:staff_member_id])
        return reject("Chọn KTV nhận tip.") if staff.nil?
        Checkout.add_tip(order: @order, amount: params[:amount].to_i, staff: staff)
      when "fee"
        Checkout.add_fee(order: @order, name: params[:name].presence || "Phụ phí",
                         amount: params[:amount].to_i)
      end
      redirect_to merchant_order_path(@order)
    end

    def remove_item
      return reject("Bill đã đóng.") unless @order.open?
      item = @order.order_items.find(params[:item_id])
      Checkout.remove_item(order: @order, item: item)
      redirect_to merchant_order_path(@order), notice: "Đã bỏ dòng khỏi bill."
    end

    def discount
      return reject("Bill đã đóng.") unless @order.open?
      Checkout.apply_discount(order: @order, amount: params[:amount].presence&.to_i,
                              percent: params[:percent].presence&.to_f,
                              note: params[:note].presence)
      audit!("order.discount", target: @order,
             summary: "#{@order.code} −#{@order.discount_total} (#{params[:note]})")
      redirect_to merchant_order_path(@order), notice: "Đã áp giảm giá."
    end

    def pay
      return reject("Bill đã đóng.") unless @order.open?
      result = Checkout.pay(order: @order, method: params[:method], amount: params[:amount].to_i,
                            reference: params[:reference].presence, actor: current_user,
                            note: params[:note].presence)
      if result.ok?
        audit!("order.pay", target: @order, summary: "#{@order.code} #{params[:method]} #{params[:amount]}")
        # Thu đủ rồi thì đóng luôn — bớt một cú bấm ở quầy lúc đông khách.
        if @order.reload.settled? && params[:auto_close] != "0"
          closed = Checkout.close!(order: @order, actor: current_user)
          return redirect_to(merchant_order_path(@order), alert: closed.error) unless closed.ok?
          audit!("order.close", target: @order, summary: "#{@order.code} #{@order.total}")
          return redirect_to merchant_order_path(@order), notice: "Đã thu đủ và đóng bill #{@order.code}."
        end
        redirect_to merchant_order_path(@order), notice: "Đã ghi nhận #{result.order.payment_summary.values.sum} đ."
      else
        redirect_to merchant_order_path(@order), alert: result.error
      end
    end

    def close
      result = Checkout.close!(order: @order, actor: current_user)
      if result.ok?
        audit!("order.close", target: @order, summary: "#{@order.code} #{@order.total}")
        redirect_to merchant_order_path(@order), notice: "Đã đóng bill #{@order.code}."
      else
        redirect_to merchant_order_path(@order), alert: result.error
      end
    end

    def void
      return redirect_to(merchant_order_path(@order), alert: "Chỉ chủ spa/quản lý huỷ được bill.") unless current_membership&.can_manage?
      result = Checkout.void!(order: @order, actor: current_user, reason: params[:reason].presence)
      audit!("order.void", target: @order, summary: "#{@order.code} · #{params[:reason]}")
      redirect_to merchant_order_path(@order),
                  notice: result.ok? ? "Đã huỷ bill (đã hoàn buổi/ví/điểm nếu có)." : nil,
                  alert: result.error
    end

    def receipt
      render layout: "print"
    end

    # VietQR đúng số tiền còn thiếu — khách quét là chuyển đúng số.
    def qr
      unless current_workspace.bank_configured?
        return redirect_to merchant_payment_settings_path,
          alert: "Chưa nhập tài khoản nhận tiền nên chưa tạo được mã VietQR."
      end
      payload = VietQrService.new(
        bin: current_workspace.bank_bin, account_no: current_workspace.bank_account_no,
        amount: @order.due, description: "Bill #{@order.code}"
      ).payload
      send_data helpers.qr_png(payload), type: "image/png", disposition: "inline",
                filename: "vietqr-#{@order.code}.png"
    end

    def update
      if @order.update(order_params)
        redirect_to merchant_order_path(@order), notice: "Đã lưu ghi chú."
      else
        load_pos_options
        render :show, status: :unprocessable_entity
      end
    end

    private

    def set_order
      @order = current_workspace.orders.includes(:order_items, :order_payments, :member, :branch)
                                .find(params[:id])
    end

    def load_pos_options
      @services = current_workspace.services.active.ordered.to_a
      @packages = current_workspace.packages.active.ordered.to_a
      @staff    = current_workspace.staff_members.active.at_branch(@order.branch_id).ordered.to_a
      @members  = current_workspace.members.active.order(last_visit_at: :desc).limit(40).to_a
      @cards    = @order.member ? @order.member.member_packages.usable.recent.to_a : []
    end

    def reject(message)
      redirect_to merchant_order_path(@order), alert: message
    end

    def order_params = params.require(:order).permit(:note, :member_id)

    def parse_date(str)
      return nil if str.blank?
      Date.parse(str.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def nav_key = :orders
  end
end
