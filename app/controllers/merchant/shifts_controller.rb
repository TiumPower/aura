module Merchant
  # Bảng ca làm: một tuần, một cơ sở, tất cả KTV trên cùng một màn hình. Ca thật
  # ở đây là nguồn duy nhất để engine biết KTV nào nhận được khách.
  class ShiftsController < BaseController
    before_action :require_manager!, only: [:create, :destroy, :generate]

    def index
      @week_start = parse_date(params[:week]) || Date.current.beginning_of_week
      @week_start = @week_start.beginning_of_week
      @days  = (@week_start..(@week_start + 6)).to_a
      @staff = current_workspace.staff_members.active.at_branch(current_branch&.id).ordered.to_a
      rows = current_workspace.staff_shifts
                              .where(staff_member_id: @staff.map(&:id))
                              .between(@days.first, @days.last)
      rows = rows.where(branch_id: current_branch.id) if current_branch
      # [staff_id][date] → các ca của ngày đó
      @grid = rows.each_with_object({}) do |s, h|
        (h[s.staff_member_id] ||= {})[s.work_date] ||= []
        h[s.staff_member_id][s.work_date] << s
      end
      @totals = rows.group_by(&:staff_member_id).transform_values { |list|
        list.select(&:working?).sum(&:hours).round(1)
      }
      @branches = current_workspace.branches.ordered.to_a
    end

    def create
      staff = current_workspace.staff_members.find(params[:staff_member_id])
      date  = parse_date(params[:work_date]) || Date.current
      kind  = StaffShift::KINDS.include?(params[:kind]) ? params[:kind] : "shift"
      from, to = params[:starts_at].presence || "09:00", params[:ends_at].presence || "21:00"
      shift = current_workspace.staff_shifts.new(
        staff_member: staff, branch_id: params[:branch_id].presence || staff.branch_id,
        work_date: date, kind: kind, created_by: current_user,
        starts_at: combine(date, from), ends_at: combine(date, to)
      )
      if shift.save
        audit!("shift.create", target: shift, summary: "#{staff.display_name} #{date} #{from}-#{to}")
        redirect_to merchant_shifts_path(week: date.beginning_of_week, branch_id: current_branch&.id),
                    notice: "Đã xếp ca cho #{staff.display_name}."
      else
        redirect_to merchant_shifts_path(week: date.beginning_of_week),
                    alert: shift.errors.full_messages.to_sentence
      end
    end

    def destroy
      shift = current_workspace.staff_shifts.find(params[:id])
      week = shift.work_date.beginning_of_week
      shift.destroy
      redirect_to merchant_shifts_path(week: week, branch_id: current_branch&.id), notice: "Đã xoá ca."
    end

    # Sinh ca cho một tuần từ mẫu tuần. Ca đã sửa tay KHÔNG bị ghi đè.
    def generate
      week = parse_date(params[:week]) || Date.current.beginning_of_week
      week = week.beginning_of_week
      scope = current_workspace.staff_members.active.at_branch(current_branch&.id)
      count = StaffShift.generate_from_templates!(current_workspace, from: week, to: week + 6, staff_scope: scope)
      audit!("shift.generate", summary: "tuần #{week}: #{count} ca")
      redirect_to merchant_shifts_path(week: week, branch_id: current_branch&.id),
                  notice: count.positive? ? "Đã sinh #{count} ca từ mẫu tuần." :
                                            "Không có ca nào được sinh — hãy khai mẫu ca cho KTV trước."
    end

    private

    def parse_date(str)
      return nil if str.blank?
      Date.parse(str.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def combine(date, hhmm)
      h, m = hhmm.to_s.split(":").map(&:to_i)
      Time.zone.local(date.year, date.month, date.day, h || 0, m || 0)
    end

    def nav_key = :shifts
  end
end
