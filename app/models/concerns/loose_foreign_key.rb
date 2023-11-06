# frozen_string_literal: true

module LooseForeignKey
  extend ActiveSupport::Concern

  # This concern adds loose foreign key support to ActiveRecord models.
  # Loose foreign keys allow delayed processing of associated database records
  # with similar guarantees than a database foreign key.
  #
  # Prerequisites:
  #
  # To start using the concern, you'll need to install a database trigger to the parent
  # table in a standard DB migration (not post-migration).
  #
  # > track_record_deletions(:projects)
  #
  # Usage:
  #
  # > class Ci::Build < ApplicationRecord
  # >
  # >   loose_foreign_key :security_scans, :build_id, on_delete: :async_delete
  # >
  # >   # associations can be still defined, the dependent options is no longer necessary:
  # >   has_many :security_scans, class_name: 'Security::Scan'
  # >
  # > end
  #
  # Options for on_delete:
  #
  # - :async_delete - deletes the children rows via an asynchronous process.
  # - :async_nullify - sets the foreign key column to null via an asynchronous process.
  #
  # How it works:
  #
  # When adding loose foreign key support to the table, a DELETE trigger is installed
  # which tracks the record deletions (stores primary key value of the deleted row) in
  # a database table.
  #
  # These deletion records are processed asynchronously and records are cleaned up
  # according to the loose foreign key definitions described in the model.
  #
  # The cleanup happens in batches, which reduces the likelyhood of statement timeouts.
  #
  # When all associations related to the deleted record are cleaned up, the record itself
  # is deleted.
  included do
    class_attribute :loose_foreign_key_definitions, default: []
  end

  class_methods do
    def loose_foreign_key(to_table, column, options)
      symbolized_options = options.symbolize_keys

      unless base_class?
        raise <<~MSG
        loose_foreign_key can be only used on base classes, inherited classes are not supported.
        Please define the loose_foreign_key on the #{base_class.name} class.
        MSG
      end

      on_delete_options = %i[async_delete async_nullify]

      unless on_delete_options.include?(symbolized_options[:on_delete]&.to_sym)
        raise "Invalid on_delete option given: #{symbolized_options[:on_delete]}. Valid options: #{on_delete_options.join(', ')}"
      end

      definition = ActiveRecord::ConnectionAdapters::ForeignKeyDefinition.new(
        table_name.to_s,
        to_table.to_s,
        {
          column: column.to_s,
          on_delete: symbolized_options[:on_delete].to_sym
        }
      )

      self.loose_foreign_key_definitions += [definition]
    end
  end
end
