# Shared date-range filtering for merchant screens (dashboard, transactions).
# Resolves ?range= preset (7d/30d/90d/mtd/all) or ?from=/?to= custom dates into
# a { key:, from:, to:, label: } hash, and scopes a relation to it via #in_range.
module DateRangeFilterable
  extend ActiveSupport::Concern

  RANGE_PRESETS = %w[7d 30d 90d mtd ytd 12m all].freeze

  private

  # Resolve the active date range from ?range= preset or ?from=/?to= custom dates.
  def resolve_range(default_key: "30d")
    from = parse_range_date(params[:from])
    to   = parse_range_date(params[:to])
    if from || to
      f = (from || Date.new(2000, 1, 1)).beginning_of_day
      t = (to || Date.current).end_of_day
      f, t = t, f if f > t
      return { key: "custom", from: f, to: t,
               label: "#{f.to_date.strftime('%d/%m/%y')} – #{t.to_date.strftime('%d/%m/%y')}" }
    end
    key = params[:range].to_s.presence_in(RANGE_PRESETS) || default_key
    now = Time.current
    spec =
      case key
      when "7d"  then { from: 7.days.ago.beginning_of_day, to: now }
      when "90d" then { from: 90.days.ago.beginning_of_day, to: now }
      when "mtd" then { from: now.beginning_of_month, to: now }
      when "ytd" then { from: now.beginning_of_year, to: now }
      when "12m" then { from: 12.months.ago.beginning_of_day, to: now }
      when "all" then { from: nil, to: nil }
      else            { from: 30.days.ago.beginning_of_day, to: now }
      end
    spec.merge(key: key, label: I18n.t("merchant.dashboard.range_#{key}"))
  end

  def parse_range_date(raw)
    return nil if raw.blank?
    Date.iso8601(raw.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  # Scope a relation to the active range on the given timestamp column
  # (no-op for the "all" preset). Defaults to created_at.
  def in_range(rel, column = :created_at)
    @range && @range[:from] ? rel.where(column => @range[:from]..@range[:to]) : rel
  end
end
