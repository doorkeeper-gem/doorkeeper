# frozen_string_literal: true

# Adds the `render_with` matcher.
# Ex:
#   expect(controller).to render_with(template: :show, locals: { alpha: "beta" })
#
module RenderWithMatcher
  def self.included(base)
    # Setup spying for our "render_with" matcher
    base.before do
      allow(controller).to receive(:render).and_wrap_original do |original, *args, **kwargs, &block|
        original.call(*args, **kwargs, &block)
      end
    end
  end

  RSpec::Matchers.define :render_with do |expected|
    match do |actual|
      have_received(:render).with(expected).matches?(actual)
    end
  end
end

RSpec.configure do |config|
  config.include RenderWithMatcher, type: :controller
end
