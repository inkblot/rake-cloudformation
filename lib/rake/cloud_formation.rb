# ex: syntax=ruby ts=2 sw=2 si et
require 'aws/cloud_formation'

module Rake
  module CloudFormation
    class Service
      extend Rake::CloudFormation
    end

    class Stack < Rake::Task
      include Rake::DSL
      include Rake::CloudFormation

      def initialize(*args)
        super
        @region = 'us-east-1'
        @parameters = {}
        @capabilities = []
      end

      def self.define_task(args, &block)
        t = super
        if (t.is_a?(Stack))
          yield t if block_given?
          t.prepare
        end
        t
      end

      attr_accessor :template, :region
      attr_reader :parameters, :capabilities

      def prepare
        prerequisites << file(@template)
      end

      def needed?
        !cf(region).stacks[name].exists? or cf(region).stacks[name].status != 'CREATE_COMPLETE'
      end

      def execute(*args)
        super
        options = {}
        unless parameters.empty?
          options[:parameters] = parameters.inject({}) do |hash, (key, value)|
            if value.is_a?(String)
              hash[key] = value
            elsif value.is_a?(Proc)
              hash[key] = value.call
            else
              raise "Parameter value of unknown type: key=#{key.inspect} value=#{value.inspect}"
            end
            hash
          end
        end
        options[:capabilities] = capabilities unless capabilities.empty?
        puts "Creating CloudFormation stack: #{name}"
        cf(region).stacks.create(name, IO.read(template), options)
        while cf(region).stacks[name].status === 'CREATE_IN_PROGRESS'
          sleep 20
        end
        unless cf(region).stacks[name].status === 'CREATE_COMPLETE'
          raise "Stack creation failed"
        end
      end
    end

    def cf(region)
      AWS.config(
        :access_key_id => access_key_id,
        :secret_access_key => secret_access_key,
        :region => region
      )
      AWS::CloudFormation.new
    end

    def access_key_id
      credential_file_hash['AWKAccessKeyId']
    end

    def secret_access_key
      credential_file_hash['AWSSecretKey']
    end

    def credential_file_hash
      Hash[*File.read(ENV['AWS_CREDENTIAL_FILE']).split(/[=\n]/)]
    end
  end
end

def cfn_stack(args, &block)
  Rake::CloudFormation::Stack.define_task(args, &block)
end

def cfn_get_stack_output(stack_name, region, output_key)
  Rake::CloudFormation::Service.cf(region).stacks[stack_name].outputs.detect { |o| o.key === output_key }.value
end

def cfn_stack_output(*args)
  Proc.new { cfn_get_stack_output(*args) }
end
