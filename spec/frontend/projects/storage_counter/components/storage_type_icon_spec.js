import { mount } from '@vue/test-utils';
import { GlIcon } from '@gitlab/ui';
import StorageTypeIcon from '~/projects/storage_counter/components/storage_type_icon.vue';

describe('StorageTypeIcon', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = mount(StorageTypeIcon, {
      propsData: {
        ...props,
      },
    });
  };

  const findGlIcon = () => wrapper.findComponent(GlIcon);

  describe('rendering icon', () => {
    afterEach(() => {
      wrapper.destroy();
    });

    it.each`
      expected                     | provided
      ${'doc-image'}               | ${'lfsObjectsSize'}
      ${'snippet'}                 | ${'snippetsSize'}
      ${'infrastructure-registry'} | ${'repositorySize'}
      ${'package'}                 | ${'packagesSize'}
      ${'upload'}                  | ${'uploadsSize'}
      ${'disk'}                    | ${'wikiSize'}
      ${'disk'}                    | ${'anything-else'}
    `(
      'renders icon with name of $expected when name prop is $provided',
      ({ expected, provided }) => {
        createComponent({ name: provided });

        expect(findGlIcon().props('name')).toBe(expected);
      },
    );
  });
});
