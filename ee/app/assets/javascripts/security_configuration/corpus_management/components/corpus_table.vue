<script>
import { GlTable } from '@gitlab/ui';
import Actions from 'ee/security_configuration/corpus_management/components/columns/actions.vue';
import Name from 'ee/security_configuration/corpus_management/components/columns/name.vue';
import Target from 'ee/security_configuration/corpus_management/components/columns/target.vue';
import { s__ } from '~/locale';
import UserDate from '~/vue_shared/components/user_date.vue';
import { ISO_SHORT_FORMAT } from '~/vue_shared/constants';
import deleteCorpusMutation from '../graphql/mutations/delete_corpus.mutation.graphql';

const thClass = 'gl-bg-transparent! gl-border-gray-100! gl-border-b-solid! gl-border-b-1!';

export default {
  components: {
    GlTable,
    Name,
    Target,
    UserDate,
    Actions,
  },
  inject: ['projectFullPath'],
  props: {
    corpuses: {
      type: Array,
      required: true,
    },
  },
  fields: [
    {
      key: 'name',
      label: s__('CorpusManagement|Corpus name'),
      thClass,
    },
    {
      key: 'target',
      label: s__('CorpusManagement|Target'),
      thClass,
    },
    {
      key: 'lastUpdated',
      label: s__('CorpusManagement|Last updated'),
      thClass,
    },
    {
      key: 'lastUsed',
      label: s__('CorpusManagement|Last used'),
      thClass,
    },
    {
      key: 'actions',
      label: s__('CorpusManagement|Actions'),
      thClass,
    },
  ],
  methods: {
    onDelete({ name }) {
      this.$apollo.mutate({
        mutation: deleteCorpusMutation,
        variables: { name, projectPath: this.projectFullPath },
      });
    },
  },
  dateFormat: ISO_SHORT_FORMAT,
};
</script>
<template>
  <gl-table :items="corpuses" :fields="$options.fields">
    <template #cell(name)="{ item }">
      <name :corpus="item" />
    </template>

    <template #cell(target)="{ item }">
      <target :target="item.target" />
    </template>

    <template #cell(lastUpdated)="{ item }">
      <user-date :date="item.lastUpdated" :date-format="$options.dateFormat" />
    </template>

    <template #cell(lastUsed)="{ item }">
      <user-date :date="item.lastUsed" :date-format="$options.dateFormat" />
    </template>

    <template #cell(actions)="{ item }">
      <actions :corpus="item" @delete="onDelete" />
    </template>
  </gl-table>
</template>
