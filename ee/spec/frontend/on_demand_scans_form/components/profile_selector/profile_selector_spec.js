import { GlDropdownItem } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import { merge } from 'lodash';
import OnDemandScansProfileSelector from 'ee/on_demand_scans_form/components/profile_selector/profile_selector.vue';
import { scannerProfiles } from '../../mocks/mock_data';

describe('OnDemandScansProfileSelector', () => {
  let wrapper;

  const defaultProps = {
    libraryPath: '/path/to/profiles/library',
    newProfilePath: '/path/to/new/profile/form',
    profiles: [],
  };

  const defaultDropdownItems = [
    {
      text: 'Create new profile',
      isChecked: false,
    },
    {
      text: 'Manage scanner profiles',
      isChecked: false,
    },
  ];

  const findByTestId = (testId) => wrapper.find(`[data-testid="${testId}"]`);
  const findCreateProfileOption = () => findByTestId('create-profile-option');
  const findManageProfilesOption = () => findByTestId('manage-profiles-option');
  const findProfilesDropdown = () => findByTestId('profiles-dropdown');
  const findCreateNewProfileLink = () => findByTestId('create-profile-link');
  const findSelectedProfileSummary = () => findByTestId('selected-profile-summary');
  const parseDropdownItems = () =>
    findProfilesDropdown()
      .findAll(GlDropdownItem)
      .wrappers.map((x) => ({
        text: x.text(),
        isChecked: x.props('isChecked'),
      }));
  const selectFirstProfile = () => {
    return findProfilesDropdown().find(GlDropdownItem).vm.$emit('click');
  };

  const createFullComponent = (options = {}) => {
    wrapper = mount(
      OnDemandScansProfileSelector,
      merge(
        {
          propsData: defaultProps,
          slots: {
            title: 'Section title',
            label: 'Use existing scanner profile',
            summary: `<div>Profile's summary</div>`,
            'no-profiles': 'No profile yet',
            'new-profile': 'Create new profile',
            'manage-profile': 'Manage scanner profiles',
          },
        },
        options,
      ),
    );
  };

  afterEach(() => {
    wrapper.destroy();
  });

  it('shows section title and link to profiles library', () => {
    createFullComponent();

    expect(wrapper.text()).toContain('Section title');
  });

  describe('when there are no profiles yet', () => {
    beforeEach(() => {
      createFullComponent();
    });

    it('do not show profile selector', () => {
      expect(findProfilesDropdown().exists()).toBe(false);
    });

    it('shows a help text and a link to create a new profile', () => {
      const link = findCreateNewProfileLink();

      expect(wrapper.text()).toContain('No profile yet');
      expect(link.exists()).toBe(true);
      expect(link.attributes('href')).toBe('/path/to/new/profile/form');
      expect(link.text()).toBe('Create new profile');
    });
  });

  describe('when there are profiles', () => {
    beforeEach(() => {
      createFullComponent({
        propsData: { profiles: scannerProfiles },
      });
    });

    it('shows a dropdown containing the profiles', () => {
      const dropdown = findProfilesDropdown();

      expect(wrapper.text()).toContain('Use existing scanner profile');
      expect(dropdown.exists()).toBe(true);
      expect(dropdown.element.children).toHaveLength(scannerProfiles.length);
    });

    it('when a profile is selected, input event is emitted', async () => {
      await selectFirstProfile();

      expect(wrapper.emitted('input')).toEqual([[scannerProfiles[0].id]]);
    });

    it('shows dropdown items for each profile', () => {
      expect(parseDropdownItems()).toEqual([
        ...scannerProfiles.map((x) => ({
          text: x.profileName,
          isChecked: false,
        })),
        ...defaultDropdownItems,
      ]);
    });

    it('show options for profiles management', () => {
      expect(findCreateProfileOption().exists()).toBe(true);
      expect(findCreateProfileOption().attributes('href')).toBe('/path/to/new/profile/form');

      expect(findManageProfilesOption().exists()).toBe(true);
      expect(findManageProfilesOption().attributes('href')).toBe('/path/to/profiles/library');
    });

    it('does not show summary', () => {
      expect(findSelectedProfileSummary().exists()).toBe(false);
    });
  });

  describe('when profile is selected', () => {
    let selectedProfile;

    beforeEach(() => {
      [selectedProfile] = scannerProfiles;
      createFullComponent({
        propsData: {
          profiles: scannerProfiles,
          value: selectedProfile.id,
        },
      });
    });

    it('displays summary below dropdown', () => {
      const summary = findSelectedProfileSummary();

      expect(summary.exists()).toBe(true);
      expect(summary.text()).toContain(`Profile's summary`);
    });

    it('displays item as checked', () => {
      expect(parseDropdownItems()).toEqual([
        ...scannerProfiles.map((x, i) => ({
          text: x.profileName,
          isChecked: i === 0,
        })),
        ...defaultDropdownItems,
      ]);
    });
  });
});
