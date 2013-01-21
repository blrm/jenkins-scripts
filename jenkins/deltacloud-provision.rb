#!/usr/bin/ruby
require 'rubygems'
require 'deltacloud'
$client = DeltaCloud.new(*ARGV.slice(0,3))

instname, image_id, cpu, mem = ARGV.slice(3, ARGV.length)

def instbyname(name)
  begin
    return $client.instances().select { |i| i.name == name }.first
  rescue
    retry
  end 
end

def waitforcond(instname)
  inst = instbyname(instname)
  while (! yield inst)
    sleep(5)
    inst = instbyname(instname)
  end
  return inst
end

def waitforstate(instname, state)
  waitforcond(instname) { |i| i.state == state }
end

def ipv4addrs(instance)
  return instance.public_addresses.select { |a| a[:type] == "ipv4" }
end


begin
  existing = instbyname(instname)
  if (existing)
    if (existing.state == "RUNNING")
      existing.stop!
    end
    existing = waitforstate(instname, "STOPPED")
    
    begin
      existing.destroy!
    rescue       
      retry
    end
    
    waitforcond(instname) { |i| i.nil? }
  end


  $client.create_instance(image_id,
                          :name => instname,
                          :hwp_id => "SERVER",
                          :hwp_cpu => cpu,
                          :hwp_memory => mem)

  inst = waitforstate(instname, "STOPPED")
  
  inst.start!

  waitforstate(instname, "RUNNING")


  inst = waitforcond(instname) { |i| ipv4addrs(i).length > 0 }
           
  puts ipv4addrs(inst).first[:address]
rescue Exception => e
  puts e.backtrace
end
