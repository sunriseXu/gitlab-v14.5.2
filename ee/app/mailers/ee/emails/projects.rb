# frozen_string_literal: true

module EE
  module Emails
    module Projects
      def mirror_was_hard_failed_email(project_id, user_id)
        @project = ::Project.find(project_id)
        user = ::User.find(user_id)

        mail(to: user.notification_email_for(@project.group),
             subject: subject('Repository mirroring paused'))
      end

      def mirror_was_disabled_email(project_id, user_id, deleted_user_name)
        @project = ::Project.find(project_id)
        user = ::User.find_by_id(user_id)
        @deleted_user_name = deleted_user_name

        return unless user

        mail(to: user.notification_email_for(@project.group),
             subject: subject('Repository mirroring disabled'))
      end

      def project_mirror_user_changed_email(new_mirror_user_id, deleted_user_name, project_id)
        @project = ::Project.find(project_id)
        @deleted_user_name = deleted_user_name
        user = ::User.find(new_mirror_user_id)

        mail(to: user.notification_email_for(@project.group),
             subject: subject('Mirror user changed'))
      end
    end
  end
end
