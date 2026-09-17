module Admin
  class BillingController < BaseController
    PER_PAGE = 20

    def show
      ActsAsTenant.without_tenant do
        # ---- Summary ----
        active = Workspace.where(status: "active").to_a
        @by_plan = active.group_by(&:plan).transform_values(&:size)
        @mrr = @by_plan.sum { |plan, count| Plan.for(plan).price.to_i * count }
        @collected_total = Invoice.where(status: "paid").sum(:amount)
        @collected_month = Invoice.where(status: "paid")
                                  .where(paid_at: Time.current.beginning_of_month..Time.current.end_of_month)
                                  .sum(:amount)

        # ---- Transaction ledger (subscription invoices) ----
        scope = Invoice.order(created_at: :desc)

        @status = params[:status].presence_in(Invoice::STATUSES)
        scope = scope.where(status: @status) if @status

        @month = parse_month(params[:month])
        scope = scope.where(created_at: @month.beginning_of_month..@month.end_of_month) if @month

        @q = params[:q].to_s.strip
        if @q.present?
          like = "%#{@q}%"
          ws_ids  = Workspace.where("name ILIKE :q OR subdomain ILIKE :q", q: like).pluck(:id)
          ws_ids |= Branch.unscoped.where("name ILIKE :q", q: like).pluck(:workspace_id)
          scope = scope.where(workspace_id: ws_ids)
        end

        @total = scope.count
        @page  = [params[:page].to_i, 1].max
        @pages = [(@total / PER_PAGE.to_f).ceil, 1].max
        @page  = @pages if @page > @pages
        @invoices = scope.includes(:workspace).offset((@page - 1) * PER_PAGE).limit(PER_PAGE).to_a
      end
    end

    private

    def nav_key = :billing

    def parse_month(str)
      return nil if str.blank?
      Date.strptime(str, "%Y-%m")
    rescue ArgumentError
      nil
    end
  end
end
