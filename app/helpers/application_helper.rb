module ApplicationHelper
  def active_menu_item
    {
      data_sources: :data_sources,
      workflows: :workflows,
      workflow_executions: :logs
    }.fetch(controller_name.to_sym, nil)
  end

  def execution_status_color(status)
    case status
    when 'pending'             then 'neutral'
    when 'processing'          then 'warning'
    when 'success', 'complete' then 'success'
    when 'failed'              then 'error'
    when 'skipped'             then 'info'
    else 'neutral'
    end
  end
end
