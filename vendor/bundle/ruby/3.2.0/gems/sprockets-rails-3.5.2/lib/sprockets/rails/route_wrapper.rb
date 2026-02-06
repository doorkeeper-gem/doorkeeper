module Sprockets
  module Rails
    module RouteWrapper
      def internal_assets_path?
        path =~ %r{\A#{self.class.assets_prefix}\z}
      end

      def internal?
        super || internal_assets_path?
      end
    end
  end
end
