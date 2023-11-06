import { GlDropdown } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import LdapDropdownItem from 'ee/members/components/ldap/ldap_dropdown_item.vue';
import waitForPromises from 'helpers/wait_for_promises';
import { member } from 'jest/members/mock_data';
import RoleDropdown from '~/members/components/table/role_dropdown.vue';
import { MEMBER_TYPES } from '~/members/constants';

describe('RoleDropdown', () => {
  let wrapper;

  const createComponent = (propsData = {}) => {
    wrapper = shallowMount(RoleDropdown, {
      provide: {
        namespace: MEMBER_TYPES.user,
      },
      propsData: {
        member,
        permissions: {},
        ...propsData,
      },
    });

    return waitForPromises();
  };

  const findDropdown = () => wrapper.find(GlDropdown);

  afterEach(() => {
    wrapper.destroy();
  });

  describe('when member has `canOverride` permissions', () => {
    describe('when member is overridden', () => {
      it('renders LDAP dropdown item', async () => {
        await createComponent({
          permissions: {
            canOverride: true,
          },
          member: { ...member, isOverridden: true },
        });

        expect(wrapper.find(LdapDropdownItem).exists()).toBe(true);
      });
    });

    describe('when member is not overridden', () => {
      it('disables dropdown', async () => {
        await createComponent({
          permissions: {
            canOverride: true,
          },
          member: { ...member, isOverridden: false },
        });

        expect(findDropdown().attributes('disabled')).toBe('true');
      });
    });
  });

  describe('when member does not have `canOverride` permissions', () => {
    it('does not render LDAP dropdown item', async () => {
      await createComponent({
        permissions: {
          canOverride: false,
        },
      });

      expect(wrapper.find(LdapDropdownItem).exists()).toBe(false);
    });
  });
});
