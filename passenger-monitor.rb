# -*- coding: utf-8 -*-

require 'ipaddr'
require 'phusion_passenger/admin_tools/server_instance'

class PassengerMonitor
  def initialize(app, opts={})
    @app = app
    raise ArgumentError, ":path and :allow options required" unless opts[:path] and opts[:allow]
    @path = opts[:path]
    @allow = opts[:allow].map{|s| IPAddr.new(s)}
  end

  def status_text(server)
    status = server.connect(:passenger_status){status.stats}
    [["Busy Processes (Active): ", status.active],
     ["Total Processes (Count): ", status.count],
     ["Max Processes: ", status.max],
     ["Global Queue Size: ", status.global_queue_size]].map{|l,v| l + v.to_i.to_s}.join("\n")
  end

  def call(env)
    if env['PATH_INFO'] == @path
      source = IPAddr.new(env['REMOTE_ADDR'])
      if @allow.inject(false){|r,a| r or a.include?(source)}
        servers = PhusionPassenger::AdminTools::ServerInstance.list
        if servers.size < 1
          [500, {}, ["passenger not running."]]
        elsif servers.size > 1
          env['QUERY_STRING'] =~ /pid=(\d+)/
          if $1 and PhusionPassenger::AdminTools::ServerInstance.for_pid($1.to_i)
            [200, {}, [status_text(PhusionPassenger::AdminTools::ServerInstance.for_pid($1.to_i))]]
          else
            [200, {}, ["<html><body><ul>" + servers.map{|s| "<li><a href='#{@path}?pid=#{s.pid}'>pid: #{s.pid}</a></li>" }.join]]
          end
        else
          [200, {}, [status_text(servers.first)]]
        end
      else
        [403, {}, ["source ip forbidden"]]
      end
    else
      @app.call(env)
    end
  end
end
