module QueryTrace
  mattr_accessor :depth
  self.depth = 20
  
  def self.enabled?
    defined?(@@trace_queries) && @@trace_queries
  end
     
  def self.enable!
    ::ActiveRecord::ConnectionAdapters::AbstractAdapter.send(:include, QueryTrace) unless defined?(@@trace_queries)
    @@trace_queries = true
  end
  
  def self.disable!
    @@trace_queries = false
  end

  # Toggles query tracing on and off and returns a boolean indicating the new
  # state of query tracing (true for enabled, false for disabled).
  def self.toggle!
    enabled? ? disable! : enable!
    enabled?
  end
  
  def self.append_features(klass)
    super
    klass.class_eval do
      unless method_defined?(:log_info_without_trace)
        alias_method :log_info_without_trace, :log_info
        alias_method :log_info, :log_info_with_trace
      end
    end
    klass.class_eval %(
      def row_even
        @@row_even
      end
    )
  end
  
  def log_info_with_trace(sql, name, runtime)
    log_info_without_trace(sql, name, runtime)

    return unless @@trace_queries
    
    return unless @logger and @logger.debug?
    return if / Columns$/ =~ name

    @logger.debug(format_trace(Rails.backtrace_cleaner.clean(caller)[0..self.depth]))
  end
  
  def format_trace(trace)
    if ActiveRecord::Base.colorize_logging
      if row_even
        message_color = "35;2"
      else
        message_color = "36;2"
      end
      trace.collect{|t| "    \e[#{message_color}m#{t}\e[0m"}.join("\n")
    else
      trace.join("\n    ")
    end
  end
end

QueryTrace.enable! if ENV["QUERY_TRACE"]
