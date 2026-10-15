module InvestmentAnalysesHelper
  ACTION_BADGE_CLASSES = {
    "add" => "bg-green-50 text-green-700 theme-dark:bg-green-900/20 theme-dark:text-green-400",
    "hold" => "bg-gray-100 text-secondary theme-dark:bg-gray-700",
    "trim" => "bg-yellow-50 text-yellow-700 theme-dark:bg-yellow-900/20 theme-dark:text-yellow-400",
    "sell" => "bg-red-50 text-red-700 theme-dark:bg-red-900/20 theme-dark:text-red-400"
  }.freeze

  def investment_action_badge(action)
    tag.span action.to_s.humanize,
      class: class_names("inline-block text-xs font-medium px-2 py-0.5 rounded-full", ACTION_BADGE_CLASSES.fetch(action.to_s, ACTION_BADGE_CLASSES["hold"]))
  end
end
