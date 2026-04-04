module Analytics
  class Dashboard
    TOTAL_MONTH_POINTS = 12
    MONTH_POINTS = 6
    WEEK_POINTS = 8
    DAY_POINTS = 14

    def initialize(
      now: Time.zone.now,
      page_view_scope: Ahoy::Event.page_views,
      visit_scope: Ahoy::Visit.all,
      search_scope: Ahoy::Event.searches
    )
      @now = now.in_time_zone
      @page_view_scope = page_view_scope
      @visit_scope = visit_scope
      @search_scope = search_scope
    end

    def call
      {
        totals: totals,
        summary_cards: summary_cards,
        week_over_week: week_over_week,
        charts: charts
      }
    end

    def totals
      {
        page_views: page_view_scope.count,
        visits: visit_scope.count,
        searches: search_scope.count,
        tracking_started_at: tracking_started_at
      }
    end

    private

    attr_reader :now, :page_view_scope, :visit_scope, :search_scope

    def summary_cards
      [
        build_total_card,
        build_period_card(
          key: :month,
          title: "今月",
          range: current_period_range(:month),
          previous_range: previous_period_range(:month),
          comparison_label: "前月比"
        ),
        build_period_card(
          key: :week,
          title: "今週",
          range: current_period_range(:week),
          previous_range: previous_period_range(:week),
          comparison_label: "前週比"
        ),
        build_period_card(
          key: :day,
          title: "今日",
          range: current_period_range(:day),
          previous_range: previous_period_range(:day),
          comparison_label: "前週同曜日比"
        )
      ]
    end

    def week_over_week
      current_range = current_period_range(:week)
      previous_range = previous_period_range(:week)

      {
        current_label: formatted_period_label(:week, current_range),
        previous_label: formatted_period_label(:week, previous_range),
        page_views: comparison_for(range: current_range, previous_range: previous_range, column: :time, scope: page_view_scope),
        visits: comparison_for(range: current_range, previous_range: previous_range, column: :started_at, scope: visit_scope),
        searches: comparison_for(range: current_range, previous_range: previous_range, column: :time, scope: search_scope)
      }
    end

    def charts
      {
        total: build_total_chart,
        monthly: build_period_chart(
          key: :monthly,
          title: "月間PV・訪問数・検索数",
          subtitle: "直近#{MONTH_POINTS}か月の推移",
          period: :month,
          points: MONTH_POINTS,
          type: "bar"
        ),
        weekly: build_period_chart(
          key: :weekly,
          title: "週間PV・訪問数・検索数",
          subtitle: "直近#{WEEK_POINTS}週間の推移",
          period: :week,
          points: WEEK_POINTS,
          type: "bar"
        ),
        daily: build_period_chart(
          key: :daily,
          title: "1日ごとのPV・訪問数・検索数",
          subtitle: "直近#{DAY_POINTS}日間の推移",
          period: :day,
          points: DAY_POINTS,
          type: "line"
        )
      }
    end

    def build_total_card
      {
        key: :total,
        title: "累計",
        subtitle: tracking_started_at.present? ? "計測開始: #{tracking_started_at.strftime('%Y/%m/%d')}" : "計測データなし",
        page_views: totals[:page_views],
        visits: totals[:visits],
        searches: totals[:searches],
        comparison_label: nil,
        page_view_change: nil,
        visit_change: nil,
        search_change: nil
      }
    end

    def build_period_card(key:, title:, range:, previous_range:, comparison_label:)
      {
        key: key,
        title: title,
        subtitle: formatted_period_label(key == :day ? :day : key, range),
        page_views: count_records(page_view_scope, :time, range),
        visits: count_records(visit_scope, :started_at, range),
        searches: count_records(search_scope, :time, range),
        comparison_label: comparison_label,
        page_view_change: comparison_for(range: range, previous_range: previous_range, column: :time, scope: page_view_scope),
        visit_change: comparison_for(range: range, previous_range: previous_range, column: :started_at, scope: visit_scope),
        search_change: comparison_for(range: range, previous_range: previous_range, column: :time, scope: search_scope)
      }
    end

    def build_total_chart
      bucket_starts = build_bucket_starts(:month, TOTAL_MONTH_POINTS)
      page_view_counts = counts_by_period(page_view_scope, column: :time, period: :month, bucket_starts: bucket_starts)
      visit_counts = counts_by_period(visit_scope, column: :started_at, period: :month, bucket_starts: bucket_starts)
      search_counts = counts_by_period(search_scope, column: :time, period: :month, bucket_starts: bucket_starts)

      {
        key: :total,
        title: "累計推移",
        subtitle: "直近#{TOTAL_MONTH_POINTS}か月の累計PV・累計訪問数・累計検索数",
        type: "line",
        has_data: [page_view_counts, visit_counts, search_counts].any? { |counts| counts.values.any?(&:positive?) },
        data: chart_payload(
          labels: bucket_starts.map { |bucket| bucket.strftime("%Y/%m") },
          page_views: cumulative_values(page_view_counts),
          visits: cumulative_values(visit_counts),
          searches: cumulative_values(search_counts),
          type: "line"
        )
      }
    end

    def build_period_chart(key:, title:, subtitle:, period:, points:, type:)
      bucket_starts = build_bucket_starts(period, points)
      page_view_counts = counts_by_period(page_view_scope, column: :time, period: period, bucket_starts: bucket_starts)
      visit_counts = counts_by_period(visit_scope, column: :started_at, period: period, bucket_starts: bucket_starts)
      search_counts = counts_by_period(search_scope, column: :time, period: period, bucket_starts: bucket_starts)

      {
        key: key,
        title: title,
        subtitle: subtitle,
        type: type,
        has_data: [page_view_counts, visit_counts, search_counts].any? { |counts| counts.values.any?(&:positive?) },
        data: chart_payload(
          labels: bucket_starts.map { |bucket| bucket_label(bucket, period) },
          page_views: page_view_counts.values,
          visits: visit_counts.values,
          searches: search_counts.values,
          type: type
        )
      }
    end

    def comparison_for(range:, previous_range:, column:, scope:)
      current = count_records(scope, column, range)
      previous = count_records(scope, column, previous_range)
      change = current - previous
      percent = previous.positive? ? ((change.to_f / previous) * 100).round(1) : nil

      {
        current: current,
        previous: previous,
        change: change,
        percent: percent
      }
    end

    def chart_payload(labels:, page_views:, visits:, searches:, type:)
      pv_dataset = {
        label: "PV",
        data: page_views,
        backgroundColor: type == "line" ? "rgba(249, 115, 22, 0.18)" : "rgba(249, 115, 22, 0.62)",
        borderColor: "rgba(249, 115, 22, 1)",
        borderWidth: 2,
        tension: 0.35,
        fill: type == "line",
        borderRadius: type == "bar" ? 10 : 0
      }
      visits_dataset = {
        label: "訪問数",
        data: visits,
        backgroundColor: type == "line" ? "rgba(14, 165, 233, 0.15)" : "rgba(14, 165, 233, 0.38)",
        borderColor: "rgba(14, 165, 233, 1)",
        borderWidth: 2,
        tension: 0.35,
        fill: type == "line",
        borderRadius: type == "bar" ? 10 : 0
      }
      searches_dataset = {
        label: "検索数",
        data: searches,
        backgroundColor: type == "line" ? "rgba(34, 197, 94, 0.15)" : "rgba(34, 197, 94, 0.36)",
        borderColor: "rgba(22, 163, 74, 1)",
        borderWidth: 2,
        tension: 0.35,
        fill: type == "line",
        borderRadius: type == "bar" ? 10 : 0
      }

      {
        labels: labels,
        datasets: [ pv_dataset, visits_dataset, searches_dataset ]
      }
    end

    def counts_by_period(scope, column:, period:, bucket_starts:)
      counts = bucket_starts.index_with { 0 }
      return counts if bucket_starts.empty?

      range = bucket_starts.first..period_end(bucket_starts.last, period)
      scope.where(column => range).pluck(column).each do |timestamp|
        next if timestamp.blank?

        bucket = period_start(timestamp.in_time_zone, period)
        counts[bucket] += 1 if counts.key?(bucket)
      end

      counts
    end

    def cumulative_values(counts)
      running_total = 0
      counts.values.map do |count|
        running_total += count
      end
    end

    def count_records(scope, column, range)
      scope.where(column => range).count
    end

    def build_bucket_starts(period, points)
      first_bucket = period_start(now, period)

      Array.new(points) do |index|
        shift_period(first_bucket, period, index - (points - 1))
      end
    end

    def current_period_range(period)
      period_start(now, period)..period_end(now, period)
    end

    def previous_period_range(period)
      previous_reference =
        case period
        when :day
          now - 1.week
        else
          shift_period(now, period, -1)
        end

      period_start(previous_reference, period)..period_end(previous_reference, period)
    end

    def period_start(timestamp, period)
      case period
      when :day
        timestamp.beginning_of_day
      when :week
        timestamp.beginning_of_week
      when :month
        timestamp.beginning_of_month
      else
        raise ArgumentError, "Unsupported period: #{period}"
      end
    end

    def period_end(timestamp, period)
      case period
      when :day
        timestamp.end_of_day
      when :week
        timestamp.end_of_week
      when :month
        timestamp.end_of_month
      else
        raise ArgumentError, "Unsupported period: #{period}"
      end
    end

    def shift_period(timestamp, period, amount)
      case period
      when :day
        timestamp + amount.days
      when :week
        timestamp + amount.weeks
      when :month
        timestamp.advance(months: amount)
      else
        raise ArgumentError, "Unsupported period: #{period}"
      end
    end

    def bucket_label(bucket, period)
      case period
      when :day
        bucket.strftime("%m/%d")
      when :week
        "#{bucket.strftime('%m/%d')}週"
      when :month
        bucket.strftime("%Y/%m")
      else
        bucket.to_s
      end
    end

    def formatted_period_label(period, range)
      case period
      when :day
        range.begin.strftime("%Y/%m/%d")
      when :week
        "#{range.begin.strftime('%Y/%m/%d')} - #{range.end.strftime('%m/%d')}"
      when :month
        range.begin.strftime("%Y/%m")
      else
        ""
      end
    end

    def tracking_started_at
      @tracking_started_at ||= [ page_view_scope.minimum(:time), visit_scope.minimum(:started_at), search_scope.minimum(:time) ].compact.min&.in_time_zone
    end
  end
end
