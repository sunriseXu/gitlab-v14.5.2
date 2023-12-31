---
stage: Verify
group: Runner
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
type: reference
---

# GitLab Runner Cloud **(FREE)**

If you are using self-managed GitLab or you want to use your own runners on GitLab.com, you can
[install and configure your own runners](https://docs.gitlab.com/runner/install/).

If you are using GitLab SaaS (GitLab.com), your CI jobs automatically run on runners in the GitLab Runner Cloud.
No configuration is required. Your jobs can run on:

- [Linux runners](build_cloud/linux_build_cloud.md).
- [Windows runners](build_cloud/windows_build_cloud.md) (beta).
- [macOS runners](build_cloud/macos_build_cloud.md) (beta).

The number of minutes you can use on these runners depends on your
[quota](../../user/admin_area/settings/continuous_integration.md#shared-runners-pipeline-minutes-quota),
which depends on your [subscription plan](../../subscriptions/gitlab_com/index.md#ci-pipeline-minutes).
