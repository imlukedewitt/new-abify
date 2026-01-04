module ApplicationHelper
  def active_menu_item
    case controller_name
    when 'data_sources'
      :data_sources
    when 'workflows'
      :workflows
    when 'logs'
      :logs
    else
      nil
    end
  end
end
