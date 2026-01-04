module ApplicationHelper
  def active_menu_item
    {
      data_sources: :data_sources,
      workflows: :workflows,
      workflow_executions: :logs
    }.fetch(controller_name.to_sym, nil)
  end

  def status_badge_class(status)
    case status
    when 'pending'             then 'badge-neutral'
    when 'processing'          then 'badge-warning'
    when 'success', 'complete' then 'badge-success'
    when 'failed'              then 'badge-error'
    when 'skipped'             then 'badge-info'
    else 'badge-neutral'
    end
  end
end
