# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::Member do
  subject(:entity_representation) { described_class.new(member).as_json }

  let(:member) { build_stubbed(:group_member) }
  let(:group_saml_identity) { build_stubbed(:group_saml_identity, extern_uid: 'TESTIDENTITY') }

  before do
    allow(member).to receive(:group_saml_identity).and_return(group_saml_identity)
  end

  context 'when current user is allowed to read group saml identity' do
    before do
      allow(Ability).to receive(:allowed?).with(anything, :read_group_saml_identity, member.source).and_return(true)
    end

    it 'exposes group_saml_identity' do
      expect(entity_representation[:group_saml_identity]).to include(extern_uid: 'TESTIDENTITY')
    end
  end

  context 'when current user is not allowed to read group saml identity' do
    before do
      allow(Ability).to receive(:allowed?).with(anything, :read_group_saml_identity, member.source).and_return(false)
    end

    it 'does not expose group saml identity' do
      expect(entity_representation.keys).not_to include(:group_saml_identity)
    end
  end

  context 'when current user is allowed to manage user' do
    before do
      allow(member.user).to receive(:managed_by?).and_return(true)
    end

    it 'exposes email' do
      expect(entity_representation.keys).to include(:email)
    end
  end

  context 'when current user is not allowed to manage user' do
    before do
      allow(member.user).to receive(:managed_by?).and_return(false)
    end

    it 'does not expose email' do
      expect(entity_representation.keys).not_to include(:email)
    end
  end
end
