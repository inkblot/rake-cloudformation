# ex: syntax=ruby ts=2 sw=2 si et
require 'aws-sdk'

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
        @notification_arns = []
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
      attr_reader :parameters, :capabilities, :notification_arns

      def prepare
        prerequisites << file(@template)
      end

      def needed?
        begin
          cf(region).describe_stacks({stack_name: name}).stacks.first.stack_status != 'CREATE_COMPLETE'
        rescue
          true
        end
      end

      def execute(*args)
        super
        options = {
          stack_name: name,
          template_body: IO.read(template),
        }
        unless parameters.empty?
          options[:parameters] = parameters.inject([]) do |params, (key, value)|
            param = {
              :parameter_key => key
            }
            if value.is_a?(String)
              param[:parameter_value] = value
            elsif value.is_a?(Proc)
              param[:parameter_value] = value.call
            else
              raise "Parameter value of unknown type: key=#{key.inspect} value=#{value.inspect}"
            end
            params << param
            params
          end
        end
        options[:capabilities] = capabilities.to_a unless capabilities.empty?
        options[:notification_arns] = notification_arns unless notification_arns.empty?
        puts "Creating CloudFormation stack: #{name}"
        cf(region).create_stack(options)
        while cf(region).describe_stacks({stack_name: name}).stacks.first.stack_status === 'CREATE_IN_PROGRESS'
          sleep 20
        end
        unless cf(region).describe_stacks({stack_name: name}).stacks.first.stack_status === 'CREATE_COMPLETE'
          raise "Stack creation failed"
        end
      end
    end

    def cf(region)
      Aws::CloudFormation::Client.new(region: region)
    end
  end
end

def cfn_stack(args, &block)
  Rake::CloudFormation::Stack.define_task(args, &block)
end

def cfn_get_stack_output(stack_name, region, output_key)
  Rake::CloudFormation::Service.cf(region).describe_stacks({stack_name: stack_name}).stacks.first.outputs
    .detect { |o| o.output_key === output_key }.output_value
end

def cfn_stack_output(*args)
  Proc.new { cfn_get_stack_output(*args) }
end
