# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScimIdentity do
  describe 'relations' do
    it { is_expected.to belong_to(:group) }
    it { is_expected.to belong_to(:user) }
  end

  describe 'validations' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }

    context 'with existing user and group' do
      before do
        create(:scim_identity, user: user, group: group, extern_uid: user.email)
      end

      it 'returns false for a duplicate identity with the same extern_uid' do
        identity = user.scim_identities.build(group: group, extern_uid: user.email)

        expect(identity.validate).to eq(false)
      end

      it 'returns false for a duplicate identity with different extern_uid' do
        identity = user.scim_identities.build(group: group, extern_uid: '1234abcd')

        expect(identity.validate).to eq(false)
      end

      it 'returns true when a different group is used' do
        other_group = create(:group)
        identity = user.scim_identities.build(group: other_group, extern_uid: user.email)

        expect(identity.validate).to eq(true)
      end

      it 'returns false for a duplicate extern_uid with different case' do
        identity = user.scim_identities.build(group: group, extern_uid: user.email.upcase)

        expect(identity.validate).to eq(false)
      end
    end
  end

  describe '.with_extern_uid' do
    it 'finds identity regardless of case' do
      user = create(:user)
      group = create(:group)

      identity = user.scim_identities.create(group: group, extern_uid: user.email)

      expect(group.scim_identities.with_extern_uid(user.email.upcase).first).to eq identity
    end
  end
end
