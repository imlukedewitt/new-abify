class LiquidProcessor
  def initialize(template_string, context_data = {})
    @template_string = template_string
    @context_data = context_data
  end

  def process
    template = Liquid::Template.parse(@template_string)
    template.render(deep_stringify_keys(@context_data))
  end

  def valid?
    Liquid::Template.parse(@template_string)
    true
  rescue Liquid::SyntaxError
    false
  end

  def validation_errors
    Liquid::Template.parse(@template_string)
    nil
  rescue Liquid::SyntaxError => e
    e.message
  end

  private

  def deep_stringify_keys(obj)
    case obj
    when Hash
      obj.transform_keys(&:to_s).transform_values { |v| deep_stringify_keys(v) }
    when Array
      obj.map { |v| deep_stringify_keys(v) }
    else
      obj
    end
  end
end