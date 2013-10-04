module Doorkeeper
  module Models
    module Ownership
      def validate_owner?
        Doorkeeper.configuration.confirm_application_owner?
      end

      def self.included(base)
        base.class_eval do
          many_to_one :owner, :polymorphic => true
          many_to_one :owner, :reciprocal=>self.table_name,
            :setter=>(proc do |owner|
              self[:owner_id] = (owner.pk if owner)
              self[:owner_type] = (owner.class.name if owner)
            end),
            :dataset=>(proc do
              klass = owner_type.constantize
              klass.where(klass.primary_key=>owner_id)
            end),
            :eager_loader=>(proc do |eo|
              id_map = {}
              eo[:rows].each do |base_model|
                base_model.associations[:owner] = nil
                ((id_map[base_model.owner_type] ||= {})[base_model.owner_id] ||= []) << base_model
              end
              id_map.each do |klass_name, id_map|
                klass = klass_name.constantize
                klass.where(klass.primary_key=>id_map.keys).all do |owner|
                  id_map[owner.pk].each do |base_model|
                    base_model.associations[:owner] = owner
                  end
                end
              end
            end)
        end
      end

      def validate
        super
        validates_presence :owner if validate_owner?
      end
    end
  end
end
