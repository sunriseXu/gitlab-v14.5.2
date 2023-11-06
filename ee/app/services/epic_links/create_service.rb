# frozen_string_literal: true

module EpicLinks
  class CreateService < IssuableLinks::CreateService
    def execute
      unless can?(current_user, :admin_epic_link, issuable.group)
        return error(issuables_not_found_message, 404)
      end

      if issuable.max_hierarchy_depth_achieved?
        return error("This epic cannot be added. One or more epics would exceed the maximum depth (#{Epic::MAX_HIERARCHY_DEPTH}) from its most distant ancestor.", 409)
      end

      if referenced_issuables.count == 1
        create_single_link
      else
        super
      end
    end

    private

    def create_single_link
      child_epic = referenced_issuables.first

      if linkable_epic?(child_epic) && set_child_epic(child_epic)
        create_notes(child_epic)
        success
      else
        error(child_epic.errors.values.flatten.to_sentence, 409)
      end
    end

    def affected_epics(epics)
      [issuable, epics].flatten.uniq
    end

    def relate_issuables(referenced_epic)
      affected_epics = [issuable]
      affected_epics << referenced_epic if referenced_epic.parent

      if set_child_epic(referenced_epic)
        create_notes(referenced_epic)
      end

      referenced_epic
    end

    def create_notes(referenced_epic)
      SystemNoteService.change_epics_relation(issuable, referenced_epic, current_user, 'relate_epic')
    end

    def set_child_epic(child_epic)
      child_epic.parent = issuable
      child_epic.move_to_start
      child_epic.save
    end

    def linkable_issuables(epics)
      @linkable_issuables ||= begin
        epics.select do |epic|
          linkable_epic?(epic)
        end
      end
    end

    def linkable_epic?(epic)
      epic.valid_parent?(
        parent_epic: issuable,
        parent_group_descendants: issuable_group_descendants
      )
    end

    def references(extractor)
      extractor.epics
    end

    def extractor_context
      { group: issuable.group }
    end

    def previous_related_issuables
      issuable.children.to_a
    end

    def issuable_group_descendants
      @descendants ||= issuable.group.self_and_descendants
    end

    def issuables_assigned_message
      'Epic(s) already assigned'
    end

    def issuables_not_found_message
      'No Epic found for given params'
    end
  end
end
