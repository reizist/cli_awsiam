# http://docs.aws.amazon.com/ja_jp/IAM/latest/UserGuide/Using_SettingUpUser.html
# http://docs.aws.amazon.com/AWSRubySDK/latest/AWS.html
require 'bundler/setup'
require 'yaml'
require 'highline'

Bundler.require

CONFIG = YAML.load_file('config.yml')

class AwsIam
  READ_ONLY = 'ReadOnly'.freeze

  def initialize(account_key)
    unless CONFIG[account_key]
      puts "Server key '#{account_key}' does not exist."
      exit(1)
    end

    @iam = AWS::IAM.new(
      access_key_id: CONFIG[account_key]['access_key_id'],
      secret_access_key: CONFIG[account_key]['secret_access_key']
    )
    @group = @iam.groups[READ_ONLY].exists? ? @iam.groups[READ_ONLY] : @iam.groups.create(READ_ONLY)
  end

  def create_user
    begin
      ui = HighLine.new
      user_name = ui.ask('user_name: ')
      password = ui.ask('password: ') { |q| q.echo = false }
      user = @iam.users.create(user_name)
      user.login_profile.password = password
      user.groups.add(@group)
      user
    rescue AWS::IAM::Errors::EntityAlreadyExists
      puts "User with name '#{user_name}' already exists. Please try another name."
    end
  end

  def delete_user(user_name)
    @iam.users[user_name].delete
  end

  def delete_user!(user_name)
    # Deletes the current user, after: * deleting its login profile * removing it from all groups
    # * deleting all of its access keys * deleting its mfa devices * deleting its signing certificates
    @iam.users[user_name].delete!
    `rm #{user_name}_keys`
  end

  def list_users
    @iam.users.each {|u| puts u.name}
  end

  def create_access_key(user)
    access_key = user.access_keys.create
    write_key(user, access_key.credentials)
  end

  def write_key(user, keys)
    File.open("#{user.name}_keys", "a") do |f|
      f.write(keys)
    end
  end
end

client = AwsIam.new(ARGV[0])
user = client.create_user
client.create_access_key(user)