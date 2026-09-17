module Admin
  class DashboardController < BaseController
    PRESETS = { "1m" => 1, "3m" => 3, "6m" => 6, "12m" => 12 }.freeze

    def show
      resolve_range
      range = @from.beginning_of_day..@to.end_of_day

      ActsAsTenant.without_tenant do
        # ---- Current snapshot (not range-dependent) ----
        @workspaces_count = Workspace.count
        @active_count     = Workspace.where(status: "active").count
        @trial_count      = Workspace.where(status: "trial").count
        @branches_count   = Branch.count
        @rooms_count      = Room.count
        @seats_count      = Room.where(status: "active").sum(:capacity)
        @staff_count      = StaffMember.where(status: "active").count
        @members_count    = Member.count
        @mrr = Workspace.where(status: "active").group(:plan).count
                        .sum { |plan, n| Plan.for(plan).price.to_i * n }

        # ---- Everything below follows the selected time range ----
        paid = Invoice.where(status: "paid", paid_at: range)
        @collected_range = paid.sum(:amount)
        @invoices_range  = paid.count
        @new_workspaces  = Workspace.where(created_at: range).count
        @new_customers   = Member.where(created_at: range).count

        @revenue_series  = monthly_series(Invoice.where(status: "paid"), :paid_at, :sum, :amount)
        @workspace_series = monthly_series(Workspace.all, :created_at, :count)
        @customer_series  = monthly_series(Member.all, :created_at, :count)

        @recent = Workspace.order(created_at: :desc).limit(6).to_a
      end
    end

    private

    def nav_key = :dashboard

    def resolve_range
      from = parse_date(params[:from])
      to   = parse_date(params[:to])
      if from && to
        @preset = nil
        @from, @to = [from, to].minmax
      else
        @preset = PRESETS.key?(params[:preset]) ? params[:preset] : "6m"
        months  = PRESETS[@preset]
        @to   = Date.current.end_of_month
        @from = (Date.current.beginning_of_month - (months - 1).months)
      end
    end

    def parse_date(str)
      return nil if str.blank?
      Date.parse(str)
    rescue ArgumentError, TypeError
      nil
    end

    # Monthly series over the selected [from, to] window (zero-filled).
    def monthly_series(scope, field, agg, col = nil)
      grp = scope.group_by_month(field, range: @from.beginning_of_month..@to.end_of_month)
      data = agg == :sum ? grp.sum(col) : grp.count
      data.map { |date, val| { label: I18n.l(date, format: "%m/%y"), value: val.to_i } }
    end

    # Current filter carried into links (preset or explicit dates).
    helper_method :filter_params
    def filter_params
      @preset ? { preset: @preset } : { from: @from.to_s, to: @to.to_s }
    end
  end
end
