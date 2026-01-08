module ApplicationHelper
  def active_menu_item
    {
      data_sources: :data_sources,
      workflows: :workflows,
      workflow_executions: :logs
    }.fetch(controller_name.to_sym, nil)
  end

  def execution_status_color(status)
    {
      'pending' => 'neutral',
      'processing' => 'warning',
      'success' => 'success',
      'complete' => 'success',
      'failed' => 'error',
      'skipped' => 'info'
    }.fetch(status, 'neutral')
  end
end
