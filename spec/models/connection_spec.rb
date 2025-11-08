# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Connection, type: :model do
  describe 'associations' do
    it 'belongs to user' do
      association = described_class.reflect_on_association(:user)
      expect(association.macro).to eq :belongs_to
    end

    it 'has many workflows' do
      association = described_class.reflect_on_association(:workflows)
      expect(association.macro).to eq :has_many
    end
  end

  describe 'validations' do
    let(:user) { create(:user) }

    it 'validates presence of name' do
      connection = build(:connection, user: user, name: nil)
      expect(connection).not_to be_valid
      expect(connection.errors[:name]).to include("can't be blank")
    end

    it 'validates presence of handle' do
      connection = build(:connection, user: user, handle: nil)
      expect(connection).not_to be_valid
      expect(connection.errors[:handle]).to include("can't be blank")
    end

    it 'validates presence of credentials' do
      connection = build(:connection, user: user, credentials: nil)
      expect(connection).not_to be_valid
      expect(connection.errors[:credentials]).to include("can't be blank")
    end

    describe 'handle format validation' do
      it 'allows lowercase alphanumeric and underscores' do
        valid_handles = %w[salesforce slack_workspace api_key_123]
        valid_handles.each do |handle|
          connection = build(:connection, user: user, handle: handle)
          expect(connection).to be_valid, "Expected '#{handle}' to be valid"
        end
      end

      it 'rejects handles with uppercase letters' do
        connection = build(:connection, user: user, handle: 'SalesForce')
        expect(connection).not_to be_valid
        expect(connection.errors[:handle]).to include('must start with a letter and contain only lowercase letters, numbers, and underscores')
      end

      it 'rejects handles with spaces' do
        connection = build(:connection, user: user, handle: 'sales force')
        expect(connection).not_to be_valid
        expect(connection.errors[:handle]).to include('must start with a letter and contain only lowercase letters, numbers, and underscores')
      end

      it 'rejects handles with special characters' do
        connection = build(:connection, user: user, handle: 'sales-force')
        expect(connection).not_to be_valid
        expect(connection.errors[:handle]).to include('must start with a letter and contain only lowercase letters, numbers, and underscores')
      end

      it 'rejects handles starting with numbers' do
        connection = build(:connection, user: user, handle: '123_api')
        expect(connection).not_to be_valid
        expect(connection.errors[:handle]).to include('must start with a letter and contain only lowercase letters, numbers, and underscores')
      end
    end

    describe 'handle uniqueness' do
      it 'validates handle is unique per user' do
        user1 = create(:user)
        user2 = create(:user)

        create(:connection, user: user1, handle: 'salesforce')

        # Same handle for same user should fail
        duplicate = build(:connection, user: user1, handle: 'salesforce')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:handle]).to include('has already been taken')

        # Same handle for different user should succeed
        different_user = build(:connection, user: user2, handle: 'salesforce')
        expect(different_user).to be_valid
      end
    end

    describe 'credentials validation' do
      it 'validates credentials is a hash' do
        connection = build(:connection, user: user, credentials: 'not a hash')
        expect(connection).not_to be_valid
        expect(connection.errors[:credentials]).to include('must be a hash')
      end

      it 'allows valid credential hashes' do
        valid_credentials = [
          { type: 'bearer', token: 'abc123' },
          { type: 'basic', username: 'user', password: 'pass' },
          { type: 'api_key', header_name: 'X-API-KEY', value: 'key123' }
        ]

        valid_credentials.each do |creds|
          connection = build(:connection, user: user, credentials: creds)
          expect(connection).to be_valid
        end
      end
    end
  end

  describe 'encryption' do
    let(:user) { create(:user) }

    it 'encrypts credentials in the database' do
      credentials = { type: 'bearer', token: 'super_secret_token_123' }
      connection = create(:connection, user: user, credentials: credentials)

      # Read directly from database to verify encryption
      raw_record = ActiveRecord::Base.connection.execute(
        "SELECT credentials FROM connections WHERE id = #{connection.id}"
      ).first

      # The raw database value should NOT contain the plaintext token
      expect(raw_record['credentials']).not_to include('super_secret_token_123')

      # But the model should decrypt it automatically
      connection.reload
      expect(connection.credentials['token']).to eq('super_secret_token_123')
    end

    it 'decrypts credentials when reading from database' do
      credentials = { type: 'basic', username: 'admin', password: 'secret_pass' }
      connection = create(:connection, user: user, credentials: credentials)

      # Reload from database
      reloaded = Connection.find(connection.id)

      expect(reloaded.credentials).to eq(credentials.stringify_keys)
      expect(reloaded.credentials['username']).to eq('admin')
      expect(reloaded.credentials['password']).to eq('secret_pass')
    end
  end

  describe 'URL fields' do
    let(:user) { create(:user) }

    it 'allows subdomain to be set' do
      connection = create(:connection, user: user, subdomain: 'mycompany')
      expect(connection.subdomain).to eq('mycompany')
    end

    it 'allows domain to be set' do
      connection = create(:connection, user: user, domain: 'salesforce.com')
      expect(connection.domain).to eq('salesforce.com')
    end

    it 'allows subdomain and domain to be nil' do
      connection = create(:connection, user: user, subdomain: nil, domain: nil)
      expect(connection).to be_valid
      expect(connection.subdomain).to be_nil
      expect(connection.domain).to be_nil
    end
  end

  describe '#base_url' do
    let(:user) { create(:user) }

    it 'returns full URL when both subdomain and domain are present' do
      connection = create(:connection, user: user, subdomain: 'mycompany', domain: 'salesforce.com')
      expect(connection.base_url).to eq('https://mycompany.salesforce.com')
    end

    it 'returns nil when subdomain is missing' do
      connection = create(:connection, user: user, subdomain: nil, domain: 'salesforce.com')
      expect(connection.base_url).to be_nil
    end

    it 'returns nil when domain is missing' do
      connection = create(:connection, user: user, subdomain: 'mycompany', domain: nil)
      expect(connection.base_url).to be_nil
    end

    it 'returns nil when both are missing' do
      connection = create(:connection, user: user, subdomain: nil, domain: nil)
      expect(connection.base_url).to be_nil
    end
  end
end
