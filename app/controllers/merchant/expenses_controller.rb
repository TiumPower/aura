module Merchant
  # Tiền ra. Ghép với doanh thu để ra lãi thật.
  class ExpensesController < BaseController
    before_action :set_expense, only: [:edit, :update, :destroy]

    def index
      @month = parse_month(params[:month]) || Date.current.beginning_of_month
      scope = by_branch(current_workspace.expenses.includes(:branch))
      @expenses = scope.in_range(@month, @month.end_of_month).recent.to_a
      @total = @expenses.sum { |e| e.amount.to_i }
      @by_category = @expenses.group_by(&:category)
                              .transform_values { |rows| rows.sum { |e| e.amount.to_i } }
                              .sort_by { |_, v| -v }
      @branches = current_workspace.branches.ordered.to_a
    end

    def new
      @expense = current_workspace.expenses.new(spent_on: Date.current, category: "supplies",
                                                branch_id: current_branch&.id)
      load_options
    end

    def create
      @expense = current_workspace.expenses.new(expense_params)
      if @expense.save
        audit!("expense.create", target: @expense, summary: "#{@expense.category_label} #{@expense.amount}")
        redirect_to merchant_expenses_path(month: @expense.spent_on.strftime("%Y-%m")),
                    notice: "Đã ghi nhận khoản chi."
      else
        load_options
        render :new, status: :unprocessable_entity
      end
    end

    def edit = load_options

    def update
      if @expense.update(expense_params)
        redirect_to merchant_expenses_path(month: @expense.spent_on.strftime("%Y-%m")),
                    notice: "Đã cập nhật khoản chi."
      else
        load_options
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @expense.destroy
      redirect_to merchant_expenses_path, notice: "Đã xoá khoản chi."
    end

    private

    def set_expense = @expense = current_workspace.expenses.find(params[:id])

    def load_options
      @branches = current_workspace.branches.ordered.to_a
    end

    def expense_params
      params.require(:expense).permit(:branch_id, :category, :note, :amount, :spent_on, :vendor)
    end

    def parse_month(str)
      return nil if str.blank?
      Date.strptime(str, "%Y-%m").beginning_of_month
    rescue ArgumentError
      nil
    end

    def nav_key = :expenses
  end
end
