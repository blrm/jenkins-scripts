#!/usr/bin/ruby
require 'rubygems'
require 'deltacloud'
require 'pp'
$client = DeltaCloud.new(*ARGV.slice(0,3))

instname, image_id, cpu, mem = ARGV.slice(3, ARGV.length)

def instbyname(name)
  retrycount=0
  begin
    puts("Retrieving instance " + name + " (if any)" + ", retry #" + retrycount.to_s)
    retrycount += 1
    return $client.instances().select { |i| i.name == name }.first
  rescue Exception => e
    puts("Couldn't retrieve instance " + name)
    puts(e.message)
    # puts(e.backtrace.inspect)
    sleep 20
    retry if retrycount < 5
    raise e
  end 
end

def waitforcond(instname)
  inst = instbyname(instname)
  puts("Instance: " + inst.to_s)
  while (! yield inst)
    sleep(20)
    inst = instbyname(instname)
    PP.pp(inst)
    puts("\n")
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
    
    destroyretrycount=0
    begin
      destroyretrycount += 1
      existing.destroy!
    rescue
      sleep 20
      retry if destroyretrycount < 5
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
           
  File.write(instname + ".address.txt", ipv4addrs(inst).first[:address])
rescue Exception => e
  puts e.message
  puts e.backtrace
end
