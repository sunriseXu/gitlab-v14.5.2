<script>
import SharedDeleteAction from './shared/shared_delete_action.vue';

export default {
  components: {
    SharedDeleteAction,
  },
  props: {
    username: {
      type: String,
      required: true,
    },
    paths: {
      type: Object,
      required: true,
    },
    userDeletionObstacles: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
};
</script>

<template>
  <shared-delete-action
    modal-type="delete-with-contributions"
    :username="username"
    :paths="paths"
    :delete-path="paths.deleteWithContributions"
    :user-deletion-obstacles="userDeletionObstacles"
  >
    <slot></slot>
  </shared-delete-action>
</template>
