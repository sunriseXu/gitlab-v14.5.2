# frozen_string_literal: true

class DependencyEntity < Grape::Entity
  include RequestAwareEntity

  class AncestorEntity < Grape::Entity
    expose :name, :version
  end

  class LocationEntity < Grape::Entity
    expose :blob_path, :path, :top_level
    expose :ancestors, using: AncestorEntity
  end

  class VulnerabilityEntity < Grape::Entity
    expose :name, :severity, :id, :url
  end

  class LicenseEntity < Grape::Entity
    expose :name, :url
  end

  expose :name, :packager, :version
  expose :location, using: LocationEntity
  expose :vulnerabilities, using: VulnerabilityEntity, if: ->(_) { can_read_vulnerabilities? }
  expose :licenses, using: LicenseEntity, if: ->(_) { can_read_licenses? }

  private

  def can_read_vulnerabilities?
    can?(request.user, :read_security_resource, request.project)
  end

  def can_read_licenses?
    can?(request.user, :read_licenses, request.project)
  end
end
