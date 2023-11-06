# frozen_string_literal: true

module EE
  module Environment
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override
    include ::Gitlab::Utils::StrongMemoize

    prepended do
      has_many :dora_daily_metrics, class_name: 'Dora::DailyMetrics'

      # Returns environments where its latest deployment is to a cluster
      scope :deployed_to_cluster, -> (cluster) do
        environments = model.arel_table
        deployments = ::Deployment.arel_table
        later_deployments = ::Deployment.arel_table.alias('latest_deployments')
        join_conditions = later_deployments[:environment_id]
          .eq(deployments[:environment_id])
          .and(deployments[:id].lt(later_deployments[:id]))

        join = deployments
          .join(later_deployments, Arel::Nodes::OuterJoin)
          .on(join_conditions)

        joins(:successful_deployments)
          .joins(join.join_sources)
          .where(later_deployments[:id].eq(nil))
          .where(deployments[:cluster_id].eq(cluster.id))
          .where(deployments[:project_id].eq(environments[:project_id]))
      end

      scope :preload_for_cluster_environment_entity, -> do
        preload(
          last_deployment: [:deployable],
          project: [:route, { namespace: :route }]
        )
      end
    end

    def reactive_cache_updated
      super

      ::Gitlab::EtagCaching::Store.new.tap do |store|
        store.touch(
          ::Gitlab::Routing.url_helpers.project_environments_path(project, format: :json))

        store.touch(cluster_environments_etag_key) if cluster_environments_etag_key
      end
    end

    def cluster_environments_etag_key
      strong_memoize(:cluster_environments_key) do
        cluster = last_deployment&.cluster

        if cluster&.group_type?
          ::Gitlab::Routing.url_helpers.environments_group_cluster_path(cluster.group, cluster)
        elsif cluster&.instance_type?
          ::Gitlab::Routing.url_helpers.environments_admin_cluster_path(cluster)
        end
      end
    end

    def protected?
      return false unless project.licensed_feature_available?(:protected_environments)

      associated_protected_environments.present?
    end

    def protected_from?(user)
      return true unless user.is_a?(User)
      return false unless protected?

      protected_environment_accesses(user).any? { |access, _| access == false }
    end

    def protected_by?(user)
      return false unless user.is_a?(User) && protected?

      protected_environment_accesses(user).all? { |access, _| access == true }
    end

    private

    def protected_environment_accesses(user)
      key = "environment:#{self.id}:for:#{user.id}"

      ::Gitlab::SafeRequestStore.fetch(key) do
        associated_protected_environments.group_by do |pe|
          pe.accessible_to?(user)
        end
      end
    end

    def associated_protected_environments
      strong_memoize(:associated_protected_environments) do
        ::ProtectedEnvironment.for_environment(self)
      end
    end
  end
end
