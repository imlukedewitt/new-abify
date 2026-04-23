# frozen_string_literal: true

module PaginationHelper
  def daisy_pagination(pagy, max_pages: 7)
    return unless pagy.pages > 1

    pages = page_window(pagy, max_pages)

    content_tag(:div, class: 'join') do
      safe_join(pages.map { |p| page_button(pagy, p) })
    end
  end

  private

  def page_window(pagy, max_pages)
    total = pagy.pages
    return (1..total).to_a if total <= max_pages

    start = window_start(pagy.page, total, max_pages)
    pages = (start...(start + max_pages)).to_a
    add_gaps(pages, total)
  end

  def window_start(current, total, max_pages)
    half = (max_pages - 1) / 2

    return 1 if current <= half + 1
    return total - max_pages + 1 if current >= total - half

    current - half
  end

  def add_gaps(pages, total)
    pages[0] = 1
    pages[1] = :gap if pages[1] != 2
    pages[-2] = :gap if pages[-2] != total - 1
    pages[-1] = total

    pages
  end

  def page_button(pagy, page)
    case page
    when Integer
      page_number_button(pagy, page)
    when :gap
      gap_button
    end
  end

  def page_number_button(pagy, page)
    if page == pagy.page
      content_tag(:button, page, class: 'join-item btn btn-sm btn-active', disabled: true)
    else
      link_to(page, url_for(page: page), class: 'join-item btn btn-sm')
    end
  end

  def gap_button
    content_tag(:button, '...', class: 'join-item btn btn-sm btn-disabled', disabled: true)
  end
end
